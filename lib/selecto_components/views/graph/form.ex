defmodule SelectoComponents.Views.Graph.Form do
  use Phoenix.LiveComponent

  import SelectoComponents.Components.Common
  alias SelectoComponents.Theme

  def render(assigns) do
    graph_view_key = current_view_key(assigns[:view])
    graph_view = view_state(assigns[:view_config], graph_view_key)

    assigns =
      assigns
      |> Map.put_new(:theme, Theme.default_theme(:light))
      |> Map.put(:graph_view_key, graph_view_key)
      |> Map.put(:graph_chart_type, map_get(graph_view, :chart_type, "bar"))
      |> Map.put(:graph_x_axis, map_get(graph_view, :x_axis, []))
      |> Map.put(:graph_y_axis, map_get(graph_view, :y_axis, []))
      |> Map.put(:graph_series, map_get(graph_view, :series, []))
      |> Map.put(:graph_options, map_get(graph_view, :options, %{}))

    ~H"""
    <div class="space-y-6">
      <!-- Chart Type Selection -->
      <div>
        <label class="mb-2 block text-sm font-medium" style="color: var(--sc-text-secondary)">Chart Type</label>
        <.sc_select_with_slot theme={@theme} name="chart_type">
          <option value="bar" selected={@graph_chart_type == "bar"}>Bar Chart</option>
          <option value="line" selected={@graph_chart_type == "line"}>Line Chart</option>
          <option value="pie" selected={@graph_chart_type == "pie"}>Pie Chart</option>
          <option value="scatter" selected={@graph_chart_type == "scatter"}>Scatter Plot</option>
          <option value="area" selected={@graph_chart_type == "area"}>Area Chart</option>
        </.sc_select_with_slot>
      </div>
      
    <!-- X-Axis Configuration -->
      <div>
        <h3 class="text-lg font-medium text-base-content mb-3">X-Axis (Categories)</h3>
        <.live_component
          module={SelectoComponents.Components.ListPicker}
          id={"#{@graph_view_key}_x_axis"}
          theme={@theme}
          fieldname="x_axis"
          view={@view}
          available={
            Enum.filter(@columns, fn {_f, _n, format} -> format not in [:component, :link] end)
          }
          selected_items={@graph_x_axis}
        >
          <:item_summary :let={{_id, item, config, _index}}>
            <% col = Selecto.field(@selecto, item) %>
            <% axis_summary = graph_x_axis_summary(col, config) %>
            <span class="truncate"><%= summary_title(config, graph_column_name(col, item)) %></span>
            <span :if={present_summary?(axis_summary)} class="truncate text-sm font-normal text-base-content/60"><%= axis_summary %></span>
          </:item_summary>
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
              theme={@theme}
            />
          </:item_form>
        </.live_component>
      </div>
      
    <!-- Y-Axis Configuration -->
      <div>
        <h3 class="text-lg font-medium text-base-content mb-3">Y-Axis (Values)</h3>
        <.live_component
          module={SelectoComponents.Components.ListPicker}
          id={"#{@graph_view_key}_y_axis"}
          theme={@theme}
          fieldname="y_axis"
          view={@view}
          available={@columns}
          selected_items={@graph_y_axis}
        >
          <:item_summary :let={{_id, item, config, _index}}>
            <% col = Selecto.field(@selecto, item) %>
            <span class="truncate"><%= summary_title(config, graph_column_name(col, item)) %></span>
            <span class="truncate text-sm font-normal text-base-content/60"><%= graph_y_axis_summary(config) %></span>
          </:item_summary>
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
              theme={@theme}
            />
          </:item_form>
        </.live_component>
      </div>
      
    <!-- Series Configuration (Optional) -->
      <div>
        <h3 class="text-lg font-medium text-base-content mb-3">Series Grouping (Optional)</h3>
        <p class="text-sm text-base-content/70 mb-3">
          Add a secondary grouping to create multiple data series in your chart.
        </p>
        <.live_component
          module={SelectoComponents.Components.ListPicker}
          id={"#{@graph_view_key}_series"}
          theme={@theme}
          fieldname="series"
          view={@view}
          available={
            Enum.filter(@columns, fn {_f, _n, format} -> format not in [:component, :link] end)
          }
          selected_items={@graph_series}
        >
          <:item_summary :let={{_id, item, config, _index}}>
            <% col = Selecto.field(@selecto, item) %>
            <span class="truncate"><%= summary_title(config, graph_column_name(col, item)) %></span>
            <span class="truncate text-sm font-normal text-base-content/60"><%= graph_series_summary(col, config) %></span>
          </:item_summary>
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
              theme={@theme}
            />
          </:item_form>
        </.live_component>
      </div>
      
    <!-- Chart Options -->
      <div>
        <h3 class="text-lg font-medium text-base-content mb-3">Chart Options</h3>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label class="mb-1 block text-sm font-medium" style="color: var(--sc-text-secondary)">Chart Title</label>
            <.sc_input theme={@theme} name="options[title]" value={option_value(@graph_options, :title, "")} placeholder="Enter chart title" />
          </div>
          <div>
            <label class="mb-1 block text-sm font-medium" style="color: var(--sc-text-secondary)">X-Axis Label</label>
            <.sc_input theme={@theme} name="options[x_axis_label]" value={option_value(@graph_options, :x_axis_label, "")} placeholder="X-axis label" />
          </div>
          <div>
            <label class="mb-1 block text-sm font-medium" style="color: var(--sc-text-secondary)">Y-Axis Label</label>
            <.sc_input theme={@theme} name="options[y_axis_label]" value={option_value(@graph_options, :y_axis_label, "")} placeholder="Y-axis label" />
          </div>
          <div>
            <label class="mb-1 block text-sm font-medium" style="color: var(--sc-text-secondary)">Y2-Axis Label</label>
            <.sc_input theme={@theme} name="options[y2_axis_label]" value={option_value(@graph_options, :y2_axis_label, "")} placeholder="Secondary Y-axis label" />
          </div>
          <div>
            <label class="mb-1 block text-sm font-medium" style="color: var(--sc-text-secondary)">Legend Position</label>
            <.sc_select_with_slot theme={@theme} name="options[legend_position]">
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
            </.sc_select_with_slot>
          </div>
        </div>

        <div class="mt-4 grid grid-cols-1 md:grid-cols-3 gap-4">
          <label class="flex items-center">
            <input
              name="options[show_grid]"
              type="checkbox"
              value="true"
              checked={option_checked(@graph_options, :show_grid, false)}
              class="mr-2 h-4 w-4 rounded border-base-300 bg-base-100 text-primary focus:ring-2 focus:ring-primary"
            />
            <span class="text-sm text-base-content/80">Show Grid Lines</span>
          </label>
          <label class="flex items-center">
            <input
              name="options[enable_animations]"
              type="checkbox"
              value="true"
              checked={option_checked(@graph_options, :enable_animations, true)}
              class="mr-2 h-4 w-4 rounded border-base-300 bg-base-100 text-primary focus:ring-2 focus:ring-primary"
            />
            <span class="text-sm text-base-content/80">Enable Animations</span>
          </label>
          <label class="flex items-center">
            <input
              name="options[responsive]"
              type="checkbox"
              value="true"
              checked={option_checked(@graph_options, :responsive, true)}
              class="mr-2 h-4 w-4 rounded border-base-300 bg-base-100 text-primary focus:ring-2 focus:ring-primary"
            />
            <span class="text-sm text-base-content/80">Responsive</span>
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

  defp graph_column_name(col, item) do
    cond do
      is_map(col) and Map.get(col, :name) -> col.name
      true -> to_string(item || "")
    end
  end

  defp summary_title(config, field_name) do
    case Map.get(config || %{}, "alias", "") do
      value when value in [nil, ""] -> field_name
      value -> "#{value} / #{field_name}"
    end
  end

  defp graph_x_axis_summary(col, config) do
    cond do
      Map.get(config || %{}, "format") not in [nil, ""] ->
        format_summary_label(Map.get(config, "format"))

      Map.get(config || %{}, "sort") not in [nil, ""] ->
        "sort #{Map.get(config, "sort")}"

      Map.get(col || %{}, :type, :string) in [:string, :text] and
          Map.get(config || %{}, "max_length") not in [nil, ""] ->
        "max #{Map.get(config, "max_length")}"

      true ->
        nil
    end
  end

  defp graph_y_axis_summary(config) do
    function = Map.get(config || %{}, "function", "count")
    axis = Map.get(config || %{}, "axis", "left")
    "#{function} on #{axis} axis"
  end

  defp graph_series_summary(col, config) do
    cond do
      Map.get(config || %{}, "format") not in [nil, ""] ->
        format_summary_label(Map.get(config, "format"))

      Map.get(config || %{}, "max_series") not in [nil, "", "10"] ->
        "max #{Map.get(config, "max_series")}"

      Map.get(col || %{}, :type, :string) in [:naive_datetime, :utc_datetime, :date] ->
        "date grouping"

      true ->
        "default grouping"
    end
  end

  defp format_summary_label(value) do
    SelectoComponents.Helpers.aggregate_datetime_format_label(value)
  end

  defp present_summary?(value), do: value not in [nil, ""]
end
