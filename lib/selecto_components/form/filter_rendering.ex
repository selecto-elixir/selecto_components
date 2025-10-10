defmodule SelectoComponents.Form.FilterRendering do
  @moduledoc """
  Handles rendering of filter forms for SelectoComponents.

  This module contains all the logic for rendering different types of filters:
  - Standard text/number filters
  - Datetime filters with shortcuts, relative dates, and between ranges
  - Custom component filters

  Also provides helper functions for:
  - Building filter lists from Selecto definitions
  - Formatting datetime values for HTML inputs
  - Detecting date shortcuts and relative date patterns
  """

  use Phoenix.Component

  @doc """
  Render a filter form based on the filter definition and field type.

  Handles three types of filters:
  1. Custom component filters (with :component type)
  2. Datetime filters (for :date, :naive_datetime, :utc_datetime types)
  3. Standard filters (for all other types)
  """
  def render_filter_form(assigns, uuid, index, section, filter_value) do
    # Get the filter definition from the selecto
    filter_id = filter_value["filter"]

    filter_def =
      case Selecto.filters(assigns.selecto) do
        filters when is_map(filters) ->
          Map.get(filters, filter_id)
        _ ->
          nil
      end

    # Also try to get the column definition if filter_def is nil
    column_def = if filter_def == nil do
      columns = Selecto.columns(assigns.selecto)
      Enum.find_value(columns, fn {_key, col} ->
        if col.colid == filter_id or to_string(col.colid) == filter_id do
          col
        else
          nil
        end
      end)
    else
      filter_def
    end

    # Determine the field type
    field_type = cond do
      filter_def && Map.has_key?(filter_def, :type) -> Map.get(filter_def, :type)
      column_def && Map.has_key?(column_def, :type) -> Map.get(column_def, :type)
      true -> :string
    end

    # Check if this is a custom filter with a component
    if filter_def && Map.get(filter_def, :type) == :component && Map.get(filter_def, :component) do
      # Render the custom component
      component_assigns = %{
        uuid: uuid,
        valmap: filter_value,
        def: filter_def
      }

      assigns =
        assigns
        |> Map.merge(component_assigns)
        |> Map.put(:section, section)
        |> Map.put(:index, index)
        |> Map.put(:filter_value, filter_value)

      ~H"""
      <div>
        <%= @def.component.(assigns) %>
        <input type="hidden" name={"filters[#{@uuid}][uuid]"} value={@uuid}/>
        <input type="hidden" name={"filters[#{@uuid}][section]"} value={@section}/>
        <input type="hidden" name={"filters[#{@uuid}][index]"} value={@index}/>
        <input type="hidden" name={"filters[#{@uuid}][filter]"} value={@filter_value["filter"]}/>
      </div>
      """
    else
      # Render the default filter form based on field type
      assigns = Map.merge(assigns, %{
        uuid: uuid,
        section: section,
        index: index,
        filter_value: filter_value,
        field_type: field_type,
        column_def: column_def,
        filter_def: filter_def
      })

      # Render different forms based on field type
      case field_type do
        type when type in [:naive_datetime, :utc_datetime, :date] ->
          render_datetime_filter(assigns)
        _ ->
          render_standard_filter(assigns)
      end
    end
  end

  @doc """
  Render datetime filter with appropriate controls.

  Supports multiple comparison modes:
  - Standard comparisons (=, !=, >, >=, <, <=)
  - Date-only comparisons (DATE=, DATE!=)
  - Range filters (BETWEEN, DATE_BETWEEN)
  - Quick shortcuts (today, this_week, last_month, etc.)
  - Relative dates (5, 3-7, -30, 30-)
  - Null checks (IS NULL, IS NOT NULL)
  """
  def render_datetime_filter(assigns) do
    # Check if value is a shortcut or relative date
    filter_value = assigns[:filter_value] || %{}

    is_shortcut = is_date_shortcut(filter_value["value"])
    is_relative = is_relative_date(filter_value["value"])

    assigns =
      assigns
      |> Map.put(:is_shortcut, is_shortcut)
      |> Map.put(:is_relative, is_relative)
      |> Map.put(:filter_value, filter_value)

    ~H"""
    <div class="space-y-2">
      <div class="grid grid-cols-3 gap-2">
        <select
          name={"filters[#{@uuid}][comp]"}
          class="sc-select"
          phx-change="datetime-filter-change"
          phx-target={@myself}
          phx-value-uuid={@uuid}>
          <option value="=" selected={@filter_value["comp"] == "="}>On</option>
          <option value="!=" selected={@filter_value["comp"] == "!="}>Not On</option>
          <option value="DATE=" selected={@filter_value["comp"] == "DATE="}>Date Equals</option>
          <option value="DATE!=" selected={@filter_value["comp"] == "DATE!="}>Date Not Equals</option>
          <option value=">" selected={@filter_value["comp"] == ">"}>After</option>
          <option value=">=" selected={@filter_value["comp"] == ">="}>On or After</option>
          <option value="<" selected={@filter_value["comp"] == "<"}>Before</option>
          <option value="<=" selected={@filter_value["comp"] == "<="}>On or Before</option>
          <option value="BETWEEN" selected={@filter_value["comp"] == "BETWEEN"}>Between</option>
          <option value="DATE_BETWEEN" selected={@filter_value["comp"] == "DATE_BETWEEN"}>Date Between</option>
          <option value="SHORTCUT" selected={@filter_value["comp"] == "SHORTCUT"}>Quick Select</option>
          <option value="RELATIVE" selected={@filter_value["comp"] == "RELATIVE"}>Relative Days</option>
          <option value="IS NULL" selected={@filter_value["comp"] == "IS NULL"}>Is Empty</option>
          <option value="IS NOT NULL" selected={@filter_value["comp"] == "IS NOT NULL"}>Is Not Empty</option>
        </select>

        <%= cond do %>
          <% @filter_value["comp"] in ["BETWEEN", "DATE_BETWEEN"] -> %>
            <div class="col-span-2 grid grid-cols-2 gap-2">
              <input
                type="date"
                name={"filters[#{@uuid}][value_start]"}
                value={format_datetime_value(@filter_value["value_start"], :date)}
                class="sc-input"
                placeholder="Start"
                phx-debounce="300"
              />
              <input
                type="date"
                name={"filters[#{@uuid}][value_end]"}
                value={format_datetime_value(@filter_value["value_end"], :date)}
                class="sc-input"
                placeholder="End (exclusive)"
                phx-debounce="300"
              />
            </div>

          <% @filter_value["comp"] == "SHORTCUT" -> %>
            <select name={"filters[#{@uuid}][value]"} class="sc-select col-span-2">
              <optgroup label="Days">
                <option value="today" selected={@filter_value["value"] == "today"}>Today</option>
                <option value="yesterday" selected={@filter_value["value"] == "yesterday"}>Yesterday</option>
                <option value="tomorrow" selected={@filter_value["value"] == "tomorrow"}>Tomorrow</option>
              </optgroup>
              <optgroup label="Weeks">
                <option value="this_week" selected={@filter_value["value"] == "this_week"}>This Week</option>
                <option value="last_week" selected={@filter_value["value"] == "last_week"}>Last Week</option>
                <option value="next_week" selected={@filter_value["value"] == "next_week"}>Next Week</option>
              </optgroup>
              <optgroup label="Months">
                <option value="this_month" selected={@filter_value["value"] == "this_month"}>This Month</option>
                <option value="last_month" selected={@filter_value["value"] == "last_month"}>Last Month</option>
                <option value="next_month" selected={@filter_value["value"] == "next_month"}>Next Month</option>
                <option value="mtd" selected={@filter_value["value"] == "mtd"}>Month to Date</option>
              </optgroup>
              <optgroup label="Quarters">
                <option value="this_quarter" selected={@filter_value["value"] == "this_quarter"}>This Quarter</option>
                <option value="last_quarter" selected={@filter_value["value"] == "last_quarter"}>Last Quarter</option>
                <option value="next_quarter" selected={@filter_value["value"] == "next_quarter"}>Next Quarter</option>
                <option value="qtd" selected={@filter_value["value"] == "qtd"}>Quarter to Date</option>
              </optgroup>
              <optgroup label="Years">
                <option value="this_year" selected={@filter_value["value"] == "this_year"}>This Year</option>
                <option value="last_year" selected={@filter_value["value"] == "last_year"}>Last Year</option>
                <option value="next_year" selected={@filter_value["value"] == "next_year"}>Next Year</option>
                <option value="ytd" selected={@filter_value["value"] == "ytd"}>Year to Date</option>
              </optgroup>
              <optgroup label="Relative Periods">
                <option value="last_7_days" selected={@filter_value["value"] == "last_7_days"}>Last 7 Days</option>
                <option value="last_30_days" selected={@filter_value["value"] == "last_30_days"}>Last 30 Days</option>
                <option value="last_60_days" selected={@filter_value["value"] == "last_60_days"}>Last 60 Days</option>
                <option value="last_90_days" selected={@filter_value["value"] == "last_90_days"}>Last 90 Days</option>
                <option value="next_7_days" selected={@filter_value["value"] == "next_7_days"}>Next 7 Days</option>
                <option value="next_30_days" selected={@filter_value["value"] == "next_30_days"}>Next 30 Days</option>
              </optgroup>
              <optgroup label="Year Comparisons">
                <option value="last_ytd" selected={@filter_value["value"] == "last_ytd"}>Last Year YTD (same period)</option>
                <option value="ytd_vs_last" selected={@filter_value["value"] == "ytd_vs_last"}>This Year and Last Year YTD</option>
                <option value="qtd_vs_last" selected={@filter_value["value"] == "qtd_vs_last"}>This Quarter and Last Quarter QTD</option>
                <option value="mtd_vs_last" selected={@filter_value["value"] == "mtd_vs_last"}>This Month and Last Month MTD</option>
                <option value="mtd_vs_last_year" selected={@filter_value["value"] == "mtd_vs_last_year"}>This Month MTD and Last Year's MTD</option>
              </optgroup>
            </select>

          <% @filter_value["comp"] == "RELATIVE" -> %>
            <div class="col-span-2 flex gap-2">
              <input
                type="text"
                name={"filters[#{@uuid}][value]"}
                value={@filter_value["value"]}
                class="sc-input flex-1"
                placeholder="e.g., 5 (5 days ago), 3-7 (3-7 days ago), -30 (>30 days ago), 30- (within 30 days)"
                pattern="^-?\d+(-\d+)?-?$"
                phx-debounce="500"
              />
              <div class="text-xs text-gray-500 self-center">
                <span class="font-semibold">Examples:</span>
                1 = yesterday,
                3-7 = 3-7 days ago,
                -30 = over 30 days ago,
                30- = within 30 days
              </div>
            </div>

          <% @filter_value["comp"] in ["DATE=", "DATE!="] -> %>
            <input
              type="date"
              name={"filters[#{@uuid}][value]"}
              value={format_datetime_value(@filter_value["value"], :date)}
              class="sc-input col-span-2"
            />

          <% @filter_value["comp"] in ["IS NULL", "IS NOT NULL"] -> %>
            <div class="col-span-2 text-gray-500 text-sm self-center">
              No value needed
            </div>

          <% true -> %>
            <input
              type={if @field_type == :date, do: "date", else: "datetime-local"}
              name={"filters[#{@uuid}][value]"}
              value={format_datetime_value(@filter_value["value"], @field_type)}
              class="sc-input col-span-2"
              disabled={@filter_value["comp"] in ["IS NULL", "IS NOT NULL"]}
            />
        <% end %>
      </div>

      <input type="hidden" name={"filters[#{@uuid}][uuid]"} value={@uuid}/>
      <input type="hidden" name={"filters[#{@uuid}][section]"} value={@section}/>
      <input type="hidden" name={"filters[#{@uuid}][index]"} value={@index}/>
      <input type="hidden" name={"filters[#{@uuid}][filter]"} value={@filter_value["filter"]}/>
    </div>
    """
  end

  @doc """
  Render standard text/number filter with basic comparison operators.

  Supports:
  - Equality (=, !=)
  - Comparisons (>, >=, <, <=)
  - Text search (LIKE, NOT LIKE)
  - Null checks (IS NULL, IS NOT NULL)
  """
  def render_standard_filter(assigns) do
    # Check if this field uses multi-select ID filtering (lookup/star/tag join modes)
    column_def = Map.get(assigns, :column_def) || Map.get(assigns, :filter_def)
    is_multi_select_id = column_def && Map.get(column_def, :filter_type) == :multi_select_id

    assigns = Map.put(assigns, :is_multi_select_id, is_multi_select_id)

    ~H"""
    <div class="grid grid-cols-3 gap-2">
      <select name={"filters[#{@uuid}][comp]"} class="sc-select">
        <option value="=" selected={@filter_value["comp"] == "="}>Equals</option>
        <option value="!=" selected={@filter_value["comp"] == "!="}>Not Equals</option>
        <option value=">" selected={@filter_value["comp"] == ">"}>Greater Than</option>
        <option value=">=" selected={@filter_value["comp"] == ">="}>Greater or Equal</option>
        <option value="<" selected={@filter_value["comp"] == "<"}>Less Than</option>
        <option value="<=" selected={@filter_value["comp"] == "<="}>Less or Equal</option>
        <option value="LIKE" selected={@filter_value["comp"] == "LIKE"}>Contains</option>
        <option value="NOT LIKE" selected={@filter_value["comp"] == "NOT LIKE"}>Does Not Contain</option>
        <option value="IS NULL" selected={@filter_value["comp"] == "IS NULL"}>Is Empty</option>
        <option value="IS NOT NULL" selected={@filter_value["comp"] == "IS NOT NULL"}>Is Not Empty</option>
      </select>

      <%= if @is_multi_select_id do %>
        <%!-- Multi-select ID filter input with helpful placeholder --%>
        <div class="col-span-2">
          <input
            type="text"
            name={"filters[#{@uuid}][value]"}
            value={@filter_value["value"]}
            placeholder="Enter IDs (comma-separated, e.g., 1,2,3)"
            class="sc-input"
            phx-debounce="300"
            disabled={@filter_value["comp"] in ["IS NULL", "IS NOT NULL"]}
          />
          <div class="text-xs text-blue-600 mt-1">
            💡 Tip: Use numeric IDs for filtering (e.g., 1,2,3)
          </div>
        </div>
      <% else %>
        <%!-- Standard text input --%>
        <input
          type="text"
          name={"filters[#{@uuid}][value]"}
          value={@filter_value["value"]}
          placeholder="Enter value..."
          class="sc-input col-span-2"
          phx-debounce="300"
          disabled={@filter_value["comp"] in ["IS NULL", "IS NOT NULL"]}
        />
      <% end %>

      <input type="hidden" name={"filters[#{@uuid}][uuid]"} value={@uuid}/>
      <input type="hidden" name={"filters[#{@uuid}][section]"} value={@section}/>
      <input type="hidden" name={"filters[#{@uuid}][index]"} value={@index}/>
      <input type="hidden" name={"filters[#{@uuid}][filter]"} value={@filter_value["filter"]}/>
    </div>
    """
  end

  @doc """
  Format datetime value for HTML input fields.

  Handles different datetime types:
  - :date -> YYYY-MM-DD format
  - :naive_datetime/:utc_datetime -> YYYY-MM-DDTHH:MM format for datetime-local inputs
  """
  def format_datetime_value(nil, _type), do: ""
  def format_datetime_value("", _type), do: ""
  def format_datetime_value(value, :date) when is_binary(value) do
    # Try to parse and format as YYYY-MM-DD
    case Date.from_iso8601(value) do
      {:ok, date} -> Date.to_string(date)
      _ -> String.slice(value, 0..9)
    end
  end
  def format_datetime_value(value, type) when type in [:naive_datetime, :utc_datetime] and is_binary(value) do
    # Try to parse and format as YYYY-MM-DDTHH:MM for datetime-local input
    cond do
      String.contains?(value, "T") -> String.slice(value, 0..15)
      String.length(value) >= 16 -> String.slice(value, 0..9) <> "T" <> String.slice(value, 11..15)
      true -> value
    end
  end
  def format_datetime_value(value, _type), do: value

  @doc """
  Check if a value is a date shortcut (today, this_week, last_month, etc.).
  """
  def is_date_shortcut(value) when is_binary(value) do
    value in ~w(today yesterday tomorrow this_week last_week next_week
                this_month last_month next_month mtd
                this_quarter last_quarter next_quarter qtd
                this_year last_year next_year ytd
                last_7_days last_30_days last_60_days last_90_days
                next_7_days next_30_days
                ytd_vs_last qtd_vs_last mtd_vs_last last_ytd mtd_vs_last_year)
  end
  def is_date_shortcut(_), do: false

  @doc """
  Check if a value is a relative date format (5, 3-7, -30, 30-).

  Patterns:
  - N = N days ago (e.g., 5 = 5 days ago)
  - N-M = between N and M days ago (e.g., 3-7 = 3-7 days ago)
  - -N = more than N days ago (e.g., -30 = over 30 days ago)
  - N- = within N days (e.g., 30- = within 30 days)
  """
  def is_relative_date(value) when is_binary(value) do
    # Matches patterns like: 5, 3-7, -30, 30-
    Regex.match?(~r/^-?\d+(-\d+)?-?$/, value)
  end
  def is_relative_date(_), do: false

  @doc """
  Hash only the filter structure (IDs and sections), not the values.

  This ensures the component remounts when filters are added/removed
  but not when filter values or comparisons change.
  """
  def hash_filter_structure(filters) do
    # Include the entire filter structure in the hash so changes to comp, value, etc.
    # will trigger a re-render of the TreeBuilder component
    filters
    |> Enum.map(fn
      {uuid, section, config} -> {uuid, section, config}
    end)
    |> :erlang.phash2()
  end

  @doc """
  Build a list of available filters from Selecto configuration.

  Includes:
  - Explicit filters defined in Selecto.filters()
  - Columns marked as filterable (make_filter: true)
  - Columns without custom formatting (assumed to be filterable)
  """
  def build_filter_list(selecto) do
    # Include explicit filters and only columns that are marked as filterable
    filterable_columns =
      Map.values(Selecto.columns(selecto))
      |> Enum.filter(fn column ->
        # Only include columns that are explicitly marked as filterable
        # or don't have component formatting (which indicates they're display-only)
        Map.get(column, :make_filter, false) or
          ((not Map.has_key?(column, :format) or Map.get(column, :format) == nil) and
             not Map.has_key?(column, :component))
      end)

    (Map.values(Selecto.filters(selecto)) ++ filterable_columns)
    |> List.flatten()
    |> Enum.sort(fn a, b -> a.name <= b.name end)
    |> Enum.map(fn
      %{colid: id} = c -> {id, c.name}
      %{id: id} = c -> {id, c.name}
    end)
  end
end