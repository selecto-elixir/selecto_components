defmodule SelectoComponents.Views.Graph.SeriesConfig do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
    <div class="border border-gray-200 rounded-lg p-3 bg-green-50">
      <div class="flex items-center justify-between mb-2">
        <span class="font-medium text-sm text-gray-700"><%= @col.name %></span>
        <span class="text-xs text-gray-500"><%= Map.get(@col, :type, :string) %></span>
      </div>
      
      <div class="grid grid-cols-1 gap-3">
        <!-- Custom Alias -->
        <div>
          <label class="block text-xs font-medium text-gray-600 mb-1">Series Label</label>
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
          </select>
        </div>

        <!-- Max Series Count -->
        <div>
          <label class="block text-xs font-medium text-gray-600 mb-1">Max Series</label>
          <input 
            name={"#{@prefix}[max_series]"}
            type="number" 
            value={Map.get(@config, "max_series", "10")}
            placeholder="10"
            min="1"
            max="20"
            class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500"/>
          <p class="text-xs text-gray-500 mt-1">Limit number of series to prevent chart clutter</p>
        </div>

        <!-- Color Palette -->
        <div>
          <label class="block text-xs font-medium text-gray-600 mb-1">Color Palette</label>
          <select name={"#{@prefix}[color_palette]"} class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500">
            <option value="default" selected={Map.get(@config, "color_palette", "default") == "default"}>Default Blues</option>
            <option value="rainbow" selected={Map.get(@config, "color_palette") == "rainbow"}>Rainbow</option>
            <option value="warm" selected={Map.get(@config, "color_palette") == "warm"}>Warm Colors</option>
            <option value="cool" selected={Map.get(@config, "color_palette") == "cool"}>Cool Colors</option>
            <option value="pastel" selected={Map.get(@config, "color_palette") == "pastel"}>Pastel</option>
            <option value="high_contrast" selected={Map.get(@config, "color_palette") == "high_contrast"}>High Contrast</option>
          </select>
        </div>

        <!-- Series Sorting -->
        <div>
          <label class="block text-xs font-medium text-gray-600 mb-1">Sort Series By</label>
          <select name={"#{@prefix}[series_sort]"} class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500">
            <option value="name_asc" selected={Map.get(@config, "series_sort", "name_asc") == "name_asc"}>Name (A-Z)</option>
            <option value="name_desc" selected={Map.get(@config, "series_sort") == "name_desc"}>Name (Z-A)</option>
            <option value="value_asc" selected={Map.get(@config, "series_sort") == "value_asc"}>Value (Low-High)</option>
            <option value="value_desc" selected={Map.get(@config, "series_sort") == "value_desc"}>Value (High-Low)</option>
          </select>
        </div>
      </div>
    </div>
    """
  end
end