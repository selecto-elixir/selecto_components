defmodule SelectoComponents.Filter.DateRangeFilter do
  @moduledoc """
  Provides date range filtering with presets and custom date selection.
  """
  
  use Phoenix.Component

  # @date_presets [
  #   {"Today", :today},
  #   {"Yesterday", :yesterday},
  #   {"Last 7 days", :last_7_days},
  #   {"Last 30 days", :last_30_days},
  #   {"This month", :this_month},
  #   {"Last month", :last_month},
  #   {"This year", :this_year},
  #   {"Last year", :last_year},
  #   {"Custom", :custom}
  # ]
  
  @doc """
  Date range filter component with presets.
  """
  def date_range_filter(assigns) do
    ~H"""
    <div class="date-range-filter" phx-hook="DateRangeFilter" id={@id}>
      <div class="flex items-center space-x-2">
        <%!-- Preset selector --%>
        <select
          name={@field <> "_preset"}
          id={@field <> "_preset"}
          class="block w-32 rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
          phx-change="date_preset_changed"
          phx-value-field={@field}
        >
          <%= for {label, value} <- @date_presets do %>
            <option value={value} selected={@preset == value}>
              <%= label %>
            </option>
          <% end %>
        </select>
        
        <%!-- Custom date inputs --%>
        <div class={"flex items-center space-x-2 #{if @preset != :custom, do: "hidden"}"} id={@field <> "_custom_dates"}>
          <input
            type="date"
            name={@field <> "_start"}
            id={@field <> "_start"}
            value={@start_date}
            class="block rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
            phx-change="date_range_changed"
            phx-value-field={@field}
            phx-value-type="start"
          />
          <span class="text-gray-500">to</span>
          <input
            type="date"
            name={@field <> "_end"}
            id={@field <> "_end"}
            value={@end_date}
            class="block rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
            phx-change="date_range_changed"
            phx-value-field={@field}
            phx-value-type="end"
          />
        </div>
        
        <%!-- Clear button --%>
        <%= if @start_date || @end_date do %>
          <button
            type="button"
            class="text-gray-400 hover:text-gray-600"
            phx-click="clear_date_filter"
            phx-value-field={@field}
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
            </svg>
          </button>
        <% end %>
      </div>
      
      <%!-- Visual indicator for active filter --%>
      <%= if @start_date || @end_date do %>
        <div class="mt-1 text-xs text-blue-600">
          Filtering: <%= format_date_range(@start_date, @end_date, @preset) %>
        </div>
      <% end %>
    </div>
    """
  end
  
  @doc """
  Calculate date range from preset.
  """
  def calculate_date_range(preset) do
    today = Date.utc_today()
    
    case preset do
      :today ->
        {today, today}
        
      :yesterday ->
        yesterday = Date.add(today, -1)
        {yesterday, yesterday}
        
      :last_7_days ->
        {Date.add(today, -6), today}
        
      :last_30_days ->
        {Date.add(today, -29), today}
        
      :this_month ->
        start = beginning_of_month(today)
        {start, today}
        
      :last_month ->
        last_month = Date.add(today, -today.day)
        start = beginning_of_month(last_month)
        end_date = end_of_month(last_month)
        {start, end_date}
        
      :this_year ->
        start = Date.new!(today.year, 1, 1)
        {start, today}
        
      :last_year ->
        start = Date.new!(today.year - 1, 1, 1)
        end_date = Date.new!(today.year - 1, 12, 31)
        {start, end_date}
        
      :custom ->
        {nil, nil}
        
      _ ->
        {nil, nil}
    end
  end
  
  @doc """
  Format date range for display.
  """
  def format_date_range(nil, nil, _preset), do: ""
  def format_date_range(_start_date, _end_date, :today), do: "Today"
  def format_date_range(_start_date, _end_date, :yesterday), do: "Yesterday"
  def format_date_range(start_date, end_date, preset) when preset in [:last_7_days, :last_30_days] do
    "#{start_date} to #{end_date}"
  end
  def format_date_range(start_date, end_date, _preset) do
    if start_date == end_date do
      "#{start_date}"
    else
      "#{start_date} to #{end_date}"
    end
  end
  
  @doc """
  Build filter expression for Selecto.
  """
  def build_filter_expression(field, start_date, end_date) do
    cond do
      start_date && end_date ->
        ["#{field} >= ?", start_date, "#{field} <= ?", end_date]
        
      start_date ->
        ["#{field} >= ?", start_date]
        
      end_date ->
        ["#{field} <= ?", end_date]
        
      true ->
        nil
    end
  end
  
  @doc """
  JavaScript hooks for date range filter.
  """
  def js_hooks do
    """
    export const DateRangeFilter = {
      mounted() {
        this.presetSelect = this.el.querySelector('[name$="_preset"]');
        this.customDates = this.el.querySelector('[id$="_custom_dates"]');
        this.startInput = this.el.querySelector('[name$="_start"]');
        this.endInput = this.el.querySelector('[name$="_end"]');
        
        if (this.presetSelect) {
          this.presetSelect.addEventListener('change', (e) => {
            if (e.target.value === 'custom') {
              this.customDates?.classList.remove('hidden');
              this.startInput?.focus();
            } else {
              this.customDates?.classList.add('hidden');
            }
          });
        }
        
        // Validate date range
        if (this.startInput && this.endInput) {
          this.startInput.addEventListener('change', () => this.validateRange());
          this.endInput.addEventListener('change', () => this.validateRange());
        }
      },
      
      validateRange() {
        const start = this.startInput?.value;
        const end = this.endInput?.value;
        
        if (start && end && start > end) {
          this.endInput.setCustomValidity('End date must be after start date');
          this.endInput.reportValidity();
        } else {
          this.endInput?.setCustomValidity('');
        }
      }
    };
    """
  end
  # Helper functions for date calculations
  
  defp beginning_of_month(date) do
    Date.new!(date.year, date.month, 1)
  end
  
  defp end_of_month(date) do
    days = :calendar.last_day_of_the_month(date.year, date.month)
    Date.new!(date.year, date.month, days)
  end
end