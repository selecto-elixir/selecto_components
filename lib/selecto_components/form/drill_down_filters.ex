defmodule SelectoComponents.Form.DrillDownFilters do
  @moduledoc """
  Handles filter creation logic for drill-down operations from aggregate views and charts.

  This module contains complex logic for:
  - Building filters from aggregate drill-down clicks
  - Handling date/time filters with various formats (YYYY, YYYY-MM, YYYY-MM-DD)
  - Processing bucket ranges (age buckets, numeric ranges)
  - Determining appropriate comparison operators for different field types
  """

  @doc """
  Build filter parameters for aggregate drill-down.

  Takes the clicked parameters and socket assigns, returns a map ready for view_from_params.
  """
  def build_agg_drill_down_params(params, socket) do
    base_params =
      case socket.assigns[:used_params] do
        map when is_map(map) -> map
        _ -> %{}
      end

    view_params =
      base_params
      |> Map.put("view_mode", "detail")
      |> Map.put("filters", build_filter_map(params, socket))

    view_params
  end

  @doc """
  Build filters map from indexed drill-down parameters.
  """
  def build_filter_map(params, socket) do
    build_filter_map_indexed(params, socket)
  end

  # New indexed format: field0/value0, field1/value1
  defp build_filter_map_indexed(params, socket) do
    existing = existing_filters(socket)
    specs = drill_down_filter_specs(params, socket)
    reused_refs = allocate_existing_filter_map_refs(existing, specs)
    cleaned_existing = drop_matching_filter_map_entries(existing, specs)

    Enum.zip(specs, reused_refs)
    |> Enum.reduce(cleaned_existing, fn {spec, reused_ref}, acc ->
      filter_key = reused_ref.key || UUID.uuid4()
      filter_uuid = reused_ref.uuid || filter_key
      filter_config = Map.put(spec.filter_config, "uuid", filter_uuid)
      Map.put(acc, filter_key, filter_config)
    end)
  end

  # Extract field0/value0, field1/value1 pairs from params
  defp extract_indexed_pairs(params) do
    # Find all field<N> keys
    params
    |> Enum.filter(fn {k, _v} -> String.starts_with?(k, "field") end)
    |> Enum.sort_by(fn {k, _v} -> k end)
    |> Enum.map(fn {field_key, field_name} ->
      # Extract index from "field0" -> "0"
      idx = String.replace_prefix(field_key, "field", "")
      value_key = "value#{idx}"
      value = Map.get(params, value_key, "")
      group_idx = Map.get(params, "gidx#{idx}")
      {field_name, value, group_idx}
    end)
  end

  defp existing_filters(socket) do
    Map.get(used_params_map(socket), "filters", %{})
  end

  defp used_params_map(socket) do
    case socket.assigns[:used_params] do
      map when is_map(map) -> map
      _ -> %{}
    end
  end

  defp find_field_group_config(used_params, field_name, group_idx) when is_map(used_params) do
    group_by_config = Map.get(used_params, "group_by", %{})

    find_field_group_config_in_collection(group_by_config, field_name, group_idx) ||
      find_graph_group_config(used_params, field_name, group_idx)
  end

  defp find_field_group_config(_used_params, _field_name, _group_idx), do: nil

  defp find_field_group_config_in_collection(config_map, field_name, group_idx)
       when is_map(config_map) do
    by_index = find_field_group_config_by_index(config_map, group_idx)

    if by_index do
      by_index
    else
      Enum.find_value(Map.values(config_map), fn config ->
        if Map.get(config, "field") == field_name do
          config
        else
          nil
        end
      end)
    end
  end

  defp find_field_group_config_in_collection(_config_map, _field_name, _group_idx), do: nil

  defp find_field_group_config_by_index(group_by_config, group_idx)
       when is_binary(group_idx) and group_idx != "" do
    Enum.find_value(Map.values(group_by_config), fn config ->
      cfg_idx = Map.get(config, "index") || to_string(Map.get(config, :index, ""))
      if cfg_idx == group_idx, do: config, else: nil
    end)
  end

  defp find_field_group_config_by_index(_group_by_config, _group_idx), do: nil

  defp find_graph_group_config(used_params, field_name, group_idx) do
    used_params
    |> graph_group_configs()
    |> Enum.find(fn %{global_index: global_index, config: config} ->
      global_index == group_idx || Map.get(config, "field") == field_name
    end)
    |> case do
      nil -> nil
      %{config: config} -> config
    end
  end

  defp graph_group_configs(used_params) do
    x_axis =
      used_params
      |> Map.get("x_axis", %{})
      |> ordered_field_configs()

    series =
      used_params
      |> Map.get("series", %{})
      |> ordered_field_configs()

    (x_axis ++ series)
    |> Enum.with_index()
    |> Enum.map(fn {config, global_index} ->
      %{global_index: Integer.to_string(global_index), config: config}
    end)
  end

  defp ordered_field_configs(configs) when is_map(configs) do
    configs
    |> Map.values()
    |> Enum.sort_by(fn config ->
      config
      |> Map.get("index", "0")
      |> to_string()
      |> String.to_integer()
    end)
  end

  defp ordered_field_configs(_configs), do: []

  @doc """
  Determine the appropriate comparison operator and values based on the clicked value format.

  Handles:
  - NULL values (creates IS_EMPTY filter)
  - Bucket ranges (1-10, 11+, Other)
  - Date formats (YYYY-MM-DD, YYYY-MM, YYYY)
  - Age buckets on date fields
  - Text-prefix buckets with optional article exclusion
  - Default equality
  """
  def determine_filter_comp_and_values(value, field_conf, drill_context) do
    context = normalize_drill_context(drill_context)

    case determine_grouped_date_filter(value, field_conf, context) do
      {comp, v1, v2} ->
        {comp, v1, v2}

      nil ->
        determine_filter_comp_and_values_default(value, field_conf, context)
    end
  end

  defp determine_filter_comp_and_values_default(value, field_conf, context) do
    cond do
      # Special marker for NULL values - create IS_EMPTY filter
      value == "__NULL__" ->
        {"IS_EMPTY", "", ""}

      context.format in ["custom_buckets", :custom_buckets] && field_conf &&
          Selecto.Temporal.date_like?(field_conf) ->
        handle_custom_date_bucket_range(value)

      # Text prefix buckets from aggregate group-by
      text_prefix_context?(context) ->
        handle_text_prefix_bucket(value, context)

      # YYYY-MM-DD format
      String.match?(value, ~r/^\d{4}-\d{2}-\d{2}$/) ->
        if field_conf && Selecto.Temporal.date_like?(field_conf) do
          {"DATE=", value, ""}
        else
          {"=", value, ""}
        end

      # YYYY-MM format
      String.match?(value, ~r/^\d{4}-\d{2}$/) ->
        handle_month_format(value, field_conf)

      # YYYY-Q format (Postgres to_char quarter output, e.g. 2026-1)
      String.match?(value, ~r/^\d{4}-[1-4]$/) ->
        handle_quarter_format(value, field_conf)

      # YYYY format
      String.match?(value, ~r/^\d{4}$/) ->
        handle_year_format(value, field_conf)

      # Bucket range patterns
      String.match?(value, ~r/^\d+-\d+$/) || String.match?(value, ~r/^\d+\+$/) || value == "Other" ->
        handle_bucket_range(value, field_conf, context)

      # Default datetime handling
      field_conf != nil ->
        handle_datetime_field(value, field_conf)

      # No field configuration
      true ->
        {"=", value, ""}
    end
  end

  defp determine_grouped_date_filter(value, field_conf, context) do
    format = context.format |> to_string()

    cond do
      format == "YYYY-WW" and String.match?(value, ~r/^\d{4}-\d{2}$/) ->
        handle_week_of_year_format(value, field_conf)

      format == "YYYY-Q" and String.match?(value, ~r/^\d{4}-[1-4]$/) ->
        handle_quarter_format(value, field_conf)

      format == "MM" and String.match?(value, ~r/^\d{1,2}$/) ->
        {"MONTH_OF_YEAR", value |> String.trim() |> String.to_integer() |> Integer.to_string(),
         ""}

      format == "DD" and String.match?(value, ~r/^\d{1,2}$/) ->
        {"DAY_OF_MONTH", value |> String.trim() |> String.to_integer() |> Integer.to_string(), ""}

      format == "D" and String.match?(value, ~r/^\d$/) ->
        {"WEEKDAY_SUN1", value |> String.trim() |> String.to_integer() |> Integer.to_string(), ""}

      format == "HH24" and String.match?(value, ~r/^\d{1,2}$/) ->
        {"HOUR_OF_DAY", value |> String.trim() |> String.to_integer() |> Integer.to_string(), ""}

      true ->
        nil
    end
  end

  defp handle_week_of_year_format(value, field_conf) do
    if field_conf && Selecto.Temporal.date_like?(field_conf) do
      {"WEEK_OF_YEAR", value, ""}
    else
      {"=", value, ""}
    end
  end

  defp normalize_drill_context(context) when is_boolean(context) do
    %{
      is_age_bucket: context,
      format: if(context, do: "age_buckets", else: nil),
      prefix_length: 2,
      exclude_articles: true
    }
  end

  defp normalize_drill_context(context) when is_map(context) do
    %{
      is_age_bucket:
        Map.get(context, :is_age_bucket) || Map.get(context, "is_age_bucket") || false,
      format: Map.get(context, :format) || Map.get(context, "format"),
      prefix_length:
        parse_prefix_length(
          Map.get(context, :prefix_length) || Map.get(context, "prefix_length"),
          2
        ),
      exclude_articles:
        parse_boolean(
          Map.get(context, :exclude_articles) || Map.get(context, "exclude_articles"),
          true
        )
    }
  end

  defp normalize_drill_context(_context) do
    %{is_age_bucket: false, format: nil, prefix_length: 2, exclude_articles: true}
  end

  defp text_prefix_context?(%{format: format}) do
    format in ["text_prefix", :text_prefix]
  end

  defp handle_text_prefix_bucket(value, context) do
    trimmed = value |> to_string() |> String.trim()

    cond do
      trimmed == "Other" ->
        {"TEXT_PREFIX_OTHER", "", ""}

      trimmed == "" ->
        {"TEXT_PREFIX_OTHER", "", ""}

      true ->
        prefix =
          trimmed
          |> String.downcase()
          |> String.slice(0, context.prefix_length)

        {"STARTS", prefix, ""}
    end
  end

  defp handle_bucket_range(value, field_conf, %{format: format, is_age_bucket: is_age_bucket}) do
    cond do
      format in ["custom_buckets", :custom_buckets] && field_conf &&
          Selecto.Temporal.date_like?(field_conf) ->
        handle_custom_date_bucket_range(value)

      format in ["year_buckets", :year_buckets] && field_conf &&
          Selecto.Temporal.date_like?(field_conf) ->
        handle_year_bucket_range(value)

      is_age_bucket && field_conf &&
          Selecto.Temporal.date_like?(field_conf) ->
        handle_age_bucket_range(value)

      true ->
        handle_numeric_bucket_range(value)
    end
  end

  defp handle_custom_date_bucket_range(value) do
    today = Date.utc_today()

    cond do
      String.downcase(value) == "today" ->
        {"DATE=", Date.to_iso8601(today), ""}

      String.downcase(value) == "yesterday" ->
        {"DATE=", Date.to_iso8601(Date.add(today, -1)), ""}

      String.downcase(value) == "tomorrow" ->
        {"DATE=", Date.to_iso8601(Date.add(today, 1)), ""}

      String.match?(value, ~r/^(\d+)-(\d+)$/) ->
        [min_days_str, max_days_str] = String.split(value, "-")
        max_days = String.to_integer(max_days_str)
        min_days = String.to_integer(min_days_str)
        start_date = Date.add(today, -max_days)
        end_date = Date.add(today, -(min_days - 1))
        {"DATE_BETWEEN", Date.to_iso8601(start_date), Date.to_iso8601(end_date)}

      String.match?(value, ~r/^(\d+)\+$/) ->
        days = value |> String.replace("+", "") |> String.to_integer()
        cutoff_date = Date.add(today, -days)
        {"<=", Date.to_iso8601(cutoff_date), ""}

      value == "Other" ->
        {"=", "", ""}

      true ->
        {"=", value, ""}
    end
  end

  defp handle_age_bucket_range(value) do
    today = Date.utc_today()

    cond do
      String.match?(value, ~r/^(\d+)-(\d+)$/) ->
        [min_days_str, max_days_str] = String.split(value, "-")
        max_days = String.to_integer(max_days_str)
        min_days = String.to_integer(min_days_str)
        start_date = Date.add(today, -max_days)
        end_date = Date.add(today, -(min_days - 1))
        {"DATE_BETWEEN", Date.to_iso8601(start_date), Date.to_iso8601(end_date)}

      String.match?(value, ~r/^(\d+)\+$/) ->
        days = value |> String.replace("+", "") |> String.to_integer()
        cutoff_date = Date.add(today, -days)
        {"<=", Date.to_iso8601(cutoff_date), ""}

      value == "Other" ->
        {"=", "", ""}

      true ->
        {"=", value, ""}
    end
  end

  defp handle_year_bucket_range(value) do
    cond do
      String.match?(value, ~r/^(\d+)-(\d+)$/) ->
        [min_year, max_year] = String.split(value, "-")
        {"DATE_BETWEEN", "#{min_year}-01-01", "#{String.to_integer(max_year) + 1}-01-01"}

      String.match?(value, ~r/^(\d+)\+$/) ->
        min_year = String.replace(value, "+", "")
        {">=", "#{min_year}-01-01", ""}

      value == "Other" ->
        {"=", "", ""}

      true ->
        {"=", value, ""}
    end
  end

  defp handle_numeric_bucket_range(value) do
    cond do
      String.match?(value, ~r/^(\d+)-(\d+)$/) ->
        [min_str, max_str] = String.split(value, "-")
        {"BETWEEN", min_str, max_str}

      String.match?(value, ~r/^(\d+)\+$/) ->
        min_str = String.replace(value, "+", "")
        {">=", min_str, ""}

      value == "Other" ->
        {"=", "", ""}

      true ->
        {"=", value, ""}
    end
  end

  defp drill_context_from_group_config(nil), do: normalize_drill_context(%{})

  defp drill_context_from_group_config(config) when is_map(config) do
    format = Map.get(config, "format") || Map.get(config, :format)

    normalize_drill_context(%{
      format: format,
      is_age_bucket: format == "age_buckets",
      prefix_length: Map.get(config, "prefix_length") || Map.get(config, :prefix_length),
      exclude_articles:
        Map.get(config, "exclude_articles") || Map.get(config, :exclude_articles, true)
    })
  end

  defp maybe_put_text_prefix_options(filter_config, context, comp_mode)

  defp maybe_put_text_prefix_options(filter_config, context, comp_mode)
       when comp_mode in ["STARTS", "TEXT_PREFIX_OTHER"] do
    filter_config
    |> Map.put("bucket_format", "text_prefix")
    |> Map.put("prefix_length", Integer.to_string(context.prefix_length))
    |> Map.put("exclude_articles", if(context.exclude_articles, do: "true", else: "false"))
    |> Map.put("ignore_case", if(context.exclude_articles, do: "true", else: "false"))
  end

  defp maybe_put_text_prefix_options(filter_config, _context, _comp_mode), do: filter_config

  defp parse_prefix_length(value, _default) when is_integer(value) and value > 0,
    do: min(value, 10)

  defp parse_prefix_length(value, default) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {parsed, ""} when parsed > 0 -> min(parsed, 10)
      _ -> default
    end
  end

  defp parse_prefix_length(_value, default), do: default

  defp parse_boolean(value, _default) when value in [true, "true", "TRUE", "on", "1", 1], do: true

  defp parse_boolean(value, _default) when value in [false, "false", "FALSE", "off", "0", 0],
    do: false

  defp parse_boolean(nil, default), do: default
  defp parse_boolean(_value, default), do: default

  defp handle_month_format(value, field_conf) do
    if field_conf && Selecto.Temporal.date_like?(field_conf) do
      [year_str, month_str] = String.split(value, "-")
      {year, _} = Integer.parse(year_str)
      {month, _} = Integer.parse(month_str)

      start_date = Date.new!(year, month, 1)
      days_in_month = Date.days_in_month(start_date)
      end_date = Date.new!(year, month, days_in_month) |> Date.add(1)

      {"DATE_BETWEEN", Date.to_iso8601(start_date), Date.to_iso8601(end_date)}
    else
      {"=", value, ""}
    end
  end

  defp handle_year_format(value, field_conf) do
    if field_conf && Selecto.Temporal.date_like?(field_conf) do
      {year, _} = Integer.parse(value)
      start_date = Date.new!(year, 1, 1)
      end_date = Date.new!(year + 1, 1, 1)

      {"DATE_BETWEEN", Date.to_iso8601(start_date), Date.to_iso8601(end_date)}
    else
      {"=", value, ""}
    end
  end

  defp handle_quarter_format(value, field_conf) do
    if field_conf && Selecto.Temporal.date_like?(field_conf) do
      [year_str, quarter_str] = String.split(value, "-")
      {year, _} = Integer.parse(year_str)
      {quarter, _} = Integer.parse(quarter_str)

      start_month = (quarter - 1) * 3 + 1
      start_date = Date.new!(year, start_month, 1)

      {end_year, end_month} =
        case start_month + 3 do
          m when m <= 12 -> {year, m}
          m -> {year + 1, m - 12}
        end

      end_date = Date.new!(end_year, end_month, 1)

      {"DATE_BETWEEN", Date.to_iso8601(start_date), Date.to_iso8601(end_date)}
    else
      {"=", value, ""}
    end
  end

  defp handle_datetime_field(value, field_conf) do
    field_type =
      Selecto.Temporal.date_like_type(field_conf) || Map.get(field_conf, :type, :string)

    case field_type do
      x when x in [:utc_datetime, :naive_datetime] ->
        {v1_parsed, v2_parsed} =
          Selecto.Helpers.Date.val_to_dates(%{"value" => value, "value2" => ""})

        {"=", v1_parsed, v2_parsed}

      _ ->
        {"=", value, ""}
    end
  end

  @doc """
  Build filter tuples for view_config from drill-down parameters (simpler version for view_config.filters).
  """
  def build_filter_tuples(params, socket) do
    existing_filters = get_in(socket.assigns, [:view_config, :filters]) || []
    specs = drill_down_filter_specs(params, socket)
    reused_refs = allocate_existing_filter_tuple_refs(existing_filters, specs)

    Enum.zip(specs, reused_refs)
    |> Enum.map(fn {spec, reused_ref} ->
      filter_uuid = reused_ref.uuid || UUID.uuid4()
      filter_section = reused_ref.section || "filters"
      {filter_uuid, filter_section, Map.put(spec.filter_config, "uuid", filter_uuid)}
    end)
  end

  defp drill_down_filter_specs(params, socket) do
    params
    |> extract_indexed_pairs()
    |> Enum.map(fn {field_name, value, group_idx} ->
      build_drill_down_filter_spec(socket, field_name, value, group_idx)
    end)
  end

  defp build_drill_down_filter_spec(socket, field_name, value, group_idx) do
    conf =
      socket.assigns.selecto
      |> Selecto.field(field_name)
      |> then(&find_join_mode_field(socket.assigns.selecto, field_name, &1))

    used_params = used_params_map(socket)
    field_group_config = find_field_group_config(used_params, field_name, group_idx)
    drill_context = drill_context_from_group_config(field_group_config)

    {comp_mode, v1, v2} =
      determine_filter_comp_and_values(value, conf, drill_context)
      |> normalize_join_mode_filter_comp(conf)

    actual_filter_field =
      cond do
        conf && Map.get(conf, :group_by_filter) -> Map.get(conf, :group_by_filter)
        true -> field_name
      end
      |> to_string()

    filter_config =
      %{
        "comp" => comp_mode,
        "filter" => actual_filter_field,
        "index" => "0",
        "promote" => "true",
        "section" => "filters",
        "value" => v1,
        "value2" => v2,
        "value_start" => if(comp_mode in ["DATE_BETWEEN", "BETWEEN"], do: v1, else: nil),
        "value_end" => if(comp_mode in ["DATE_BETWEEN", "BETWEEN"], do: v2, else: nil)
      }
      |> maybe_put_text_prefix_options(drill_context, comp_mode)

    %{
      filter_config: filter_config,
      match_fields: matching_filter_fields(field_name, actual_filter_field)
    }
  end

  defp allocate_existing_filter_map_refs(existing_filters, specs) when is_map(existing_filters) do
    {refs, _used_keys} =
      Enum.map_reduce(specs, MapSet.new(), fn spec, used_keys ->
        case Enum.find(existing_filters, fn {key, filter} ->
               not MapSet.member?(used_keys, key) and filter_matches_spec?(filter, spec)
             end) do
          {key, filter} ->
            {%{key: key, uuid: Map.get(filter, "uuid", key)}, MapSet.put(used_keys, key)}

          nil ->
            {%{key: nil, uuid: nil}, used_keys}
        end
      end)

    refs
  end

  defp allocate_existing_filter_map_refs(_existing_filters, specs) do
    Enum.map(specs, fn _ -> %{key: nil, uuid: nil} end)
  end

  defp drop_matching_filter_map_entries(existing_filters, specs) when is_map(existing_filters) do
    Enum.reject(existing_filters, fn {_key, filter} ->
      Enum.any?(specs, &filter_matches_spec?(filter, &1))
    end)
    |> Enum.into(%{})
  end

  defp drop_matching_filter_map_entries(_existing_filters, _specs), do: %{}

  defp allocate_existing_filter_tuple_refs(existing_filters, specs)
       when is_list(existing_filters) do
    {refs, _used_uuids} =
      Enum.map_reduce(specs, MapSet.new(), fn spec, used_uuids ->
        case Enum.find(existing_filters, fn
               {uuid, "filters", filter} ->
                 not MapSet.member?(used_uuids, to_string(uuid)) and
                   filter_matches_spec?(filter, spec)

               [uuid, "filters", filter] ->
                 not MapSet.member?(used_uuids, to_string(uuid)) and
                   filter_matches_spec?(filter, spec)

               _ ->
                 false
             end) do
          {uuid, section, filter} ->
            {%{uuid: uuid, section: section, filter: filter},
             MapSet.put(used_uuids, to_string(uuid))}

          [uuid, section, filter] ->
            {%{uuid: uuid, section: section, filter: filter},
             MapSet.put(used_uuids, to_string(uuid))}

          nil ->
            {%{uuid: nil, section: nil, filter: nil}, used_uuids}
        end
      end)

    refs
  end

  defp allocate_existing_filter_tuple_refs(_existing_filters, specs) do
    Enum.map(specs, fn _ -> %{uuid: nil, section: nil, filter: nil} end)
  end

  defp matching_filter_fields(field_name, actual_filter_field) do
    [field_name, actual_filter_field]
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&to_string/1)
    |> MapSet.new()
  end

  defp filter_matches_spec?(filter, spec) when is_map(filter) do
    existing_field = Map.get(filter, "filter") || Map.get(filter, :filter)
    not is_nil(existing_field) and MapSet.member?(spec.match_fields, to_string(existing_field))
  end

  defp filter_matches_spec?(_filter, _spec), do: false

  defp normalize_join_mode_filter_comp({comp_mode, v1, v2}, %{
         join_mode: join_mode,
         filter_type: :multi_select_id
       })
       when join_mode in [:lookup, :star, :tag] do
    normalized_comp =
      case comp_mode do
        "=" -> "IN"
        "!=" -> "NOT IN"
        "IS_EMPTY" -> "IS NULL"
        "IS_NOT_EMPTY" -> "IS NOT NULL"
        other -> other
      end

    {normalized_comp, v1, v2}
  end

  defp normalize_join_mode_filter_comp(result, _conf), do: result

  defp find_join_mode_field(selecto, field_name, original_conf) do
    cond do
      # Case 1: field_name contains "." like "category.id"
      is_binary(field_name) and String.contains?(field_name, ".") ->
        [schema_name, field_part] = String.split(field_name, ".", parts: 2)

        # Check if this looks like an ID field
        if field_part in ["id", "category_id", "supplier_id", "shipper_id"] or
             String.ends_with?(field_part, "_id") do
          # Get the domain to search for join_mode fields
          domain = Selecto.domain(selecto)

          schema_atom =
            try do
              String.to_existing_atom(schema_name)
            rescue
              ArgumentError -> nil
            end

          if schema_atom do
            schema_config = get_in(domain, [:schemas, schema_atom])

            if schema_config do
              # Search through columns to find one with join_mode metadata matching this ID field
              columns = Map.get(schema_config, :columns, %{})

              found_field =
                Enum.find_value(columns, fn {col_name, col_config} ->
                  # Check if this column has join_mode and its id_field matches our field
                  join_mode = Map.get(col_config, :join_mode)
                  id_field = Map.get(col_config, :id_field)
                  filter_type = Map.get(col_config, :filter_type)

                  # Match if this column is configured for join mode and references our ID field
                  if join_mode in [:lookup, :star, :tag] and filter_type == :multi_select_id and
                       (id_field == :id or Atom.to_string(id_field) == field_part) do
                    # Return the full field name for this display field
                    {col_name, col_config}
                  else
                    nil
                  end
                end)

              case found_field do
                {display_col_name, display_col_config} ->
                  # Build the qualified field name
                  qualified_name = "#{schema_name}.#{display_col_name}"

                  # Merge the display field config with necessary metadata
                  Map.merge(original_conf || %{}, display_col_config)
                  |> Map.put(:_display_field_name, qualified_name)
                  # Remember we're actually filtering on the ID field
                  |> Map.put(:_filter_on_field, field_name)

                nil ->
                  original_conf
              end
            else
              original_conf
            end
          else
            original_conf
          end
        else
          original_conf
        end

      # Case 2: field_name is a foreign key like "category_id" (no dot)
      is_binary(field_name) and String.ends_with?(field_name, "_id") ->
        domain = Selecto.domain(selecto)
        schemas = Map.get(domain, :schemas, %{})

        # Search all schemas for a field with group_by_filter matching this field_name
        found_field =
          Enum.find_value(schemas, fn {schema_name, schema_config} ->
            columns = Map.get(schema_config, :columns, %{})

            Enum.find_value(columns, fn {col_name, col_config} ->
              join_mode = Map.get(col_config, :join_mode)
              filter_type = Map.get(col_config, :filter_type)
              group_by_filter = Map.get(col_config, :group_by_filter)

              # Match if this column has group_by_filter pointing to our field
              if join_mode in [:lookup, :star, :tag] and
                   filter_type == :multi_select_id and
                   group_by_filter == field_name do
                {schema_name, col_name, col_config}
              else
                nil
              end
            end)
          end)

        case found_field do
          {schema_name, display_col_name, display_col_config} ->
            qualified_name = "#{schema_name}.#{display_col_name}"

            # Merge the display field config with necessary metadata
            Map.merge(original_conf || %{}, display_col_config)
            |> Map.put(:_display_field_name, qualified_name)
            # Filter stays on the foreign key field
            |> Map.put(:_filter_on_field, field_name)

          nil ->
            original_conf
        end

      true ->
        original_conf
    end
  end
end
