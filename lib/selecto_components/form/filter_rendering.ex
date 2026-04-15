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
  require Logger

  alias SelectoComponents.SchemaUtils

  @identifier_regex ~r/^[a-zA-Z_][a-zA-Z0-9_]*(\.[a-zA-Z_][a-zA-Z0-9_]*)*$/

  @doc """
  Render a filter form based on the filter definition and field type.

  Handles three types of filters:
  1. Custom component filters (with :component type)
  2. Datetime filters (for :date, :naive_datetime, :utc_datetime types)
  3. Standard filters (for all other types)
  """
  def render_filter_form(assigns, uuid, index, section, filter_value) do
    # Get the filter definition from the selecto
    filter_id = value_for(filter_value, "filter")

    filter_def =
      case Selecto.filters(assigns.selecto) do
        filters when is_map(filters) ->
          Map.get(filters, filter_id)

        _ ->
          nil
      end

    # Also try to get the column definition if filter_def is nil
    column_def =
      if filter_def == nil do
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

    filter_def =
      if is_map(filter_def),
        do: SchemaUtils.with_resolved_type(assigns.selecto, filter_def),
        else: filter_def

    column_def =
      if is_map(column_def),
        do: SchemaUtils.with_resolved_type(assigns.selecto, column_def),
        else: column_def

    # Determine the field type
    field_type =
      cond do
        filter_def && Selecto.Temporal.date_like?(filter_def) ->
          Selecto.Temporal.date_like_type(filter_def)

        column_def && Selecto.Temporal.date_like?(column_def) ->
          Selecto.Temporal.date_like_type(column_def)

        filter_def && Map.has_key?(filter_def, :type) ->
          Map.get(filter_def, :type)

        column_def && Map.has_key?(column_def, :type) ->
          Map.get(column_def, :type)

        true ->
          :string
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
        |> assign(component_assigns)
        |> assign(section: section, index: index, filter_value: filter_value)

      ~H"""
      <div>
        {@def.component.(assigns)}
        <input type="hidden" name={"filters[#{@uuid}][uuid]"} value={@uuid} />
        <input type="hidden" name={"filters[#{@uuid}][section]"} value={@section} />
        <input type="hidden" name={"filters[#{@uuid}][index]"} value={@index} />
        <input type="hidden" name={"filters[#{@uuid}][filter]"} value={@filter_value["filter"]} />
      </div>
      """
    else
      # Render the default filter form based on field type
      assigns =
        assign(assigns, %{
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
          render_polymorphic_filter(assign(assigns, :polymorphic_config, polymorphic_config))

        join_mode_config ->
          render_multiselect_filter(assign(assigns, :join_mode_config, join_mode_config))

        field_type in [:naive_datetime, :utc_datetime, :date] or
            date_specific_datetime_comp?(value_for(filter_value, "comp")) ->
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

    is_shortcut = is_date_shortcut(value_for(filter_value, "value"))
    is_relative = is_relative_date(value_for(filter_value, "value"))

    current_comp = normalize_comp(value_for(filter_value, "comp"), "=")
    current_value = normalize_string(value_for(filter_value, "value"))

    assigns =
      assigns
      |> assign(
        is_shortcut: is_shortcut,
        is_relative: is_relative,
        filter_value: filter_value,
        current_comp: current_comp,
        current_value: current_value,
        shortcut_preview: date_shortcut_preview(current_value),
        promote_checked: promote_checked?(filter_value)
      )

    ~H"""
    <div class="space-y-2">
      <div
        class={[
          "grid grid-cols-3 gap-2",
          @promote_checked && "opacity-60"
        ]}
        inert={@promote_checked}
        aria-disabled={to_string(@promote_checked)}
        data-promoted-lock={to_string(@promote_checked)}
      >
        <select
          name={"filters[#{@uuid}][comp]"}
          class="sc-select"
        >
          <option value="=" selected={@current_comp == "="}>On</option>
          <option value="!=" selected={@current_comp == "!="}>Not On</option>
          <option value="DATE=" selected={@current_comp == "DATE="}>Date Equals</option>
          <option value="DATE!=" selected={@current_comp == "DATE!="}>Date Not Equals</option>
          <option value=">" selected={@current_comp == ">"}>After</option>
          <option value=">=" selected={@current_comp == ">="}>On or After</option>
          <option value="<" selected={@current_comp == "<"}>Before</option>
          <option value="<=" selected={@current_comp == "<="}>On or Before</option>
          <option value="BETWEEN" selected={@current_comp == "BETWEEN"}>Between</option>
          <option value="DATE_BETWEEN" selected={@current_comp == "DATE_BETWEEN"}>
            Date Between
          </option>
          <option value="SHORTCUT" selected={@current_comp == "SHORTCUT"}>
            Quick Select
          </option>
          <option value="RELATIVE" selected={@current_comp == "RELATIVE"}>
            Relative Days
          </option>
          <option value="WEEKDAY_SUN1" selected={@current_comp == "WEEKDAY_SUN1"}>Day of Week</option>
          <option value="WEEK_OF_YEAR" selected={@current_comp == "WEEK_OF_YEAR"}>
            Week of Year
          </option>
          <option value="MONTH_OF_YEAR" selected={@current_comp == "MONTH_OF_YEAR"}>
            Month of Year
          </option>
          <option value="DAY_OF_MONTH" selected={@current_comp == "DAY_OF_MONTH"}>
            Day of Month
          </option>
          <option value="HOUR_OF_DAY" selected={@current_comp == "HOUR_OF_DAY"}>Hour of Day</option>
          <option value="IS NULL" selected={@current_comp == "IS NULL"}>Is Empty</option>
          <option value="IS NOT NULL" selected={@current_comp == "IS NOT NULL"}>
            Is Not Empty
          </option>
        </select>

        <%= cond do %>
          <% @current_comp in ["BETWEEN", "DATE_BETWEEN"] -> %>
            <div class="col-span-2 grid grid-cols-2 gap-2">
              <input
                type="date"
                name={"filters[#{@uuid}][value_start]"}
                value={
                  format_datetime_value(
                    @filter_value["value_start"],
                    @column_def || @filter_def || :date
                  )
                }
                class="sc-input"
                placeholder="Start"
                phx-debounce="300"
              />
              <input
                type="date"
                name={"filters[#{@uuid}][value_end]"}
                value={
                  format_datetime_value(
                    @filter_value["value_end"],
                    @column_def || @filter_def || :date
                  )
                }
                class="sc-input"
                placeholder="End (exclusive)"
                phx-debounce="300"
              />
            </div>
          <% @current_comp == "SHORTCUT" -> %>
            <div class="col-span-2 space-y-1">
              <select name={"filters[#{@uuid}][value]"} class="sc-select w-full">
                <optgroup label="Days">
                  <option value="today" selected={@current_value == "today"}>Today</option>
                  <option value="yesterday" selected={@current_value == "yesterday"}>
                    Yesterday
                  </option>
                  <option value="tomorrow" selected={@current_value == "tomorrow"}>
                    Tomorrow
                  </option>
                </optgroup>
                <optgroup label="Weeks">
                  <option value="this_week" selected={@current_value == "this_week"}>
                    This Week
                  </option>
                  <option value="last_week" selected={@current_value == "last_week"}>
                    Last Week
                  </option>
                  <option value="next_week" selected={@current_value == "next_week"}>
                    Next Week
                  </option>
                  <option value="weekdays" selected={@current_value == "weekdays"}>
                    Weekdays (Mon-Fri)
                  </option>
                  <option value="weekends" selected={@current_value == "weekends"}>
                    Weekends (Sat-Sun)
                  </option>
                </optgroup>
                <optgroup label="Specific Weekday">
                  <option value="monday" selected={@current_value == "monday"}>Mondays</option>
                  <option value="tuesday" selected={@current_value == "tuesday"}>
                    Tuesdays
                  </option>
                  <option value="wednesday" selected={@current_value == "wednesday"}>
                    Wednesdays
                  </option>
                  <option value="thursday" selected={@current_value == "thursday"}>
                    Thursdays
                  </option>
                  <option value="friday" selected={@current_value == "friday"}>Fridays</option>
                  <option value="saturday" selected={@current_value == "saturday"}>
                    Saturdays
                  </option>
                  <option value="sunday" selected={@current_value == "sunday"}>Sundays</option>
                </optgroup>
                <optgroup label="Months">
                  <option value="this_month" selected={@filter_value["value"] == "this_month"}>
                    This Month
                  </option>
                  <option value="last_month" selected={@filter_value["value"] == "last_month"}>
                    Last Month
                  </option>
                  <option value="next_month" selected={@filter_value["value"] == "next_month"}>
                    Next Month
                  </option>
                  <option value="mtd" selected={@filter_value["value"] == "mtd"}>
                    Month to Date
                  </option>
                </optgroup>
                <optgroup label="Quarters">
                  <option value="this_quarter" selected={@filter_value["value"] == "this_quarter"}>
                    This Quarter
                  </option>
                  <option value="last_quarter" selected={@filter_value["value"] == "last_quarter"}>
                    Last Quarter
                  </option>
                  <option value="next_quarter" selected={@filter_value["value"] == "next_quarter"}>
                    Next Quarter
                  </option>
                  <option value="qtd" selected={@filter_value["value"] == "qtd"}>
                    Quarter to Date
                  </option>
                </optgroup>
                <optgroup label="Years">
                  <option value="this_year" selected={@filter_value["value"] == "this_year"}>
                    This Year
                  </option>
                  <option value="last_year" selected={@filter_value["value"] == "last_year"}>
                    Last Year
                  </option>
                  <option value="next_year" selected={@filter_value["value"] == "next_year"}>
                    Next Year
                  </option>
                  <option value="ytd" selected={@filter_value["value"] == "ytd"}>Year to Date</option>
                </optgroup>
                <optgroup label="Relative Periods">
                  <option value="last_7_days" selected={@filter_value["value"] == "last_7_days"}>
                    Last 7 Days
                  </option>
                  <option value="last_30_days" selected={@filter_value["value"] == "last_30_days"}>
                    Last 30 Days
                  </option>
                  <option value="last_60_days" selected={@filter_value["value"] == "last_60_days"}>
                    Last 60 Days
                  </option>
                  <option value="last_90_days" selected={@filter_value["value"] == "last_90_days"}>
                    Last 90 Days
                  </option>
                  <option value="next_7_days" selected={@filter_value["value"] == "next_7_days"}>
                    Next 7 Days
                  </option>
                  <option value="next_30_days" selected={@filter_value["value"] == "next_30_days"}>
                    Next 30 Days
                  </option>
                </optgroup>
                <optgroup label="Year Comparisons">
                  <option value="last_ytd" selected={@filter_value["value"] == "last_ytd"}>
                    Last Year YTD (same period)
                  </option>
                  <option value="ytd_vs_last" selected={@filter_value["value"] == "ytd_vs_last"}>
                    This Year and Last Year YTD
                  </option>
                  <option value="qtd_vs_last" selected={@filter_value["value"] == "qtd_vs_last"}>
                    This Quarter and Last Quarter QTD
                  </option>
                  <option value="mtd_vs_last" selected={@filter_value["value"] == "mtd_vs_last"}>
                    This Month and Last Month MTD
                  </option>
                  <option
                    value="mtd_vs_last_year"
                    selected={@filter_value["value"] == "mtd_vs_last_year"}
                  >
                    This Month MTD and Last Year's MTD
                  </option>
                </optgroup>
              </select>
              <p
                :if={@shortcut_preview}
                class="px-1 text-xs"
                style="color: var(--sc-text-muted);"
              >
                Preview: {@shortcut_preview}
              </p>
            </div>
          <% @current_comp == "RELATIVE" -> %>
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
              <div class="self-center text-xs" style="color: var(--sc-text-muted);">
                <span class="font-semibold">Examples:</span> 1 = yesterday,
                3-7 = 3-7 days ago,
                -30 = over 30 days ago,
                30- = within 30 days
              </div>
            </div>
          <% @current_comp == "WEEKDAY_SUN1" -> %>
            <select name={"filters[#{@uuid}][value]"} class="sc-select col-span-2">
              <option value="1" selected={to_string(value_for(@filter_value, "value")) == "1"}>
                Sunday
              </option>
              <option value="2" selected={to_string(value_for(@filter_value, "value")) == "2"}>
                Monday
              </option>
              <option value="3" selected={to_string(value_for(@filter_value, "value")) == "3"}>
                Tuesday
              </option>
              <option value="4" selected={to_string(value_for(@filter_value, "value")) == "4"}>
                Wednesday
              </option>
              <option value="5" selected={to_string(value_for(@filter_value, "value")) == "5"}>
                Thursday
              </option>
              <option value="6" selected={to_string(value_for(@filter_value, "value")) == "6"}>
                Friday
              </option>
              <option value="7" selected={to_string(value_for(@filter_value, "value")) == "7"}>
                Saturday
              </option>
            </select>
          <% @current_comp == "WEEK_OF_YEAR" -> %>
            <input
              type="text"
              name={"filters[#{@uuid}][value]"}
              value={value_for(@filter_value, "value")}
              class="sc-input col-span-2"
              placeholder="YYYY-WW (e.g., 2026-10)"
              pattern="^\d{4}-\d{2}$"
            />
          <% @current_comp in ["MONTH_OF_YEAR", "DAY_OF_MONTH", "HOUR_OF_DAY"] -> %>
            <input
              type="number"
              name={"filters[#{@uuid}][value]"}
              value={value_for(@filter_value, "value")}
              class="sc-input col-span-2"
            />
          <% @current_comp in ["DATE=", "DATE!="] -> %>
            <input
              type="date"
              name={"filters[#{@uuid}][value]"}
              value={
                format_datetime_value(@filter_value["value"], @column_def || @filter_def || :date)
              }
              class="sc-input col-span-2"
            />
          <% @current_comp in ["IS NULL", "IS NOT NULL"] -> %>
            <div class="col-span-2 self-center text-sm" style="color: var(--sc-text-muted);">
              No value needed
            </div>
          <% true -> %>
            <input
              type={if @field_type == :date, do: "date", else: "datetime-local"}
              name={"filters[#{@uuid}][value]"}
              value={
                format_datetime_value(
                  @filter_value["value"],
                  @column_def || @filter_def || @field_type
                )
              }
              class="sc-input col-span-2"
              disabled={@current_comp in ["IS NULL", "IS NOT NULL"]}
            />
        <% end %>
      </div>

      <p
        :if={@promote_checked}
        class="text-xs"
        style="color: var(--sc-text-muted);"
      >
        Edited in View Controller.
      </p>

      <input type="hidden" name={"filters[#{@uuid}][uuid]"} value={@uuid} />
      <input type="hidden" name={"filters[#{@uuid}][section]"} value={@section} />
      <input type="hidden" name={"filters[#{@uuid}][index]"} value={@index} />
      <input type="hidden" name={"filters[#{@uuid}][filter]"} value={@filter_value["filter"]} />
      <.promote_checkbox uuid={@uuid} checked={@promote_checked} />
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

    filter_id = value_for(assigns.filter_value, "filter")
    operator_options = standard_operator_options(assigns.field_type, assigns.selecto, filter_id)
    operator_values = Enum.map(operator_options, &elem(&1, 0))
    default_comp = default_standard_comp(assigns.field_type, filter_id, operator_options)

    current_comp =
      case normalize_comp(value_for(assigns.filter_value, "comp"), default_comp) do
        comp ->
          if comp in operator_values do
            comp
          else
            default_comp
          end
      end

    between_start =
      value_for(assigns.filter_value, "value_start") || value_for(assigns.filter_value, "value") ||
        ""

    between_end =
      value_for(assigns.filter_value, "value_end") || value_for(assigns.filter_value, "value2") ||
        ""

    assigns =
      assigns
      |> assign(
        is_multi_select_id: is_multi_select_id,
        supports_manual_in_values: supports_manual_in_values?(assigns.field_type),
        operator_options: operator_options,
        current_comp: current_comp,
        between_start: between_start,
        between_end: between_end,
        selected_in_values: selected_in_values(assigns.filter_value),
        pending_in_values: value_for(assigns.filter_value, "pending_values") || "",
        ignore_case_checked:
          Map.get(assigns.filter_value, "ignore_case", "false") in [
            true,
            "true",
            "on",
            "1",
            "Y",
            "y"
          ],
        promote_checked:
          Map.get(assigns.filter_value, "promote", "false") in [
            true,
            "true",
            "on",
            "1",
            "Y",
            "y"
          ],
        is_text_field: assigns.field_type in [:string, :text, :citext, :custom_column]
      )

    ~H"""
    <div class="space-y-2">
      <div
        class={[
          "grid grid-cols-3 gap-2",
          @promote_checked && "opacity-60"
        ]}
        inert={@promote_checked}
        aria-disabled={to_string(@promote_checked)}
        data-promoted-lock={to_string(@promote_checked)}
      >
        <select name={"filters[#{@uuid}][comp]"} class="sc-select">
          <%= for {op, label} <- @operator_options do %>
            <option value={op} selected={@current_comp == op}>{label}</option>
          <% end %>
        </select>

        <%= cond do %>
          <% @current_comp == "BETWEEN" -> %>
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
          <% @supports_manual_in_values and @current_comp in ["IN", "NOT IN"] -> %>
            <div
              id={"filter-in-values-#{@uuid}-#{:erlang.phash2({@selected_in_values, @current_comp})}"}
              class="col-span-2 space-y-2"
            >
              <textarea
                id={"filter-pending-values-#{@uuid}"}
                name={"filters[#{@uuid}][pending_values]"}
                rows="3"
                placeholder="Paste one value per line"
                class="sc-input min-h-24 resize-y"
                phx-debounce="300"
                phx-hook=".FilterPendingValuesSync"
                data-pending-value={@pending_in_values}
                data-filter-uuid={@uuid}
              >{@pending_in_values}</textarea>

              <input
                type="hidden"
                name={"filters[#{@uuid}][value]"}
                value={Enum.join(@selected_in_values, ",")}
              />

              <%= if @selected_in_values != [] do %>
                <div
                  class="rounded-md border p-2"
                  style="border-color: var(--sc-surface-border); background: var(--sc-surface-bg-alt);"
                >
                  <div class="mb-2 flex items-center justify-between gap-2">
                    <p class="text-xs font-medium" style="color: var(--sc-text-secondary);">
                      {length(@selected_in_values)} selected value{if(
                        length(@selected_in_values) == 1,
                        do: "",
                        else: "s"
                      )}
                    </p>

                    <button
                      type="button"
                      phx-click="clear_filter_selected_values"
                      phx-value-filter-uuid={@uuid}
                      class="text-xs font-medium underline-offset-2 hover:underline"
                      style="color: var(--sc-accent);"
                    >
                      Uncheck all
                    </button>
                  </div>

                  <div class="max-h-40 space-y-1 overflow-y-auto pr-1">
                    <button
                      :for={selected_value <- @selected_in_values}
                      id={"filter-selected-value-#{@uuid}-#{:erlang.phash2(selected_value)}"}
                      type="button"
                      phx-click="toggle_filter_selected_value"
                      phx-value-filter-uuid={@uuid}
                      phx-value-item={selected_value}
                      class="flex w-full items-start gap-2 rounded px-2 py-1 text-left text-sm"
                      style="color: var(--sc-text-primary);"
                    >
                      <input
                        type="checkbox"
                        checked
                        disabled
                        aria-hidden="true"
                        class="pointer-events-none"
                        style="margin-top: 0.15rem;"
                      />
                      <span class="break-all">{selected_value}</span>
                    </button>
                  </div>
                </div>
              <% else %>
                <p class="text-xs" style="color: var(--sc-text-muted);">
                  Paste values above to add them as selectable items.
                </p>
              <% end %>

              <script :type={Phoenix.LiveView.ColocatedHook} name=".FilterPendingValuesSync">
                export default {
                  commitPendingValues() {
                    const pendingValue = this.el.value || "";

                    if (pendingValue.trim() === "") {
                      return;
                    }

                    this.pushEvent("commit_filter_pending_values", {
                      "filter-uuid": this.el.dataset.filterUuid,
                      "pending-values": pendingValue
                    });
                  },

                  syncFromServer() {
                    const pendingValue = this.el.dataset.pendingValue || "";

                    if (this.el.value !== pendingValue) {
                      this.el.value = pendingValue;
                    }
                  },

                  mounted() {
                    this.onBlur = () => this.commitPendingValues();
                    this.el.addEventListener("blur", this.onBlur);
                    this.syncFromServer();
                  },

                  updated() {
                    this.syncFromServer();
                  },

                  destroyed() {
                    if (this.onBlur) {
                      this.el.removeEventListener("blur", this.onBlur);
                    }
                  }
                };
              </script>
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
                disabled={@current_comp in ["IS NULL", "IS NOT NULL"]}
              />
              <div class="mt-1 text-xs" style="color: var(--sc-accent);">
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
              disabled={@current_comp in ["IS NULL", "IS NOT NULL"]}
            />
        <% end %>

        <%= if @is_text_field and @current_comp in ["=", "STARTS"] do %>
          <div
            class="col-span-3 flex items-center gap-2 text-sm"
            style="color: var(--sc-text-secondary);"
          >
            <input type="hidden" name={"filters[#{@uuid}][exclude_articles]"} value="false" />
            <input
              type="checkbox"
              class="checkbox checkbox-sm"
              name={"filters[#{@uuid}][exclude_articles]"}
              value="true"
              checked={
                Map.get(@filter_value, "exclude_articles", "false") in [true, "true", "on", "1"]
              }
              style="border-color: var(--sc-surface-border); --chkbg: var(--sc-accent); --chkfg: var(--sc-surface-bg);"
            /> Ignore leading articles (a, an, the)
          </div>
        <% end %>

        <%= if @is_text_field and @current_comp not in ["IS NULL", "IS NOT NULL"] do %>
          <div
            class="col-span-3 flex items-center gap-2 text-sm"
            style="color: var(--sc-text-secondary);"
          >
            <input type="hidden" name={"filters[#{@uuid}][ignore_case]"} value="false" />
            <input
              type="checkbox"
              class="checkbox checkbox-sm"
              name={"filters[#{@uuid}][ignore_case]"}
              value="true"
              checked={@ignore_case_checked}
              style="border-color: var(--sc-surface-border); --chkbg: var(--sc-accent); --chkfg: var(--sc-surface-bg);"
            /> Case insensitive
          </div>
        <% end %>
      </div>

      <p
        :if={@promote_checked}
        class="text-xs"
        style="color: var(--sc-text-muted);"
      >
        Edited in View Controller.
      </p>

      <.promote_checkbox uuid={@uuid} checked={@promote_checked} />

      <input type="hidden" name={"filters[#{@uuid}][uuid]"} value={@uuid} />
      <input type="hidden" name={"filters[#{@uuid}][section]"} value={@section} />
      <input type="hidden" name={"filters[#{@uuid}][index]"} value={@index} />
      <input type="hidden" name={"filters[#{@uuid}][filter]"} value={@filter_value["filter"]} />
    </div>
    """
  end

  defp standard_operator_options(field_type, selecto, filter_id) do
    if enum_filter?(selecto, filter_id) do
      [
        {"=", "Equals"},
        {"!=", "Not Equals"},
        {"IS NULL", "Is Empty"},
        {"IS NOT NULL", "Is Not Empty"}
      ]
    else
      case field_type do
        x when x in [:id, :integer, :float, :decimal] ->
          [
            {"=", "Equals"},
            {"!=", "Not Equals"},
            {"IN", "Is One Of"},
            {"NOT IN", "Is Not One Of"},
            {">", "Greater Than"},
            {">=", "Greater or Equal"},
            {"<", "Less Than"},
            {"<=", "Less or Equal"},
            {"BETWEEN", "Between"},
            {"IS NULL", "Is Empty"},
            {"IS NOT NULL", "Is Not Empty"}
          ]

        :uuid ->
          [
            {"=", "Equals"},
            {"!=", "Not Equals"},
            {"IN", "Is One Of"},
            {"NOT IN", "Is Not One Of"},
            {"IS NULL", "Is Empty"},
            {"IS NOT NULL", "Is Not Empty"}
          ]

        {:array, _} ->
          [
            {"LIKE", "Contains"},
            {"NOT LIKE", "Does Not Contain"},
            {"IN", "Contains Any Of"},
            {"NOT IN", "Contains None Of"},
            {"IS NULL", "Is Empty"},
            {"IS NOT NULL", "Is Not Empty"}
          ]

        _ ->
          [
            {"=", "Equals"},
            {"!=", "Not Equals"},
            {"IN", "Is One Of"},
            {"NOT IN", "Is Not One Of"},
            {"STARTS", "Begins With"},
            {"LIKE", "Contains"},
            {"NOT LIKE", "Does Not Contain"},
            {"IS NULL", "Is Empty"},
            {"IS NOT NULL", "Is Not Empty"}
          ]
      end
    end
  end

  defp default_standard_comp(field_type, filter_id, operator_options) do
    fallback = operator_options |> List.first() |> elem(0)

    cond do
      match?({:array, _}, field_type) -> "LIKE"
      is_binary(filter_id) and String.contains?(String.downcase(filter_id), "search") -> "LIKE"
      true -> fallback
    end
  end

  defp enum_filter?(selecto, filter_id) do
    with %{field: field, requires_join: join_ref} <- Selecto.field(selecto, filter_id),
         {:ok, field_atom} <- to_existing_atom_safe(field),
         {:ok, schema_module} <- schema_module_for_join(join_ref, selecto),
         true <- function_exported?(schema_module, :__schema__, 2),
         {:parameterized, {Ecto.Enum, _}} <- schema_module.__schema__(:type, field_atom) do
      true
    else
      _ -> false
    end
  end

  defp supports_manual_in_values?(field_type),
    do: field_type in [:id, :integer, :float, :decimal, :string, :text, :citext, :custom_column]

  defp selected_in_values(filter_value) when is_map(filter_value) do
    cond do
      is_list(Map.get(filter_value, "selected_values")) ->
        Map.get(filter_value, "selected_values")
        |> Enum.map(&to_string/1)
        |> Enum.reject(&(&1 == ""))

      is_list(Map.get(filter_value, :selected_values)) ->
        Map.get(filter_value, :selected_values)
        |> Enum.map(&to_string/1)
        |> Enum.reject(&(&1 == ""))

      true ->
        (value_for(filter_value, "value") || "")
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
    end
  end

  defp selected_in_values(_filter_value), do: []

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
    current_mode =
      case normalize_string(assigns.filter_value["mode"]) do
        "" ->
          SelectoComponents.Helpers.default_text_search_mode(Map.get(assigns.selecto, :adapter))

        mode ->
          mode
      end

    assigns =
      assigns
      |> assign(
        text_search_mode_options:
          SelectoComponents.Helpers.text_search_mode_options(Map.get(assigns.selecto, :adapter)),
        text_search_help_text:
          SelectoComponents.Helpers.text_search_help_text(Map.get(assigns.selecto, :adapter)),
        current_text_search_mode: current_mode,
        promote_checked: promote_checked?(assigns.filter_value)
      )

    ~H"""
    <div class="space-y-2">
      <div
        class={[
          "grid grid-cols-1 gap-2",
          @promote_checked && "opacity-60"
        ]}
        inert={@promote_checked}
        aria-disabled={to_string(@promote_checked)}
        data-promoted-lock={to_string(@promote_checked)}
      >
        <div class="flex items-center gap-2">
          <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
            />
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
        <div class="grid grid-cols-1 gap-2 sm:grid-cols-[12rem_minmax(0,1fr)] sm:items-center">
          <label class="text-xs font-medium text-gray-600">Search Mode</label>
          <select name={"filters[#{@uuid}][mode]"} class="sc-select">
            <%= for {value, label} <- @text_search_mode_options do %>
              <option value={value} selected={@current_text_search_mode == value}>{label}</option>
            <% end %>
          </select>
        </div>
        <div class="text-xs text-gray-500">
          {@text_search_help_text}
        </div>
      </div>

      <p
        :if={@promote_checked}
        class="text-xs"
        style="color: var(--sc-text-muted);"
      >
        Edited in View Controller.
      </p>

      <input type="hidden" name={"filters[#{@uuid}][uuid]"} value={@uuid} />
      <input type="hidden" name={"filters[#{@uuid}][section]"} value={@section} />
      <input type="hidden" name={"filters[#{@uuid}][index]"} value={@index} />
      <input type="hidden" name={"filters[#{@uuid}][filter]"} value={@filter_value["filter"]} />
      <.promote_checkbox uuid={@uuid} checked={@promote_checked} />
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

  def format_datetime_value(value, %{} = field_conf) do
    field_conf
    |> Selecto.Temporal.to_display_temporal(value)
    |> case do
      %Date{} = date ->
        format_datetime_value(Date.to_iso8601(date), :date)

      %NaiveDateTime{} = dt ->
        format_datetime_value(NaiveDateTime.to_iso8601(dt), :naive_datetime)

      %DateTime{} = dt ->
        format_datetime_value(DateTime.to_iso8601(dt), :utc_datetime)

      other ->
        format_datetime_value(
          other,
          Selecto.Temporal.date_like_type(field_conf) || Map.get(field_conf, :type)
        )
    end
  end

  def format_datetime_value(value, :date) when is_binary(value) do
    # Try to parse and format as YYYY-MM-DD
    case Date.from_iso8601(value) do
      {:ok, date} -> Date.to_string(date)
      _ -> String.slice(value, 0..9)
    end
  end

  def format_datetime_value(value, type)
      when type in [:naive_datetime, :utc_datetime] and is_binary(value) do
    # Try to parse and format as YYYY-MM-DDTHH:MM for datetime-local input
    cond do
      String.contains?(value, "T") ->
        String.slice(value, 0..15)

      String.length(value) >= 16 ->
        String.slice(value, 0..9) <> "T" <> String.slice(value, 11..15)

      true ->
        value
    end
  end

  def format_datetime_value(value, _type), do: value

  @doc """
  Check if a value is a date shortcut (today, this_week, last_month, etc.).
  """
  def is_date_shortcut(value) when is_binary(value) do
    value in ~w(today yesterday tomorrow this_week last_week next_week
                weekdays weekends monday tuesday wednesday thursday friday saturday sunday
                this_month last_month next_month mtd
                this_quarter last_quarter next_quarter qtd
                this_year last_year next_year ytd
                last_7_days last_30_days last_60_days last_90_days
                next_7_days next_30_days
                ytd_vs_last qtd_vs_last mtd_vs_last last_ytd mtd_vs_last_year)
  end

  def is_date_shortcut(_), do: false

  @doc """
  Build a compact human preview for a date shortcut using the server-local date.
  """
  def date_shortcut_preview(shortcut, today \\ local_today())

  def date_shortcut_preview(shortcut, today) when is_atom(shortcut) do
    date_shortcut_preview(Atom.to_string(shortcut), today)
  end

  def date_shortcut_preview(shortcut, %Date{} = today) when is_binary(shortcut) do
    case shortcut do
      "today" ->
        format_date_preview(today)

      "yesterday" ->
        format_date_preview(Date.add(today, -1))

      "tomorrow" ->
        format_date_preview(Date.add(today, 1))

      "this_week" ->
        format_date_range_preview(beginning_of_week(today), Date.add(beginning_of_week(today), 6))

      "last_week" ->
        start_of_week = beginning_of_week(Date.add(today, -7))
        format_date_range_preview(start_of_week, Date.add(start_of_week, 6))

      "next_week" ->
        start_of_week = beginning_of_week(Date.add(today, 7))
        format_date_range_preview(start_of_week, Date.add(start_of_week, 6))

      "weekdays" ->
        "Every Mon-Fri"

      "weekends" ->
        "Every Sat-Sun"

      "monday" ->
        "Every Monday"

      "tuesday" ->
        "Every Tuesday"

      "wednesday" ->
        "Every Wednesday"

      "thursday" ->
        "Every Thursday"

      "friday" ->
        "Every Friday"

      "saturday" ->
        "Every Saturday"

      "sunday" ->
        "Every Sunday"

      "this_month" ->
        format_month_preview(today.year, today.month)

      "last_month" ->
        last_month = Date.add(Date.beginning_of_month(today), -1)
        format_month_preview(last_month.year, last_month.month)

      "next_month" ->
        next_month = Date.beginning_of_month(Date.add(Date.end_of_month(today), 1))
        format_month_preview(next_month.year, next_month.month)

      "mtd" ->
        format_date_range_preview(Date.beginning_of_month(today), today)

      "this_quarter" ->
        format_quarter_preview(today)

      "last_quarter" ->
        last_quarter = Date.add(beginning_of_quarter(today), -1)
        format_quarter_preview(last_quarter)

      "next_quarter" ->
        next_quarter = Date.add(quarter_end(today), 1)
        format_quarter_preview(next_quarter)

      "qtd" ->
        format_date_range_preview(beginning_of_quarter(today), today)

      "this_year" ->
        Integer.to_string(today.year)

      "last_year" ->
        Integer.to_string(today.year - 1)

      "next_year" ->
        Integer.to_string(today.year + 1)

      "ytd" ->
        format_date_range_preview(Date.new!(today.year, 1, 1), today)

      "last_7_days" ->
        format_date_range_preview(Date.add(today, -6), today)

      "last_30_days" ->
        format_date_range_preview(Date.add(today, -29), today)

      "last_60_days" ->
        format_date_range_preview(Date.add(today, -59), today)

      "last_90_days" ->
        format_date_range_preview(Date.add(today, -89), today)

      "next_7_days" ->
        format_date_range_preview(today, Date.add(today, 6))

      "next_30_days" ->
        format_date_range_preview(today, Date.add(today, 29))

      "last_ytd" ->
        same_day = safe_same_day_last_year(today)
        format_date_range_preview(Date.new!(today.year - 1, 1, 1), same_day)

      "ytd_vs_last" ->
        same_day = safe_same_day_last_year(today)

        format_comparison_preview([
          {Date.new!(today.year, 1, 1), today},
          {Date.new!(today.year - 1, 1, 1), same_day}
        ])

      "qtd_vs_last" ->
        same_day = safe_same_day_last_year(today)
        last_year_quarter_start = Date.new!(today.year - 1, beginning_of_quarter(today).month, 1)

        format_comparison_preview([
          {beginning_of_quarter(today), today},
          {last_year_quarter_start, same_day}
        ])

      "mtd_vs_last" ->
        {last_month_start, same_day_last_month} = last_month_range(today)

        format_comparison_preview([
          {Date.beginning_of_month(today), today},
          {last_month_start, same_day_last_month}
        ])

      "mtd_vs_last_year" ->
        same_day = safe_same_day_last_year(today)

        format_comparison_preview([
          {Date.beginning_of_month(today), today},
          {Date.new!(today.year - 1, today.month, 1), same_day}
        ])

      _ ->
        nil
    end
  end

  def date_shortcut_preview(_, _), do: nil

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

  defp format_date_preview(%Date{} = date), do: Date.to_iso8601(date)

  defp format_date_range_preview(%Date{} = start_date, %Date{} = end_date) do
    "#{Date.to_iso8601(start_date)} to #{Date.to_iso8601(end_date)}"
  end

  defp format_month_preview(year, month) do
    "#{String.pad_leading(Integer.to_string(month), 2, "0")}-#{year}"
  end

  defp format_quarter_preview(%Date{} = date) do
    quarter = div(date.month - 1, 3) + 1
    "Q#{quarter}-#{date.year}"
  end

  defp format_comparison_preview(ranges) when is_list(ranges) do
    ranges
    |> Enum.map(fn {start_date, end_date} -> format_date_range_preview(start_date, end_date) end)
    |> Enum.join(" + ")
  end

  defp safe_same_day_last_year(%Date{} = today) do
    case Date.new(today.year - 1, today.month, today.day) do
      {:ok, date} ->
        date

      {:error, _reason} ->
        Date.new!(today.year - 1, today.month, today.day - 1)
    end
  end

  defp last_month_range(%Date{} = today) do
    {year, month} =
      if today.month == 1 do
        {today.year - 1, 12}
      else
        {today.year, today.month - 1}
      end

    start_date = Date.new!(year, month, 1)
    max_day = Date.days_in_month(start_date)
    same_day = Date.new!(year, month, min(today.day, max_day))

    {start_date, same_day}
  end

  defp beginning_of_week(%Date{} = date) do
    day_of_week = Date.day_of_week(date, :monday)
    Date.add(date, -(day_of_week - 1))
  end

  defp beginning_of_quarter(%Date{} = date) do
    quarter_month = div(date.month - 1, 3) * 3 + 1
    Date.new!(date.year, quarter_month, 1)
  end

  defp quarter_end(%Date{} = date) do
    quarter_start = beginning_of_quarter(date)

    Date.add(Date.add(quarter_start, 93), -1)
    |> Date.beginning_of_month()
    |> Date.add(-1)
  end

  defp local_today do
    {{year, month, day}, _time} = :calendar.local_time()
    Date.new!(year, month, day)
  end

  defp date_specific_datetime_comp?(comp) when is_binary(comp) do
    comp in [
      "DATE=",
      "DATE!=",
      "DATE_BETWEEN",
      "SHORTCUT",
      "RELATIVE",
      "WEEKDAY",
      "WEEKDAY_SUN1",
      "WEEK_OF_YEAR",
      "MONTH_OF_YEAR",
      "DAY_OF_MONTH",
      "HOUR_OF_DAY"
    ]
  end

  defp date_specific_datetime_comp?(_), do: false

  defp promote_checked?(filter_value) when is_map(filter_value) do
    Map.get(filter_value, "promote", Map.get(filter_value, :promote, "false")) in [
      true,
      "true",
      "on",
      "1",
      "Y",
      "y"
    ]
  end

  defp promote_checked?(_filter_value), do: false

  defp value_for(map, key) when is_map(map) and is_binary(key) do
    atom_key =
      try do
        String.to_existing_atom(key)
      rescue
        ArgumentError -> nil
      end

    if atom_key, do: Map.get(map, key, Map.get(map, atom_key)), else: Map.get(map, key)
  rescue
    _ -> Map.get(map, key)
  end

  defp value_for(_map, _key), do: nil

  defp normalize_comp(value, _fallback) when is_atom(value), do: Atom.to_string(value)
  defp normalize_comp(value, _fallback) when is_binary(value) and value != "", do: value
  defp normalize_comp(_value, fallback), do: fallback

  defp normalize_string(value) when is_binary(value), do: value
  defp normalize_string(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_string(value) when is_integer(value), do: Integer.to_string(value)
  defp normalize_string(value) when is_float(value), do: :erlang.float_to_binary(value)
  defp normalize_string(nil), do: ""
  defp normalize_string(value), do: to_string(value)

  @doc """
  Hash filter structure and comparator mode, not filter values.

  This ensures the component remounts when filters are added/removed or
  comparator mode changes, but not when filter values change.
  """
  def hash_filter_structure(filters) do
    # Hash UUIDs, sections, filter field IDs, and comparator mode so the
    # component remounts when input shape changes (e.g. BETWEEN -> IS NULL)
    filters
    |> Enum.map(fn
      {uuid, section, config} when is_map(config) ->
        {uuid, section, Map.get(config, "filter"), Map.get(config, "comp")}

      {uuid, section, conj} when is_binary(conj) ->
        {uuid, section, conj}
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
      Selecto.columns(selecto)
      |> Enum.map(fn {colid, column} -> Map.put_new(column, :colid, colid) end)
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
      %{colid: id} = c ->
        {id, c.name,
         %{
           type: Selecto.Temporal.date_like_type(c) || Map.get(c, :type),
           format: Map.get(c, :format),
           icon: Map.get(c, :icon),
           icon_family: Map.get(c, :icon_family)
         }}

      %{id: id} = c ->
        {id, c.name,
         %{
           type: Selecto.Temporal.date_like_type(c) || Map.get(c, :type),
           format: Map.get(c, :format),
           icon: Map.get(c, :icon),
           icon_family: Map.get(c, :icon_family)
         }}
    end)
  end

  defp find_join_mode_config(selecto, filter_id, column_def) do
    # Check if column_def already has join_mode
    if column_def && Map.get(column_def, :join_mode) in [:lookup, :star, :tag] &&
         Map.get(column_def, :filter_type) == :multi_select_id do
      column_def
    else
      domain = Selecto.domain(selecto)

      # Parse filter_id to get schema and field parts
      {schema_name, field_part} =
        if is_binary(filter_id) and String.contains?(filter_id, ".") do
          parts = String.split(filter_id, ".", parts: 2)
          {Enum.at(parts, 0), Enum.at(parts, 1)}
        else
          # For fields without schema prefix (e.g., "category_id"), use source schema
          source_table = get_in(domain, [:source, :source_table])
          {source_table, filter_id}
        end

      # Check if this is an ID field that might have join_mode configuration
      if field_part in ["id"] or String.ends_with?(field_part || "", "_id") do
        schema_atom =
          try do
            String.to_existing_atom(schema_name)
          rescue
            ArgumentError -> nil
          end

        result_case1 =
          if schema_atom do
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

          Enum.find_value(schemas, fn {_schema_name_atom, schema_config} ->
            columns = Map.get(schema_config, :columns, %{})

            Enum.find_value(columns, fn {_col_name, col_config} ->
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
    query_where = Map.get(join_mode_config, :query_where)
    query_params = Map.get(join_mode_config, :query_params, [])

    options =
      if table do
        query_table_options(
          assigns.selecto,
          table,
          id_field,
          display_field,
          100,
          query_where,
          query_params
        )
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
      |> assign(
        options: options,
        selected_ids: selected_ids,
        join_mode: join_mode,
        current_comp: current_comp,
        display_field: display_field,
        filter_label: Map.get(join_mode_config, :name) || humanize_field(display_field),
        promote_checked: promote_checked?(assigns.filter_value)
      )

    ~H"""
    <div class="space-y-2">
      <div
        class={[
          "space-y-2",
          @promote_checked && "opacity-60"
        ]}
        inert={@promote_checked}
        aria-disabled={to_string(@promote_checked)}
        data-promoted-lock={to_string(@promote_checked)}
      >
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
            Select {@filter_label}:
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
                  <span class="text-sm text-gray-900">{opt.name}</span>
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
              class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
            >
              <%= for opt <- @options do %>
                <option value={opt.id} selected={opt.id in @selected_ids}>
                  {opt.name}
                </option>
              <% end %>
            </select>
            <p class="text-xs text-gray-500 mt-1">
              Hold Ctrl/Cmd to select multiple. Click outside when done.
            </p>
          <% end %>

          <div class="text-xs text-gray-500">
            {length(@selected_ids)} of {length(@options)} selected
          </div>

          <%!-- Hidden field to store comma-separated IDs (only needed for IN/NOT IN) --%>
          <%= if @current_comp in ["IN", "NOT IN"] do %>
            <input
              id={"filter-value-#{@uuid}"}
              type="hidden"
              name={"filters[#{@uuid}][value]"}
              value={Enum.join(@selected_ids, ",")}
            />
          <% end %>
        <% end %>
      </div>

      <p
        :if={@promote_checked}
        class="text-xs"
        style="color: var(--sc-text-muted);"
      >
        Edited in View Controller.
      </p>

      <.promote_checkbox uuid={@uuid} checked={@promote_checked} />

      <%!-- Hidden inputs to preserve filter structure --%>
      <input type="hidden" name={"filters[#{@uuid}][uuid]"} value={@uuid} />
      <input type="hidden" name={"filters[#{@uuid}][section]"} value={@section} />
      <input type="hidden" name={"filters[#{@uuid}][index]"} value={@index} />
      <input type="hidden" name={"filters[#{@uuid}][filter]"} value={@filter_value["filter"]} />
    </div>
    """
  end

  def join_mode_options(selecto, join_mode_config, limit \\ 100)

  def join_mode_options(selecto, %{} = join_mode_config, limit) do
    table = Map.get(join_mode_config, :source_table)
    id_field = Map.get(join_mode_config, :id_field, :id)
    display_field = Map.get(join_mode_config, :display_field, :name)
    query_where = Map.get(join_mode_config, :query_where)
    query_params = Map.get(join_mode_config, :query_params, [])

    if table do
      query_table_options(
        selecto,
        table,
        id_field,
        display_field,
        limit,
        query_where,
        query_params
      )
    else
      []
    end
  end

  def join_mode_options(_selecto, _join_mode_config, _limit), do: []

  # Query database for ID+name pairs using Selecto's connection (Repo)
  defp query_table_options(
         selecto,
         table,
         id_field,
         display_field,
         limit,
         query_where,
         query_params
       ) do
    with {:ok, safe_table} <- safe_sql_identifier(table),
         {:ok, safe_id_field} <- safe_sql_identifier(id_field),
         {:ok, safe_display_field} <- safe_sql_identifier(display_field) do
      where_clause =
        if is_binary(query_where) and query_where != "", do: "AND #{query_where}", else: ""

      query = """
      SELECT #{safe_id_field} as id, #{safe_display_field} as name
      FROM #{safe_table}
      WHERE #{safe_display_field} IS NOT NULL
      #{where_clause}
      ORDER BY #{safe_display_field}
      LIMIT $1
      """

      connection = selecto.connection

      case execute_options_query(connection, query, [limit | query_params]) do
        {:ok, %{rows: rows}} ->
          Enum.map(rows, fn [id, name] ->
            %{id: normalize_option_id(id), name: to_string(name)}
          end)

        {:error, error} ->
          Logger.warning("Failed to query options for multi-select filter: #{inspect(error)}")
          []
      end
    else
      {:error, :invalid_identifier} ->
        Logger.warning("Skipped multi-select options query due to invalid SQL identifier")
        []
    end
  rescue
    e ->
      Logger.warning("Exception querying options for multi-select filter: #{inspect(e)}")
      []
  end

  defp execute_options_query(connection, query, params) when is_atom(connection) do
    cond do
      function_exported?(connection, :query, 2) ->
        connection.query(query, params)

      function_exported?(connection, :query, 3) ->
        connection.query(query, params, [])

      true ->
        do_postgrex_query(connection, query, params)
    end
  end

  defp execute_options_query(connection, query, params) when is_pid(connection) do
    do_postgrex_query(connection, query, params)
  end

  defp execute_options_query(_connection, _query, _params), do: {:error, :invalid_connection}

  defp do_postgrex_query(connection, query, params) do
    if Code.ensure_loaded?(Postgrex) do
      apply(Postgrex, :query, [connection, query, params])
    else
      {:error, :postgrex_not_available}
    end
  end

  defp normalize_option_id(id) when is_binary(id) do
    case Ecto.UUID.load(id) do
      {:ok, uuid} -> uuid
      :error -> id
    end
  end

  defp normalize_option_id(id), do: to_string(id)

  defp humanize_field(field) when is_atom(field),
    do: field |> Atom.to_string() |> humanize_field()

  defp humanize_field(field) when is_binary(field) do
    field
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp humanize_field(field), do: to_string(field)

  defp safe_sql_identifier(value) when is_atom(value),
    do: safe_sql_identifier(Atom.to_string(value))

  defp safe_sql_identifier(value) when is_binary(value) do
    trimmed = String.trim(value)

    if Regex.match?(@identifier_regex, trimmed) do
      {:ok, trimmed}
    else
      {:error, :invalid_identifier}
    end
  end

  defp safe_sql_identifier(_value), do: {:error, :invalid_identifier}

  # Parse comma-separated IDs from value string
  defp parse_filter_ids(value) when is_binary(value) do
    value
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp parse_filter_ids(_), do: []

  attr(:uuid, :string, required: true)
  attr(:checked, :boolean, required: true)

  defp promote_checkbox(assigns) do
    ~H"""
    <div
      class="col-span-3 flex items-center gap-2 text-sm"
      style="color: var(--sc-text-secondary);"
    >
      <input type="hidden" name={"filters[#{@uuid}][promote]"} value="false" />
      <input
        type="checkbox"
        class="checkbox checkbox-sm"
        name={"filters[#{@uuid}][promote]"}
        value="true"
        checked={@checked}
        style="border-color: var(--sc-surface-border); --chkbg: var(--sc-accent); --chkfg: var(--sc-surface-bg);"
      /> Promote to View Controller
    </div>
    """
  end

  defp find_polymorphic_config(selecto, filter_id, column_def) do
    # Check if column_def already has polymorphic join_mode
    if column_def && Map.get(column_def, :join_mode) == :polymorphic &&
         Map.get(column_def, :filter_type) == :polymorphic do
      column_def
    else
      domain = Selecto.domain(selecto)

      # Parse filter_id to get schema and field parts
      {schema_name, field_part} =
        if is_binary(filter_id) and String.contains?(filter_id, ".") do
          parts = String.split(filter_id, ".", parts: 2)
          {Enum.at(parts, 0), Enum.at(parts, 1)}
        else
          # For fields without schema prefix, use source schema
          source_table = get_in(domain, [:source, :source_table])
          {source_table, filter_id}
        end

      # Check if this is a type or id field that might have polymorphic configuration
      if String.ends_with?(field_part || "", "_type") or
           String.ends_with?(field_part || "", "_id") do
        schema_atom =
          try do
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
      |> assign(
        entity_types: entity_types,
        type_field: type_field,
        id_field: id_field,
        selected_types: selected_types,
        current_selection: current_value
      )

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
            <span class="text-sm text-gray-900">{entity_type}</span>
          </label>
        <% end %>
      </div>

      <%!-- Value selection for each selected type --%>
      <%= if length(@selected_types) > 0 do %>
        <div class="space-y-2 border-t pt-2">
          <%= for entity_type <- @selected_types do %>
            <div class="space-y-1">
              <label class="text-xs font-medium text-gray-600">
                {entity_type} IDs:
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
      <input type="hidden" name={"filters[#{@uuid}][uuid]"} value={@uuid} />
      <input type="hidden" name={"filters[#{@uuid}][section]"} value={@section} />
      <input type="hidden" name={"filters[#{@uuid}][index]"} value={@index} />
      <input type="hidden" name={"filters[#{@uuid}][filter]"} value={@filter_value["filter"]} />
      <input type="hidden" name={"filters[#{@uuid}][comp]"} value="POLYMORPHIC" />

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
