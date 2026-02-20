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

      # Check if this is a join_mode field (lookup/star/tag) - should render as multi-select
      join_mode_config = find_join_mode_config(assigns.selecto, filter_id, column_def)

      # Check if this is a polymorphic join mode field
      polymorphic_config = find_polymorphic_config(assigns.selecto, filter_id, column_def)

      # Render different forms based on field type or join_mode
      cond do
        polymorphic_config ->
          render_polymorphic_filter(Map.put(assigns, :polymorphic_config, polymorphic_config))
        join_mode_config ->
          render_multiselect_filter(Map.put(assigns, :join_mode_config, join_mode_config))
        field_type in [:naive_datetime, :utc_datetime, :date] ->
          render_datetime_filter(assigns)
        field_type == :tsvector ->
          render_text_search_filter(assigns)
        true ->
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

    between_start = assigns.filter_value["value_start"] || assigns.filter_value["value"] || ""
    between_end = assigns.filter_value["value_end"] || assigns.filter_value["value2"] || ""

    assigns =
      assigns
      |> Map.put(:is_multi_select_id, is_multi_select_id)
      |> Map.put(:between_start, between_start)
      |> Map.put(:between_end, between_end)

    ~H"""
    <div class="grid grid-cols-3 gap-2">
      <select name={"filters[#{@uuid}][comp]"} class="sc-select">
        <option value="=" selected={@filter_value["comp"] == "="}>Equals</option>
        <option value="!=" selected={@filter_value["comp"] == "!="}>Not Equals</option>
        <option value=">" selected={@filter_value["comp"] == ">"}>Greater Than</option>
        <option value=">=" selected={@filter_value["comp"] == ">="}>Greater or Equal</option>
        <option value="<" selected={@filter_value["comp"] == "<"}>Less Than</option>
        <option value="<=" selected={@filter_value["comp"] == "<="}>Less or Equal</option>
        <option value="BETWEEN" selected={@filter_value["comp"] == "BETWEEN"}>Between</option>
        <option value="LIKE" selected={@filter_value["comp"] == "LIKE"}>Contains</option>
        <option value="NOT LIKE" selected={@filter_value["comp"] == "NOT LIKE"}>Does Not Contain</option>
        <option value="IS NULL" selected={@filter_value["comp"] == "IS NULL"}>Is Empty</option>
        <option value="IS NOT NULL" selected={@filter_value["comp"] == "IS NOT NULL"}>Is Not Empty</option>
      </select>

      <%= cond do %>
        <% @filter_value["comp"] == "BETWEEN" -> %>
          <div class="col-span-2 grid grid-cols-2 gap-2">
            <input
              type="text"
              name={"filters[#{@uuid}][value_start]"}
              value={@between_start}
              placeholder="Start"
              class="sc-input"
              phx-debounce="300"
            />
            <input
              type="text"
              name={"filters[#{@uuid}][value_end]"}
              value={@between_end}
              placeholder="End"
              class="sc-input"
              phx-debounce="300"
            />
          </div>

        <% @is_multi_select_id -> %>
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

        <% true -> %>
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
  Render text search filter for tsvector columns.

  This filter type uses PostgreSQL's full-text search with websearch_to_tsquery,
  which supports natural language search queries including:
  - Simple words: "matrix" finds documents containing "matrix"
  - Phrases: "the matrix" finds documents with those words near each other
  - OR searches: "matrix OR reloaded" finds documents with either word
  - Exclusions: "matrix -reloaded" excludes documents with "reloaded"
  """
  def render_text_search_filter(assigns) do
    ~H"""
    <div class="grid grid-cols-1 gap-2">
      <div class="flex items-center gap-2">
        <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
        </svg>
        <input
          type="text"
          name={"filters[#{@uuid}][value]"}
          value={@filter_value["value"]}
          placeholder="Search... (e.g., matrix, 'the matrix', matrix OR reloaded)"
          class="sc-input flex-1"
          phx-debounce="300"
        />
      </div>
      <div class="text-xs text-gray-500">
        Full-text search supports phrases in quotes, OR for alternatives, and - to exclude terms
      </div>

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
    # Only hash UUIDs, sections, and filter field IDs so the component remounts
    # when filters are added/removed but NOT when values/comparisons change
    filters
    |> Enum.map(fn
      {uuid, section, config} when is_map(config) -> {uuid, section, Map.get(config, "filter")}
      {uuid, section, conj} when is_binary(conj) -> {uuid, section, conj}
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

  @doc """
  Find join mode configuration for a filter field.

  Handles two cases:
  1. Filtering on "category.id" - finds "category.category_name" with join_mode metadata
  2. Filtering on "category_id" (product table) - finds the category schema field that has group_by_filter: "category_id"
  """
  defp find_join_mode_config(selecto, filter_id, column_def) do
    # Check if column_def already has join_mode
    if column_def && Map.get(column_def, :join_mode) in [:lookup, :star, :tag] &&
       Map.get(column_def, :filter_type) == :multi_select_id do
      column_def
    else
      domain = Selecto.domain(selecto)

      # Parse filter_id to get schema and field parts
      {schema_name, field_part} = if is_binary(filter_id) and String.contains?(filter_id, ".") do
        parts = String.split(filter_id, ".", parts: 2)
        {Enum.at(parts, 0), Enum.at(parts, 1)}
      else
        # For fields without schema prefix (e.g., "category_id"), use source schema
        source_table = get_in(domain, [:source, :source_table])
        {source_table, filter_id}
      end

      # Check if this is an ID field that might have join_mode configuration
      if field_part in ["id"] or String.ends_with?(field_part || "", "_id") do
        schema_atom = try do
          String.to_existing_atom(schema_name)
        rescue
          ArgumentError -> nil
        end

        result_case1 = if schema_atom do
          # Case 1: filtering on "category.id" - look in category schema for join_mode field
          schema_config = get_in(domain, [:schemas, schema_atom])

          if schema_config do
            columns = Map.get(schema_config, :columns, %{})

            Enum.find_value(columns, fn {_col_name, col_config} ->
              join_mode = Map.get(col_config, :join_mode)
              id_field = Map.get(col_config, :id_field)
              filter_type = Map.get(col_config, :filter_type)

              if join_mode in [:lookup, :star, :tag] and filter_type == :multi_select_id and
                 (id_field == :id or Atom.to_string(id_field) == field_part) do
                # Include source_table from schema config so query_table_options knows which table to query
                source_table = Map.get(schema_config, :source_table)
                Map.put(col_config, :source_table, source_table)
              else
                nil
              end
            end)
          else
            nil
          end
        else
          nil
        end

        # Case 2: filtering on "category_id" (foreign key) - search all schemas for field with matching group_by_filter
        if result_case1 == nil and String.ends_with?(field_part, "_id") do
          schemas = Map.get(domain, :schemas, %{})

          Enum.find_value(schemas, fn {schema_name_atom, schema_config} ->
            columns = Map.get(schema_config, :columns, %{})

            Enum.find_value(columns, fn {col_name, col_config} ->
              join_mode = Map.get(col_config, :join_mode)
              filter_type = Map.get(col_config, :filter_type)
              group_by_filter = Map.get(col_config, :group_by_filter)

              if join_mode in [:lookup, :star, :tag] and
                 filter_type == :multi_select_id and
                 group_by_filter == field_part do
                # Include source_table from schema config so query_table_options knows which table to query
                source_table = Map.get(schema_config, :source_table)
                Map.put(col_config, :source_table, source_table)
              else
                nil
              end
            end)
          end)
        else
          result_case1
        end
      else
        nil
      end
    end
  end

  @doc """
  Render multi-select filter for join_mode fields (lookup/star/tag).

  Displays checkboxes for small datasets (lookup mode) or searchable dropdown
  for larger datasets (star/tag modes).
  """
  defp render_multiselect_filter(assigns) do
    # Get the configuration
    join_mode_config = assigns.join_mode_config

    # Get table from join_mode_config (added by find_join_mode_config)
    # This is more reliable than parsing the filter_id
    table = Map.get(join_mode_config, :source_table)
    id_field = Map.get(join_mode_config, :id_field, :id)
    display_field = Map.get(join_mode_config, :display_field, :name)
    join_mode = Map.get(join_mode_config, :join_mode, :lookup)

    # Query options from database using selecto's connection pool
    options = if table do
      query_table_options(assigns.selecto, table, id_field, display_field, 100)
    else
      []
    end

    # Parse selected IDs from filter value
    current_value = assigns.filter_value["value"] || ""
    selected_ids = parse_filter_ids(current_value)

    # Get current comparison operator, default to IN
    current_comp = assigns.filter_value["comp"] || "IN"

    assigns =
      assigns
      |> Map.put(:options, options)
      |> Map.put(:selected_ids, selected_ids)
      |> Map.put(:join_mode, join_mode)
      |> Map.put(:current_comp, current_comp)

    ~H"""
    <div class="space-y-2">
      <%!-- Comparison operator selector --%>
      <div class="flex items-center gap-2">
        <select name={"filters[#{@uuid}][comp]"} class="sc-select text-sm">
          <option value="IN" selected={@current_comp == "IN"}>Is One Of</option>
          <option value="NOT IN" selected={@current_comp == "NOT IN"}>Is Not One Of</option>
          <option value="IS NULL" selected={@current_comp == "IS NULL"}>Is Empty</option>
          <option value="IS NOT NULL" selected={@current_comp == "IS NOT NULL"}>Is Not Empty</option>
        </select>
      </div>

      <%= if @current_comp in ["IS NULL", "IS NOT NULL"] do %>
        <div class="text-sm text-gray-500 italic">
          No value selection needed
        </div>
      <% else %>
        <label class="text-sm font-medium text-gray-700">
          Select <%= display_field %>:
        </label>

        <%= if @join_mode == :lookup and length(@options) < 20 do %>
          <%!-- Checkbox list for small datasets --%>
          <div class="max-h-48 overflow-y-auto border border-gray-300 rounded-md p-2 bg-white space-y-1">
            <%= for opt <- @options do %>
              <label class="flex items-center space-x-2 hover:bg-blue-50 px-2 py-1 rounded cursor-pointer">
                <input
                  type="checkbox"
                  name={"filters[#{@uuid}][selected_ids][]"}
                  value={opt.id}
                  checked={opt.id in @selected_ids}
                  class="rounded border-gray-300 text-blue-600 focus:ring-blue-500 h-4 w-4"
                />
                <span class="text-sm text-gray-900"><%= opt.name %></span>
              </label>
            <% end %>
          </div>
        <% else %>
          <%!-- Simple multi-select for larger datasets --%>
          <select
            multiple
            size="8"
            name={"filters[#{@uuid}][selected_ids][]"}
            phx-debounce="blur"
            class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm">
            <%= for opt <- @options do %>
              <option value={opt.id} selected={opt.id in @selected_ids}>
                <%= opt.name %>
              </option>
            <% end %>
          </select>
          <p class="text-xs text-gray-500 mt-1">Hold Ctrl/Cmd to select multiple. Click outside when done.</p>
        <% end %>

        <div class="text-xs text-gray-500">
          <%= length(@selected_ids) %> of <%= length(@options) %> selected
        </div>
      <% end %>

      <%!-- Hidden inputs to preserve filter structure --%>
      <input type="hidden" name={"filters[#{@uuid}][uuid]"} value={@uuid}/>
      <input type="hidden" name={"filters[#{@uuid}][section]"} value={@section}/>
      <input type="hidden" name={"filters[#{@uuid}][index]"} value={@index}/>
      <input type="hidden" name={"filters[#{@uuid}][filter]"} value={@filter_value["filter"]}/>

      <%!-- Hidden field to store comma-separated IDs (only needed for IN/NOT IN) --%>
      <%= if @current_comp in ["IN", "NOT IN"] do %>
        <input
          id={"filter-value-#{@uuid}"}
          type="hidden"
          name={"filters[#{@uuid}][value]"}
          value={Enum.join(@selected_ids, ",")}
        />
      <% end %>
    </div>
    """
  end

  # Query database for ID+name pairs using Selecto's connection (Repo)
  defp query_table_options(selecto, table, id_field, display_field, limit) do
    require Logger

    query = """
    SELECT #{id_field} as id, #{display_field} as name
    FROM #{table}
    WHERE #{display_field} IS NOT NULL
    ORDER BY #{display_field}
    LIMIT $1
    """

    # Use Repo.query directly - selecto.connection is the Repo module
    repo = selecto.connection
    case repo.query(query, [limit]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [id, name] ->
          %{id: id, name: to_string(name)}
        end)

      {:error, error} ->
        Logger.warning("Failed to query options for multi-select filter: #{inspect(error)}")
        []
    end
  rescue
    e ->
      Logger.warning("Exception querying options for multi-select filter: #{inspect(e)}")
      []
  end

  # Parse comma-separated IDs from value string
  defp parse_filter_ids(value) when is_binary(value) do
    value
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(fn id_str ->
      case Integer.parse(id_str) do
        {id, _} -> id
        :error -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end
  defp parse_filter_ids(_), do: []

  @doc """
  Find polymorphic join mode configuration for a filter field.

  Looks for columns with join_mode: :polymorphic and returns the configuration
  including the entity types that can be filtered.
  """
  defp find_polymorphic_config(selecto, filter_id, column_def) do
    # Check if column_def already has polymorphic join_mode
    if column_def && Map.get(column_def, :join_mode) == :polymorphic &&
       Map.get(column_def, :filter_type) == :polymorphic do
      column_def
    else
      domain = Selecto.domain(selecto)

      # Parse filter_id to get schema and field parts
      {schema_name, field_part} = if is_binary(filter_id) and String.contains?(filter_id, ".") do
        parts = String.split(filter_id, ".", parts: 2)
        {Enum.at(parts, 0), Enum.at(parts, 1)}
      else
        # For fields without schema prefix, use source schema
        source_table = get_in(domain, [:source, :source_table])
        {source_table, filter_id}
      end

      # Check if this is a type or id field that might have polymorphic configuration
      if String.ends_with?(field_part || "", "_type") or String.ends_with?(field_part || "", "_id") do
        schema_atom = try do
          String.to_existing_atom(schema_name)
        rescue
          ArgumentError -> nil
        end

        if schema_atom do
          # Look in schema for polymorphic field
          schema_config = get_in(domain, [:schemas, schema_atom])

          if schema_config do
            columns = Map.get(schema_config, :columns, %{})

            Enum.find_value(columns, fn {_col_name, col_config} ->
              join_mode = Map.get(col_config, :join_mode)
              filter_type = Map.get(col_config, :filter_type)

              if join_mode == :polymorphic and filter_type == :polymorphic do
                # Include source_table so we know which table to query
                source_table = Map.get(schema_config, :source_table)
                Map.put(col_config, :source_table, source_table)
              else
                nil
              end
            end)
          else
            nil
          end
        else
          nil
        end
      else
        nil
      end
    end
  end

  @doc """
  Render polymorphic filter with type selector and dynamic value loading.

  Allows users to:
  1. Select which entity type(s) to filter (Product, Order, Customer)
  2. For each type, select specific entities via multi-select
  """
  defp render_polymorphic_filter(assigns) do
    # Get the configuration
    polymorphic_config = assigns.polymorphic_config

    # Get entity types from config
    entity_types = Map.get(polymorphic_config, :entity_types, ["Product", "Order", "Customer"])
    type_field = Map.get(polymorphic_config, :type_field, "commentable_type")
    id_field = Map.get(polymorphic_config, :id_field, "commentable_id")

    # Parse current selection
    current_value = assigns.filter_value["polymorphic_selection"] || %{}
    selected_types = Map.get(current_value, "types", [])

    assigns =
      assigns
      |> Map.put(:entity_types, entity_types)
      |> Map.put(:type_field, type_field)
      |> Map.put(:id_field, id_field)
      |> Map.put(:selected_types, selected_types)
      |> Map.put(:current_selection, current_value)

    ~H"""
    <div class="space-y-3">
      <label class="text-sm font-medium text-gray-700">
        Select Entity Type(s):
      </label>

      <%!-- Type selection checkboxes --%>
      <div class="border border-gray-300 rounded-md p-2 bg-white space-y-1">
        <%= for entity_type <- @entity_types do %>
          <label class="flex items-center space-x-2 hover:bg-blue-50 px-2 py-1 rounded cursor-pointer">
            <input
              type="checkbox"
              phx-change="polymorphic_type_toggle"
              phx-value-filter-uuid={@uuid}
              phx-value-entity-type={entity_type}
              checked={entity_type in @selected_types}
              class="rounded border-gray-300 text-blue-600 focus:ring-blue-500 h-4 w-4"
            />
            <span class="text-sm text-gray-900"><%= entity_type %></span>
          </label>
        <% end %>
      </div>

      <%!-- Value selection for each selected type --%>
      <%= if length(@selected_types) > 0 do %>
        <div class="space-y-2 border-t pt-2">
          <%= for entity_type <- @selected_types do %>
            <div class="space-y-1">
              <label class="text-xs font-medium text-gray-600">
                <%= entity_type %> IDs:
              </label>
              <input
                type="text"
                name={"filters[#{@uuid}][poly_values][#{entity_type}]"}
                value={get_in(@current_selection, ["values", entity_type]) || ""}
                placeholder="Enter IDs (comma-separated, e.g., 1,2,3)"
                class="sc-input text-sm"
                phx-debounce="300"
              />
            </div>
          <% end %>
        </div>
      <% end %>

      <%!-- Hidden inputs to preserve filter structure --%>
      <input type="hidden" name={"filters[#{@uuid}][uuid]"} value={@uuid}/>
      <input type="hidden" name={"filters[#{@uuid}][section]"} value={@section}/>
      <input type="hidden" name={"filters[#{@uuid}][index]"} value={@index}/>
      <input type="hidden" name={"filters[#{@uuid}][filter]"} value={@filter_value["filter"]}/>
      <input type="hidden" name={"filters[#{@uuid}][comp]"} value="POLYMORPHIC"/>

      <%!-- Store selected types as JSON --%>
      <input
        type="hidden"
        name={"filters[#{@uuid}][selected_types]"}
        value={Jason.encode!(@selected_types)}
      />
    </div>
    """
  end
end
