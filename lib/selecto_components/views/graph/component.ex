defmodule SelectoComponents.Views.Graph.Component do
  @doc """
  Display results as interactive charts using Chart.js
  """
  use Phoenix.LiveComponent
  require Logger
  alias SelectoComponents.Env
  alias SelectoComponents.ErrorHandling.ErrorBuilder
  alias SelectoComponents.Theme

  def update(assigns, socket) do
    # Force a complete re-assignment to ensure LiveView recognizes data changes
    socket =
      socket
      |> assign(assigns)
      |> assign(:theme, Map.get(assigns, :theme, Theme.default_theme(:light)))

    if Env.dev?() do
      IO.puts("[theme-debug][Graph.Component] update theme=#{socket.assigns.theme.id}")
    end

    # Add a timestamp to force re-rendering if data changed
    socket = assign(socket, :last_update, System.system_time(:microsecond))

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="graph-component-wrapper">
      <%= cond do %>
        <% assigns[:execution_error] -> %>
          {render_error_state(assigns)}
        <% assigns[:executed] == false -> %>
          {render_loading_state(assigns)}
        <% assigns[:executed] && assigns.query_results == nil -> %>
          {render_no_results_state(assigns)}
        <% assigns[:executed] && match?({_results, _fields, _aliases}, assigns.query_results) -> %>
          <% {results, _fields, aliases} = assigns.query_results %>
          {render_chart(assigns, results, aliases)}
        <% true -> %>
          {render_unknown_state(assigns)}
      <% end %>
    </div>
    """
  end

  defp render_error_state(assigns) do
    assigns = assign(assigns, :error_info, ErrorBuilder.normalize(assigns[:execution_error]))

    ~H"""
    <div class="flex min-h-64 items-center justify-center rounded-lg border p-6" style="background: var(--sc-danger-soft); border-color: color-mix(in srgb, var(--sc-danger) 35%, var(--sc-surface-border)); color: var(--sc-danger);">
      <div class="text-center max-w-2xl">
        <div class="mb-3 text-4xl">⚠️</div>
        <div class="mb-2 text-lg font-semibold">{@error_info.summary}</div>
        <div class="mb-2">{@error_info.user_message}</div>
        <div :if={@error_info.detail} class="mb-2 text-sm">{@error_info.detail}</div>
        <div :if={@error_info.suggestion} class="mt-4 text-sm" style="color: var(--sc-text-secondary);">
          Next step: {@error_info.suggestion}
        </div>

        <details :if={Env.dev?() && is_map(@error_info.debug) && map_size(@error_info.debug) > 0} class="mt-3 text-left">
          <summary class="cursor-pointer text-sm">
            Debug Details
          </summary>
          <pre class="mt-2 overflow-x-auto rounded p-2 text-xs" style="background: var(--sc-surface-bg-alt); color: var(--sc-text-primary);"><%= inspect(@error_info.debug, pretty: true) %></pre>
        </details>
      </div>
    </div>
    """
  end

  defp render_loading_state(assigns) do
    ~H"""
    <div class="flex h-64 items-center justify-center rounded-lg border" style="background: var(--sc-surface-bg-alt); border-color: var(--sc-surface-border); color: var(--sc-accent);">
      <div class="text-center">
        <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary mx-auto mb-4"></div>
        <div class="italic">Loading chart...</div>
      </div>
    </div>
    """
  end

  defp render_no_results_state(assigns) do
    ~H"""
    <div class="flex h-64 items-center justify-center rounded-lg border" style="background: var(--sc-danger-soft); border-color: color-mix(in srgb, var(--sc-danger) 35%, var(--sc-surface-border)); color: var(--sc-danger);">
      <div class="text-center">
        <div class="text-4xl mb-2">📊</div>
        <div class="font-semibold">No Data Available</div>
        <div class="text-sm mt-1">Query executed but returned no results for the chart.</div>
      </div>
    </div>
    """
  end

  defp render_unknown_state(assigns) do
    ~H"""
    <div class="flex h-64 items-center justify-center rounded-lg border" style="background: color-mix(in srgb, var(--sc-accent-soft) 45%, var(--sc-surface-bg)); border-color: var(--sc-surface-border); color: var(--sc-text-secondary);">
      <div class="text-center">
        <div class="font-semibold">Unknown Chart State</div>
        <div class="text-sm mt-1">
          Executed: {inspect(assigns[:executed])}<br />
          Query Results: {inspect(assigns.query_results != nil)}
        </div>
      </div>
    </div>
    """
  end

  defp render_chart(assigns, results, aliases) do
    # Transform query results into chart data
    chart_data = prepare_chart_data(assigns, results, aliases)
    chart_options = prepare_chart_options(assigns)
    chart_type = get_chart_type(assigns)

    # Generate unique ID for this chart instance
    chart_id = "graph-#{assigns[:id] || :rand.uniform(10000)}"

    assigns =
      assign(assigns,
        chart_data: chart_data,
        chart_options: chart_options,
        chart_type: chart_type,
        chart_id: chart_id
      )

    ~H"""
    <div class="rounded-lg border p-6" style="background: var(--sc-surface-bg); border-color: var(--sc-surface-border); color: var(--sc-text-primary);">
      <!-- Chart Header with Title and Controls -->
      <div class="flex items-center justify-between mb-6">
        <div>
          <h3 :if={get_in(@chart_options, [:title])} class="text-lg font-semibold" style="color: var(--sc-text-primary);">
            {get_in(@chart_options, [:title])}
          </h3>
        </div>
        <div class="flex items-center gap-2">
          <button
            data-export
            class={Theme.slot(@theme, :button_secondary) <> " px-3 py-1 text-xs leading-4 shadow-sm"}
          >
            📥 Export
          </button>
        </div>
      </div>
      
    <!-- Chart Container -->
      <div
        id={@chart_id}
        phx-hook=".GraphComponent"
        phx-update="ignore"
        data-chart-type={@chart_type}
        data-chart-data={Jason.encode!(@chart_data)}
        data-chart-options={Jason.encode!(@chart_options)}
        data-x-axis={get_x_axis_field(@selecto.set[:x_axis_groups])}
        class="relative"
        style="height: 400px;"
      >
        <canvas id={"#{@chart_id}-canvas"}></canvas>
      </div>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".GraphComponent">
        export default {
          chart: null,
          
          mounted() {
            this.initializeChart();
          },

          updated() {
            this.updateChart();
          },

          destroyed() {
            if (this.chart) {
              this.chart.destroy();
              this.chart = null;
            }
          },

          initializeChart() {
            const canvas = this.el.querySelector('canvas');
            if (!canvas) return;

            if (!window.Chart) {
              // Leave server-rendered content intact if Chart.js is unavailable.
              return;
            }

            const chartData = JSON.parse(this.el.dataset.chartData || '{}');
            const chartOptions = JSON.parse(this.el.dataset.chartOptions || '{}');
            const chartType = this.el.dataset.chartType || 'bar';

            const pushEvent = (event, payload) => {
              this.pushEvent(event, payload);
            };

            try {
              this.chart = new Chart(canvas, {
                type: chartType,
                data: chartData,
                options: {
                  ...chartOptions,
                  onClick: (event, elements) => {
                    if (elements.length > 0) {
                      const element = elements[0];
                      const datasetIndex = element.datasetIndex;
                      const index = element.index;
                      const dataset = chartData.datasets[datasetIndex];
                      const value = dataset.data[index];
                      const label = chartData.labels[index];

                      const xFieldName = this.el.dataset.xAxis;
                      const yFieldName = dataset.label;

                      pushEvent('chart_click', {
                        label: label,
                        value: value,
                        dataset_label: dataset.label,
                        x_field: xFieldName,
                        y_field: yFieldName
                      });
                    }
                  }
                }
              });
            } catch (error) {
              console.error('Error initializing chart:', error);
            }
          },

          updateChart() {
            if (this.chart) {
              const chartData = JSON.parse(this.el.dataset.chartData || '{}');
              const chartOptions = JSON.parse(this.el.dataset.chartOptions || '{}');

              this.chart.data = chartData;
              this.chart.options = chartOptions;
              this.chart.update();
            } else {
              this.initializeChart();
            }
          }
        }
      </script>
      
    <!-- Chart Legend/Summary -->
      <div class="mt-4 text-sm" style="color: var(--sc-text-secondary);">
        <div class="flex items-center justify-between">
          <span>
            {chart_summary(@chart_data, @chart_type)}
          </span>
          <span class="text-xs" style="color: var(--sc-text-muted);">
            Click data points to drill down
          </span>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Transform query results into Chart.js compatible data format
  """
  def prepare_chart_data(assigns, results, aliases) do
    chart_type = get_chart_type(assigns)

    # Get the selecto configuration to understand the data structure
    selecto_set = assigns.selecto.set
    x_axis_groups = selecto_set[:x_axis_groups] || []
    y_axis_aggregates = selecto_set[:aggregates] || []
    metric_defs = build_metric_defs(selecto_set[:graph_series_defs], y_axis_aggregates)
    series_groups = selecto_set[:series_groups] || []

    case chart_type do
      type when type in ["pie", "doughnut"] ->
        prepare_pie_data(results, aliases, x_axis_groups, metric_defs)

      type when type in ["line", "area"] ->
        prepare_line_data(results, aliases, x_axis_groups, metric_defs, series_groups, chart_type)

      "scatter" ->
        prepare_scatter_data(results, aliases, x_axis_groups, metric_defs, series_groups)

      # Default to bar chart
      _ ->
        prepare_bar_data(results, aliases, x_axis_groups, metric_defs, series_groups, chart_type)
    end
  end

  defp prepare_bar_data(results, _aliases, _x_axis_groups, metric_defs, series_groups, chart_type) do
    # Simplified for now
    num_x_fields = 1
    num_series_fields = Enum.count(series_groups)

    # Simple case: single X-axis, single or multiple Y-axis, no series
    if num_series_fields == 0 do
      labels = results |> Enum.map(fn row -> format_chart_label(Enum.at(row, 0)) end)

      datasets =
        metric_defs
        |> Enum.with_index()
        |> Enum.map(fn {metric_def, index} ->
          data =
            results
            |> Enum.map(fn row ->
              value = Enum.at(row, num_x_fields + index)
              format_numeric_value(value)
            end)

          series_type = dataset_type(metric_def, chart_type)

          dataset = %{
            label: metric_def.alias,
            data: data,
            yAxisID: axis_id(metric_def),
            borderColor: metric_color(metric_def, index, 1.0),
            borderWidth: 2
          }

          case series_type do
            "line" ->
              dataset
              |> Map.put(:type, "line")
              |> Map.put(:backgroundColor, metric_color(metric_def, index, 0.15))
              |> Map.put(:fill, false)
              |> Map.put(:tension, 0.35)

            _ ->
              dataset
              |> Map.put(:type, "bar")
              |> Map.put(:backgroundColor, metric_color(metric_def, index, 0.7))
          end
        end)

      %{labels: labels, datasets: datasets}
    else
      # More complex cases would be handled here
      %{labels: ["No Data"], datasets: [%{data: [0]}]}
    end
  end

  defp prepare_line_data(
         results,
         _aliases,
         x_axis_groups,
         metric_defs,
         series_groups,
         chart_type
       ) do
    num_x_fields = max(Enum.count(x_axis_groups), 1)
    num_series_fields = Enum.count(series_groups)

    filtered_results =
      results
      |> filter_rollup_rows(num_x_fields, num_series_fields)
      |> case do
        [] -> results
        rows -> rows
      end

    if num_series_fields == 0 do
      labels = Enum.map(filtered_results, &x_label(&1, num_x_fields))

      datasets =
        metric_defs
        |> Enum.with_index()
        |> Enum.map(fn {metric_def, index} ->
          data =
            Enum.map(filtered_results, fn row ->
              value = Enum.at(row, num_x_fields + index)
              format_numeric_value(value)
            end)

          series_type = dataset_type(metric_def, chart_type)

          dataset = %{
            label: metric_def.alias,
            data: data,
            yAxisID: axis_id(metric_def),
            borderColor: metric_color(metric_def, index, 1.0),
            borderWidth: 2
          }

          case series_type do
            "bar" ->
              dataset
              |> Map.put(:type, "bar")
              |> Map.put(:backgroundColor, metric_color(metric_def, index, 0.7))

            _ ->
              dataset
              |> Map.put(:type, "line")
              |> Map.put(:backgroundColor, metric_color(metric_def, index, 0.1))
              |> Map.put(:fill, false)
              |> Map.put(:tension, 0.4)
          end
        end)

      %{labels: labels, datasets: datasets}
    else
      labels =
        filtered_results
        |> Enum.map(&x_label(&1, num_x_fields))
        |> Enum.uniq()

      series_keys =
        filtered_results
        |> Enum.map(&series_key(&1, num_x_fields, num_series_fields))
        |> Enum.uniq()

      datasets =
        metric_defs
        |> Enum.with_index()
        |> Enum.flat_map(fn {metric_def, metric_index} ->
          series_keys
          |> Enum.with_index()
          |> Enum.map(fn {series_key, series_index} ->
            rows_for_series =
              Enum.filter(filtered_results, fn row ->
                series_key(row, num_x_fields, num_series_fields) == series_key
              end)

            values_by_label =
              Map.new(rows_for_series, fn row ->
                value = Enum.at(row, num_x_fields + num_series_fields + metric_index)
                {x_label(row, num_x_fields), format_numeric_value(value)}
              end)

            data = Enum.map(labels, &Map.get(values_by_label, &1, nil))
            series_type = dataset_type(metric_def, chart_type)
            dataset_offset = metric_index * max(length(series_keys), 1) + series_index

            dataset = %{
              label: "#{metric_def.alias} - #{format_series_key(series_key)}",
              data: data,
              yAxisID: axis_id(metric_def),
              borderColor: metric_color(metric_def, dataset_offset, 1.0),
              borderWidth: 2
            }

            case series_type do
              "bar" ->
                dataset
                |> Map.put(:type, "bar")
                |> Map.put(:backgroundColor, metric_color(metric_def, dataset_offset, 0.7))

              _ ->
                dataset
                |> Map.put(:type, "line")
                |> Map.put(:backgroundColor, metric_color(metric_def, dataset_offset, 0.1))
                |> Map.put(:fill, false)
                |> Map.put(:tension, 0.4)
            end
          end)
        end)

      %{labels: labels, datasets: datasets}
    end
  end

  defp filter_rollup_rows(results, num_x_fields, num_series_fields) do
    Enum.reject(results, fn row ->
      x_values = Enum.take(row, num_x_fields)
      series_values = Enum.slice(row, num_x_fields, num_series_fields)

      Enum.any?(x_values, &is_nil/1) || Enum.any?(series_values, &is_nil/1)
    end)
  end

  defp x_label(row, num_x_fields) do
    row
    |> Enum.take(num_x_fields)
    |> Enum.map(&format_chart_label/1)
    |> Enum.join(" / ")
  end

  defp series_key(row, num_x_fields, num_series_fields) do
    Enum.slice(row, num_x_fields, num_series_fields)
  end

  defp format_series_key(series_key) when is_list(series_key) do
    series_key
    |> Enum.map(&format_chart_label/1)
    |> Enum.join(" / ")
  end

  defp prepare_pie_data(results, _aliases, _x_axis_groups, _metric_defs) do
    labels = results |> Enum.map(fn row -> format_chart_label(Enum.at(row, 0)) end)
    data = results |> Enum.map(fn row -> format_numeric_value(Enum.at(row, 1)) end)

    %{
      labels: labels,
      datasets: [
        %{
          data: data,
          backgroundColor:
            Enum.with_index(labels) |> Enum.map(fn {_, i} -> generate_color(i, 0.8) end),
          borderColor:
            Enum.with_index(labels) |> Enum.map(fn {_, i} -> generate_color(i, 1.0) end),
          borderWidth: 1
        }
      ]
    }
  end

  defp prepare_scatter_data(
         _results,
         _aliases,
         _x_axis_groups,
         _metric_defs,
         _series_groups
       ) do
    # Simplified scatter data
    %{
      datasets: [
        %{
          label: "Scatter Data",
          data: [%{x: 0, y: 0}],
          backgroundColor: generate_color(0, 0.7),
          borderColor: generate_color(0, 1.0)
        }
      ]
    }
  end

  @doc """
  Prepare Chart.js options from view configuration
  """
  def prepare_chart_options(assigns) do
    chart_type = get_chart_type(assigns)

    selecto_set =
      case assigns[:selecto] do
        %{set: set} when is_map(set) -> set
        _ -> %{}
      end

    metric_defs =
      build_metric_defs(selecto_set[:graph_series_defs], selecto_set[:aggregates] || [])

    graph_options = selecto_set[:graph_options] || %{}
    uses_right_axis? = Enum.any?(metric_defs, &(&1.axis == "right"))

    base_options = %{
      title: Map.get(graph_options, "title"),
      responsive: truthy?(Map.get(graph_options, "responsive"), true),
      maintainAspectRatio: false,
      plugins: %{
        legend: %{position: Map.get(graph_options, "legend_position", "bottom")},
        tooltip: %{mode: "index", intersect: false}
      }
    }

    if chart_type in ["pie", "doughnut"] do
      base_options
    else
      scales = %{
        x: %{
          title: %{display: true, text: Map.get(graph_options, "x_axis_label", "")},
          beginAtZero: false,
          grid: %{display: truthy?(Map.get(graph_options, "show_grid"), true)}
        },
        y: %{
          type: "linear",
          position: "left",
          title: %{display: true, text: Map.get(graph_options, "y_axis_label", "")},
          beginAtZero: true,
          grid: %{display: truthy?(Map.get(graph_options, "show_grid"), true)}
        }
      }

      scales =
        if uses_right_axis? do
          Map.put(scales, :y1, %{
            type: "linear",
            position: "right",
            title: %{
              display: true,
              text: Map.get(graph_options, "y2_axis_label", "Secondary Axis")
            },
            beginAtZero: true,
            grid: %{drawOnChartArea: false}
          })
        else
          scales
        end

      Map.put(base_options, :scales, scales)
    end
  end

  def get_chart_type(assigns) do
    selecto_set =
      case assigns[:selecto] do
        %{set: set} when is_map(set) -> set
        _ -> %{}
      end

    chart_type =
      assigns[:chart_type] ||
        Map.get(selecto_set, :chart_type) ||
        Map.get(selecto_set, "chart_type") ||
        "bar"

    if is_atom(chart_type), do: Atom.to_string(chart_type), else: chart_type
  end

  defp truthy?(nil, default), do: default
  defp truthy?(v, _default) when v in [true, "true", "on", 1], do: true
  defp truthy?(_, _default), do: false

  def format_aggregate_label(aggregate) do
    get_aggregate_label(aggregate)
  end

  def get_aggregate_label({:field, {_fn, _field_name}, display_name})
      when is_binary(display_name) and display_name != "",
      do: display_name

  def get_aggregate_label({:field, {fn_name, field_name}, _display_name})
      when is_atom(fn_name) and is_binary(field_name),
      do: "#{fn_name}(#{field_name})"

  def get_aggregate_label({:field, _field_spec, display_name})
      when is_binary(display_name) and display_name != "",
      do: display_name

  def get_aggregate_label({:count, field_name}) when is_binary(field_name),
    do: "count(#{field_name})"

  def get_aggregate_label({:sum, field_name}) when is_binary(field_name), do: "sum(#{field_name})"
  def get_aggregate_label({:avg, field_name}) when is_binary(field_name), do: "avg(#{field_name})"
  def get_aggregate_label({:min, field_name}) when is_binary(field_name), do: "min(#{field_name})"
  def get_aggregate_label({:max, field_name}) when is_binary(field_name), do: "max(#{field_name})"
  def get_aggregate_label(_), do: "Value"

  def format_chart_label(value) when is_nil(value), do: "N/A"

  def format_chart_label({value, _meta}) when is_binary(value) or is_number(value),
    do: to_string(value)

  def format_chart_label(value) when is_tuple(value) do
    case value do
      {:field, {:count, field_name}, display_name}
      when is_binary(field_name) and is_binary(display_name) ->
        display_name

      {:field, {:count, field_name}, _} when is_binary(field_name) ->
        field_name

      {:field, _field_spec, field_name} when is_binary(field_name) ->
        field_name

      {:field, _field_spec} ->
        "Field"

      _ ->
        to_string(value)
    end
  end

  def format_chart_label(value), do: to_string(value)

  def format_numeric_value(value) when is_number(value), do: value
  def format_numeric_value({value, _meta}), do: format_numeric_value(value)
  def format_numeric_value(%Decimal{} = value), do: Decimal.to_float(value)

  def format_numeric_value(value) when is_binary(value) do
    case Integer.parse(value) do
      {int_value, ""} ->
        int_value

      _ ->
        case Float.parse(value) do
          {float_value, ""} -> float_value
          _ -> 0
        end
    end
  end

  def format_numeric_value(_), do: 0

  def generate_color(index, alpha) do
    colors = [
      # blue
      "59, 130, 246",
      # green
      "16, 185, 129",
      # red
      "245, 101, 101",
      # yellow
      "251, 191, 36",
      # purple
      "139, 92, 246",
      # pink
      "236, 72, 153",
      # cyan
      "6, 182, 212",
      # orange
      "251, 146, 60",
      # lime
      "34, 197, 94",
      # violet
      "168, 85, 247"
    ]

    color = Enum.at(colors, rem(index, length(colors)))
    "rgba(#{color}, #{alpha})"
  end

  def chart_summary(chart_data, chart_type) do
    dataset_count = length(chart_data[:datasets] || [])
    label_count = length(chart_data[:labels] || [])

    case chart_type do
      type when type in ["pie", "doughnut"] -> "#{label_count} categories"
      "scatter" -> "#{label_count} data points"
      _ -> "#{label_count} categories, #{dataset_count} series"
    end
  end

  defp get_x_axis_field(x_axis_groups) when is_list(x_axis_groups) do
    case x_axis_groups do
      [{_column, {:field, field_name, _alias}} | _] when is_binary(field_name) ->
        field_name

      [{_column, {:field, field_name, _alias}} | _] when is_atom(field_name) ->
        Atom.to_string(field_name)

      [{_column, {:field, field_name}} | _] when is_binary(field_name) ->
        field_name

      [{_column, {:field, field_name}} | _] when is_atom(field_name) ->
        Atom.to_string(field_name)

      [{_id, field, _config} | _] ->
        to_string(field)

      _ ->
        ""
    end
  end

  defp get_x_axis_field(_), do: ""

  defp build_metric_defs(graph_series_defs, _y_axis_aggregates) when is_list(graph_series_defs) do
    graph_series_defs
    |> Enum.map(fn defn ->
      %{
        alias: Map.get(defn, :alias) || "Value",
        series_type: Map.get(defn, :series_type, "auto"),
        axis: Map.get(defn, :axis, "left"),
        color: Map.get(defn, :color)
      }
    end)
  end

  defp build_metric_defs(_, y_axis_aggregates) do
    Enum.map(y_axis_aggregates, fn agg ->
      %{
        alias: format_aggregate_label(agg),
        series_type: "auto",
        axis: "left",
        color: nil
      }
    end)
  end

  defp dataset_type(metric_def, chart_type) do
    case metric_def.series_type do
      "bar" -> "bar"
      "line" -> "line"
      _ -> if(chart_type in ["line", "area"], do: "line", else: "bar")
    end
  end

  defp axis_id(%{axis: "right"}), do: "y1"
  defp axis_id(_), do: "y"

  defp metric_color(%{color: <<?#, _::binary>> = hex}, _index, alpha), do: hex_to_rgba(hex, alpha)
  defp metric_color(_, index, alpha), do: generate_color(index, alpha)

  defp hex_to_rgba("#" <> hex, alpha) when byte_size(hex) == 6 do
    <<r::binary-size(2), g::binary-size(2), b::binary-size(2)>> = hex
    {ri, _} = Integer.parse(r, 16)
    {gi, _} = Integer.parse(g, 16)
    {bi, _} = Integer.parse(b, 16)
    "rgba(#{ri}, #{gi}, #{bi}, #{alpha})"
  end

  defp hex_to_rgba(_, alpha), do: generate_color(0, alpha)
end
