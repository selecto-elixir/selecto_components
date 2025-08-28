defmodule SelectoComponents.Views.Graph.Form do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
      <div class="space-y-6">
        <!-- Chart Type Selection -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Chart Type</label>
          <select name="chart_type" class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500">
            <option value="bar" selected={@view_config.views.graph.chart_type == "bar"}>Bar Chart</option>
            <option value="line" selected={@view_config.views.graph.chart_type == "line"}>Line Chart</option>
            <option value="pie" selected={@view_config.views.graph.chart_type == "pie"}>Pie Chart</option>
            <option value="scatter" selected={@view_config.views.graph.chart_type == "scatter"}>Scatter Plot</option>
            <option value="area" selected={@view_config.views.graph.chart_type == "area"}>Area Chart</option>
          </select>
        </div>

        <!-- X-Axis Configuration -->
        <div>
          <h3 class="text-lg font-medium text-gray-900 mb-3">X-Axis (Categories)</h3>
          <.live_component
            module={SelectoComponents.Components.ListPicker}
            id="x_axis"
            fieldname="x_axis"
            view={@view}
            available={Enum.filter(@columns, fn {_f, _n, format} -> format not in [:component, :link] end)}
            selected_items={@view_config.views.graph.x_axis}>
            <:item_form :let={{id, item, config, index}}>
              <input name={"x_axis[#{id}][field]"} type="hidden" value={item}/>
              <input name={"x_axis[#{id}][index]"} type="hidden" value={index}/>
              <.live_component
                module={SelectoComponents.Views.Graph.XAxisConfig}
                id={id}
                col={Selecto.field(@selecto, item)}
                uuid={id}
                item={item}
                fieldname="x_axis"
                prefix={"x_axis[#{id}]"}
                config={config}/>
            </:item_form>
          </.live_component>
        </div>

        <!-- Y-Axis Configuration -->
        <div>
          <h3 class="text-lg font-medium text-gray-900 mb-3">Y-Axis (Values)</h3>
          <.live_component
            module={SelectoComponents.Components.ListPicker}
            id="y_axis"
            fieldname="y_axis"
            view={@view}
            available={@columns}
            selected_items={@view_config.views.graph.y_axis}>
            <:item_form :let={{id, item, config, index}}>
              <input name={"y_axis[#{id}][field]"} type="hidden" value={item}/>
              <input name={"y_axis[#{id}][index]"} type="hidden" value={index}/>
              <.live_component
                module={SelectoComponents.Views.Graph.YAxisConfig}
                id={id}
                col={Selecto.field(@selecto, item)}
                uuid={id}
                item={item}
                fieldname="y_axis"
                prefix={"y_axis[#{id}]"}
                config={config}/>
            </:item_form>
          </.live_component>
        </div>

        <!-- Series Configuration (Optional) -->
        <div>
          <h3 class="text-lg font-medium text-gray-900 mb-3">Series Grouping (Optional)</h3>
          <p class="text-sm text-gray-600 mb-3">Add a secondary grouping to create multiple data series in your chart.</p>
          <.live_component
            module={SelectoComponents.Components.ListPicker}
            id="series"
            fieldname="series"
            view={@view}
            available={Enum.filter(@columns, fn {_f, _n, format} -> format not in [:component, :link] end)}
            selected_items={@view_config.views.graph.series}>
            <:item_form :let={{id, item, config, index}}>
              <input name={"series[#{id}][field]"} type="hidden" value={item}/>
              <input name={"series[#{id}][index]"} type="hidden" value={index}/>
              <.live_component
                module={SelectoComponents.Views.Graph.SeriesConfig}
                id={id}
                col={Selecto.field(@selecto, item)}
                uuid={id}
                item={item}
                fieldname="series"
                prefix={"series[#{id}]"}
                config={config}/>
            </:item_form>
          </.live_component>
        </div>

        <!-- Chart Options -->
        <div>
          <h3 class="text-lg font-medium text-gray-900 mb-3">Chart Options</h3>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Chart Title</label>
              <input 
                name="options[title]" 
                type="text" 
                value={get_in(@view_config.views.graph.options, ["title"]) || ""}
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="Enter chart title"/>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">X-Axis Label</label>
              <input 
                name="options[x_axis_label]" 
                type="text" 
                value={get_in(@view_config.views.graph.options, ["x_axis_label"]) || ""}
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="X-axis label"/>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Y-Axis Label</label>
              <input 
                name="options[y_axis_label]" 
                type="text" 
                value={get_in(@view_config.views.graph.options, ["y_axis_label"]) || ""}
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="Y-axis label"/>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Legend Position</label>
              <select name="options[legend_position]" class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500">
                <option value="top" selected={get_in(@view_config.views.graph.options, ["legend_position"]) == "top"}>Top</option>
                <option value="bottom" selected={get_in(@view_config.views.graph.options, ["legend_position"]) == "bottom"}>Bottom</option>
                <option value="left" selected={get_in(@view_config.views.graph.options, ["legend_position"]) == "left"}>Left</option>
                <option value="right" selected={get_in(@view_config.views.graph.options, ["legend_position"]) == "right"}>Right</option>
                <option value="none" selected={get_in(@view_config.views.graph.options, ["legend_position"]) == "none"}>Hide Legend</option>
              </select>
            </div>
          </div>
          
          <div class="mt-4 grid grid-cols-1 md:grid-cols-3 gap-4">
            <label class="flex items-center">
              <input 
                name="options[show_grid]" 
                type="checkbox" 
                value="true"
                checked={get_in(@view_config.views.graph.options, ["show_grid"]) == "true"}
                class="mr-2 h-4 w-4 text-blue-600 border-gray-300 rounded focus:ring-2 focus:ring-blue-500"/>
              <span class="text-sm text-gray-700">Show Grid Lines</span>
            </label>
            <label class="flex items-center">
              <input 
                name="options[enable_animations]" 
                type="checkbox" 
                value="true"
                checked={get_in(@view_config.views.graph.options, ["enable_animations"]) != "false"}
                class="mr-2 h-4 w-4 text-blue-600 border-gray-300 rounded focus:ring-2 focus:ring-blue-500"/>
              <span class="text-sm text-gray-700">Enable Animations</span>
            </label>
            <label class="flex items-center">
              <input 
                name="options[responsive]" 
                type="checkbox" 
                value="true"
                checked={get_in(@view_config.views.graph.options, ["responsive"]) != "false"}
                class="mr-2 h-4 w-4 text-blue-600 border-gray-300 rounded focus:ring-2 focus:ring-blue-500"/>
              <span class="text-sm text-gray-700">Responsive</span>
            </label>
          </div>
        </div>
      </div>
    """
  end
end
