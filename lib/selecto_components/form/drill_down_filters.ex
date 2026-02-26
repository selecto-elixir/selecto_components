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
  Build filters map from drill-down parameters.

  Supports two formats:
  1. Legacy: phx-value-<fieldname> (doesn't work with dots in field names)
  2. New indexed: phx-value-field0/phx-value-value0, field1/value1, etc.
  """
  def build_filter_map(params, socket) do
    # Check if using new indexed format (field0, value0, field1, value1, etc.)
    has_indexed_params = Map.has_key?(params, "field0") || Map.has_key?(params, "field")

    if has_indexed_params do
      build_filter_map_indexed(params, socket)
    else
      build_filter_map_legacy(params, socket)
    end
  end

  # New indexed format: field0/value0, field1/value1
  defp build_filter_map_indexed(params, socket) do
    # Extract field/value pairs
    field_value_pairs = extract_indexed_pairs(params)

    Enum.reduce(
      field_value_pairs,
      existing_filters(socket),
      fn {field_name, v}, acc ->
        newid = UUID.uuid4()

        # Get field configuration
        conf = Selecto.field(socket.assigns.selecto, field_name)

        # If filtering on a join mode ID field, find the display field with metadata
        conf = find_join_mode_field(socket.assigns.selecto, field_name, conf)

        # Check if this is an age bucket field
        group_by_config = Map.get(used_params_map(socket), "group_by", %{})
        field_group_config = find_field_group_config(group_by_config, field_name)

        is_age_bucket =
          field_group_config && Map.get(field_group_config, "format") == "age_buckets"

        # Determine comparison mode and values based on format
        {comp_mode, v1, v2} = determine_filter_comp_and_values(v, conf, is_age_bucket)

        # Build filter configuration
        filter_config = %{
          "comp" => comp_mode,
          "filter" => field_name,
          "index" => "0",
          "section" => "filters",
          "uuid" => newid,
          "value" => v1,
          "value2" => v2,
          "value_start" => if(comp_mode in ["DATE_BETWEEN", "BETWEEN"], do: v1, else: nil),
          "value_end" => if(comp_mode in ["DATE_BETWEEN", "BETWEEN"], do: v2, else: nil)
        }

        # Use group_by_filter if configured
        actual_filter_field =
          if conf && Map.get(conf, :group_by_filter) do
            Map.get(conf, :group_by_filter)
          else
            field_name
          end

        # Update the filter config to use the correct field
        filter_config = Map.put(filter_config, "filter", actual_filter_field)
        Map.put(acc, newid, filter_config)
      end
    )
  end

  # Extract field0/value0, field1/value1 pairs from params
  defp extract_indexed_pairs(params) do
    # Find all field<N> keys
    params
    |> Enum.filter(fn {k, _v} -> String.starts_with?(k, "field") end)
    |> Enum.map(fn {field_key, field_name} ->
      # Extract index from "field0" -> "0"
      idx = String.replace_prefix(field_key, "field", "")
      value_key = "value#{idx}"
      value = Map.get(params, value_key, "")
      {field_name, value}
    end)
  end

  # Legacy format: phx-value-<fieldname>
  defp build_filter_map_legacy(params, socket) do
    Enum.reduce(
      params,
      existing_filters(socket),
      fn {f, v}, acc ->
        newid = UUID.uuid4()

        # Extract field name from phx-value-* parameters
        field_name = extract_field_name(f, socket)

        # Get field configuration
        conf = Selecto.field(socket.assigns.selecto, field_name)

        # If filtering on a join mode ID field, find the display field with metadata
        conf = find_join_mode_field(socket.assigns.selecto, field_name, conf)

        # Check if this is an age bucket field
        group_by_config = Map.get(used_params_map(socket), "group_by", %{})
        field_group_config = find_field_group_config(group_by_config, field_name)

        is_age_bucket =
          field_group_config && Map.get(field_group_config, "format") == "age_buckets"

        # Determine comparison mode and values based on format
        {comp_mode, v1, v2} = determine_filter_comp_and_values(v, conf, is_age_bucket)

        # Build filter configuration
        filter_config = %{
          "comp" => comp_mode,
          "filter" => field_name,
          "index" => "0",
          "section" => "filters",
          "uuid" => newid,
          "value" => v1,
          "value2" => v2,
          "value_start" => if(comp_mode in ["DATE_BETWEEN", "BETWEEN"], do: v1, else: nil),
          "value_end" => if(comp_mode in ["DATE_BETWEEN", "BETWEEN"], do: v2, else: nil)
        }

        # Use group_by_filter if configured
        actual_filter_field =
          if conf && Map.get(conf, :group_by_filter) do
            Map.get(conf, :group_by_filter)
          else
            field_name
          end

        # Update the filter config to use the correct field
        filter_config = Map.put(filter_config, "filter", actual_filter_field)
        Map.put(acc, newid, filter_config)
      end
    )
  end

  @doc """
  Extract field name from parameter key, handling phx-value-* prefixes.
  """
  def extract_field_name(field_key, socket) do
    case field_key do
      "phx-value-" <> actual_field ->
        actual_field

      "" ->
        fallback_field_from_group_by(socket)

      nil ->
        fallback_field_from_group_by(socket)

      _ ->
        field_key
    end
  end

  defp fallback_field_from_group_by(socket) do
    current_group_by =
      case socket.assigns[:used_params] do
        map when is_map(map) -> Map.get(map, "group_by", %{})
        _ -> %{}
      end

    first_group =
      current_group_by
      |> Map.values()
      |> Enum.sort(fn a, b ->
        String.to_integer(Map.get(a, "index", "0")) <= String.to_integer(Map.get(b, "index", "0"))
      end)
      |> List.first()

    case first_group do
      %{"field" => field} -> field
      # Fallback to basic field
      _ -> "id"
    end
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

  defp find_field_group_config(group_by_config, field_name) do
    Enum.find_value(Map.values(group_by_config), fn config ->
      if Map.get(config, "field") == field_name do
        config
      else
        nil
      end
    end)
  end

  @doc """
  Determine the appropriate comparison operator and values based on the clicked value format.

  Handles:
  - NULL values (creates IS_EMPTY filter)
  - Bucket ranges (1-10, 11+, Other)
  - Date formats (YYYY-MM-DD, YYYY-MM, YYYY)
  - Age buckets on date fields
  - Default equality
  """
  def determine_filter_comp_and_values(value, field_conf, is_age_bucket) do
    cond do
      # Special marker for NULL values - create IS_EMPTY filter
      value == "__NULL__" ->
        {"IS_EMPTY", "", ""}

      # YYYY-MM-DD format
      String.match?(value, ~r/^\d{4}-\d{2}-\d{2}$/) ->
        if field_conf && Map.get(field_conf, :type) in [:utc_datetime, :naive_datetime, :date] do
          {"DATE=", value, ""}
        else
          {"=", value, ""}
        end

      # YYYY-MM format
      String.match?(value, ~r/^\d{4}-\d{2}$/) ->
        handle_month_format(value, field_conf)

      # YYYY format
      String.match?(value, ~r/^\d{4}$/) ->
        handle_year_format(value, field_conf)

      # Bucket range patterns
      String.match?(value, ~r/^\d+-\d+$/) || String.match?(value, ~r/^\d+\+$/) || value == "Other" ->
        handle_bucket_range(value, field_conf, is_age_bucket)

      # Default datetime handling
      field_conf != nil ->
        handle_datetime_field(value, field_conf)

      # No field configuration
      true ->
        {"=", value, ""}
    end
  end

  defp handle_bucket_range(value, field_conf, is_age_bucket) do
    if is_age_bucket && field_conf &&
         Map.get(field_conf, :type) in [:utc_datetime, :naive_datetime, :date] do
      # Age buckets on date fields - convert to date ranges
      today = Date.utc_today()

      cond do
        # Range like "1-10" or "0-10"
        String.match?(value, ~r/^(\d+)-(\d+)$/) ->
          [min_days_str, max_days_str] = String.split(value, "-")
          max_days = String.to_integer(max_days_str)
          min_days = String.to_integer(min_days_str)
          start_date = Date.add(today, -(max_days + 1))
          end_date = Date.add(today, -min_days)
          {"DATE_BETWEEN", Date.to_iso8601(start_date), Date.to_iso8601(end_date)}

        # Open-ended range like "11+"
        String.match?(value, ~r/^(\d+)\+$/) ->
          days = value |> String.replace("+", "") |> String.to_integer()
          cutoff_date = Date.add(today, -days)
          {"<=", Date.to_iso8601(cutoff_date), ""}

        # "Other" bucket
        value == "Other" ->
          {"=", "", ""}

        true ->
          {"=", value, ""}
      end
    else
      # Numeric buckets
      cond do
        # Range like "1-10"
        String.match?(value, ~r/^(\d+)-(\d+)$/) ->
          [min_str, max_str] = String.split(value, "-")
          {"BETWEEN", min_str, max_str}

        # Open-ended range like "11+"
        String.match?(value, ~r/^(\d+)\+$/) ->
          min_str = String.replace(value, "+", "")
          {">=", min_str, ""}

        # "Other" bucket
        value == "Other" ->
          {"=", "", ""}

        true ->
          {"=", value, ""}
      end
    end
  end

  defp handle_month_format(value, field_conf) do
    if field_conf && Map.get(field_conf, :type) in [:utc_datetime, :naive_datetime, :date] do
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
    if field_conf && Map.get(field_conf, :type) in [:utc_datetime, :naive_datetime, :date] do
      {year, _} = Integer.parse(value)
      start_date = Date.new!(year, 1, 1)
      end_date = Date.new!(year + 1, 1, 1)

      {"DATE_BETWEEN", Date.to_iso8601(start_date), Date.to_iso8601(end_date)}
    else
      {"=", value, ""}
    end
  end

  defp handle_datetime_field(value, field_conf) do
    field_type = Map.get(field_conf, :type, :string)

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
    Enum.map(params, fn {f, v} ->
      field_name = extract_field_name(f, socket)
      conf = Selecto.field(socket.assigns.selecto, field_name)

      if conf != nil do
        field_type = Map.get(conf, :type, :string)

        case field_type do
          x when x in [:utc_datetime, :naive_datetime] ->
            {v1, v2} = Selecto.Helpers.Date.val_to_dates(%{"value" => v, "value2" => ""})
            {UUID.uuid4(), "filters", %{"filter" => field_name, "value" => v1, "value2" => v2}}

          _ ->
            {UUID.uuid4(), "filters", %{"filter" => field_name, "value" => v}}
        end
      else
        {UUID.uuid4(), "filters", %{"filter" => field_name, "value" => v}}
      end
    end)
  end

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
