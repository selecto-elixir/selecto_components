defmodule SelectoComponents.Views.Graph.Component do
  @doc """
  Display results as interactive charts using Chart.js
  """
  use Phoenix.LiveComponent
  require Logger

  def update(assigns, socket) do
    # Force a complete re-assignment to ensure LiveView recognizes data changes
    socket = assign(socket, assigns)

    # Add a timestamp to force re-rendering if data changed
    socket = assign(socket, :last_update, System.system_time(:microsecond))

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="graph-component-wrapper">
      <%= cond do %>
        <% assigns[:execution_error] -> %>
          <%= render_error_state(assigns) %>
        <% assigns[:executed] == false -> %>
          <%= render_loading_state(assigns) %>
        <% assigns[:executed] && assigns.query_results == nil -> %>
          <%= render_no_results_state(assigns) %>
        <% assigns[:executed] && match?({_results, _fields, _aliases}, assigns.query_results) -> %>
          <% {results, _fields, aliases} = assigns.query_results %>
          <%= render_chart(assigns, results, aliases) %>
        <% true -> %>
          <%= render_unknown_state(assigns) %>
      <% end %>
    </div>
    """
  end

  defp render_error_state(assigns) do
    assigns = assign(assigns, :error, assigns[:execution_error])
    
    ~H"""
    <div class="flex items-center justify-center min-h-64 bg-red-50 rounded-lg border border-red-300 p-6">
      <div class="text-center max-w-2xl">
        <div class="text-4xl mb-3 text-red-500">⚠️</div>
        <div class="font-semibold text-red-700 text-lg mb-2">Query Execution Error</div>
        
        <%= if is_struct(@error, Selecto.Error) do %>
          <%= if @error.message do %>
            <div class="text-red-600 mb-2"><%= @error.message %></div>
          <% end %>
          
          <%= if @error.details[:exception] do %>
            <%= case @error.details.exception do %>
              <% %Postgrex.Error{postgres: postgres} when is_map(postgres) -> %>
                <div class="bg-red-100 rounded p-3 mt-3 text-left">
                  <div class="font-mono text-sm text-red-700">
                    <%= Map.get(postgres, :message, "Database error occurred") %>
                  </div>
                  <%= if Map.get(postgres, :position) do %>
                    <div class="text-xs text-red-600 mt-1">
                      Position: <%= postgres.position %>
                    </div>
                  <% end %>
                  <%= if Map.get(postgres, :code) do %>
                    <div class="text-xs text-red-600 mt-1">
                      Error Code: <%= postgres.code %>
                    </div>
                  <% end %>
                </div>
              <% _ -> %>
                <div class="bg-red-100 rounded p-3 mt-3 text-left">
                  <div class="font-mono text-sm text-red-700">
                    <%= inspect(@error.details.exception) %>
                  </div>
                </div>
            <% end %>
          <% end %>
          
          <%= if @error.query do %>
            <details class="mt-3 text-left">
              <summary class="cursor-pointer text-sm text-red-600 hover:text-red-700">Show Query</summary>
              <pre class="bg-gray-100 p-2 rounded mt-2 text-xs overflow-x-auto"><%= @error.query %></pre>
            </details>
          <% end %>
        <% else %>
          <div class="text-red-600">
            <%= inspect(@error) %>
          </div>
        <% end %>
        
        <div class="mt-4 text-sm text-gray-600">
          Please check your query configuration and try again.
        </div>
      </div>
    </div>
    """
  end
  
  defp render_loading_state(assigns) do
    ~H"""
    <div class="flex items-center justify-center h-64 bg-gray-50 rounded-lg border border-gray-200">
      <div class="text-center">
        <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500 mx-auto mb-4"></div>
        <div class="text-blue-500 italic">Loading chart...</div>
      </div>
    </div>
    """
  end

  defp render_no_results_state(assigns) do
    ~H"""
    <div class="flex items-center justify-center h-64 bg-red-50 rounded-lg border border-red-200">
      <div class="text-center text-red-500">
        <div class="text-4xl mb-2">📊</div>
        <div class="font-semibold">No Data Available</div>
        <div class="text-sm mt-1">Query executed but returned no results for the chart.</div>
      </div>
    </div>
    """
  end

  defp render_unknown_state(assigns) do
    ~H"""
    <div class="flex items-center justify-center h-64 bg-yellow-50 rounded-lg border border-yellow-200">
      <div class="text-center text-yellow-600">
        <div class="font-semibold">Unknown Chart State</div>
        <div class="text-sm mt-1">
          Executed: <%= inspect(assigns[:executed]) %><br/>
          Query Results: <%= inspect(assigns.query_results != nil) %>
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

    assigns = assign(assigns,
      chart_data: chart_data,
      chart_options: chart_options,
      chart_type: chart_type,
      chart_id: chart_id
    )

    ~H"""
    <div class="bg-white rounded-lg border border-gray-200 p-6">
      <!-- Chart Header with Title and Controls -->
      <div class="flex items-center justify-between mb-6">
        <div>
          <h3 :if={get_in(@chart_options, [:title])} class="text-lg font-semibold text-gray-800">
            <%= get_in(@chart_options, [:title]) %>
          </h3>
        </div>
        <div class="flex items-center gap-2">
          <button
            data-export
            class="inline-flex items-center px-3 py-1 border border-gray-300 shadow-sm text-xs leading-4 font-medium rounded text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500">
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
        style="height: 400px;">
        <canvas id={"#{@chart_id}-canvas"}></canvas>
      </div>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".GraphComponent">
      export default {
        chart: null,
        
        mounted() {
          console.log('GraphHook mounted');
          this.initializeChart();
        },

        updated() {
          console.log('GraphHook updated');
          this.updateChart();
        },

        destroyed() {
          console.log('GraphHook destroyed');
          if (this.chart) {
            this.chart.destroy();
          }
        },

        initializeChart() {
          const canvas = this.el.querySelector('canvas');
          if (!canvas) {
            console.error('Canvas not found for chart');
            return;
          }

          if (!window.Chart) {
            console.error('Chart.js not loaded. Please ensure Chart.js is included before this hook.');
            // Show an error message in the chart container
            this.el.innerHTML = `
              <div class="flex items-center justify-center h-64 bg-red-50 rounded-lg border border-red-200">
                <div class="text-center text-red-500">
                  <div class="text-4xl mb-2">⚠️</div>
                  <div class="font-semibold">Chart.js Not Loaded</div>
                  <div class="text-sm mt-1">Chart.js library is required to display charts.</div>
                </div>
              </div>
            `;
            return;
          }

          const chartData = JSON.parse(this.el.dataset.chartData || '{}');
          const chartOptions = JSON.parse(this.el.dataset.chartOptions || '{}');
          const chartType = this.el.dataset.chartType || 'bar';

          console.log('Initializing chart with:', { chartType, chartData, chartOptions });

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
            console.log('Chart initialized successfully');
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
            console.log('Chart updated');
          } else {
            console.log('No chart to update, initializing...');
            this.initializeChart();
          }
        }
      }
      </script>

      <!-- Chart Legend/Summary -->
      <div class="mt-4 text-sm text-gray-600">
        <div class="flex items-center justify-between">
          <span>
            <%= chart_summary(@chart_data, @chart_type) %>
          </span>
          <span class="text-xs text-gray-400">
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
    series_groups = selecto_set[:series_groups] || []

    case chart_type do
      type when type in ["pie", "doughnut"] ->
        prepare_pie_data(results, aliases, x_axis_groups, y_axis_aggregates)

      type when type in ["line", "area"] ->
        prepare_line_data(results, aliases, x_axis_groups, y_axis_aggregates, series_groups)

      "scatter" ->
        prepare_scatter_data(results, aliases, x_axis_groups, y_axis_aggregates, series_groups)

      _ -> # Default to bar chart
        prepare_bar_data(results, aliases, x_axis_groups, y_axis_aggregates, series_groups)
    end
  end

  defp prepare_bar_data(results, _aliases, _x_axis_groups, y_axis_aggregates, series_groups) do
    num_x_fields = 1  # Simplified for now
    num_series_fields = Enum.count(series_groups)

    # Simple case: single X-axis, single or multiple Y-axis, no series
    if num_series_fields == 0 do
      labels = results |> Enum.map(fn row -> format_chart_label(Enum.at(row, 0)) end)

      datasets = y_axis_aggregates
      |> Enum.with_index()
      |> Enum.map(fn {y_agg, index} ->
        data = results |> Enum.map(fn row ->
          value = Enum.at(row, num_x_fields + index)
          format_numeric_value(value)
        end)

        %{
          label: format_aggregate_label(y_agg),
          data: data,
          backgroundColor: generate_color(index, 0.7),
          borderColor: generate_color(index, 1.0),
          borderWidth: 1
        }
      end)

      %{labels: labels, datasets: datasets}
    else
      # More complex cases would be handled here
      %{labels: ["No Data"], datasets: [%{data: [0]}]}
    end
  end

  defp prepare_line_data(results, _aliases, _x_axis_groups, _y_axis_aggregates, _series_groups) do
    # Simplified line data preparation
    labels = results |> Enum.with_index() |> Enum.map(fn {_, i} -> "Point #{i + 1}" end)
    data = results |> Enum.map(fn row -> format_numeric_value(Enum.at(row, 1)) end)

    %{
      labels: labels,
      datasets: [%{
        label: "Line Data",
        data: data,
        borderColor: generate_color(0, 1.0),
        backgroundColor: generate_color(0, 0.1),
        borderWidth: 2,
        fill: false
      }]
    }
  end

  defp prepare_pie_data(results, _aliases, _x_axis_groups, _y_axis_aggregates) do
    labels = results |> Enum.map(fn row -> format_chart_label(Enum.at(row, 0)) end)
    data = results |> Enum.map(fn row -> format_numeric_value(Enum.at(row, 1)) end)

    %{
      labels: labels,
      datasets: [%{
        data: data,
        backgroundColor: Enum.with_index(labels) |> Enum.map(fn {_, i} -> generate_color(i, 0.8) end),
        borderColor: Enum.with_index(labels) |> Enum.map(fn {_, i} -> generate_color(i, 1.0) end),
        borderWidth: 1
      }]
    }
  end

  defp prepare_scatter_data(_results, _aliases, _x_axis_groups, _y_axis_aggregates, _series_groups) do
    # Simplified scatter data
    %{
      datasets: [%{
        label: "Scatter Data",
        data: [%{x: 0, y: 0}],
        backgroundColor: generate_color(0, 0.7),
        borderColor: generate_color(0, 1.0)
      }]
    }
  end

  @doc """
  Prepare Chart.js options from view configuration
  """
  def prepare_chart_options(assigns) do
    %{
      responsive: true,
      maintainAspectRatio: false,
      plugins: %{
        legend: %{position: get_legend_position(assigns)},
        tooltip: %{mode: "index", intersect: false}
      },
      scales: %{
        x: %{
          title: %{display: true, text: get_x_axis_label(assigns)},
          beginAtZero: false,
          grid: %{display: get_show_grid(assigns)}
        },
        y: %{
          title: %{display: true, text: get_y_axis_label(assigns)},
          beginAtZero: true,
          grid: %{display: get_show_grid(assigns)}
        }
      }
    }
  end

  defp get_chart_type(assigns) do
    assigns[:chart_type] || "bar"
  end

  defp get_legend_position(_assigns), do: "bottom"
  defp get_show_grid(_assigns), do: true
  defp get_x_axis_label(_assigns), do: ""
  defp get_y_axis_label(_assigns), do: ""

  defp format_aggregate_label(aggregate) do
    case aggregate do
      {:field, {:count, field_name}, display_name} when is_binary(field_name) and is_binary(display_name) ->
        "Count of #{display_name}"
      {:field, {:count, field_name}, _} when is_binary(field_name) ->
        "Count of #{field_name}"
      {:field, {:sum, field_name}, display_name} when is_binary(field_name) and is_binary(display_name) ->
        "Sum of #{display_name}"
      {:field, {:sum, field_name}, _} when is_binary(field_name) ->
        "Sum of #{field_name}"
      {:field, {:avg, field_name}, display_name} when is_binary(field_name) and is_binary(display_name) ->
        "Average of #{display_name}"
      {:field, {:avg, field_name}, _} when is_binary(field_name) ->
        "Average of #{field_name}"
      {:field, {:min, field_name}, display_name} when is_binary(field_name) and is_binary(display_name) ->
        "Minimum of #{display_name}"
      {:field, {:min, field_name}, _} when is_binary(field_name) ->
        "Minimum of #{field_name}"
      {:field, {:max, field_name}, display_name} when is_binary(field_name) and is_binary(display_name) ->
        "Maximum of #{display_name}"
      {:field, {:max, field_name}, _} when is_binary(field_name) ->
        "Maximum of #{field_name}"
      {:field, _field_spec, field_name} when is_binary(field_name) ->
        field_name
      {:field, _field_spec} ->
        "Field"
      {:count, field_name} when is_binary(field_name) ->
        "Count of #{field_name}"
      {:count, _} ->
        "Count"
      {:sum, field_name} when is_binary(field_name) ->
        "Sum of #{field_name}"
      {:sum, _} ->
        "Sum"
      {:avg, field_name} when is_binary(field_name) ->
        "Average of #{field_name}"
      {:avg, _} ->
        "Average"
      {:min, field_name} when is_binary(field_name) ->
        "Minimum of #{field_name}"
      {:min, _} ->
        "Minimum"
      {:max, field_name} when is_binary(field_name) ->
        "Maximum of #{field_name}"
      {:max, _} ->
        "Maximum"
      _ ->
        to_string(aggregate)
    end
  end

  defp format_chart_label(value) when is_nil(value), do: "N/A"
  defp format_chart_label(value) when is_tuple(value) do
    case value do
      {:field, {:count, field_name}, display_name} when is_binary(field_name) and is_binary(display_name) ->
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
  defp format_chart_label(value), do: to_string(value)

  defp format_numeric_value(value) when is_number(value), do: value
  defp format_numeric_value(_), do: 0

  defp generate_color(index, alpha) do
    colors = [
      "59, 130, 246",   # blue
      "16, 185, 129",   # green
      "245, 101, 101",  # red
      "251, 191, 36",   # yellow
      "139, 92, 246",   # purple
      "236, 72, 153",   # pink
      "6, 182, 212",    # cyan
      "251, 146, 60",   # orange
      "34, 197, 94",    # lime
      "168, 85, 247"    # violet
    ]

    color = Enum.at(colors, rem(index, length(colors)))
    "rgba(#{color}, #{alpha})"
  end

  defp chart_summary(chart_data, _chart_type) do
    dataset_count = length(chart_data[:datasets] || [])
    label_count = length(chart_data[:labels] || [])
    "#{dataset_count} series, #{label_count} data points"
  end

  defp get_x_axis_field(x_axis_groups) when is_list(x_axis_groups) do
    case x_axis_groups do
      [{_id, field, _config} | _] -> to_string(field)
      _ -> ""
    end
  end
  defp get_x_axis_field(_), do: ""
end
