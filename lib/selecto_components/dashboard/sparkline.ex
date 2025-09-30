defmodule SelectoComponents.Dashboard.Sparkline do
  @moduledoc """
  Lightweight sparkline chart component for inline data visualization.
  Supports line, bar, and area sparklines with customizable styling.
  """
  
  use Phoenix.Component
  
  @doc """
  Renders a sparkline chart.
  """
  attr :id, :string, required: true
  attr :data, :list, required: true
  attr :type, :atom, default: :line, values: [:line, :bar, :area]
  attr :width, :integer, default: 100
  attr :height, :integer, default: 30
  attr :color, :string, default: "blue"
  attr :show_dots, :boolean, default: false
  attr :show_reference, :boolean, default: false
  attr :reference_value, :float, default: nil
  attr :class, :string, default: ""
  
  def sparkline(assigns) do
    assigns = 
      assigns
      |> assign(:chart_id, "sparkline-#{assigns.id}")
      |> assign(:color_rgb, get_color_rgb(assigns.color))
    
    ~H"""
    <div
      id={@id}
      class={["sparkline-container inline-block", @class]}
      phx-hook="Sparkline"
      data-chart-id={@chart_id}
      data-type={@type}
      data-values={Jason.encode!(@data)}
      data-color={@color_rgb}
      data-show-dots={@show_dots}
      data-show-reference={@show_reference}
      data-reference-value={@reference_value}
    >
      <canvas
        id={@chart_id}
        width={@width}
        height={@height}
        style={"width: #{@width}px; height: #{@height}px;"}
      />
    </div>
    """
  end
  
  @doc """
  Renders a mini bar chart sparkline.
  """
  attr :id, :string, required: true
  attr :data, :list, required: true
  attr :width, :integer, default: 100
  attr :height, :integer, default: 30
  attr :color, :string, default: "blue"
  attr :highlight_last, :boolean, default: true
  attr :class, :string, default: ""
  
  def bar_sparkline(assigns) do
    assigns = assign(assigns, :max_value, Enum.max(assigns.data, fn -> 1 end))
    
    ~H"""
    <div
      id={@id}
      class={["bar-sparkline inline-flex items-end gap-0.5", @class]}
      style={"width: #{@width}px; height: #{@height}px;"}
    >
      <%= for {value, index} <- Enum.with_index(@data) do %>
        <div
          class={[
            "flex-1 rounded-t",
            bar_color(@color, @highlight_last && index == length(@data) - 1)
          ]}
          style={"height: #{(value / @max_value) * 100}%; min-height: 2px;"}
          title={to_string(value)}
        />
      <% end %>
    </div>
    """
  end
  
  @doc """
  Renders a win/loss sparkline (binary outcomes).
  """
  attr :id, :string, required: true
  attr :data, :list, required: true
  attr :width, :integer, default: 100
  attr :height, :integer, default: 20
  attr :win_color, :string, default: "green"
  attr :loss_color, :string, default: "red"
  attr :draw_color, :string, default: "gray"
  attr :class, :string, default: ""
  
  def win_loss_sparkline(assigns) do
    ~H"""
    <div
      id={@id}
      class={["win-loss-sparkline inline-flex items-center gap-0.5", @class]}
      style={"width: #{@width}px; height: #{@height}px;"}
    >
      <%= for value <- @data do %>
        <div
          class={[
            "flex-1",
            win_loss_bar_class(value, @win_color, @loss_color, @draw_color)
          ]}
          style={"height: #{abs(value) * @height / 2}px; #{if value < 0, do: "margin-top: auto;"}"}
          title={to_string(value)}
        />
      <% end %>
    </div>
    """
  end
  
  @doc """
  Renders a pie sparkline (micro pie chart).
  """
  attr :id, :string, required: true
  attr :data, :list, required: true
  attr :size, :integer, default: 30
  attr :colors, :list, default: ["blue", "green", "yellow", "red", "purple"]
  attr :class, :string, default: ""
  
  def pie_sparkline(assigns) do
    assigns = 
      assigns
      |> assign(:total, Enum.sum(assigns.data))
      |> assign(:segments, calculate_pie_segments(assigns.data, assigns.colors))
    
    ~H"""
    <div
      id={@id}
      class={["pie-sparkline inline-block", @class]}
      phx-hook="PieSparkline"
      data-segments={Jason.encode!(@segments)}
    >
      <svg width={@size} height={@size} viewBox="0 0 100 100">
        <%= for {segment, index} <- Enum.with_index(@segments) do %>
          <path
            d={segment.path}
            fill={segment.color}
            stroke="white"
            stroke-width="1"
            title={"#{segment.label}: #{segment.value}"}
          />
        <% end %>
      </svg>
    </div>
    """
  end
  
  @doc """
  Renders a bullet chart sparkline.
  """
  attr :id, :string, required: true
  attr :value, :float, required: true
  attr :target, :float, required: true
  attr :ranges, :list, default: []
  attr :width, :integer, default: 100
  attr :height, :integer, default: 20
  attr :class, :string, default: ""
  
  def bullet_sparkline(assigns) do
    assigns = 
      assigns
      |> assign(:max_value, max(assigns.target * 1.2, assigns.value))
      |> assign(:value_width, (assigns.value / assigns.max_value) * 100)
      |> assign(:target_position, (assigns.target / assigns.max_value) * 100)
    
    ~H"""
    <div
      id={@id}
      class={["bullet-sparkline relative", @class]}
      style={"width: #{@width}px; height: #{@height}px;"}
    >
      <!-- Background ranges -->
      <div class="absolute inset-0 flex">
        <%= for {range, index} <- Enum.with_index(@ranges || default_ranges(@max_value)) do %>
          <div
            class={range_color(index)}
            style={"width: #{(range / @max_value) * 100}%;"}
          />
        <% end %>
      </div>
      
      <!-- Value bar -->
      <div
        class="absolute top-1 bottom-1 left-0 bg-gray-800 rounded-r"
        style={"width: #{@value_width}%;"}
      />
      
      <!-- Target line -->
      <div
        class="absolute top-0 bottom-0 w-0.5 bg-red-600"
        style={"left: #{@target_position}%;"}
      />
    </div>
    """
  end
  
  @doc """
  Renders a trend sparkline with positive/negative areas.
  """
  attr :id, :string, required: true
  attr :data, :list, required: true
  attr :baseline, :float, default: 0.0
  attr :width, :integer, default: 100
  attr :height, :integer, default: 30
  attr :positive_color, :string, default: "green"
  attr :negative_color, :string, default: "red"
  attr :class, :string, default: ""
  
  def trend_sparkline(assigns) do
    ~H"""
    <div
      id={@id}
      class={["trend-sparkline", @class]}
      phx-hook="TrendSparkline"
      data-values={Jason.encode!(@data)}
      data-baseline={@baseline}
      data-positive-color={get_color_rgb(@positive_color)}
      data-negative-color={get_color_rgb(@negative_color)}
    >
      <canvas
        width={@width}
        height={@height}
        style={"width: #{@width}px; height: #{@height}px;"}
      />
    </div>
    """
  end
  
  # Private functions
  
  defp get_color_rgb(color) do
    case color do
      "blue" -> "59, 130, 246"
      "green" -> "34, 197, 94"
      "red" -> "239, 68, 68"
      "yellow" -> "250, 204, 21"
      "purple" -> "168, 85, 247"
      "gray" -> "107, 114, 128"
      "orange" -> "251, 146, 60"
      _ -> "59, 130, 246"
    end
  end
  
  defp bar_color(color, highlight) do
    base_color = case color do
      "blue" -> "bg-blue-400"
      "green" -> "bg-green-400"
      "red" -> "bg-red-400"
      "yellow" -> "bg-yellow-400"
      "purple" -> "bg-purple-400"
      _ -> "bg-gray-400"
    end
    
    if highlight do
      String.replace(base_color, "400", "600")
    else
      base_color
    end
  end
  
  defp win_loss_bar_class(value, win_color, loss_color, draw_color) do
    cond do
      value > 0 -> "bg-#{win_color}-500 self-start"
      value < 0 -> "bg-#{loss_color}-500 self-end"
      true -> "bg-#{draw_color}-400 self-center"
    end
  end
  
  defp calculate_pie_segments(data, colors) do
    total = Enum.sum(data)
    if total == 0, do: [], else: calculate_pie_segments_recursive(data, colors, 0, total, [])
  end
  
  defp calculate_pie_segments_recursive([], _, _, _, acc), do: Enum.reverse(acc)
  defp calculate_pie_segments_recursive([value | rest], [color | colors], start_angle, total, acc) do
    sweep_angle = (value / total) * 360
    segment = %{
      value: value,
      color: get_pie_color(color),
      path: create_pie_path(start_angle, sweep_angle),
      label: "Value"
    }
    
    calculate_pie_segments_recursive(
      rest,
      colors ++ [color],
      start_angle + sweep_angle,
      total,
      [segment | acc]
    )
  end
  
  defp get_pie_color(color) do
    case color do
      "blue" -> "#3b82f6"
      "green" -> "#22c55e"
      "red" -> "#ef4444"
      "yellow" -> "#facc15"
      "purple" -> "#a855f7"
      _ -> "#6b7280"
    end
  end
  
  defp create_pie_path(start_angle, sweep_angle) do
    # SVG path for pie segment
    # This is simplified - actual implementation would calculate proper arc paths
    "M 50 50 L #{50 + 40 * :math.cos(start_angle * :math.pi() / 180)} #{50 + 40 * :math.sin(start_angle * :math.pi() / 180)} A 40 40 0 #{if sweep_angle > 180, do: 1, else: 0} 1 #{50 + 40 * :math.cos((start_angle + sweep_angle) * :math.pi() / 180)} #{50 + 40 * :math.sin((start_angle + sweep_angle) * :math.pi() / 180)} Z"
  end
  
  defp default_ranges(max_value) do
    [max_value * 0.6, max_value * 0.8, max_value]
  end
  
  defp range_color(index) do
    case index do
      0 -> "bg-gray-300"
      1 -> "bg-gray-400"
      _ -> "bg-gray-500"
    end
  end
  
  def __hooks__ do
    """
    export const Sparkline = {
      mounted() {
        this.drawSparkline();
      },
      
      updated() {
        this.drawSparkline();
      },
      
      drawSparkline() {
        const canvas = document.getElementById(this.el.dataset.chartId);
        if (!canvas) return;
        
        const ctx = canvas.getContext('2d');
        const data = JSON.parse(this.el.dataset.values || '[]');
        const type = this.el.dataset.type || 'line';
        const color = this.el.dataset.color || '59, 130, 246';
        const showDots = this.el.dataset.showDots === 'true';
        const showReference = this.el.dataset.showReference === 'true';
        const referenceValue = parseFloat(this.el.dataset.referenceValue || '0');
        
        if (data.length === 0) return;
        
        // Clear canvas
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        
        // Calculate dimensions
        const padding = 2;
        const width = canvas.width - (padding * 2);
        const height = canvas.height - (padding * 2);
        
        // Find min and max
        const min = Math.min(...data, showReference ? referenceValue : Infinity);
        const max = Math.max(...data, showReference ? referenceValue : -Infinity);
        const range = max - min || 1;
        
        // Calculate points
        const points = data.map((value, index) => ({
          x: padding + (index / (data.length - 1)) * width,
          y: padding + height - ((value - min) / range) * height
        }));
        
        // Draw reference line if enabled
        if (showReference) {
          const refY = padding + height - ((referenceValue - min) / range) * height;
          ctx.strokeStyle = `rgba(${color}, 0.3)`;
          ctx.lineWidth = 1;
          ctx.setLineDash([2, 2]);
          ctx.beginPath();
          ctx.moveTo(padding, refY);
          ctx.lineTo(canvas.width - padding, refY);
          ctx.stroke();
          ctx.setLineDash([]);
        }
        
        if (type === 'area' || type === 'line') {
          // Draw area fill
          if (type === 'area') {
            const gradient = ctx.createLinearGradient(0, 0, 0, canvas.height);
            gradient.addColorStop(0, `rgba(${color}, 0.3)`);
            gradient.addColorStop(1, `rgba(${color}, 0)`);
            
            ctx.beginPath();
            ctx.moveTo(points[0].x, canvas.height - padding);
            points.forEach(point => ctx.lineTo(point.x, point.y));
            ctx.lineTo(points[points.length - 1].x, canvas.height - padding);
            ctx.closePath();
            ctx.fillStyle = gradient;
            ctx.fill();
          }
          
          // Draw line
          ctx.beginPath();
          ctx.moveTo(points[0].x, points[0].y);
          points.forEach(point => ctx.lineTo(point.x, point.y));
          ctx.strokeStyle = `rgb(${color})`;
          ctx.lineWidth = 1.5;
          ctx.stroke();
          
          // Draw dots if enabled
          if (showDots) {
            points.forEach(point => {
              ctx.beginPath();
              ctx.arc(point.x, point.y, 2, 0, Math.PI * 2);
              ctx.fillStyle = `rgb(${color})`;
              ctx.fill();
            });
          }
        } else if (type === 'bar') {
          // Draw bars
          const barWidth = width / data.length * 0.8;
          const barGap = width / data.length * 0.2;
          
          data.forEach((value, index) => {
            const barHeight = ((value - min) / range) * height;
            const x = padding + index * (barWidth + barGap);
            const y = padding + height - barHeight;
            
            ctx.fillStyle = `rgba(${color}, 0.8)`;
            ctx.fillRect(x, y, barWidth, barHeight);
          });
        }
      }
    };
    
    export const TrendSparkline = {
      mounted() {
        this.drawTrend();
      },
      
      updated() {
        this.drawTrend();
      },
      
      drawTrend() {
        const canvas = this.el.querySelector('canvas');
        if (!canvas) return;
        
        const ctx = canvas.getContext('2d');
        const data = JSON.parse(this.el.dataset.values || '[]');
        const baseline = parseFloat(this.el.dataset.baseline || '0');
        const positiveColor = this.el.dataset.positiveColor || '34, 197, 94';
        const negativeColor = this.el.dataset.negativeColor || '239, 68, 68';
        
        if (data.length === 0) return;
        
        // Clear canvas
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        
        // Calculate dimensions
        const padding = 2;
        const width = canvas.width - (padding * 2);
        const height = canvas.height - (padding * 2);
        
        // Find min and max
        const min = Math.min(...data, baseline);
        const max = Math.max(...data, baseline);
        const range = max - min || 1;
        
        // Calculate baseline position
        const baselineY = padding + height - ((baseline - min) / range) * height;
        
        // Draw baseline
        ctx.strokeStyle = 'rgba(107, 114, 128, 0.3)';
        ctx.lineWidth = 1;
        ctx.setLineDash([2, 2]);
        ctx.beginPath();
        ctx.moveTo(padding, baselineY);
        ctx.lineTo(canvas.width - padding, baselineY);
        ctx.stroke();
        ctx.setLineDash([]);
        
        // Calculate points
        const points = data.map((value, index) => ({
          x: padding + (index / (data.length - 1)) * width,
          y: padding + height - ((value - min) / range) * height,
          value: value
        }));
        
        // Draw positive and negative areas separately
        let lastPoint = points[0];
        
        points.forEach((point, index) => {
          if (index === 0) return;
          
          // Determine if segment is positive or negative
          const isPositive = point.value >= baseline && lastPoint.value >= baseline;
          const isNegative = point.value <= baseline && lastPoint.value <= baseline;
          
          if (isPositive || isNegative) {
            // Draw area
            const gradient = ctx.createLinearGradient(0, baselineY, 0, point.y);
            const color = isPositive ? positiveColor : negativeColor;
            gradient.addColorStop(0, `rgba(${color}, 0)`);
            gradient.addColorStop(1, `rgba(${color}, 0.3)`);
            
            ctx.beginPath();
            ctx.moveTo(lastPoint.x, baselineY);
            ctx.lineTo(lastPoint.x, lastPoint.y);
            ctx.lineTo(point.x, point.y);
            ctx.lineTo(point.x, baselineY);
            ctx.closePath();
            ctx.fillStyle = gradient;
            ctx.fill();
            
            // Draw line
            ctx.beginPath();
            ctx.moveTo(lastPoint.x, lastPoint.y);
            ctx.lineTo(point.x, point.y);
            ctx.strokeStyle = `rgb(${color})`;
            ctx.lineWidth = 1.5;
            ctx.stroke();
          }
          
          lastPoint = point;
        });
      }
    };
    
    export const PieSparkline = {
      mounted() {
        // Pie sparkline is rendered with SVG, no canvas needed
        this.setupTooltips();
      },
      
      setupTooltips() {
        const paths = this.el.querySelectorAll('path');
        paths.forEach(path => {
          path.addEventListener('mouseenter', (e) => {
            // Could show custom tooltip here
          });
        });
      }
    };
    """
  end
end