defmodule SelectoComponents.Dashboard.MetricDisplay do
  @moduledoc """
  Advanced metric display components with real-time updates,
  comparisons, and drill-down capabilities.
  """

  use Phoenix.LiveComponent
  import Phoenix.LiveView

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:metrics, %{})
     |> assign(:update_interval, 30_000)
     |> assign(:loading, false)
     |> assign(:error, nil)}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> load_metrics()
      |> schedule_refresh()

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class="metric-display" phx-hook="MetricDisplay">
      <%= case @display_type do %>
        <% :comparison -> %>
          <.comparison_display metrics={@metrics} config={@config} />
        <% :timeline -> %>
          <.timeline_display metrics={@metrics} config={@config} />
        <% :gauge -> %>
          <.gauge_display metrics={@metrics} config={@config} />
        <% :progress -> %>
          <.progress_display metrics={@metrics} config={@config} />
        <% _ -> %>
          <.standard_display metrics={@metrics} config={@config} />
      <% end %>

      <%= if @loading do %>
        <div class="absolute inset-0 bg-white bg-opacity-75 flex items-center justify-center">
          <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600" />
        </div>
      <% end %>

      <%= if @error do %>
        <div class="mt-2 text-sm text-red-600">
          {@error}
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Standard metric display with value and optional comparison.
  """
  attr :metrics, :map, required: true
  attr :config, :map, default: %{}

  def standard_display(assigns) do
    ~H"""
    <div class="standard-metric">
      <div class="metric-value">
        <span class="text-3xl font-bold text-gray-900">
          {format_metric_value(@metrics.value, @config)}
        </span>
        <%= if @metrics[:comparison] do %>
          <span class={["ml-2 text-sm", comparison_color(@metrics.comparison)]}>
            {format_comparison(@metrics.comparison, @config)}
          </span>
        <% end %>
      </div>

      <%= if @metrics[:subtitle] do %>
        <div class="text-sm text-gray-600 mt-1">
          {@metrics.subtitle}
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Comparison display showing current vs previous period.
  """
  attr :metrics, :map, required: true
  attr :config, :map, default: %{}

  def comparison_display(assigns) do
    ~H"""
    <div class="comparison-metric grid grid-cols-2 gap-4">
      <div class="current-period">
        <div class="text-xs text-gray-500 uppercase tracking-wider mb-1">
          {@config[:current_label] || "Current"}
        </div>
        <div class="text-2xl font-bold text-gray-900">
          {format_metric_value(@metrics.current, @config)}
        </div>
      </div>

      <div class="previous-period">
        <div class="text-xs text-gray-500 uppercase tracking-wider mb-1">
          {@config[:previous_label] || "Previous"}
        </div>
        <div class="text-2xl font-bold text-gray-600">
          {format_metric_value(@metrics.previous, @config)}
        </div>
      </div>

      <%= if @metrics[:change] do %>
        <div class="col-span-2 pt-2 border-t">
          <div class="flex items-center justify-between">
            <span class="text-sm text-gray-600">Change</span>
            <span class={["text-sm font-medium", change_color(@metrics.change)]}>
              {format_change(@metrics.change, @config)}
            </span>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Timeline display showing metric values over time.
  """
  attr :metrics, :map, required: true
  attr :config, :map, default: %{}

  def timeline_display(assigns) do
    ~H"""
    <div class="timeline-metric">
      <div class="timeline-header mb-4">
        <div class="text-lg font-semibold text-gray-900">
          {@config[:title] || "Metric Timeline"}
        </div>
        <div class="text-sm text-gray-600">
          {@config[:period] || "Last 7 days"}
        </div>
      </div>

      <div class="timeline-chart">
        <canvas
          id={"#{@id}-timeline"}
          class="w-full h-48"
          phx-hook="TimelineChart"
          data-values={Jason.encode!(@metrics.timeline || [])}
          data-labels={Jason.encode!(@metrics.labels || [])}
        />
      </div>

      <div class="timeline-summary mt-4 grid grid-cols-3 gap-2 text-center">
        <div>
          <div class="text-xs text-gray-500">Min</div>
          <div class="font-semibold">
            {format_metric_value(@metrics.min, @config)}
          </div>
        </div>
        <div>
          <div class="text-xs text-gray-500">Avg</div>
          <div class="font-semibold">
            {format_metric_value(@metrics.avg, @config)}
          </div>
        </div>
        <div>
          <div class="text-xs text-gray-500">Max</div>
          <div class="font-semibold">
            {format_metric_value(@metrics.max, @config)}
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Gauge display for percentage or range-based metrics.
  """
  attr :metrics, :map, required: true
  attr :config, :map, default: %{}

  def gauge_display(assigns) do
    assigns = assign(assigns, :percentage, calculate_percentage(assigns.metrics, assigns.config))

    ~H"""
    <div class="gauge-metric">
      <div class="gauge-container relative w-32 h-32 mx-auto">
        <svg class="transform -rotate-90 w-32 h-32">
          <circle
            cx="64"
            cy="64"
            r="56"
            stroke="currentColor"
            stroke-width="12"
            fill="none"
            class="text-gray-200"
          />
          <circle
            cx="64"
            cy="64"
            r="56"
            stroke="currentColor"
            stroke-width="12"
            fill="none"
            stroke-dasharray={"#{@percentage * 3.51} 351.86"}
            class={gauge_color(@percentage)}
            stroke-linecap="round"
          />
        </svg>
        <div class="absolute inset-0 flex items-center justify-center">
          <div class="text-center">
            <div class="text-2xl font-bold text-gray-900">
              {round(@percentage)}%
            </div>
            <div class="text-xs text-gray-500">
              {@config[:label] || "Complete"}
            </div>
          </div>
        </div>
      </div>

      <div class="gauge-details mt-4 flex justify-between text-sm">
        <span class="text-gray-600">
          {@config[:min_label] || format_metric_value(@config[:min] || 0, @config)}
        </span>
        <span class="font-semibold text-gray-900">
          {format_metric_value(@metrics.value, @config)}
        </span>
        <span class="text-gray-600">
          {@config[:max_label] || format_metric_value(@config[:max] || 100, @config)}
        </span>
      </div>
    </div>
    """
  end

  @doc """
  Progress display with multiple segments.
  """
  attr :metrics, :map, required: true
  attr :config, :map, default: %{}

  def progress_display(assigns) do
    ~H"""
    <div class="progress-metric">
      <div class="progress-header mb-3">
        <div class="flex justify-between items-baseline">
          <span class="text-sm font-medium text-gray-700">
            {@config[:title] || "Progress"}
          </span>
          <span class="text-sm text-gray-600">
            {format_metric_value(@metrics.value, @config)} / {format_metric_value(
              @metrics.target,
              @config
            )}
          </span>
        </div>
      </div>

      <div class="progress-bars space-y-2">
        <%= for segment <- (@metrics.segments || [%{value: @metrics.value, color: "blue", label: "Progress"}]) do %>
          <div class="progress-segment">
            <%= if segment[:label] do %>
              <div class="text-xs text-gray-600 mb-1">
                {segment.label}
              </div>
            <% end %>
            <div class="w-full bg-gray-200 rounded-full h-2">
              <div
                class={[
                  "h-2 rounded-full transition-all duration-500",
                  progress_color(segment[:color])
                ]}
                style={"width: #{calculate_segment_percentage(segment, @metrics.target)}%"}
              />
            </div>
          </div>
        <% end %>
      </div>

      <%= if @metrics[:milestones] do %>
        <div class="milestones mt-3 flex justify-between">
          <%= for milestone <- @metrics.milestones do %>
            <div class={["text-xs", milestone_status(milestone, @metrics.value)]}>
              <div class="font-medium">{milestone.label}</div>
              <div>{format_metric_value(milestone.value, @config)}</div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # Event handlers

  @impl true
  def handle_event("refresh", _, socket) do
    {:noreply, load_metrics(socket)}
  end

  @impl true
  def handle_event("drill_down", %{"metric" => metric}, socket) do
    send(self(), {:drill_down, metric, socket.assigns.metrics})
    {:noreply, socket}
  end

  @impl true
  def handle_event("export", _, socket) do
    export_data = prepare_export_data(socket.assigns.metrics, socket.assigns.config)
    {:noreply, push_event(socket, "download", %{data: export_data, filename: "metrics.csv"})}
  end

  def handle_info(:refresh_metrics, socket) do
    socket =
      socket
      |> load_metrics()
      |> schedule_refresh()

    {:noreply, socket}
  end

  # Private functions

  defp load_metrics(socket) do
    socket
    |> assign(:loading, true)
    |> fetch_metric_data()
  end

  defp fetch_metric_data(socket) do
    # Integration with Selecto would go here
    # For now, generate sample data
    metrics = generate_sample_metrics(socket.assigns[:config] || %{})

    socket
    |> assign(:metrics, metrics)
    |> assign(:loading, false)
    |> assign(:error, nil)
  end

  defp schedule_refresh(socket) do
    if socket.assigns[:auto_refresh] && socket.assigns.update_interval > 0 do
      Process.send_after(self(), :refresh_metrics, socket.assigns.update_interval)
    end

    socket
  end

  defp generate_sample_metrics(_config) do
    %{
      value: :rand.uniform(10000),
      previous: :rand.uniform(10000),
      current: :rand.uniform(10000),
      change: :rand.uniform(200) - 100,
      comparison: :rand.uniform(50) - 25,
      target: 10000,
      min: 0,
      max: 15000,
      avg: 7500,
      timeline: Enum.map(1..7, fn _ -> :rand.uniform(10000) end),
      labels: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
      segments: [
        %{value: :rand.uniform(3000), color: "blue", label: "Completed"},
        %{value: :rand.uniform(2000), color: "yellow", label: "In Progress"},
        %{value: :rand.uniform(1000), color: "gray", label: "Pending"}
      ],
      milestones: [
        %{label: "Q1", value: 2500},
        %{label: "Q2", value: 5000},
        %{label: "Q3", value: 7500},
        %{label: "Q4", value: 10000}
      ]
    }
  end

  defp format_metric_value(nil, _), do: "—"

  defp format_metric_value(value, config) do
    case config[:format] do
      :currency -> "$#{format_number(value)}"
      :percentage -> "#{round(value)}%"
      :decimal -> Float.round(value * 1.0, config[:decimals] || 2) |> to_string()
      _ -> format_number(value)
    end
  end

  defp format_number(value) when is_number(value) do
    value
    |> round()
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.join()
  end

  defp format_number(value), do: to_string(value)

  defp format_comparison(value, config) when value > 0 do
    "+#{format_metric_value(abs(value), config)}"
  end

  defp format_comparison(value, config) do
    "-#{format_metric_value(abs(value), config)}"
  end

  defp format_change(value, config) when value > 0 do
    "↑ #{format_metric_value(abs(value), Map.put(config, :format, :percentage))}"
  end

  defp format_change(value, config) do
    "↓ #{format_metric_value(abs(value), Map.put(config, :format, :percentage))}"
  end

  defp comparison_color(value) when value > 0, do: "text-green-600"
  defp comparison_color(value) when value < 0, do: "text-red-600"
  defp comparison_color(_), do: "text-gray-600"

  defp change_color(value) when value > 0, do: "text-green-600"
  defp change_color(value) when value < 0, do: "text-red-600"
  defp change_color(_), do: "text-gray-600"

  defp gauge_color(percentage) when percentage >= 80, do: "text-green-500"
  defp gauge_color(percentage) when percentage >= 60, do: "text-yellow-500"
  defp gauge_color(percentage) when percentage >= 40, do: "text-orange-500"
  defp gauge_color(_), do: "text-red-500"

  defp progress_color("green"), do: "bg-green-500"
  defp progress_color("yellow"), do: "bg-yellow-500"
  defp progress_color("red"), do: "bg-red-500"
  defp progress_color("blue"), do: "bg-blue-500"
  defp progress_color(_), do: "bg-gray-500"

  defp calculate_percentage(metrics, config) do
    min = config[:min] || 0
    max = config[:max] || 100
    value = metrics[:value] || 0

    if max - min > 0 do
      (value - min) / (max - min) * 100
    else
      0
    end
  end

  defp calculate_segment_percentage(segment, target) do
    if target && target > 0 do
      min((segment[:value] || 0) / target * 100, 100)
    else
      0
    end
  end

  defp milestone_status(milestone, current_value) do
    if current_value >= milestone.value do
      "text-green-600"
    else
      "text-gray-400"
    end
  end

  defp prepare_export_data(metrics, _config) do
    # Convert metrics to CSV format
    headers = ["Metric", "Value", "Previous", "Change"]

    rows = [
      ["Current", metrics[:value], metrics[:previous], metrics[:change]]
    ]

    ([headers] ++ rows)
    |> Enum.map(&Enum.join(&1, ","))
    |> Enum.join("\n")
  end

  def __hooks__ do
    """
    export const MetricDisplay = {
      mounted() {
        this.setupMetricHandlers();
      },
      
      setupMetricHandlers() {
        // Handle metric clicks for drill-down
        this.el.addEventListener('click', (e) => {
          const metric = e.target.closest('[data-metric]');
          if (metric) {
            this.pushEvent('drill_down', {metric: metric.dataset.metric});
          }
        });
        
        // Handle data export
        this.handleEvent('download', ({data, filename}) => {
          const blob = new Blob([data], {type: 'text/csv'});
          const url = URL.createObjectURL(blob);
          const a = document.createElement('a');
          a.href = url;
          a.download = filename;
          document.body.appendChild(a);
          a.click();
          document.body.removeChild(a);
          URL.revokeObjectURL(url);
        });
      }
    };

    export const TimelineChart = {
      mounted() {
        this.drawChart();
      },
      
      updated() {
        this.drawChart();
      },
      
      drawChart() {
        const canvas = this.el;
        const ctx = canvas.getContext('2d');
        const values = JSON.parse(canvas.dataset.values || '[]');
        const labels = JSON.parse(canvas.dataset.labels || '[]');
        
        if (values.length === 0) return;
        
        // Set canvas size
        const rect = canvas.getBoundingClientRect();
        canvas.width = rect.width;
        canvas.height = rect.height;
        
        // Clear canvas
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        
        // Calculate dimensions
        const padding = 20;
        const width = canvas.width - (padding * 2);
        const height = canvas.height - (padding * 2);
        
        // Find min and max
        const min = Math.min(...values);
        const max = Math.max(...values);
        const range = max - min || 1;
        
        // Draw grid lines
        ctx.strokeStyle = '#e5e7eb';
        ctx.lineWidth = 1;
        
        for (let i = 0; i <= 4; i++) {
          const y = padding + (i * height / 4);
          ctx.beginPath();
          ctx.moveTo(padding, y);
          ctx.lineTo(canvas.width - padding, y);
          ctx.stroke();
        }
        
        // Calculate points
        const points = values.map((value, index) => ({
          x: padding + (index / (values.length - 1)) * width,
          y: padding + height - ((value - min) / range) * height,
          value: value,
          label: labels[index] || ''
        }));
        
        // Draw area fill
        const gradient = ctx.createLinearGradient(0, padding, 0, canvas.height - padding);
        gradient.addColorStop(0, 'rgba(59, 130, 246, 0.2)');
        gradient.addColorStop(1, 'rgba(59, 130, 246, 0)');
        
        ctx.beginPath();
        ctx.moveTo(points[0].x, canvas.height - padding);
        points.forEach(point => ctx.lineTo(point.x, point.y));
        ctx.lineTo(points[points.length - 1].x, canvas.height - padding);
        ctx.closePath();
        ctx.fillStyle = gradient;
        ctx.fill();
        
        // Draw line
        ctx.beginPath();
        ctx.moveTo(points[0].x, points[0].y);
        points.forEach(point => ctx.lineTo(point.x, point.y));
        ctx.strokeStyle = 'rgb(59, 130, 246)';
        ctx.lineWidth = 2;
        ctx.stroke();
        
        // Draw points and labels
        points.forEach((point, index) => {
          // Draw point
          ctx.beginPath();
          ctx.arc(point.x, point.y, 4, 0, Math.PI * 2);
          ctx.fillStyle = 'white';
          ctx.fill();
          ctx.strokeStyle = 'rgb(59, 130, 246)';
          ctx.lineWidth = 2;
          ctx.stroke();
          
          // Draw label
          if (point.label) {
            ctx.fillStyle = '#6b7280';
            ctx.font = '11px system-ui';
            ctx.textAlign = 'center';
            ctx.fillText(point.label, point.x, canvas.height - 5);
          }
        });
      }
    };
    """
  end
end
