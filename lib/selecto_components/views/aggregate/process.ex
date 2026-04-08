defmodule SelectoComponents.Views.Aggregate.Process do
  alias SelectoComponents.Helpers.BucketParser
  alias SelectoComponents.SchemaUtils
  alias SelectoComponents.SafeAtom
  alias SelectoComponents.Views.Aggregate.Options

  def param_to_state(params, _v) do
    %{
      group_by: SelectoComponents.Views.view_param_process(params, "group_by", "field"),
      aggregate: SelectoComponents.Views.view_param_process(params, "aggregate", "field"),
      per_page: Options.normalize_per_page_param(Map.get(params, "aggregate_per_page")),
      grid: truthy_param?(Map.get(params, "aggregate_grid")),
      grid_colorize: truthy_param?(Map.get(params, "aggregate_grid_colorize")),
      grid_color_scale:
        Options.normalize_grid_color_scale_mode(Map.get(params, "aggregate_grid_color_scale"))
    }
  end

  def initial_state(selecto, _v) do
    %{
      aggregate:
        Map.get(Selecto.domain(selecto), :default_aggregate, [])
        |> SelectoComponents.Helpers.build_initial_state(),
      group_by:
        Map.get(Selecto.domain(selecto), :default_group_by, [])
        |> SelectoComponents.Helpers.build_initial_state(),
      per_page: Options.default_per_page(),
      grid: false,
      grid_colorize: false,
      grid_color_scale: Options.default_grid_color_scale_mode()
    }
  end

  def view(_opt, params, columns, filtered, selecto) do
    group_by_params = Map.get(params, "group_by", %{})
    per_page = Options.normalize_per_page_param(Map.get(params, "aggregate_per_page"))
    grid = truthy_param?(Map.get(params, "aggregate_grid"))
    grid_colorize = truthy_param?(Map.get(params, "aggregate_grid_colorize"))

    grid_color_scale =
      Options.normalize_grid_color_scale_mode(Map.get(params, "aggregate_grid_color_scale"))

    aggregate =
      Map.get(params, "aggregate", %{})
      |> aggregates(columns)

    group_by = group_by_params |> group_by(columns, selecto)

    # Wrap only text-compatible group-by selectors in COALESCE to display '[NULL]'.
    # Applying string fallback to non-text fields (integer, enum, array, etc.) causes SQL type errors.
    group_by_with_coalesce =
      Enum.map(group_by, fn {col, sel} ->
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

    literal_positions =
      case Enum.count(group_by) do
        0 -> []
        count -> Enum.map(1..count, fn g -> {:literal_position, g} end)
      end

    rollup_group_by =
      case Enum.map(group_by_with_coalesce, fn {_col, sel} -> sel end) do
        [] -> []
        selectors -> [{:rollup, selectors}]
      end

    view_set = %{
      groups: group_by_with_coalesce,
      gb_params: group_by_params,
      aggregates: aggregate,
      selected: selected,
      filtered: filtered,
      group_by: rollup_group_by,
      ### when using rollup, we need to workaround postgres bug. Currently implemented in Selecto builder
      order_by: literal_positions
    }

    {view_set,
     %{
       per_page: per_page,
       grid_enabled: grid,
       grid_colorize: grid_colorize,
       grid_color_scale: grid_color_scale
     }}
  end

  defp truthy_param?(value) when value in [true, "true", "on", "1", 1], do: true
  defp truthy_param?(_), do: false

  def group_by(group_by, columns, selecto) do
    group_by
    |> Map.values()
    |> Enum.sort(fn a, b ->
      String.to_integer(Map.get(a, "index", "0")) <= String.to_integer(Map.get(b, "index", "0"))
    end)
    |> Enum.map(fn e ->
      field_name = Map.get(e, "field")

      # Get column metadata - need to check domain schemas for join mode metadata
      # Selecto.field() doesn't return custom metadata from joined schema columns
      col =
        if selecto && String.contains?(to_string(field_name), ".") do
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

      col =
        if is_map(col) do
          col
          |> Map.put(:group_format, Map.get(e, "format"))
          |> Map.put("group_format", Map.get(e, "format"))
        else
          col
        end

      col =
        if is_map(col) and selecto do
          SchemaUtils.with_resolved_type(selecto, col)
        else
          col
        end

      # ????
      alias =
        case Map.get(e, "alias") do
          "" -> default_field_label(Map.get(e, "field"), col, columns)
          nil -> default_field_label(Map.get(e, "field"), col, columns)
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
          case Selecto.Temporal.date_like_type(col) || col.type do
            x when x in [:naive_datetime, :utc_datetime, :date] ->
              {:field, datetime_gb_proc(col, e), alias}

            x when x in [:integer, :float, :decimal, :id] ->
              # Check if buckets format is specified
              format = Map.get(e, "format")
              bucket_ranges = Map.get(e, "bucket_ranges")

              if format == "buckets" and is_binary(bucket_ranges) and bucket_ranges != "" do
                field_with_alias =
                  if String.contains?(to_string(col.colid), ".") do
                    to_string(col.colid)
                  else
                    "selecto_root.#{col.colid}"
                  end

                case_sql =
                  BucketParser.generate_bucket_case_sql(
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

            x when x in [:string, :text, :citext] ->
              format = Map.get(e, "format")

              if format == "text_prefix" do
                prefix_length = Map.get(e, "prefix_length", "2")
                exclude_articles = Map.get(e, "exclude_articles", "true")

                case_sql =
                  BucketParser.generate_text_prefix_case_sql(
                    col.colid,
                    %{
                      "prefix_length" => prefix_length,
                      "exclude_articles" => exclude_articles
                    }
                  )

                {:field, {:raw_sql, case_sql}, alias}
              else
                default_group_selector(col, alias)
              end

            _ ->
              default_group_selector(col, alias)
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

  defp default_group_selector(col, alias) do
    case Map.get(col, :join_mode) do
      mode when mode in [:lookup, :star, :tag] ->
        # Special join modes: select both display field and ID field as a row
        id_field = Map.get(col, :id_field)
        display_field = col.colid

        if id_field do
          # Extract table prefix from display field (e.g., "category.category_name" -> "category")
          {table_prefix, _field_name} = extract_table_and_field(display_field)

          # Build ID field reference
          id_colid =
            if table_prefix do
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
    field_name = Map.get(resolved_col, :field) || Map.get(col, :field)
    colid = Map.get(resolved_col, :colid) || Map.get(col, :colid)
    text_type = text_type?(Map.get(resolved_col, :type))
    enum_by_name = enum_field_name_any_schema?(field_name, selecto)
    root_enum = root_enum_field?(col, selecto)
    enum_by_metadata = enum_field?(resolved_col, selecto)
    filter_type = Map.get(resolved_col, :filter_type) || Map.get(resolved_col, "filter_type")

    id_like =
      filter_type == :multi_select_id or
        filter_type == "multi_select_id" or
        id_like_name?(field_name) or
        id_like_name?(colid)

    text_type and not enum_by_name and not root_enum and not enum_by_metadata and not id_like
  end

  defp resolve_column_metadata(col, selecto) do
    SchemaUtils.with_resolved_type(selecto, col)
  end

  defp enum_field?(col, selecto) do
    enum_field_by_metadata?(col, selecto) or enum_field_by_colid?(col, selecto)
  end

  defp enum_field_by_metadata?(%{field: field, requires_join: join_ref}, selecto) do
    with {:ok, field_atom} <- to_existing_atom_safe(field),
         {:ok, schema_module} <- schema_module_for_join(join_ref, selecto),
         true <- Code.ensure_loaded?(schema_module),
         {:parameterized, {Ecto.Enum, _}} <- schema_module.__schema__(:type, field_atom) do
      true
    else
      _ -> false
    end
  end

  defp enum_field_by_metadata?(_, _), do: false

  defp enum_field_by_colid?(%{colid: colid}, selecto) when is_binary(colid) or is_atom(colid) do
    case Selecto.field(selecto, colid) do
      nil -> false
      metadata -> enum_field_by_metadata?(metadata, selecto)
    end
  end

  defp enum_field_by_colid?(_, _), do: false

  defp root_enum_field?(%{field: field, requires_join: :selecto_root}, selecto) do
    with {:ok, field_atom} <- to_existing_atom_safe(field),
         module when is_atom(module) <- get_in(Selecto.domain(selecto), [:source, :schema_module]),
         true <- Code.ensure_loaded?(module),
         {:parameterized, {Ecto.Enum, _}} <- module.__schema__(:type, field_atom) do
      true
    else
      _ -> false
    end
  end

  defp root_enum_field?(_, _), do: false

  defp id_like_name?(nil), do: false

  defp id_like_name?(name) do
    case to_string(name) do
      "id" -> true
      value -> String.ends_with?(value, ".id") or String.ends_with?(value, "_id")
    end
  end

  defp enum_field_name_any_schema?(field, selecto) do
    with {:ok, field_atom} <- to_existing_atom_safe(field) do
      domain = Selecto.domain(selecto)

      source_module = get_in(domain, [:source, :schema_module])

      schema_modules =
        (get_in(domain, [:schemas]) || %{})
        |> Map.values()
        |> Enum.map(&Map.get(&1, :schema_module))

      ([source_module] ++ schema_modules)
      |> Enum.any?(fn
        module when is_atom(module) ->
          Code.ensure_loaded?(module) and
            match?({:parameterized, {Ecto.Enum, _}}, module.__schema__(:type, field_atom))

        _ ->
          false
      end)
    else
      _ -> false
    end
  end

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
        # Generate CASE expression for age buckets in group by.
        # Joined fields need their fully-qualified reference, not the pivot alias.
        field_with_alias = aggregate_field_ref(col.colid)

        alias SelectoComponents.Helpers.BucketParser

        case_sql =
          BucketParser.generate_bucket_case_sql(
            "EXTRACT(DAY FROM AGE(CURRENT_DATE, #{field_with_alias}))",
            bucket_ranges,
            :integer
          )

        {:raw_sql, case_sql}

      "custom_buckets" when is_binary(bucket_ranges) and bucket_ranges != "" ->
        field_with_alias = aggregate_field_ref(col.colid)

        alias SelectoComponents.Helpers.BucketParser

        case_sql =
          BucketParser.generate_bucket_case_sql(
            field_with_alias,
            bucket_ranges,
            :date
          )

        {:raw_sql, case_sql}

      "year_buckets" when is_binary(bucket_ranges) and bucket_ranges != "" ->
        field_with_alias = aggregate_field_ref(col.colid)

        alias SelectoComponents.Helpers.BucketParser

        case_sql =
          BucketParser.generate_bucket_case_sql(
            "EXTRACT(YEAR FROM #{field_with_alias})",
            bucket_ranges,
            :integer
          )

        {:raw_sql, case_sql}

      _ ->
        # Default to day format
        {:to_char, {col.colid, "YYYY-MM-DD"}}
    end
  end

  defp aggregate_field_ref(colid) do
    colid_str = to_string(colid)
    if String.contains?(colid_str, "."), do: colid_str, else: "selecto_root." <> colid_str
  end

  def aggregates(aggregates, columns) do
    result =
      aggregates
      |> Map.values()
      |> Enum.sort(fn a, b ->
        String.to_integer(Map.get(a, "index", "0")) <= String.to_integer(Map.get(b, "index", "0"))
      end)
      |> Enum.flat_map(fn e ->
        # ????
        # Handle special formats like buckets and age_buckets
        format = Map.get(e, "format")
        field = Map.get(e, "field")
        bucket_ranges = Map.get(e, "bucket_ranges")
        ignore_nulls_in_sum = truthy_param?(Map.get(e, "ignore_nulls_in_sum"))

        function_name =
          case Map.get(e, "function", Map.get(e, "format")) do
            nil -> "count"
            "" -> "count"
            function -> function
          end

        aggregate_alias =
          case Map.get(e, "alias") do
            "" -> default_aggregate_label(field, columns, function_name)
            nil -> default_aggregate_label(field, columns, function_name)
            custom -> custom
          end

        case format do
          "age_buckets" when is_binary(bucket_ranges) and bucket_ranges != "" ->
            # Generate multiple columns for age buckets
            alias SelectoComponents.Helpers.BucketParser

            # Get bucket labels to create separate columns
            # Remove "Other" from the labels since users should explicitly ask for what they want
            labels =
              BucketParser.get_bucket_labels(bucket_ranges)
              |> Enum.reject(fn label -> label == "Other" end)

            # Return multiple aggregate specs, one for each bucket
            # Use a special aggregate type that preserves field references
            labels
            |> Enum.with_index()
            |> Enum.map(fn {label, index} ->
              # Create a prettier display name for the bucket column
              # Put the user's alias only at the beginning of the first column
              pretty_label =
                case label do
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
              pretty_label =
                if index == 0 && aggregate_alias != "" && aggregate_alias != nil do
                  "#{aggregate_alias}: #{pretty_label}"
                else
                  pretty_label
                end

              # Parse the bucket range for this label
              ranges = BucketParser.parse_bucket_ranges(bucket_ranges)

              # Find the range for this label
              range_spec = Enum.find(ranges, fn {_, _, l} -> l == label end)

              aggregate_spec =
                case range_spec do
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
            # Remove any nil entries
            |> Enum.reject(&is_nil/1)

          "buckets" when is_binary(bucket_ranges) and bucket_ranges != "" ->
            # Generate multiple columns for numeric buckets
            alias SelectoComponents.Helpers.BucketParser

            # Get bucket labels to create separate columns
            # Remove "Other" from the labels since users should explicitly ask for what they want
            labels =
              BucketParser.get_bucket_labels(bucket_ranges)
              |> Enum.reject(fn label -> label == "Other" end)

            # Return multiple aggregate specs, one for each bucket
            labels
            |> Enum.with_index()
            |> Enum.map(fn {label, index} ->
              # Create a prettier display name for the bucket column
              # Put the user's alias only at the beginning of the first column
              pretty_label =
                case label do
                  "Other" ->
                    "Other"

                  _ ->
                    # Numeric buckets use the label as-is
                    label
                end

              # Add the alias prefix only to the first column
              pretty_label =
                if index == 0 && aggregate_alias != "" && aggregate_alias != nil do
                  "#{aggregate_alias}: #{pretty_label}"
                else
                  pretty_label
                end

              # Parse the bucket range for this label
              ranges = BucketParser.parse_bucket_ranges(bucket_ranges)

              # Find the range for this label
              range_spec = Enum.find(ranges, fn {_, _, l} -> l == label end)

              aggregate_spec =
                case range_spec do
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
            # Remove any nil entries
            |> Enum.reject(&is_nil/1)

          _other ->
            # Standard aggregates - return as single item list for consistency
            [
              {:field, aggregate_selector(function_name, field, ignore_nulls_in_sum),
               aggregate_alias}
            ]
        end
      end)

    result
  end

  defp aggregate_selector("true_count", field, _ignore_nulls_in_sum),
    do: {:count, field, {field, true}}

  defp aggregate_selector("false_count", field, _ignore_nulls_in_sum),
    do: {:count, field, {field, false}}

  defp aggregate_selector("sum", field, true),
    do: {:sum, {:coalesce, [field, 0]}}

  defp aggregate_selector(function_name, field, _ignore_nulls_in_sum),
    do: {SafeAtom.to_aggregate_function(function_name), field}

  defp default_aggregate_label(field, columns, function_name) do
    "#{default_field_label(field, lookup_column(columns, field), columns)} #{aggregate_function_label(function_name)}"
  end

  defp default_field_label(field, col, columns) do
    fallback = humanize_field_name(field)

    candidate =
      case lookup_column(columns, field) do
        %{name: name} when is_binary(name) and name != "" ->
          name

        %{"name" => name} when is_binary(name) and name != "" ->
          name

        _ ->
          cond do
            is_map(col) and is_binary(Map.get(col, :name)) and Map.get(col, :name) != "" ->
              Map.get(col, :name)

            is_map(col) and is_binary(Map.get(col, "name")) and Map.get(col, "name") != "" ->
              Map.get(col, "name")

            true ->
              nil
          end
      end

    normalize_field_label(candidate, fallback)
  end

  defp lookup_column(columns, field) when is_map(columns) do
    Map.get(columns, field) ||
      case field do
        field_name when is_binary(field_name) ->
          try do
            field_name
            |> String.to_existing_atom()
            |> then(&Map.get(columns, &1))
          rescue
            ArgumentError -> nil
          end

        field_name when is_atom(field_name) ->
          Map.get(columns, Atom.to_string(field_name))

        _ ->
          nil
      end
  end

  defp lookup_column(_columns, _field), do: nil

  defp humanize_field_name(field) do
    field
    |> to_string()
    |> String.split(".")
    |> List.last()
    |> String.split("_")
    |> Enum.map_join(" ", fn
      "id" -> "ID"
      part -> String.capitalize(part)
    end)
  end

  defp normalize_field_label(nil, fallback), do: fallback
  defp normalize_field_label("", fallback), do: fallback

  defp normalize_field_label(candidate, fallback) when is_binary(candidate) do
    cond do
      candidate == fallback ->
        fallback

      String.ends_with?(candidate, ": #{fallback}") ->
        fallback

      String.contains?(candidate, ": ") ->
        fallback

      String.contains?(candidate, "_") ->
        fallback

      true ->
        candidate
    end
  end

  defp aggregate_function_label(function_name) do
    case to_string(function_name) do
      "count_distinct" -> "Distinct Count"
      "count" -> "Count"
      "sum" -> "Sum"
      "avg" -> "Average"
      "min" -> "Min"
      "max" -> "Max"
      "buckets" -> "Buckets"
      "age_buckets" -> "Age Buckets"
      "year_buckets" -> "Year Buckets"
      "true_count" -> "True Count"
      "false_count" -> "False Count"
      value -> SelectoComponents.Helpers.aggregate_datetime_format_label(value)
    end
  end
end
