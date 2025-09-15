defmodule SelectoComponents.Views.Graph.XAxisConfig do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
    <div class="border border-gray-200 rounded-lg p-3 bg-gray-50">
      <div class="flex items-center justify-between mb-2">
        <span class="font-medium text-sm text-gray-700"><%= @col.name %></span>
        <span class="text-xs text-gray-500"><%= Map.get(@col, :type, :string) %></span>
      </div>
      
      <div class="grid grid-cols-1 gap-3">
        <!-- Custom Alias -->
        <div>
          <label class="block text-xs font-medium text-gray-600 mb-1">Label</label>
          <input 
            name={"#{@prefix}[alias]"}
            type="text" 
            value={Map.get(@config, "alias", "")}
            placeholder={@col.name}
            class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500"/>
        </div>

        <!-- Datetime Formatting (if applicable) -->
        <div :if={Map.get(@col, :type, :string) in [:naive_datetime, :utc_datetime, :date]}>
          <label class="block text-xs font-medium text-gray-600 mb-1">Date Format</label>
          <select name={"#{@prefix}[format]"} class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500">
            <option value="" selected={Map.get(@config, "format", "") == ""}>Default</option>
            <option value="YYYY" selected={Map.get(@config, "format") == "YYYY"}>Year (2023)</option>
            <option value="YYYY-MM" selected={Map.get(@config, "format") == "YYYY-MM"}>Year-Month (2023-12)</option>
            <option value="YYYY-MM-DD" selected={Map.get(@config, "format") == "YYYY-MM-DD"}>Full Date (2023-12-31)</option>
            <option value="Month" selected={Map.get(@config, "format") == "Month"}>Month Name</option>
            <option value="Day" selected={Map.get(@config, "format") == "Day"}>Day</option>
            <option value="Hour" selected={Map.get(@config, "format") == "Hour"}>Hour</option>
          </select>
        </div>

        <!-- String truncation (if applicable) -->
        <div :if={Map.get(@col, :type, :string) in [:string, :text]}>
          <label class="block text-xs font-medium text-gray-600 mb-1">Max Length</label>
          <input 
            name={"#{@prefix}[max_length]"}
            type="number" 
            value={Map.get(@config, "max_length", "")}
            placeholder="No limit"
            min="1"
            class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500"/>
        </div>

        <!-- Sorting -->
        <div>
          <label class="block text-xs font-medium text-gray-600 mb-1">Sort Order</label>
          <select name={"#{@prefix}[sort]"} class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500">
            <option value="" selected={Map.get(@config, "sort", "") == ""}>Default</option>
            <option value="asc" selected={Map.get(@config, "sort") == "asc"}>Ascending</option>
            <option value="desc" selected={Map.get(@config, "sort") == "desc"}>Descending</option>
          </select>
        </div>
      </div>
    </div>
    """
  end
end