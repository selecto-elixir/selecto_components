defmodule SelectoComponents.Views.Graph.Process do
  alias SelectoComponents.Helpers.BucketParser
  alias SelectoComponents.SafeAtom

  @doc """
  Converts form parameters to view state for form rendering
  """
  def param_to_state(params, _view) do
    %{
      x_axis: SelectoComponents.Views.view_param_process(params, "x_axis", "field"),
      y_axis: SelectoComponents.Views.view_param_process(params, "y_axis", "field"),
      series: SelectoComponents.Views.view_param_process(params, "series", "field"),
      chart_type: Map.get(params, "chart_type", "bar"),
      options: Map.get(params, "options", %{})
    }
  end

  @doc """
  Initial state when view is created without params
  """
  def initial_state(selecto, _view) do
    domain = Selecto.domain(selecto)

    %{
      x_axis:
        Map.get(domain, :default_graph_x_axis, [])
        |> SelectoComponents.Helpers.build_initial_state(),
      y_axis:
        Map.get(domain, :default_graph_y_axis, [])
        |> SelectoComponents.Helpers.build_initial_state(),
      series:
        Map.get(domain, :default_graph_series, [])
        |> SelectoComponents.Helpers.build_initial_state(),
      chart_type: Map.get(domain, :default_chart_type, "bar"),
      options: Map.get(domain, :default_chart_options, %{})
    }
  end

  @doc """
  Converts parameters into Selecto query structure
  """
  def view(_opt, params, columns, filtered, _selecto) do
    x_axis_params = Map.get(params, "x_axis", %{})
    y_axis_params = Map.get(params, "y_axis", %{})
    series_params = Map.get(params, "series", %{})
    chart_type = Map.get(params, "chart_type", "bar")
    presentation_context = runtime_presentation_context(params)

    # Process X-axis (grouping fields)
    x_axis_fields = x_axis_params |> group_by_fields(columns, presentation_context)

    # Process Y-axis (aggregate fields)
    y_axis_defs = y_axis_params |> aggregate_defs(columns)
    y_axis_fields = Enum.map(y_axis_defs, & &1.select_field)

    # Process Series (optional secondary grouping)
    series_fields = series_params |> group_by_fields(columns, presentation_context)

    # Combine all grouping fields (x_axis + series)
    all_group_by = x_axis_fields ++ series_fields

    # Build selected fields for query
    selected_fields = Enum.map(all_group_by, fn {_col, sel} -> sel end) ++ y_axis_fields

    {%{
       groups: all_group_by,
       x_axis_groups: x_axis_fields,
       series_groups: series_fields,
       aggregates: y_axis_fields,
       graph_series_defs: y_axis_defs,
       selected: selected_fields,
       filtered: filtered,
       chart_type: chart_type,
       graph_options: Map.get(params, "options", %{}),
       group_by: Enum.map(all_group_by, fn {_col, sel} -> sel end),
       order_by:
         case all_group_by do
           [] ->
             []

           group_fields ->
             Enum.map(1..Enum.count(group_fields), fn g -> {:literal_position, g} end)
         end
     }, %{}}
  end

  @doc """
  Process group by fields (for X-axis and Series)
  """
  def group_by_fields(field_params, columns, presentation_context \\ %{}) do
    field_params
    |> Map.values()
    |> Enum.sort(fn a, b -> String.to_integer(a["index"]) <= String.to_integer(b["index"]) end)
    |> Enum.map(fn field_config ->
      col = columns[field_config["field"]]

      # Skip if column not found
      if col == nil do
        nil
      else
        col =
          if is_map(col) do
            linked? = truthy_param?(Map.get(field_config, "linked_to_next"))

            col
            |> maybe_set_group_format(Map.get(field_config, "format"))
            |> Map.put(:linked_to_next, linked?)
            |> Map.put("linked_to_next", linked?)
          else
            col
          end

        # Generate alias
        alias_name =
          case field_config["alias"] do
            "" -> field_config["field"]
            nil -> field_config["field"]
            custom_alias -> custom_alias
          end

        # Build field selector based on column type
        field_selector =
          case Selecto.Temporal.date_like_type(col) || col.type do
            x
            when x in [:naive_datetime, :utc_datetime, :naive_datetime_usec, :utc_datetime_usec] ->
              {:field, datetime_group_by_processor(col, field_config, presentation_context),
               alias_name}

            :custom_column ->
              case Map.get(col, :requires_select) do
                x when is_list(x) -> {:row, col.requires_select, alias_name}
                x when is_function(x) -> {:row, col.requires_select.(field_config), alias_name}
                nil -> {col.colid, alias_name}
              end

            _ ->
              {:field, col.colid, alias_name}
          end

        {col, field_selector}
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp truthy_param?(value) when value in [true, "true", "on", "1", 1], do: true
  defp truthy_param?(_), do: false

  @doc """
  Process aggregate fields (for Y-axis)
  """
  def aggregate_fields(aggregate_params, columns) do
    aggregate_params
    |> aggregate_defs(columns)
    |> Enum.map(& &1.select_field)
  end

  def aggregate_defs(aggregate_params, columns) do
    aggregate_params
    |> Map.values()
    |> Enum.sort(fn a, b -> String.to_integer(a["index"]) <= String.to_integer(b["index"]) end)
    |> Enum.map(fn field_config ->
      column_def = Map.get(columns, field_config["field"])

      # Generate alias
      alias_name =
        case field_config["alias"] do
          "" -> field_config["field"]
          nil -> field_config["field"]
          custom_alias -> custom_alias
        end

      # Build aggregate function
      # Use SafeAtom to prevent atom table exhaustion from user input
      aggregate_function =
        SafeAtom.to_aggregate_function(
          case field_config["function"] do
            nil -> "count"
            "" -> "count"
            func -> func
          end
        )

      series_type =
        case field_config["series_type"] do
          "line" -> "line"
          "bar" -> "bar"
          _ -> "auto"
        end

      axis =
        case field_config["axis"] do
          "right" -> "right"
          _ -> "left"
        end

      color =
        case field_config["color"] do
          x when is_binary(x) and x != "" -> x
          _ -> nil
        end

      %{
        select_field: {:field, {aggregate_function, field_config["field"]}, alias_name},
        alias: alias_name,
        field: field_config["field"],
        function: aggregate_function,
        series_type: series_type,
        axis: axis,
        color: color,
        column_def: column_def
      }
    end)
  end

  defp maybe_set_group_format(col, format)
       when is_map(col) and is_binary(format) and format != "" do
    col
    |> Map.put(:group_format, format)
    |> Map.put("group_format", format)
  end

  defp maybe_set_group_format(col, _format), do: col

  # Process datetime fields for grouping (Year, Month, Day, etc.)
  defp datetime_group_by_processor(col, config, presentation_context) do
    format = config["format"]
    bucket_ranges = config["bucket_ranges"]
    field_with_alias = graph_field_ref(col.colid)

    case format do
      format when format in ~w(YYYY-MM-DD YYYY-WW YYYY-MM YYYY-Q YYYY MM DD D HH24) ->
        maybe_timezone_aware_datetime_selector(
          col,
          field_with_alias,
          format,
          presentation_context
        )

      "age_buckets" when is_binary(bucket_ranges) and bucket_ranges != "" ->
        case_sql =
          BucketParser.generate_bucket_case_sql(
            "(CURRENT_DATE - DATE(#{field_with_alias}))",
            bucket_ranges,
            :integer
          )

        {:raw_sql, case_sql}

      "custom_buckets" when is_binary(bucket_ranges) and bucket_ranges != "" ->
        case_sql =
          BucketParser.generate_bucket_case_sql(
            field_with_alias,
            bucket_ranges,
            :date
          )

        {:raw_sql, case_sql}

      "year_buckets" when is_binary(bucket_ranges) and bucket_ranges != "" ->
        case_sql =
          BucketParser.generate_bucket_case_sql(
            year_bucket_extract_sql(col, field_with_alias, presentation_context),
            bucket_ranges,
            :integer
          )

        {:raw_sql, case_sql}

      _ ->
        col.colid
    end
  end

  defp graph_field_ref(colid) do
    colid_str = to_string(colid)
    if String.contains?(colid_str, "."), do: colid_str, else: "selecto_root." <> colid_str
  end

  defp runtime_presentation_context(params) when is_map(params) do
    Map.get(params, "_presentation_context", %{})
  end

  defp runtime_presentation_context(_params), do: %{}

  defp maybe_timezone_aware_datetime_selector(col, field_ref, format, presentation_context) do
    if timezone_grouping_applicable?(col, presentation_context) do
      {:raw_sql, timezone_aware_to_char_sql(col, field_ref, format, presentation_context)}
    else
      {:to_char, {col.colid, format}}
    end
  end

  defp year_bucket_extract_sql(col, field_ref, presentation_context) do
    if timezone_grouping_applicable?(col, presentation_context) do
      "EXTRACT(YEAR FROM #{timezone_grouping_expression(col, field_ref, presentation_context)})"
    else
      "EXTRACT(YEAR FROM #{field_ref})"
    end
  end

  defp timezone_grouping_applicable?(col, presentation_context) do
    Selecto.Presentation.temporal_kind(col) == :instant and
      is_binary(runtime_timezone(presentation_context)) and
      runtime_timezone(presentation_context) != ""
  end

  defp timezone_aware_to_char_sql(col, field_ref, format, presentation_context) do
    "to_char(#{timezone_grouping_expression(col, field_ref, presentation_context)}, '#{format}')"
  end

  defp timezone_grouping_expression(col, field_ref, presentation_context) do
    timezone = runtime_timezone(presentation_context)

    case Selecto.Temporal.epoch_storage(col) do
      :unix_seconds -> "to_timestamp(#{field_ref}) AT TIME ZONE '#{timezone}'"
      :unix_milliseconds -> "to_timestamp((#{field_ref}) / 1000.0) AT TIME ZONE '#{timezone}'"
      _ -> "#{field_ref} AT TIME ZONE '#{timezone}'"
    end
  end

  defp runtime_timezone(presentation_context) when is_map(presentation_context) do
    case Map.get(presentation_context, :timezone, Map.get(presentation_context, "timezone")) do
      timezone when is_binary(timezone) and timezone != "" -> timezone
      _ -> nil
    end
  end

  defp runtime_timezone(_presentation_context), do: nil
end
