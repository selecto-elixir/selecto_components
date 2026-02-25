defmodule SelectoComponents.Views.Aggregate.Process do
  alias SelectoComponents.SafeAtom

  def param_to_state(params, _v) do
    %{
      group_by: SelectoComponents.Views.view_param_process(params, "group_by", "field"),
      aggregate: SelectoComponents.Views.view_param_process(params, "aggregate", "field")
    }
  end

  def initial_state(selecto, _v) do
    %{
      aggregate:
        Map.get(Selecto.domain(selecto), :default_aggregate, [])
        |> SelectoComponents.Helpers.build_initial_state(),
      group_by:
        Map.get(Selecto.domain(selecto), :default_group_by, [])
        |> SelectoComponents.Helpers.build_initial_state()
    }
  end

  def view(_opt, params, columns, filtered, selecto) do
    group_by_params = Map.get(params, "group_by", %{})

    aggregate =
      Map.get(params, "aggregate", %{})
      |> aggregates(columns)

    group_by = group_by_params |> group_by(columns, selecto)

    # Wrap only text-compatible group-by selectors in COALESCE to display '[NULL]'.
    # Applying string fallback to non-text fields (integer, enum, array, etc.) causes SQL type errors.
    group_by_with_coalesce = Enum.map(group_by, fn {col, sel} ->
      coalesced_sel =
        case sel do
          {:field, field_expr, alias} ->
            if should_coalesce_field?(col, selecto) do
              {:field, {:coalesce, [field_expr, {:literal, "[NULL]"}]}, alias}
            else
              sel
            end

          {:row, [display_field, id_field], alias}
          when is_binary(display_field) or is_atom(display_field) ->
            if row_display_coalesce?(display_field, columns, selecto) do
              {:row, [{:coalesce, [display_field, {:literal, "[NULL]"}]}, id_field], alias}
            else
              sel
            end

          _other ->
            sel
        end

      {col, coalesced_sel}
    end)

    selected = Enum.map(group_by_with_coalesce, fn {_c, sel} -> sel end) ++ aggregate

    view_set = %{
       groups: group_by_with_coalesce,
       gb_params: group_by_params,
       aggregates: aggregate,
       selected: selected,
       filtered: filtered,
       group_by: [
         {:rollup, Enum.map(1..Enum.count(group_by), fn g -> {:literal_position, g} end)}
       ],
       ### when using rollup, we need to workaround postgres bug. Currently implemented in Selecto builder
       order_by: Enum.map(1..Enum.count(group_by), fn g -> {:literal_position, g} end)
     }

    {view_set, %{}}
  end

  def group_by(group_by, columns, selecto) do
    group_by
    |> Map.values()
    |> Enum.sort(fn a, b -> String.to_integer(Map.get(a, "index", "0")) <= String.to_integer(Map.get(b, "index", "0")) end)
    |> Enum.map(fn e ->
      field_name = Map.get(e, "field")

      # Get column metadata - need to check domain schemas for join mode metadata
      # Selecto.field() doesn't return custom metadata from joined schema columns
      col = if selecto && String.contains?(to_string(field_name), ".") do
        # This is a joined field like "category.category_name"
        # Parse it to get schema and field name
        [schema_name, field_only] = String.split(to_string(field_name), ".", parts: 2)
        schema_atom = String.to_existing_atom(schema_name)
        field_atom = String.to_existing_atom(field_only)

        # Look up the column metadata from domain.schemas[schema].columns[field]
        domain = Selecto.domain(selecto)
        schema_col_metadata = get_in(domain, [:schemas, schema_atom, :columns, field_atom])

        if schema_col_metadata do
          # Merge with basic field info and ensure colid is set
          field_info = Selecto.field(selecto, field_name) || %{name: field_name, type: :string}
          Map.merge(field_info, schema_col_metadata)
          |> Map.put(:colid, field_name)
        else
          # Fall back to Selecto.field or columns map
          field_info = Selecto.field(selecto, field_name)
          if field_info do
            Map.put_new(field_info, :colid, field_name)
          else
            columns[field_name]
          end
        end
      else
        # Source table field or no selecto - use columns map
        columns[field_name]
      end
      # ????
      alias =
        case Map.get(e, "alias") do
          "" -> Map.get(e, "field")
          nil -> Map.get(e, "field")
          _ -> Map.get(e, "alias")
        end

      ### Group by filter, _select, format...
      sel =
        if Map.get(col, :group_by_filter_select) do
          case col.group_by_filter_select do
            x when is_list(x) -> {:row, col.group_by_filter_select, alias}
            x when is_function(x) -> {:row, col.group_by_filter_select.(e), alias}
          end
        else
          case col.type do
            x when x in [:naive_datetime, :utc_datetime, :date] ->
              {:field, datetime_gb_proc(col, e), alias}

            x when x in [:integer, :float, :decimal, :id] ->
              # Check if buckets format is specified
              format = Map.get(e, "format")
              bucket_ranges = Map.get(e, "bucket_ranges")

              if format == "buckets" and is_binary(bucket_ranges) and bucket_ranges != "" do
                field_with_alias = if String.contains?(to_string(col.colid), ".") do
                  to_string(col.colid)
                else
                  "selecto_root.#{col.colid}"
                end
                alias SelectoComponents.Helpers.BucketParser
                case_sql = BucketParser.generate_bucket_case_sql(
                  field_with_alias,
                  bucket_ranges,
                  :integer
                )
                {:field, {:raw_sql, case_sql}, alias}
              else
                {:field, col.colid, alias}
              end

            :custom_column ->
              case Map.get(col, :requires_select) do
                x when is_list(x) -> {:row, col.requires_select, alias}
                x when is_function(x) -> {:row, col.requires_select.(e), alias}
                nil -> {col.colid, alias}
              end

            _ ->
              # Check for join mode (lookup, star, tag) to select both display and ID
              case Map.get(col, :join_mode) do
                mode when mode in [:lookup, :star, :tag] ->
                  # Special join modes: select both display field and ID field as a row
                  id_field = Map.get(col, :id_field)
                  display_field = col.colid

                  if id_field do
                    # Extract table prefix from display field (e.g., "category.category_name" -> "category")
                    {table_prefix, _field_name} = extract_table_and_field(display_field)

                    # Build ID field reference
                    id_colid = if table_prefix do
                      "#{table_prefix}.#{id_field}"
                    else
                      id_field
                    end

                    # Return ROW(display_field, id_field) to get both values
                    {:row, [display_field, id_colid], alias}
                  else
                    # Fallback if no id_field specified
                    {:field, col.colid, alias}
                  end

                _ ->
                  # Normal columns: just select the field
                  {:field, col.colid, alias}
              end
          end
        end

      {col, sel}
    end)
  end

  # Extract table and field name from a column ID
  # Examples: "category.category_name" -> {"category", "category_name"}
  #           :category_name -> {nil, "category_name"}
  #           "category_name" -> {nil, "category_name"}
  defp extract_table_and_field(colid) do
    colid_str = to_string(colid)
    case String.split(colid_str, ".", parts: 2) do
      [table, field] -> {table, field}
      [field] -> {nil, field}
    end
  end

  defp text_type?(type) do
    type in [:string, :text, :citext]
  end

  defp row_display_coalesce?(display_field, columns, selecto) do
    col =
      Map.get(columns, display_field) ||
        Map.get(columns, to_string(display_field))

    case col do
      nil -> false
      col -> should_coalesce_field?(col, selecto)
    end
  end

  defp should_coalesce_field?(col, selecto) do
    resolved_col = resolve_column_metadata(col, selecto)
    text_type?(Map.get(resolved_col, :type)) and not enum_field?(resolved_col, selecto)
  end

  defp resolve_column_metadata(col, selecto) do
    colid = Map.get(col, :colid)

    if is_binary(colid) or is_atom(colid) do
      Selecto.field(selecto, colid) || col
    else
      col
    end
  end

  defp enum_field?(%{field: field, requires_join: join_ref}, selecto) do
    with {:ok, field_atom} <- to_existing_atom_safe(field),
         {:ok, schema_module} <- schema_module_for_join(join_ref, selecto),
         true <- function_exported?(schema_module, :__schema__, 2),
         {:parameterized, {Ecto.Enum, _}} <- schema_module.__schema__(:type, field_atom) do
      true
    else
      _ -> false
    end
  end

  defp enum_field?(_, _), do: false

  defp schema_module_for_join(:selecto_root, selecto) do
    case get_in(Selecto.domain(selecto), [:source, :schema_module]) do
      module when is_atom(module) -> {:ok, module}
      _ -> :error
    end
  end

  defp schema_module_for_join(join_ref, selecto) when is_atom(join_ref) do
    case get_in(Selecto.domain(selecto), [:schemas, join_ref, :schema_module]) do
      module when is_atom(module) -> {:ok, module}
      _ -> :error
    end
  end

  defp schema_module_for_join(join_ref, selecto) when is_binary(join_ref) do
    case to_existing_atom_safe(join_ref) do
      {:ok, join_atom} -> schema_module_for_join(join_atom, selecto)
      :error -> :error
    end
  end

  defp schema_module_for_join(_, _), do: :error

  defp to_existing_atom_safe(value) when is_atom(value), do: {:ok, value}

  defp to_existing_atom_safe(value) when is_binary(value) do
    try do
      {:ok, String.to_existing_atom(value)}
    rescue
      ArgumentError -> :error
    end
  end

  defp to_existing_atom_safe(_), do: :error

  defp datetime_gb_proc(col, config) do
    format = Map.get(config, "format")
    bucket_ranges = Map.get(config, "bucket_ranges")

    case format do
      # Standard date formats
      x when x in ~w(YYYY-MM-DD YYYY-MM YYYY YYYY-WW YYYY-Q MM DD D HH24) ->
        {:to_char, {col.colid, x}}

      # Bucket formats
      "age_buckets" when is_binary(bucket_ranges) and bucket_ranges != "" ->
        # Generate CASE expression for age buckets in group by
        field_with_alias = if String.contains?(to_string(col.colid), ".") do
          # For qualified names like "category.updated_at", extract just the column part
          # and use the pivot table alias "t"
          [_table, column] = String.split(to_string(col.colid), ".", parts: 2)
          "t.#{column}"
        else
          "selecto_root.#{col.colid}"
        end
        alias SelectoComponents.Helpers.BucketParser
        case_sql = BucketParser.generate_bucket_case_sql(
          "EXTRACT(DAY FROM AGE(CURRENT_DATE, #{field_with_alias}))",
          bucket_ranges,
          :integer
        )
        {:raw_sql, case_sql}

      "custom_buckets" when is_binary(bucket_ranges) and bucket_ranges != "" ->
        # Generate CASE expression for custom date buckets
        field_with_alias = if String.contains?(to_string(col.colid), ".") do
          # For qualified names like "category.updated_at", extract just the column part
          # and use the pivot table alias "t"
          [_table, column] = String.split(to_string(col.colid), ".", parts: 2)
          "t.#{column}"
        else
          "selecto_root.#{col.colid}"
        end
        alias SelectoComponents.Helpers.BucketParser
        case_sql = BucketParser.generate_bucket_case_sql(
          field_with_alias,
          bucket_ranges,
          :date
        )
        {:raw_sql, case_sql}

      _ ->
        # Default to day format
        {:to_char, {col.colid, "YYYY-MM-DD"}}
    end
  end

  def aggregates(aggregates, _columns) do
    result = aggregates
    |> Map.values()
    |> Enum.sort(fn a, b -> String.to_integer(Map.get(a, "index", "0")) <= String.to_integer(Map.get(b, "index", "0")) end)
    |> Enum.flat_map(fn e ->
      # ????
      alias =
        case Map.get(e, "alias") do
          "" -> Map.get(e, "field")
          nil -> Map.get(e, "field")
          _ -> Map.get(e, "alias")
        end

      # Handle special formats like buckets and age_buckets
      format = Map.get(e, "format", "count")
      field = Map.get(e, "field")
      bucket_ranges = Map.get(e, "bucket_ranges")

      case format do
        "age_buckets" when is_binary(bucket_ranges) and bucket_ranges != "" ->
          # Generate multiple columns for age buckets
          alias SelectoComponents.Helpers.BucketParser

          # Get bucket labels to create separate columns
          # Remove "Other" from the labels since users should explicitly ask for what they want
          labels = BucketParser.get_bucket_labels(bucket_ranges)
          |> Enum.reject(fn label -> label == "Other" end)

          # Return multiple aggregate specs, one for each bucket
          # Use a special aggregate type that preserves field references
          labels
          |> Enum.with_index()
          |> Enum.map(fn {label, index} ->
            # Create a prettier display name for the bucket column
            # Put the user's alias only at the beginning of the first column
            pretty_label = case label do
              "Other" ->
                "Other"
              _ ->
                # Parse the label to determine the format
                cond do
                  # Single day: "0" -> "0 days" or "1 day"
                  Regex.match?(~r/^\d+$/, label) ->
                    days = String.to_integer(label)
                    if days == 1 do
                      "1 day"
                    else
                      "#{label} days"
                    end

                  # Range: "3-10" -> "3-10 days"
                  Regex.match?(~r/^\d+-\d+$/, label) ->
                    "#{label} days"

                  # Open-ended: "11+" -> "11+ days"
                  Regex.match?(~r/^\d+\+$/, label) ->
                    "#{label} days"

                  # Default fallback
                  true ->
                    label
                end
            end

            # Add the alias prefix only to the first column
            pretty_label = if index == 0 && alias != "" && alias != nil do
              "#{alias}: #{pretty_label}"
            else
              pretty_label
            end

            # Parse the bucket range for this label
            ranges = BucketParser.parse_bucket_ranges(bucket_ranges)

            # Find the range for this label
            range_spec = Enum.find(ranges, fn {_, _, l} -> l == label end)

            aggregate_spec = case range_spec do
              {min, max, _} when is_integer(min) and is_integer(max) ->
                if min == max do
                  {:count_age_bucket, field, min, min}
                else
                  {:count_age_bucket, field, min, max}
                end
              {min, :infinity, _} ->
                {:count_age_bucket, field, min, :infinity}
              {:negative_infinity, max, _} ->
                {:count_age_bucket, field, :negative_infinity, max}
              _ ->
                # Should not happen since we filtered out "Other" from labels
                nil
            end

            # Only return the field spec if we have a valid aggregate_spec
            if aggregate_spec do
              {:field, aggregate_spec, pretty_label}
            else
              nil
            end
          end)
          |> Enum.reject(&is_nil/1)  # Remove any nil entries

        "buckets" when is_binary(bucket_ranges) and bucket_ranges != "" ->
          # Generate multiple columns for numeric buckets
          alias SelectoComponents.Helpers.BucketParser

          # Get bucket labels to create separate columns
          # Remove "Other" from the labels since users should explicitly ask for what they want
          labels = BucketParser.get_bucket_labels(bucket_ranges)
          |> Enum.reject(fn label -> label == "Other" end)

          # Return multiple aggregate specs, one for each bucket
          labels
          |> Enum.with_index()
          |> Enum.map(fn {label, index} ->
            # Create a prettier display name for the bucket column
            # Put the user's alias only at the beginning of the first column
            pretty_label = case label do
              "Other" ->
                "Other"
              _ ->
                label  # Numeric buckets use the label as-is
            end

            # Add the alias prefix only to the first column
            pretty_label = if index == 0 && alias != "" && alias != nil do
              "#{alias}: #{pretty_label}"
            else
              pretty_label
            end

            # Parse the bucket range for this label
            ranges = BucketParser.parse_bucket_ranges(bucket_ranges)

            # Find the range for this label
            range_spec = Enum.find(ranges, fn {_, _, l} -> l == label end)

            aggregate_spec = case range_spec do
              {min, max, _} when is_integer(min) and is_integer(max) ->
                if min == max do
                  {:count_bucket, field, min, min}
                else
                  {:count_bucket, field, min, max}
                end
              {min, :infinity, _} ->
                {:count_bucket, field, min, :infinity}
              {:negative_infinity, max, _} ->
                {:count_bucket, field, :negative_infinity, max}
              _ ->
                # Should not happen since we filtered out "Other" from labels
                nil
            end

            # Only return the field spec if we have a valid aggregate_spec
            if aggregate_spec do
              {:field, aggregate_spec, pretty_label}
            else
              nil
            end
          end)
          |> Enum.reject(&is_nil/1)  # Remove any nil entries

        format_str ->
          # Standard aggregates - return as single item list for consistency
          # Use SafeAtom to prevent atom table exhaustion from user input
          [{:field, {SafeAtom.to_aggregate_function(format_str), field}, alias}]
      end
    end)

    result
  end
end
