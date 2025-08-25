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
    # Check if we have valid query results and execution state
    case {assigns[:executed], assigns.query_results} do
      {false, _} ->
        # Query is being executed or hasn't been executed yet
        render_loading_state(assigns)

      {true, nil} ->
        # Executed but no results - this is an error state
        render_no_results_state(assigns)

      {true, {results, _fields, aliases}} ->
        # Valid execution with results - proceed with chart rendering
        render_chart(assigns, results, aliases)

      _ ->
        # Fallback for unexpected states
        render_unknown_state(assigns)
    end
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
        phx-hook=".GraphViewHook"
        phx-update="ignore"
        data-chart-type={@chart_type}
        data-chart-data={Jason.encode!(@chart_data)}
        data-chart-options={Jason.encode!(@chart_options)}
        class="relative"
        style="height: 400px;">
        <canvas id={"#{@chart_id}-canvas"}></canvas>
      </div>

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
      
      <!-- Chart.js Colocated Hook -->
      <script :type={Phoenix.LiveView.ColocatedHook} name=".GraphViewHook">
        export default {
          mounted() {
            this.chart = null
            this.initializeChart()
            this.bindEvents()
          },

          updated() {
            this.updateChart()
          },

          destroyed() {
            if (this.chart) {
              this.chart.destroy()
              this.chart = null
            }
          },

          initializeChart() {
            const canvas = this.el.querySelector('canvas')
            if (!canvas) return
            
            const ctx = canvas.getContext('2d')
            
            // Get configuration from data attributes
            const chartType = this.el.dataset.chartType || 'bar'
            const chartData = this.getChartData()
            const chartOptions = this.getChartOptions()

            // Create the chart using global Chart.js
            if (typeof Chart === 'undefined') {
              console.error('Chart.js is not loaded')
              return
            }

            this.chart = new Chart(ctx, {
              type: chartType,
              data: chartData,
              options: {
                ...chartOptions,
                responsive: true,
                maintainAspectRatio: false,
                interaction: {
                  intersect: false,
                  mode: 'index'
                },
                onClick: (event, activeElements) => {
                  this.handleChartClick(event, activeElements)
                },
                onHover: (event, activeElements) => {
                  this.handleChartHover(event, activeElements)
                }
              }
            })
          },

          updateChart() {
            if (!this.chart) {
              this.initializeChart()
              return
            }

            const newData = this.getChartData()
            const newOptions = this.getChartOptions()
            
            // Update chart data
            this.chart.data = newData
            this.chart.options = {
              ...this.chart.options,
              ...newOptions
            }
            
            this.chart.update('none') // No animation for updates
          },

          getChartData() {
            try {
              const dataJson = this.el.dataset.chartData
              if (!dataJson) return this.getDefaultData()
              
              const data = JSON.parse(dataJson)
              return this.formatDataForChart(data)
            } catch (error) {
              console.error('Error parsing chart data:', error)
              return this.getDefaultData()
            }
          },

          getChartOptions() {
            try {
              const optionsJson = this.el.dataset.chartOptions
              if (!optionsJson) return this.getDefaultOptions()
              
              const options = JSON.parse(optionsJson)
              return this.formatOptionsForChart(options)
            } catch (error) {
              console.error('Error parsing chart options:', error)
              return this.getDefaultOptions()
            }
          },

          formatDataForChart(rawData) {
            const chartType = this.el.dataset.chartType || 'bar'
            
            switch (chartType) {
              case 'pie':
              case 'doughnut':
                return this.formatPieData(rawData)
              case 'line':
              case 'area':
                return this.formatLineData(rawData)
              case 'scatter':
                return this.formatScatterData(rawData)
              default:
                return this.formatBarData(rawData)
            }
          },

          formatBarData(rawData) {
            const labels = rawData.labels || []
            const datasets = rawData.datasets || []
            
            return {
              labels: labels,
              datasets: datasets.map((dataset, index) => ({
                label: dataset.label || `Series ${index + 1}`,
                data: dataset.data || [],
                backgroundColor: dataset.backgroundColor || this.generateColors(dataset.data?.length || 0, 0.7),
                borderColor: dataset.borderColor || this.generateColors(dataset.data?.length || 0, 1.0),
                borderWidth: dataset.borderWidth || 1
              }))
            }
          },

          formatLineData(rawData) {
            const labels = rawData.labels || []
            const datasets = rawData.datasets || []
            
            return {
              labels: labels,
              datasets: datasets.map((dataset, index) => ({
                label: dataset.label || `Series ${index + 1}`,
                data: dataset.data || [],
                borderColor: dataset.borderColor || this.generateColors(1, 1.0)[0],
                backgroundColor: dataset.backgroundColor || this.generateColors(1, 0.1)[0],
                borderWidth: dataset.borderWidth || 2,
                fill: this.el.dataset.chartType === 'area',
                tension: 0.4
              }))
            }
          },

          formatPieData(rawData) {
            const labels = rawData.labels || []
            const data = rawData.data || []
            
            return {
              labels: labels,
              datasets: [{
                data: data,
                backgroundColor: this.generateColors(labels.length, 0.8),
                borderColor: this.generateColors(labels.length, 1.0),
                borderWidth: 2
              }]
            }
          },

          formatScatterData(rawData) {
            const datasets = rawData.datasets || []
            
            return {
              datasets: datasets.map((dataset, index) => ({
                label: dataset.label || `Series ${index + 1}`,
                data: dataset.data || [], // Should be array of {x, y} objects
                backgroundColor: dataset.backgroundColor || this.generateColors(1, 0.7)[0],
                borderColor: dataset.borderColor || this.generateColors(1, 1.0)[0],
                pointRadius: dataset.pointRadius || 5
              }))
            }
          },

          formatOptionsForChart(rawOptions) {
            const chartType = this.el.dataset.chartType || 'bar'
            const baseOptions = this.getDefaultOptions()
            
            // Merge with base options
            const options = { ...baseOptions, ...rawOptions }
            
            // Chart type specific options
            if (chartType === 'pie' || chartType === 'doughnut') {
              options.scales = undefined // Remove scales for pie charts
            }
            
            return options
          },

          getDefaultData() {
            return {
              labels: ['No Data'],
              datasets: [{
                label: 'No Data',
                data: [0],
                backgroundColor: ['#e5e7eb'],
                borderColor: ['#9ca3af'],
                borderWidth: 1
              }]
            }
          },

          getDefaultOptions() {
            return {
              responsive: true,
              maintainAspectRatio: false,
              plugins: {
                legend: {
                  position: 'bottom'
                },
                tooltip: {
                  mode: 'index',
                  intersect: false
                }
              },
              scales: {
                x: {
                  beginAtZero: true,
                  grid: {
                    display: true
                  }
                },
                y: {
                  beginAtZero: true,
                  grid: {
                    display: true
                  }
                }
              }
            }
          },

          generateColors(count, alpha = 1.0) {
            const colors = [
              `rgba(59, 130, 246, ${alpha})`,   // blue
              `rgba(16, 185, 129, ${alpha})`,   // green
              `rgba(245, 101, 101, ${alpha})`,  // red
              `rgba(251, 191, 36, ${alpha})`,   // yellow
              `rgba(139, 92, 246, ${alpha})`,   // purple
              `rgba(236, 72, 153, ${alpha})`,   // pink
              `rgba(6, 182, 212, ${alpha})`,    // cyan
              `rgba(251, 146, 60, ${alpha})`,   // orange
              `rgba(34, 197, 94, ${alpha})`,    // lime
              `rgba(168, 85, 247, ${alpha})`    // violet
            ]
            
            const result = []
            for (let i = 0; i < count; i++) {
              result.push(colors[i % colors.length])
            }
            return result
          },

          handleChartClick(event, activeElements) {
            if (activeElements.length === 0) return
            
            const element = activeElements[0]
            const dataIndex = element.index
            const datasetIndex = element.datasetIndex
            
            // Get the clicked data point information
            const clickedData = {
              dataIndex,
              datasetIndex,
              label: this.chart.data.labels[dataIndex],
              value: this.chart.data.datasets[datasetIndex].data[dataIndex]
            }
            
            // Send drill-down event to LiveView
            this.pushEvent('graph_drill_down', clickedData)
          },

          handleChartHover(event, activeElements) {
            // Change cursor to pointer when hovering over data points
            event.native.target.style.cursor = activeElements.length > 0 ? 'pointer' : 'default'
          },

          bindEvents() {
            // Export functionality
            const exportBtn = this.el.querySelector('[data-export]')
            if (exportBtn) {
              exportBtn.addEventListener('click', () => this.exportChart())
            }
          },

          exportChart() {
            if (!this.chart) return
            
            const canvas = this.chart.canvas
            const url = canvas.toDataURL('image/png')
            const link = document.createElement('a')
            link.download = 'chart.png'
            link.href = url
            link.click()
          }
        }
      </script>
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

  defp prepare_bar_data(results, aliases, x_axis_groups, y_axis_aggregates, series_groups) do
    num_x_fields = Enum.count(x_axis_groups)
    num_y_fields = Enum.count(y_axis_aggregates)
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
          label: get_aggregate_label(y_agg),
          data: data,
          backgroundColor: generate_color(index, 0.7),
          borderColor: generate_color(index, 1.0),
          borderWidth: 1
        }
      end)
      
      %{labels: labels, datasets: datasets}
    else
      # Complex case: with series grouping - this needs more sophisticated handling
      # For now, simplified to single series
      prepare_simple_bar_data(results, aliases)
    end
  end

  defp prepare_line_data(results, aliases, x_axis_groups, y_axis_aggregates, _series_groups) do
    num_x_fields = Enum.count(x_axis_groups)
    
    labels = results |> Enum.map(fn row -> format_chart_label(Enum.at(row, 0)) end)
    
    datasets = y_axis_aggregates
    |> Enum.with_index()
    |> Enum.map(fn {y_agg, index} ->
      data = results |> Enum.map(fn row -> 
        value = Enum.at(row, num_x_fields + index)
        format_numeric_value(value)
      end)
      
      %{
        label: get_aggregate_label(y_agg),
        data: data,
        borderColor: generate_color(index, 1.0),
        backgroundColor: generate_color(index, 0.1),
        borderWidth: 2,
        fill: false,
        tension: 0.4
      }
    end)
    
    %{labels: labels, datasets: datasets}
  end

  defp prepare_pie_data(results, _aliases, _x_axis_groups, y_axis_aggregates) do
    # For pie charts, we typically want the first grouping field as labels
    # and the first aggregate as data
    labels = results |> Enum.map(fn row -> format_chart_label(Enum.at(row, 0)) end)
    
    # Use the first aggregate field for pie data
    data = results |> Enum.map(fn row -> 
      # Assuming the first aggregate is at position after grouping fields
      value = Enum.at(row, 1) # Simplified - assumes one grouping field
      format_numeric_value(value)
    end)
    
    %{
      labels: labels,
      datasets: [%{
        data: data,
        backgroundColor: 0..(Enum.count(labels) - 1) |> Enum.map(fn i -> generate_color(i, 0.8) end),
        borderColor: 0..(Enum.count(labels) - 1) |> Enum.map(fn i -> generate_color(i, 1.0) end),
        borderWidth: 2
      }]
    }
  end

  defp prepare_scatter_data(results, _aliases, _x_axis_groups, y_axis_aggregates, _series_groups) do
    # Scatter plots need x,y coordinate pairs
    # Simplified implementation
    data = results |> Enum.map(fn row ->
      %{
        x: format_numeric_value(Enum.at(row, 0)),
        y: format_numeric_value(Enum.at(row, 1))
      }
    end)
    
    %{
      datasets: [%{
        label: "Data Points",
        data: data,
        backgroundColor: generate_color(0, 0.7),
        borderColor: generate_color(0, 1.0),
        pointRadius: 5
      }]
    }
  end

  # Fallback for simple bar data when complex grouping isn't implemented yet
  defp prepare_simple_bar_data(results, aliases) do
    if Enum.empty?(results) do
      %{labels: [], datasets: []}
    else
      # Assume first column is labels, rest are data
      labels = results |> Enum.map(fn row -> format_chart_label(Enum.at(row, 0)) end)
      
      # Create dataset for each data column (skip first column which is labels)
      num_columns = Enum.count(List.first(results))
      
      datasets = 1..(num_columns - 1)
      |> Enum.map(fn col_index ->
        data = results |> Enum.map(fn row -> format_numeric_value(Enum.at(row, col_index)) end)
        alias_name = Enum.at(aliases, col_index) || "Series #{col_index}"
        
        %{
          label: alias_name,
          data: data,
          backgroundColor: generate_color(col_index - 1, 0.7),
          borderColor: generate_color(col_index - 1, 1.0),
          borderWidth: 1
        }
      end)
      
      %{labels: labels, datasets: datasets}
    end
  end

  @doc """
  Prepare Chart.js options from view configuration
  """
  def prepare_chart_options(assigns) do
    # Get options from the selecto configuration
    base_options = %{
      responsive: true,
      maintainAspectRatio: false,
      plugins: %{
        legend: %{
          position: get_legend_position(assigns)
        },
        tooltip: %{
          mode: "index",
          intersect: false
        }
      }
    }
    
    # Add scales for non-pie charts
    chart_type = get_chart_type(assigns)
    if chart_type not in ["pie", "doughnut"] do
      Map.put(base_options, :scales, %{
        x: %{
          beginAtZero: false,
          grid: %{display: get_show_grid(assigns)},
          title: %{
            display: true,
            text: get_x_axis_label(assigns)
          }
        },
        y: %{
          beginAtZero: true,
          grid: %{display: get_show_grid(assigns)},
          title: %{
            display: true,
            text: get_y_axis_label(assigns)
          }
        }
      })
    else
      base_options
    end
  end

  # Helper functions for extracting configuration
  defp get_chart_type(assigns) do
    selecto_set = assigns.selecto.set
    selecto_set[:chart_type] || "bar"
  end

  defp get_legend_position(assigns) do
    # TODO: Extract from selecto options
    "bottom"
  end

  defp get_show_grid(assigns) do
    # TODO: Extract from selecto options
    true
  end

  defp get_x_axis_label(assigns) do
    # TODO: Extract from selecto options
    ""
  end

  defp get_y_axis_label(assigns) do
    # TODO: Extract from selecto options
    ""
  end

  # Utility functions
  defp format_chart_label(value) do
    case value do
      nil -> "N/A"
      {display_value, _id} -> to_string(display_value)
      tuple when is_tuple(tuple) -> to_string(elem(tuple, 0))
      _ -> to_string(value)
    end
  end

  defp format_numeric_value(value) do
    case value do
      nil -> 0
      {numeric_value, _id} when is_number(numeric_value) -> numeric_value
      {numeric_value, _id} -> parse_numeric(numeric_value)
      tuple when is_tuple(tuple) -> parse_numeric(elem(tuple, 0))
      val when is_number(val) -> val
      val -> parse_numeric(val)
    end
  end

  defp parse_numeric(value) do
    case value do
      val when is_number(val) -> val
      val when is_binary(val) ->
        case Float.parse(val) do
          {num, _} -> num
          :error -> 
            case Integer.parse(val) do
              {num, _} -> num
              :error -> 0
            end
        end
      _ -> 0
    end
  end

  defp get_aggregate_label(aggregate_field) do
    case aggregate_field do
      {:field, {func, field}, alias_name} -> alias_name || "#{func}(#{field})"
      {:field, field, alias_name} -> alias_name || to_string(field)
      _ -> "Value"
    end
  end

  defp generate_color(index, alpha) do
    colors = [
      {59, 130, 246},   # blue
      {16, 185, 129},   # green  
      {245, 101, 101},  # red
      {251, 191, 36},   # yellow
      {139, 92, 246},   # purple
      {236, 72, 153},   # pink
      {6, 182, 212},    # cyan
      {251, 146, 60},   # orange
      {34, 197, 94},    # lime
      {168, 85, 247}    # violet
    ]
    
    {r, g, b} = Enum.at(colors, rem(index, Enum.count(colors)))
    "rgba(#{r}, #{g}, #{b}, #{alpha})"
  end

  defp chart_summary(chart_data, chart_type) do
    labels_count = Enum.count(chart_data[:labels] || [])
    datasets_count = Enum.count(chart_data[:datasets] || [])
    
    case chart_type do
      "pie" -> "#{labels_count} categories"
      "scatter" -> "#{labels_count} data points"
      _ -> "#{labels_count} categories, #{datasets_count} #{if datasets_count == 1, do: "series", else: "series"}"
    end
  end
end
