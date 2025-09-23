defmodule SelectoComponents.Views.Aggregate.Process do
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

  def view(_opt, params, columns, filtered, _selecto) do
    group_by_params = Map.get(params, "group_by", %{})

    aggregate =
      Map.get(params, "aggregate", %{})
      |> aggregates(columns)

    group_by = group_by_params |> group_by(columns)

    {%{
       groups: group_by,
       gb_params: group_by_params,
       aggregates: aggregate,
       selected: Enum.map(group_by, fn {_c, sel} -> sel end) ++ aggregate,
       filtered: filtered,
       group_by: [
         {:rollup, Enum.map(1..Enum.count(group_by), fn g -> {:literal_position, g} end)}
       ],
       ### when using rollup, we need to workaround postgres bug. Currently implemented in Selecto builder
       order_by: Enum.map(1..Enum.count(group_by), fn g -> {:literal_position, g} end)
     }, %{}}
  end

  def group_by(group_by, columns) do
    group_by
    |> Map.values()
    |> Enum.sort(fn a, b -> String.to_integer(Map.get(a, "index", "0")) <= String.to_integer(Map.get(b, "index", "0")) end)
    |> Enum.map(fn e ->
      col = columns[Map.get(e, "field")]
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
              # col.colid
              {:field, col.colid, alias}
          end
        end

      {col, sel}
    end)
  end

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
    aggregates
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
          labels = BucketParser.get_bucket_labels(bucket_ranges)

          # Return multiple aggregate specs, one for each bucket
          # Use a special aggregate type that preserves field references
          Enum.map(labels, fn label ->
            bucket_alias = "#{alias}_#{String.replace(label, ~r/[^a-zA-Z0-9_]/, "_")}"

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
                # For "Other" bucket
                {:count_age_bucket_other, field, bucket_ranges}
            end

            {:field, aggregate_spec, bucket_alias}
          end)

        "buckets" when is_binary(bucket_ranges) and bucket_ranges != "" ->
          # Generate multiple columns for numeric buckets
          alias SelectoComponents.Helpers.BucketParser

          # Get bucket labels to create separate columns
          labels = BucketParser.get_bucket_labels(bucket_ranges)

          # Return multiple aggregate specs, one for each bucket
          Enum.map(labels, fn label ->
            bucket_alias = "#{alias}_#{String.replace(label, ~r/[^a-zA-Z0-9_]/, "_")}"

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
                # For "Other" bucket
                {:count_bucket_other, field, bucket_ranges}
            end

            {:field, aggregate_spec, bucket_alias}
          end)

        format_str ->
          # Standard aggregates - return as single item list for consistency
          [{:field, {String.to_atom(format_str), field}, alias}]
      end
    end)
  end
end
