defmodule SelectoComponents.Views.Graph.YAxisConfig do
  use Phoenix.LiveComponent

  def render(assigns) do
    col =
      case Map.get(assigns, :col) do
        %{} = col -> col
        _ -> %{name: Map.get(assigns, :item, "Unknown field"), type: :string}
      end

    config =
      case Map.get(assigns, :config) do
        %{} = config -> config
        _ -> %{}
      end

    assigns = assign(assigns, :col, col)
    assigns = assign(assigns, :config, config)

    ~H"""
    <div class="border border-gray-200 rounded-lg p-3 bg-blue-50">
      <div class="flex items-center justify-between mb-2">
        <span class="font-medium text-sm text-gray-700"><%= @col.name %></span>
        <span class="text-xs text-gray-500"><%= Map.get(@col, :type, :string) %></span>
      </div>
      
      <div class="grid grid-cols-1 gap-3">
        <!-- Aggregate Function -->
        <div>
          <label class="block text-xs font-medium text-gray-600 mb-1">Aggregate Function</label>
          <select name={"#{@prefix}[function]"} class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500">
            <option value="count" selected={Map.get(@config, "function", "count") == "count"}>Count</option>
            <option value="sum" selected={Map.get(@config, "function") == "sum"}>Sum</option>
            <option value="avg" selected={Map.get(@config, "function") == "avg"}>Average</option>
            <option value="min" selected={Map.get(@config, "function") == "min"}>Minimum</option>
            <option value="max" selected={Map.get(@config, "function") == "max"}>Maximum</option>
            <option value="count_distinct" selected={Map.get(@config, "function") == "count_distinct"}>Count Distinct</option>
          </select>
        </div>

        <!-- Custom Alias -->
        <div>
          <label class="block text-xs font-medium text-gray-600 mb-1">Label</label>
          <input 
            name={"#{@prefix}[alias]"}
            type="text" 
            value={Map.get(@config, "alias", "")}
            placeholder={generate_default_alias(@col.name, Map.get(@config, "function", "count"))}
            class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500"/>
        </div>

        <!-- Number Formatting -->
        <div>
          <label class="block text-xs font-medium text-gray-600 mb-1">Number Format</label>
          <select name={"#{@prefix}[number_format]"} class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500">
            <option value="" selected={Map.get(@config, "number_format", "") == ""}>Default</option>
            <option value="integer" selected={Map.get(@config, "number_format") == "integer"}>Integer (1,234)</option>
            <option value="decimal_1" selected={Map.get(@config, "number_format") == "decimal_1"}>1 Decimal (1,234.5)</option>
            <option value="decimal_2" selected={Map.get(@config, "number_format") == "decimal_2"}>2 Decimals (1,234.56)</option>
            <option value="percentage" selected={Map.get(@config, "number_format") == "percentage"}>Percentage (12.34%)</option>
            <option value="currency" selected={Map.get(@config, "number_format") == "currency"}>Currency ($1,234.56)</option>
          </select>
        </div>

        <div>
          <label class="block text-xs font-medium text-gray-600 mb-1">Series Type</label>
          <select name={"#{@prefix}[series_type]"} class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500">
            <option value="auto" selected={Map.get(@config, "series_type", "auto") == "auto"}>Auto</option>
            <option value="bar" selected={Map.get(@config, "series_type") == "bar"}>Bar</option>
            <option value="line" selected={Map.get(@config, "series_type") == "line"}>Line</option>
          </select>
        </div>

        <div>
          <label class="block text-xs font-medium text-gray-600 mb-1">Axis</label>
          <select name={"#{@prefix}[axis]"} class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500">
            <option value="left" selected={Map.get(@config, "axis", "left") == "left"}>Left (Y)</option>
            <option value="right" selected={Map.get(@config, "axis") == "right"}>Right (Y2)</option>
          </select>
        </div>

        <!-- Color (for multiple Y-axis series) -->
        <div>
          <label class="block text-xs font-medium text-gray-600 mb-1">Color</label>
          <div class="flex gap-2">
            <input 
              name={"#{@prefix}[color]"}
              type="color" 
              value={Map.get(@config, "color", "#3b82f6")}
              class="w-8 h-6 border border-gray-300 rounded cursor-pointer"/>
            <input 
              name={"#{@prefix}[color]"}
              type="text" 
              value={Map.get(@config, "color", "#3b82f6")}
              placeholder="#3b82f6"
              class="flex-1 px-2 py-1 text-sm border border-gray-300 rounded focus:outline-none focus:ring-1 focus:ring-blue-500"/>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp generate_default_alias(field_name, function) do
    case function do
      "count" -> "Count"
      "sum" -> "Sum of #{field_name}"
      "avg" -> "Average #{field_name}"
      "min" -> "Min #{field_name}"
      "max" -> "Max #{field_name}"
      "count_distinct" -> "Distinct #{field_name}"
      _ -> field_name
    end
  end
end
