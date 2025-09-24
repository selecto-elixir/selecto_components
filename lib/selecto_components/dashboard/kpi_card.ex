defmodule SelectoComponents.Dashboard.KpiCard do
  @moduledoc """
  KPI (Key Performance Indicator) card component for dashboard displays.
  Shows metrics with trends, comparisons, and sparklines.
  """
  
  use Phoenix.Component
  import Phoenix.LiveView
  alias Phoenix.LiveView.JS
  alias SelectoComponents.Dashboard.Sparkline
  
  @doc """
  Renders a KPI card with metric value, trend, and optional sparkline.
  """
  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :value, :any, required: true
  attr :format, :atom, default: :number
  attr :trend, :atom, values: [:up, :down, :neutral], default: :neutral
  attr :trend_value, :any, default: nil
  attr :trend_label, :string, default: "vs last period"
  attr :target, :any, default: nil
  attr :sparkline_data, :list, default: []
  attr :color, :string, default: "blue"
  attr :icon, :string, default: nil
  attr :clickable, :boolean, default: false
  attr :class, :string, default: ""
  slot :actions
  
  def kpi_card(assigns) do
    assigns = 
      assigns
      |> assign(:formatted_value, format_value(assigns.value, assigns.format))
      |> assign(:formatted_trend, format_trend_value(assigns.trend_value, assigns.format))
      |> assign(:progress, calculate_progress(assigns.value, assigns.target))
      |> assign(:color_classes, get_color_classes(assigns.color))
    
    ~H"""
    <div
      id={@id}
      class={[
        "kpi-card relative bg-white rounded-lg shadow-sm border border-gray-200 p-6",
        if(@clickable, do: "cursor-pointer hover:shadow-md transition-shadow"),
        @class
      ]}
      phx-hook={if @sparkline_data != [], do: "KpiSparkline"}
      data-sparkline={Jason.encode!(@sparkline_data)}
    >
      <div class="flex items-start justify-between mb-4">
        <div class="flex items-center">
          <%= if @icon do %>
            <div class={["kpi-icon p-3 rounded-lg mr-3", @color_classes.bg_light]}>
              <span class={["text-2xl", @color_classes.text]}><%= @icon %></span>
            </div>
          <% end %>
          
          <div>
            <h3 class="text-sm font-medium text-gray-600 uppercase tracking-wider">
              <%= @title %>
            </h3>
            <div class="flex items-baseline gap-2 mt-1">
              <span class="text-3xl font-bold text-gray-900">
                <%= @formatted_value %>
              </span>
              <%= if @trend_value do %>
                <%= render_trend_indicator(assigns) %>
              <% end %>
            </div>
          </div>
        </div>
        
        <%= if @actions != [] do %>
          <div class="kpi-actions">
            <%= render_slot(@actions) %>
          </div>
        <% end %>
      </div>
      
      <%= if @target do %>
        <div class="mb-4">
          <div class="flex justify-between text-sm text-gray-600 mb-1">
            <span>Progress</span>
            <span><%= round(@progress) %>%</span>
          </div>
          <div class="w-full bg-gray-200 rounded-full h-2">
            <div
              class={["h-2 rounded-full transition-all duration-500", @color_classes.bg]}
              style={"width: #{min(@progress, 100)}%"}
            />
          </div>
          <div class="flex justify-between text-xs text-gray-500 mt-1">
            <span>Current: <%= @formatted_value %></span>
            <span>Target: <%= format_value(@target, @format) %></span>
          </div>
        </div>
      <% end %>
      
      <%= if @sparkline_data != [] do %>
        <div class="kpi-sparkline mt-4">
          <canvas
            id={"#{@id}-sparkline"}
            class="w-full h-12"
            width="300"
            height="50"
          />
        </div>
      <% end %>
      
      <%= if @trend_label do %>
        <div class="text-xs text-gray-500 mt-2">
          <%= @trend_label %>
        </div>
      <% end %>
    </div>
    """
  end
  
  @doc """
  Renders a compact KPI metric card.
  """
  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :format, :atom, default: :number
  attr :change, :any, default: nil
  attr :change_type, :atom, values: [:percentage, :absolute], default: :percentage
  attr :color, :string, default: "gray"
  attr :class, :string, default: ""
  
  def metric_card(assigns) do
    assigns = 
      assigns
      |> assign(:formatted_value, format_value(assigns.value, assigns.format))
      |> assign(:formatted_change, format_change(assigns.change, assigns.change_type))
      |> assign(:change_color, get_change_color(assigns.change))
    
    ~H"""
    <div
      id={@id}
      class={[
        "metric-card bg-white rounded-md border border-gray-200 p-4",
        @class
      ]}
    >
      <div class="text-xs font-medium text-gray-500 uppercase tracking-wider mb-1">
        <%= @label %>
      </div>
      <div class="flex items-baseline justify-between">
        <span class="text-2xl font-semibold text-gray-900">
          <%= @formatted_value %>
        </span>
        <%= if @change do %>
          <span class={["text-sm font-medium", @change_color]}>
            <%= if @change > 0 do %>
              <span>↑</span>
            <% else %>
              <span>↓</span>
            <% end %>
            <%= @formatted_change %>
          </span>
        <% end %>
      </div>
    </div>
    """
  end
  
  @doc """
  Renders a grid of KPI cards.
  """
  attr :id, :string, required: true
  attr :cards, :list, required: true
  attr :columns, :integer, default: 4
  attr :gap, :integer, default: 4
  attr :class, :string, default: ""
  
  def kpi_grid(assigns) do
    ~H"""
    <div
      id={@id}
      class={[
        "kpi-grid grid",
        "grid-cols-1 sm:grid-cols-2 lg:grid-cols-#{@columns}",
        "gap-#{@gap}",
        @class
      ]}
    >
      <%= for card <- @cards do %>
        <.kpi_card
          id={card.id}
          title={card.title}
          value={card.value}
          format={Map.get(card, :format, :number)}
          trend={Map.get(card, :trend, :neutral)}
          trend_value={Map.get(card, :trend_value)}
          trend_label={Map.get(card, :trend_label)}
          target={Map.get(card, :target)}
          sparkline_data={Map.get(card, :sparkline_data, [])}
          color={Map.get(card, :color, "blue")}
          icon={Map.get(card, :icon)}
          clickable={Map.get(card, :clickable, false)}
        />
      <% end %>
    </div>
    """
  end
  
  # Private functions
  
  defp render_trend_indicator(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center text-sm font-medium",
      trend_color_class(@trend)
    ]}>
      <%= case @trend do %>
        <% :up -> %>
          <svg class="w-4 h-4 mr-1" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M5.293 9.707a1 1 0 010-1.414l4-4a1 1 0 011.414 0l4 4a1 1 0 01-1.414 1.414L11 7.414V15a1 1 0 11-2 0V7.414L6.707 9.707a1 1 0 01-1.414 0z" clip-rule="evenodd" />
          </svg>
        <% :down -> %>
          <svg class="w-4 h-4 mr-1" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M14.707 10.293a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 111.414-1.414L9 12.586V5a1 1 0 012 0v7.586l2.293-2.293a1 1 0 011.414 0z" clip-rule="evenodd" />
          </svg>
        <% _ -> %>
          <svg class="w-4 h-4 mr-1" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M5 10a1 1 0 011-1h8a1 1 0 110 2H6a1 1 0 01-1-1z" clip-rule="evenodd" />
          </svg>
      <% end %>
      <%= @formatted_trend %>
    </span>
    """
  end
  
  defp format_value(value, format) do
    case format do
      :currency ->
        "$#{format_number(value)}"
      
      :percentage ->
        "#{round(value)}%"
      
      :decimal ->
        Float.round(value * 1.0, 2) |> to_string()
      
      :compact ->
        compact_number(value)
      
      _ ->
        format_number(value)
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
  
  defp compact_number(value) when value >= 1_000_000_000 do
    "#{Float.round(value / 1_000_000_000, 1)}B"
  end
  defp compact_number(value) when value >= 1_000_000 do
    "#{Float.round(value / 1_000_000, 1)}M"
  end
  defp compact_number(value) when value >= 1_000 do
    "#{Float.round(value / 1_000, 1)}K"
  end
  defp compact_number(value), do: format_number(value)
  
  defp format_trend_value(nil, _), do: ""
  defp format_trend_value(value, format) do
    case format do
      :percentage -> "+#{round(value)}%"
      _ -> format_value(value, format)
    end
  end
  
  defp format_change(nil, _), do: ""
  defp format_change(value, :percentage), do: "#{abs(round(value))}%"
  defp format_change(value, :absolute), do: format_number(abs(value))
  
  defp calculate_progress(nil, _), do: 0
  defp calculate_progress(_, nil), do: 0
  defp calculate_progress(value, target) when is_number(value) and is_number(target) and target != 0 do
    (value / target) * 100
  end
  defp calculate_progress(_, _), do: 0
  
  defp trend_color_class(:up), do: "text-green-600"
  defp trend_color_class(:down), do: "text-red-600"
  defp trend_color_class(_), do: "text-gray-600"
  
  defp get_change_color(nil), do: "text-gray-500"
  defp get_change_color(change) when change > 0, do: "text-green-600"
  defp get_change_color(change) when change < 0, do: "text-red-600"
  defp get_change_color(_), do: "text-gray-500"
  
  defp get_color_classes(color) do
    case color do
      "blue" -> %{
        bg: "bg-blue-500",
        bg_light: "bg-blue-100",
        text: "text-blue-600",
        border: "border-blue-200"
      }
      "green" -> %{
        bg: "bg-green-500",
        bg_light: "bg-green-100",
        text: "text-green-600",
        border: "border-green-200"
      }
      "red" -> %{
        bg: "bg-red-500",
        bg_light: "bg-red-100",
        text: "text-red-600",
        border: "border-red-200"
      }
      "yellow" -> %{
        bg: "bg-yellow-500",
        bg_light: "bg-yellow-100",
        text: "text-yellow-600",
        border: "border-yellow-200"
      }
      "purple" -> %{
        bg: "bg-purple-500",
        bg_light: "bg-purple-100",
        text: "text-purple-600",
        border: "border-purple-200"
      }
      _ -> %{
        bg: "bg-gray-500",
        bg_light: "bg-gray-100",
        text: "text-gray-600",
        border: "border-gray-200"
      }
    end
  end
  
  def __hooks__ do
    """
    export const KpiSparkline = {
      mounted() {
        this.drawSparkline();
      },
      
      updated() {
        this.drawSparkline();
      },
      
      drawSparkline() {
        const canvas = this.el.querySelector('canvas');
        if (!canvas) return;
        
        const ctx = canvas.getContext('2d');
        const data = JSON.parse(this.el.dataset.sparkline || '[]');
        
        if (data.length === 0) return;
        
        // Clear canvas
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        
        // Calculate dimensions
        const padding = 5;
        const width = canvas.width - (padding * 2);
        const height = canvas.height - (padding * 2);
        
        // Find min and max values
        const min = Math.min(...data);
        const max = Math.max(...data);
        const range = max - min || 1;
        
        // Calculate points
        const points = data.map((value, index) => ({
          x: padding + (index / (data.length - 1)) * width,
          y: padding + height - ((value - min) / range) * height
        }));
        
        // Draw gradient fill
        const gradient = ctx.createLinearGradient(0, 0, 0, canvas.height);
        gradient.addColorStop(0, 'rgba(59, 130, 246, 0.1)');
        gradient.addColorStop(1, 'rgba(59, 130, 246, 0)');
        
        ctx.beginPath();
        ctx.moveTo(points[0].x, canvas.height);
        points.forEach(point => ctx.lineTo(point.x, point.y));
        ctx.lineTo(points[points.length - 1].x, canvas.height);
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
        
        // Draw points
        points.forEach((point, index) => {
          // Highlight last point
          if (index === points.length - 1) {
            ctx.beginPath();
            ctx.arc(point.x, point.y, 3, 0, Math.PI * 2);
            ctx.fillStyle = 'rgb(59, 130, 246)';
            ctx.fill();
          }
        });
      }
    };
    """
  end
end