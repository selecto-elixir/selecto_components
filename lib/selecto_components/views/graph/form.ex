defmodule SelectoComponents.Views.Graph.Form do
  use Phoenix.LiveComponent

  def render(assigns) do
    graph_view_key = current_view_key(assigns[:view])
    graph_view = view_state(assigns[:view_config], graph_view_key)

    assigns =
      assigns
      |> assign(:graph_view_key, graph_view_key)
      |> assign(:graph_chart_type, map_get(graph_view, :chart_type, "bar"))
      |> assign(:graph_x_axis, map_get(graph_view, :x_axis, []))
      |> assign(:graph_y_axis, map_get(graph_view, :y_axis, []))
      |> assign(:graph_series, map_get(graph_view, :series, []))
      |> assign(:graph_options, map_get(graph_view, :options, %{}))

    ~H"""
    <div class="space-y-6">
      <!-- Chart Type Selection -->
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Chart Type</label>
        <select
          name="chart_type"
          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <option value="bar" selected={@graph_chart_type == "bar"}>Bar Chart</option>
          <option value="line" selected={@graph_chart_type == "line"}>Line Chart</option>
          <option value="pie" selected={@graph_chart_type == "pie"}>Pie Chart</option>
          <option value="scatter" selected={@graph_chart_type == "scatter"}>Scatter Plot</option>
          <option value="area" selected={@graph_chart_type == "area"}>Area Chart</option>
        </select>
      </div>
      
    <!-- X-Axis Configuration -->
      <div>
        <h3 class="text-lg font-medium text-gray-900 mb-3">X-Axis (Categories)</h3>
        <.live_component
          module={SelectoComponents.Components.ListPicker}
          id={"#{@graph_view_key}_x_axis"}
          fieldname="x_axis"
          view={@view}
          available={
            Enum.filter(@columns, fn {_f, _n, format} -> format not in [:component, :link] end)
          }
          selected_items={@graph_x_axis}
        >
          <:item_form :let={{id, item, config, index}}>
            <input name={"x_axis[#{id}][field]"} type="hidden" value={item} />
            <input name={"x_axis[#{id}][index]"} type="hidden" value={index} />
            <.live_component
              module={SelectoComponents.Views.Graph.XAxisConfig}
              id={"#{@graph_view_key}-x-axis-config-#{id}"}
              col={Selecto.field(@selecto, item)}
              uuid={id}
              item={item}
              fieldname="x_axis"
              prefix={"x_axis[#{id}]"}
              config={config}
            />
          </:item_form>
        </.live_component>
      </div>
      
    <!-- Y-Axis Configuration -->
      <div>
        <h3 class="text-lg font-medium text-gray-900 mb-3">Y-Axis (Values)</h3>
        <.live_component
          module={SelectoComponents.Components.ListPicker}
          id={"#{@graph_view_key}_y_axis"}
          fieldname="y_axis"
          view={@view}
          available={@columns}
          selected_items={@graph_y_axis}
        >
          <:item_form :let={{id, item, config, index}}>
            <input name={"y_axis[#{id}][field]"} type="hidden" value={item} />
            <input name={"y_axis[#{id}][index]"} type="hidden" value={index} />
            <.live_component
              module={SelectoComponents.Views.Graph.YAxisConfig}
              id={"#{@graph_view_key}-y-axis-config-#{id}"}
              col={Selecto.field(@selecto, item)}
              uuid={id}
              item={item}
              fieldname="y_axis"
              prefix={"y_axis[#{id}]"}
              config={config}
            />
          </:item_form>
        </.live_component>
      </div>
      
    <!-- Series Configuration (Optional) -->
      <div>
        <h3 class="text-lg font-medium text-gray-900 mb-3">Series Grouping (Optional)</h3>
        <p class="text-sm text-gray-600 mb-3">
          Add a secondary grouping to create multiple data series in your chart.
        </p>
        <.live_component
          module={SelectoComponents.Components.ListPicker}
          id={"#{@graph_view_key}_series"}
          fieldname="series"
          view={@view}
          available={
            Enum.filter(@columns, fn {_f, _n, format} -> format not in [:component, :link] end)
          }
          selected_items={@graph_series}
        >
          <:item_form :let={{id, item, config, index}}>
            <input name={"series[#{id}][field]"} type="hidden" value={item} />
            <input name={"series[#{id}][index]"} type="hidden" value={index} />
            <.live_component
              module={SelectoComponents.Views.Graph.SeriesConfig}
              id={"#{@graph_view_key}-series-config-#{id}"}
              col={Selecto.field(@selecto, item)}
              uuid={id}
              item={item}
              fieldname="series"
              prefix={"series[#{id}]"}
              config={config}
            />
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
              value={option_value(@graph_options, :title, "")}
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              placeholder="Enter chart title"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">X-Axis Label</label>
            <input
              name="options[x_axis_label]"
              type="text"
              value={option_value(@graph_options, :x_axis_label, "")}
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              placeholder="X-axis label"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Y-Axis Label</label>
            <input
              name="options[y_axis_label]"
              type="text"
              value={option_value(@graph_options, :y_axis_label, "")}
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              placeholder="Y-axis label"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Y2-Axis Label</label>
            <input
              name="options[y2_axis_label]"
              type="text"
              value={option_value(@graph_options, :y2_axis_label, "")}
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              placeholder="Secondary Y-axis label"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Legend Position</label>
            <select
              name="options[legend_position]"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option value="top" selected={option_value(@graph_options, :legend_position) == "top"}>
                Top
              </option>
              <option
                value="bottom"
                selected={option_value(@graph_options, :legend_position) == "bottom"}
              >
                Bottom
              </option>
              <option value="left" selected={option_value(@graph_options, :legend_position) == "left"}>
                Left
              </option>
              <option
                value="right"
                selected={option_value(@graph_options, :legend_position) == "right"}
              >
                Right
              </option>
              <option value="none" selected={option_value(@graph_options, :legend_position) == "none"}>
                Hide Legend
              </option>
            </select>
          </div>
        </div>

        <div class="mt-4 grid grid-cols-1 md:grid-cols-3 gap-4">
          <label class="flex items-center">
            <input
              name="options[show_grid]"
              type="checkbox"
              value="true"
              checked={option_checked(@graph_options, :show_grid, false)}
              class="mr-2 h-4 w-4 text-blue-600 border-gray-300 rounded focus:ring-2 focus:ring-blue-500"
            />
            <span class="text-sm text-gray-700">Show Grid Lines</span>
          </label>
          <label class="flex items-center">
            <input
              name="options[enable_animations]"
              type="checkbox"
              value="true"
              checked={option_checked(@graph_options, :enable_animations, true)}
              class="mr-2 h-4 w-4 text-blue-600 border-gray-300 rounded focus:ring-2 focus:ring-blue-500"
            />
            <span class="text-sm text-gray-700">Enable Animations</span>
          </label>
          <label class="flex items-center">
            <input
              name="options[responsive]"
              type="checkbox"
              value="true"
              checked={option_checked(@graph_options, :responsive, true)}
              class="mr-2 h-4 w-4 text-blue-600 border-gray-300 rounded focus:ring-2 focus:ring-blue-500"
            />
            <span class="text-sm text-gray-700">Responsive</span>
          </label>
        </div>
      </div>
    </div>
    """
  end

  defp current_view_key({id, _mod, _name, _opts}) when is_atom(id), do: id
  defp current_view_key(_), do: :graph

  defp view_state(view_config, view_key) do
    view_config
    |> map_get(:views, %{})
    |> map_get(view_key, %{})
  end

  defp map_get(map, key, default) when is_map(map) and is_atom(key) do
    Map.get(map, key, Map.get(map, Atom.to_string(key), default))
  end

  defp map_get(map, key, default) when is_map(map) and is_binary(key) do
    Map.get(map, key, default)
  end

  defp map_get(_map, _key, default), do: default

  defp option_value(options, key, default \\ nil) do
    map_get(options, key, default)
  end

  defp option_checked(options, key, default) do
    case option_value(options, key, default) do
      true -> true
      false -> false
      "true" -> true
      "false" -> false
      nil -> default
      _ -> default
    end
  end
end
