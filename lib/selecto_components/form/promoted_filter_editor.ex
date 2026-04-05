defmodule SelectoComponents.Form.PromotedFilterEditor do
  use Phoenix.Component

  alias SelectoComponents.Form.FilterRendering
  alias SelectoComponents.Theme

  attr(:filter, :map, required: true)
  attr(:theme, :map, required: true)

  def editor(assigns) do
    assigns = assign(assigns, :comp_label, filter_badge_label(assigns.filter))

    case assigns.filter.render_kind do
      :datetime -> datetime_filter_editor(assigns)
      :text_search -> text_search_filter_editor(assigns)
      _ -> standard_filter_editor(assigns)
    end
  end

  attr(:filter, :map, required: true)
  attr(:theme, :map, required: true)

  defp standard_filter_editor(assigns) do
    ~H"""
    <div class="space-y-2">
      <span
        class="inline-flex shrink-0 items-center rounded-full px-2 py-1 text-[0.7rem] font-medium uppercase tracking-[0.12em]"
        style="background: color-mix(in srgb, var(--sc-primary) 14%, transparent); color: var(--sc-primary);"
      >
        {@comp_label}
      </span>

      <%= cond do %>
        <% @filter.comp == "BETWEEN" -> %>
          <div class="grid grid-cols-2 gap-2">
            <input
              id={"promoted-filter-value-start-#{@filter.uuid}"}
              type="text"
              name={"promoted_filters[#{@filter.uuid}][value_start]"}
              value={@filter.value_start}
              placeholder="Start"
              class={Theme.slot(@theme, :input)}
              phx-debounce="300"
            />
            <input
              id={"promoted-filter-value-end-#{@filter.uuid}"}
              type="text"
              name={"promoted_filters[#{@filter.uuid}][value_end]"}
              value={@filter.value_end}
              placeholder="End"
              class={Theme.slot(@theme, :input)}
              phx-debounce="300"
            />
          </div>
        <% @filter.comp in ["IN", "NOT IN"] -> %>
          <textarea
            id={"promoted-filter-value-#{@filter.uuid}"}
            name={"promoted_filters[#{@filter.uuid}][value]"}
            rows="3"
            placeholder="Enter one value per line or use commas"
            class={Theme.slot(@theme, :input) <> " min-h-24 resize-y"}
            phx-debounce="300"
          >{@filter.list_value}</textarea>
        <% @filter.comp in ["IS NULL", "IS NOT NULL"] -> %>
          <p class="text-sm" style="color: var(--sc-text-muted);">
            No value needed for this filter.
          </p>
        <% true -> %>
          <input
            id={"promoted-filter-value-#{@filter.uuid}"}
            type="text"
            name={"promoted_filters[#{@filter.uuid}][value]"}
            value={@filter.value}
            class={Theme.slot(@theme, :input)}
            phx-debounce="300"
          />
      <% end %>
    </div>
    """
  end

  attr(:filter, :map, required: true)
  attr(:theme, :map, required: true)

  defp datetime_filter_editor(assigns) do
    ~H"""
    <div class="space-y-2">
      <span
        class="inline-flex shrink-0 items-center rounded-full px-2 py-1 text-[0.7rem] font-medium uppercase tracking-[0.12em]"
        style="background: color-mix(in srgb, var(--sc-primary) 14%, transparent); color: var(--sc-primary);"
      >
        {@comp_label}
      </span>

      <%= cond do %>
        <% @filter.comp in ["BETWEEN", "DATE_BETWEEN"] -> %>
          <div class="grid grid-cols-2 gap-2">
            <input
              id={"promoted-filter-value-start-#{@filter.uuid}"}
              type={if @filter.comp == "DATE_BETWEEN" or @filter.field_type == :date, do: "date", else: "datetime-local"}
              name={"promoted_filters[#{@filter.uuid}][value_start]"}
              value={FilterRendering.format_datetime_value(@filter.value_start, @filter.field_conf)}
              class={Theme.slot(@theme, :input)}
              phx-debounce="300"
            />
            <input
              id={"promoted-filter-value-end-#{@filter.uuid}"}
              type={if @filter.comp == "DATE_BETWEEN" or @filter.field_type == :date, do: "date", else: "datetime-local"}
              name={"promoted_filters[#{@filter.uuid}][value_end]"}
              value={FilterRendering.format_datetime_value(@filter.value_end, @filter.field_conf)}
              class={Theme.slot(@theme, :input)}
              phx-debounce="300"
            />
          </div>
        <% @filter.comp == "WEEKDAY_SUN1" -> %>
          <select
            id={"promoted-filter-value-#{@filter.uuid}"}
            name={"promoted_filters[#{@filter.uuid}][value]"}
            class="sc-select"
          >
            <%= for {value, label} <- weekday_options() do %>
              <option value={value} selected={to_string(@filter.value) == value}>{label}</option>
            <% end %>
          </select>
        <% @filter.comp in ["MONTH_OF_YEAR", "DAY_OF_MONTH", "HOUR_OF_DAY"] -> %>
          <input
            id={"promoted-filter-value-#{@filter.uuid}"}
            type="number"
            name={"promoted_filters[#{@filter.uuid}][value]"}
            value={@filter.value}
            class={Theme.slot(@theme, :input)}
            phx-debounce="300"
          />
        <% @filter.comp in ["IS NULL", "IS NOT NULL"] -> %>
          <p class="text-sm" style="color: var(--sc-text-muted);">
            No value needed for this filter.
          </p>
        <% @filter.comp in ["DATE=", "DATE!="] -> %>
          <input
            id={"promoted-filter-value-#{@filter.uuid}"}
            type="date"
            name={"promoted_filters[#{@filter.uuid}][value]"}
            value={FilterRendering.format_datetime_value(@filter.value, :date)}
            class={Theme.slot(@theme, :input)}
            phx-debounce="300"
          />
        <% @filter.comp == "SHORTCUT" -> %>
          <div class="space-y-1">
            <select
              id={"promoted-filter-value-#{@filter.uuid}"}
              name={"promoted_filters[#{@filter.uuid}][value]"}
              class="sc-select w-full"
            >
              <%= for {group_label, options} <- shortcut_option_groups() do %>
                <optgroup label={group_label}>
                  <%= for {value, label} <- options do %>
                    <option value={value} selected={@filter.value == value}>{label}</option>
                  <% end %>
                </optgroup>
              <% end %>
            </select>
            <p
              :if={FilterRendering.date_shortcut_preview(@filter.value)}
              class="px-1 text-xs"
              style="color: var(--sc-text-muted);"
            >
              Preview: {FilterRendering.date_shortcut_preview(@filter.value)}
            </p>
          </div>
        <% @filter.comp in ["RELATIVE", "WEEK_OF_YEAR"] -> %>
          <input
            id={"promoted-filter-value-#{@filter.uuid}"}
            type="text"
            name={"promoted_filters[#{@filter.uuid}][value]"}
            value={@filter.value}
            class={Theme.slot(@theme, :input)}
            phx-debounce="300"
          />
        <% true -> %>
          <input
            id={"promoted-filter-value-#{@filter.uuid}"}
            type={if @filter.field_type == :date, do: "date", else: "datetime-local"}
            name={"promoted_filters[#{@filter.uuid}][value]"}
            value={FilterRendering.format_datetime_value(@filter.value, @filter.field_conf)}
            class={Theme.slot(@theme, :input)}
            phx-debounce="300"
          />
      <% end %>
    </div>
    """
  end

  attr(:filter, :map, required: true)
  attr(:theme, :map, required: true)

  defp text_search_filter_editor(assigns) do
    ~H"""
    <div class="space-y-2">
      <span
        class="inline-flex shrink-0 items-center rounded-full px-2 py-1 text-[0.7rem] font-medium uppercase tracking-[0.12em]"
        style="background: color-mix(in srgb, var(--sc-primary) 14%, transparent); color: var(--sc-primary);"
      >
        {@comp_label}
      </span>

      <input
        id={"promoted-filter-value-#{@filter.uuid}"}
        type="text"
        name={"promoted_filters[#{@filter.uuid}][value]"}
        value={@filter.value}
        placeholder="Search query"
        class={Theme.slot(@theme, :input)}
        phx-debounce="300"
      />

      <select name={"promoted_filters[#{@filter.uuid}][mode]"} class="sc-select">
        <%= for {value, label} <- @filter.text_search_mode_options do %>
          <option value={value} selected={@filter.mode == value}>{label}</option>
        <% end %>
      </select>
    </div>
    """
  end

  defp filter_comp_label(comp) do
    case comp do
      "=" -> "Equals"
      "!=" -> "Not Equals"
      "IN" -> "Is One Of"
      "NOT IN" -> "Is Not One Of"
      ">" -> "Greater Than"
      ">=" -> "Greater or Equal"
      "<" -> "Less Than"
      "<=" -> "Less or Equal"
      "BETWEEN" -> "Between"
      "DATE=" -> "Date Equals"
      "DATE!=" -> "Date Not Equals"
      "DATE_BETWEEN" -> "Date Between"
      "SHORTCUT" -> "Quick Select"
      "RELATIVE" -> "Relative Days"
      "WEEKDAY_SUN1" -> "Day of Week"
      "WEEK_OF_YEAR" -> "Week of Year"
      "MONTH_OF_YEAR" -> "Month of Year"
      "DAY_OF_MONTH" -> "Day of Month"
      "HOUR_OF_DAY" -> "Hour of Day"
      "LIKE" -> "Contains"
      "NOT LIKE" -> "Does Not Contain"
      "STARTS" -> "Begins With"
      "ENDS" -> "Ends With"
      "CONTAINS" -> "Contains"
      "TEXT_PREFIX" -> "Text Prefix"
      "TEXT_SEARCH" -> "Text Search"
      "IS NULL" -> "Is Empty"
      "IS NOT NULL" -> "Is Not Empty"
      _ -> comp
    end
  end

  defp filter_badge_label(%{render_kind: :text_search}), do: "Text Search"
  defp filter_badge_label(filter), do: filter_comp_label(filter.comp)

  defp weekday_options do
    [
      {"1", "Sunday"},
      {"2", "Monday"},
      {"3", "Tuesday"},
      {"4", "Wednesday"},
      {"5", "Thursday"},
      {"6", "Friday"},
      {"7", "Saturday"}
    ]
  end

  defp shortcut_option_groups do
    [
      {"Days",
       [
         {"today", "Today"},
         {"yesterday", "Yesterday"},
         {"tomorrow", "Tomorrow"}
       ]},
      {"Weeks",
       [
         {"this_week", "This Week"},
         {"last_week", "Last Week"},
         {"next_week", "Next Week"},
         {"weekdays", "Weekdays (Mon-Fri)"},
         {"weekends", "Weekends (Sat-Sun)"}
       ]},
      {"Specific Weekday",
       [
         {"monday", "Mondays"},
         {"tuesday", "Tuesdays"},
         {"wednesday", "Wednesdays"},
         {"thursday", "Thursdays"},
         {"friday", "Fridays"},
         {"saturday", "Saturdays"},
         {"sunday", "Sundays"}
       ]},
      {"Months",
       [
         {"this_month", "This Month"},
         {"last_month", "Last Month"},
         {"next_month", "Next Month"},
         {"mtd", "Month to Date"}
       ]},
      {"Quarters",
       [
         {"this_quarter", "This Quarter"},
         {"last_quarter", "Last Quarter"},
         {"next_quarter", "Next Quarter"},
         {"qtd", "Quarter to Date"}
       ]},
      {"Years",
       [
         {"this_year", "This Year"},
         {"last_year", "Last Year"},
         {"next_year", "Next Year"},
         {"ytd", "Year to Date"}
       ]},
      {"Relative Periods",
       [
         {"last_7_days", "Last 7 Days"},
         {"last_30_days", "Last 30 Days"},
         {"last_60_days", "Last 60 Days"},
         {"last_90_days", "Last 90 Days"},
         {"next_7_days", "Next 7 Days"},
         {"next_30_days", "Next 30 Days"}
       ]},
      {"Year Comparisons",
       [
         {"last_ytd", "Last Year YTD (same period)"},
         {"ytd_vs_last", "This Year and Last Year YTD"},
         {"qtd_vs_last", "This Quarter and Last Quarter QTD"},
         {"mtd_vs_last", "This Month and Last Month MTD"},
         {"mtd_vs_last_year", "This Month MTD and Last Year's MTD"}
       ]}
    ]
  end
end
