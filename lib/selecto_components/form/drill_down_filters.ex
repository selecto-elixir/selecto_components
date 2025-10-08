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
    selected_view = String.to_atom(socket.assigns.view_config.view_mode)

    {_, _, _, opt} =
      Enum.find(socket.assigns.views, fn {id, _, _, _} -> id == selected_view end)

    _new_view_mode = Map.get(opt, :drill_down, "detail")

    view_params =
      %{socket.assigns.used_params | "view_mode" => "detail"}
      |> Map.put(
        "filters",
        build_filter_map(params, socket)
      )

    view_params
  end

  @doc """
  Build filters map from drill-down parameters.
  """
  def build_filter_map(params, socket) do
    Enum.reduce(
      params,
      Map.get(socket.assigns.used_params, "filters", %{}),
      fn {f, v}, acc ->
        newid = UUID.uuid4()

        # Extract field name from phx-value-* parameters
        field_name = extract_field_name(f, socket)

        # Get field configuration
        conf = Selecto.field(socket.assigns.selecto, field_name)

        # Check if this is an age bucket field
        group_by_config = Map.get(socket.assigns.used_params, "group_by", %{})
        field_group_config = find_field_group_config(group_by_config, field_name)
        is_age_bucket = field_group_config && Map.get(field_group_config, "format") == "age_buckets"

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
        actual_filter_field = if conf && Map.get(conf, :group_by_filter) do
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
    current_group_by = Map.get(socket.assigns.used_params, "group_by", %{})
    first_group = current_group_by
      |> Map.values()
      |> Enum.sort(fn a, b ->
        String.to_integer(Map.get(a, "index", "0")) <= String.to_integer(Map.get(b, "index", "0"))
      end)
      |> List.first()

    case first_group do
      %{"field" => field} -> field
      _ -> "id"  # Fallback to basic field
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
  - Bucket ranges (1-10, 11+, Other)
  - Date formats (YYYY-MM-DD, YYYY-MM, YYYY)
  - Age buckets on date fields
  - Default equality
  """
  def determine_filter_comp_and_values(value, field_conf, is_age_bucket) do
    cond do
      # Bucket range patterns
      String.match?(value, ~r/^\d+-\d+$/) || String.match?(value, ~r/^\d+\+$/) || value == "Other" ->
        handle_bucket_range(value, field_conf, is_age_bucket)

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

      # Default datetime handling
      field_conf != nil ->
        handle_datetime_field(value, field_conf)

      # No field configuration
      true ->
        {"=", value, ""}
    end
  end

  defp handle_bucket_range(value, field_conf, is_age_bucket) do
    if is_age_bucket && field_conf && Map.get(field_conf, :type) in [:utc_datetime, :naive_datetime, :date] do
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
        {v1_parsed, v2_parsed} = Selecto.Helpers.Date.val_to_dates(%{"value" => value, "value2" => ""})
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
end