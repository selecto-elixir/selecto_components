defmodule SelectoComponents.Performance.Dashboard do
  @moduledoc """
  Performance monitoring dashboard for Selecto queries with real-time metrics.
  """

  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
    <div class="performance-dashboard" id={"perf-dashboard-#{@id}"}>
      <div class="bg-white rounded-lg shadow-lg">
        <!-- Header -->
        <div class="px-6 py-4 border-b bg-gray-50">
          <div class="flex items-center justify-between">
            <h3 class="text-lg font-semibold">Performance Monitoring</h3>
            <div class="flex items-center space-x-4">
              <div class="flex items-center space-x-2">
                <span class="text-sm text-gray-600">Auto-refresh:</span>
                <label class="relative inline-flex items-center cursor-pointer">
                  <input
                    type="checkbox"
                    checked={@auto_refresh}
                    phx-change="toggle_auto_refresh"
                    phx-target={@myself}
                    class="sr-only peer"
                  />
                  <div class="w-9 h-5 bg-gray-200 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:bg-blue-600"></div>
                </label>
              </div>
              <select
                phx-change="change_time_range"
                phx-target={@myself}
                class="px-3 py-1 border border-gray-300 rounded text-sm"
              >
                <option value="1h" selected={@time_range == "1h"}>Last hour</option>
                <option value="6h" selected={@time_range == "6h"}>Last 6 hours</option>
                <option value="24h" selected={@time_range == "24h"}>Last 24 hours</option>
                <option value="7d" selected={@time_range == "7d"}>Last 7 days</option>
              </select>
            </div>
          </div>
        </div>
        
        <!-- Metrics Overview -->
        <div class="p-6 border-b">
          <div class="grid grid-cols-4 gap-4">
            <.metric_tile
              title="Avg Response Time"
              value={format_duration(@metrics.avg_response_time)}
              trend={@metrics.response_time_trend}
              icon="hero-clock"
              color="blue"
            />
            <.metric_tile
              title="Queries/Min"
              value={@metrics.queries_per_minute}
              trend={@metrics.qpm_trend}
              icon="hero-chart-bar"
              color="green"
            />
            <.metric_tile
              title="Error Rate"
              value={"#{@metrics.error_rate}%"}
              trend={@metrics.error_trend}
              icon="hero-exclamation-triangle"
              color="red"
              inverse_trend={true}
            />
            <.metric_tile
              title="Cache Hit Rate"
              value={"#{@metrics.cache_hit_rate}%"}
              trend={@metrics.cache_trend}
              icon="hero-lightning-bolt"
              color="purple"
            />
          </div>
        </div>
        
        <!-- Query Timeline -->
        <div class="p-6 border-b">
          <h4 class="font-medium text-sm text-gray-700 mb-4">Query Execution Timeline</h4>
          <div
            class="h-64 bg-gray-50 rounded"
            id={"timeline-chart-#{@id}"}
            phx-hook="TimelineChart"
            data-queries={Jason.encode!(@timeline_data)}
          >
            <!-- Chart rendered by JavaScript -->
          </div>
        </div>
        
        <!-- Slow Query Log -->
        <div class="p-6 border-b">
          <div class="flex items-center justify-between mb-4">
            <h4 class="font-medium text-sm text-gray-700">Slow Queries</h4>
            <div class="flex items-center space-x-2">
              <span class="text-xs text-gray-500">Threshold:</span>
              <select
                phx-change="change_slow_threshold"
                phx-target={@myself}
                class="px-2 py-1 border border-gray-200 rounded text-xs"
              >
                <option value="100" selected={@slow_threshold == 100}>100ms</option>
                <option value="500" selected={@slow_threshold == 500}>500ms</option>
                <option value="1000" selected={@slow_threshold == 1000}>1s</option>
                <option value="5000" selected={@slow_threshold == 5000}>5s</option>
              </select>
            </div>
          </div>
          
          <div class="space-y-2 max-h-96 overflow-y-auto">
            <%= for query <- @slow_queries do %>
              <.slow_query_card query={query} myself={@myself} />
            <% end %>
            
            <%= if @slow_queries == [] do %>
              <div class="text-center py-8 text-gray-500">
                <.icon name="hero-check-circle" class="w-8 h-8 mx-auto mb-2 text-green-500" />
                <p class="text-sm">No slow queries detected</p>
              </div>
            <% end %>
          </div>
        </div>
        
        <!-- Index Usage Analysis -->
        <div class="p-6 border-b">
          <h4 class="font-medium text-sm text-gray-700 mb-4">Index Usage</h4>
          <div class="grid grid-cols-2 gap-6">
            <div>
              <h5 class="text-xs text-gray-600 mb-2">Most Used Indexes</h5>
              <div class="space-y-2">
                <%= for index <- @most_used_indexes do %>
                  <div class="flex items-center justify-between text-sm">
                    <span class="text-gray-700"><%= index.name %></span>
                    <span class="text-gray-500"><%= index.usage_count %> uses</span>
                  </div>
                <% end %>
              </div>
            </div>
            
            <div>
              <h5 class="text-xs text-gray-600 mb-2">Unused Indexes</h5>
              <div class="space-y-2">
                <%= for index <- @unused_indexes do %>
                  <div class="flex items-center justify-between text-sm">
                    <span class="text-gray-700"><%= index.name %></span>
                    <button
                      type="button"
                      phx-click="analyze_index"
                      phx-target={@myself}
                      phx-value-index={index.name}
                      class="text-xs text-blue-600 hover:text-blue-700"
                    >
                      Analyze
                    </button>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        </div>
        
        <!-- Performance Trends -->
        <div class="p-6">
          <h4 class="font-medium text-sm text-gray-700 mb-4">Performance Trends</h4>
          <div class="grid grid-cols-3 gap-4">
            <.trend_chart
              title="Response Time"
              data={@response_time_trend}
              color="blue"
              unit="ms"
            />
            <.trend_chart
              title="Query Volume"
              data={@query_volume_trend}
              color="green"
              unit="queries"
            />
            <.trend_chart
              title="Memory Usage"
              data={@memory_trend}
              color="purple"
              unit="MB"
            />
          </div>
        </div>
        
        <!-- Alert Configuration -->
        <%= if @show_alerts do %>
          <div class="px-6 py-4 border-t bg-gray-50">
            <.alert_configuration alerts={@alerts} myself={@myself} />
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  def metric_tile(assigns) do
    assigns = assign(assigns, :trend_positive, 
      if(assigns[:inverse_trend], do: assigns.trend < 0, else: assigns.trend > 0))
    
    ~H"""
    <div class={"bg-#{@color}-50 p-4 rounded-lg"}>
      <div class="flex items-center justify-between mb-2">
        <.icon name={@icon} class={"w-5 h-5 text-#{@color}-600"} />
        <%= if @trend != 0 do %>
          <div class={"text-xs flex items-center #{if @trend_positive, do: "text-green-600", else: "text-red-600"}"}>
            <%= if @trend > 0 do %>
              ↑ <%= abs(@trend) %>%
            <% else %>
              ↓ <%= abs(@trend) %>%
            <% end %>
          </div>
        <% end %>
      </div>
      <div class={"text-2xl font-bold text-#{@color}-700"}><%= @value %></div>
      <div class={"text-xs text-#{@color}-600"}><%= @title %></div>
    </div>
    """
  end

  def slow_query_card(assigns) do
    ~H"""
    <div class="border rounded-lg p-4 hover:bg-gray-50 transition-colors">
      <div class="flex items-start justify-between">
        <div class="flex-1">
          <div class="flex items-center space-x-2 mb-2">
            <span class="text-xs px-2 py-1 bg-red-100 text-red-700 rounded">
              <%= format_duration(@query.execution_time) %>
            </span>
            <span class="text-xs text-gray-500">
              <%= format_timestamp(@query.timestamp) %>
            </span>
          </div>
          <pre class="text-xs text-gray-700 font-mono whitespace-pre-wrap"><%= truncate_sql(@query.sql) %></pre>
          <div class="mt-2 flex items-center space-x-4 text-xs">
            <span class="text-gray-500">Rows: <%= @query.row_count %></span>
            <span class="text-gray-500">Scans: <%= @query.table_scans %></span>
            <button
              type="button"
              phx-click="show_query_plan"
              phx-target={@myself}
              phx-value-query-id={@query.id}
              class="text-blue-600 hover:text-blue-700"
            >
              View Plan
            </button>
            <button
              type="button"
              phx-click="optimize_query"
              phx-target={@myself}
              phx-value-query-id={@query.id}
              class="text-green-600 hover:text-green-700"
            >
              Optimize
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def trend_chart(assigns) do
    ~H"""
    <div class="bg-gray-50 p-3 rounded">
      <h5 class="text-xs text-gray-600 mb-2"><%= @title %></h5>
      <div
        class="h-20"
        id={"trend-#{String.downcase(String.replace(@title, " ", "-"))}-#{System.unique_integer()}"} 
        phx-hook="TrendChart"
        data-values={Jason.encode!(@data)}
        data-color={@color}
        data-unit={@unit}
      >
        <!-- Mini chart rendered by JavaScript -->
      </div>
    </div>
    """
  end

  def alert_configuration(assigns) do
    ~H"""
    <div>
      <h4 class="font-medium text-sm text-gray-700 mb-3">Alert Configuration</h4>
      <div class="space-y-2">
        <%= for alert <- @alerts do %>
          <div class="flex items-center justify-between p-3 bg-white rounded border">
            <div class="flex items-center space-x-3">
              <input
                type="checkbox"
                checked={alert.enabled}
                phx-change="toggle_alert"
                phx-target={@myself}
                phx-value-id={alert.id}
                class="h-4 w-4 text-blue-600 rounded"
              />
              <div>
                <div class="text-sm font-medium"><%= alert.name %></div>
                <div class="text-xs text-gray-500"><%= alert.condition %></div>
              </div>
            </div>
            <button
              type="button"
              phx-click="edit_alert"
              phx-target={@myself}
              phx-value-id={alert.id}
              class="text-xs text-blue-600 hover:text-blue-700"
            >
              Configure
            </button>
          </div>
        <% end %>
      </div>
      <button
        type="button"
        phx-click="add_alert"
        phx-target={@myself}
        class="mt-3 px-3 py-1 bg-blue-600 text-white rounded text-sm hover:bg-blue-700"
      >
        Add Alert
      </button>
    </div>
    """
  end

  def mount(socket) do
    {:ok,
     socket
     |> assign(default_assigns())
     |> schedule_refresh()}
  end

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> load_performance_data()}
  end

  def handle_event("toggle_auto_refresh", %{"value" => value}, socket) do
    auto_refresh = value == "on"
    
    socket = 
      socket
      |> assign(auto_refresh: auto_refresh)
      |> schedule_refresh()
    
    {:noreply, socket}
  end

  def handle_event("change_time_range", %{"value" => range}, socket) do
    {:noreply,
     socket
     |> assign(time_range: range)
     |> load_performance_data()}
  end

  def handle_event("change_slow_threshold", %{"value" => threshold}, socket) do
    {:noreply,
     socket
     |> assign(slow_threshold: String.to_integer(threshold))
     |> load_slow_queries()}
  end

  def handle_event("show_query_plan", %{"query-id" => id}, socket) do
    send(self(), {:show_query_plan, id})
    {:noreply, socket}
  end

  def handle_event("optimize_query", %{"query-id" => id}, socket) do
    send(self(), {:optimize_query, id})
    {:noreply, socket}
  end

  def handle_info(:refresh_data, socket) do
    {:noreply,
     socket
     |> load_performance_data()
     |> schedule_refresh()}
  end

  # Private functions

  defp default_assigns do
    %{
      id: Ecto.UUID.generate(),
      auto_refresh: true,
      time_range: "1h",
      slow_threshold: 500,
      show_alerts: false,
      metrics: default_metrics(),
      timeline_data: [],
      slow_queries: [],
      most_used_indexes: [],
      unused_indexes: [],
      response_time_trend: [],
      query_volume_trend: [],
      memory_trend: [],
      alerts: default_alerts()
    }
  end

  defp default_metrics do
    %{
      avg_response_time: 0,
      response_time_trend: 0,
      queries_per_minute: 0,
      qpm_trend: 0,
      error_rate: 0,
      error_trend: 0,
      cache_hit_rate: 0,
      cache_trend: 0
    }
  end

  defp default_alerts do
    [
      %{
        id: "slow_query",
        name: "Slow Query Alert",
        condition: "Response time > 1000ms",
        enabled: true
      },
      %{
        id: "high_error",
        name: "High Error Rate",
        condition: "Error rate > 5%",
        enabled: true
      },
      %{
        id: "low_cache",
        name: "Low Cache Hit Rate",
        condition: "Cache hit rate < 80%",
        enabled: false
      }
    ]
  end

  defp load_performance_data(socket) do
    # In a real implementation, this would fetch from database/monitoring service
    socket
    |> assign(
      metrics: generate_mock_metrics(),
      timeline_data: generate_timeline_data(socket.assigns.time_range),
      response_time_trend: generate_trend_data(),
      query_volume_trend: generate_trend_data(),
      memory_trend: generate_trend_data()
    )
    |> load_slow_queries()
    |> load_index_usage()
  end

  defp load_slow_queries(socket) do
    # Mock slow queries
    queries = [
      %{
        id: Ecto.UUID.generate(),
        sql: "SELECT * FROM orders o JOIN order_items oi ON o.order_id = oi.order_id WHERE o.status = 'processing'",
        execution_time: 1250,
        row_count: 5234,
        table_scans: 2,
        timestamp: DateTime.utc_now()
      },
      %{
        id: Ecto.UUID.generate(),
        sql: "SELECT COUNT(*) FROM rentals WHERE return_date IS NULL GROUP BY customer_id",
        execution_time: 890,
        row_count: 125,
        table_scans: 1,
        timestamp: DateTime.add(DateTime.utc_now(), -300, :second)
      }
    ]
    
    assign(socket, slow_queries: queries)
  end

  defp load_index_usage(socket) do
    most_used = [
      %{name: "idx_orders_created_at", usage_count: 1523},
      %{name: "idx_customer_email", usage_count: 892},
      %{name: "idx_rental_date", usage_count: 654}
    ]
    
    unused = [
      %{name: "idx_order_items_product_id", usage_count: 0},
      %{name: "idx_address_postal_code", usage_count: 0}
    ]
    
    assign(socket,
      most_used_indexes: most_used,
      unused_indexes: unused
    )
  end

  defp generate_mock_metrics do
    %{
      avg_response_time: 125 + :rand.uniform(50),
      response_time_trend: :rand.uniform(20) - 10,
      queries_per_minute: 450 + :rand.uniform(100),
      qpm_trend: :rand.uniform(30) - 15,
      error_rate: Float.round(:rand.uniform() * 2, 1),
      error_trend: :rand.uniform(10) - 5,
      cache_hit_rate: 85 + :rand.uniform(10),
      cache_trend: :rand.uniform(10) - 5
    }
  end

  defp generate_timeline_data(range) do
    points = case range do
      "1h" -> 60
      "6h" -> 72
      "24h" -> 96
      "7d" -> 168
      _ -> 60
    end
    
    Enum.map(1..points, fn i ->
      %{
        time: DateTime.add(DateTime.utc_now(), -i * 60, :second),
        value: 100 + :rand.uniform(200),
        queries: :rand.uniform(50)
      }
    end)
  end

  defp generate_trend_data do
    Enum.map(1..20, fn _ -> :rand.uniform(100) end)
  end

  defp schedule_refresh(socket) do
    if socket.assigns.auto_refresh do
      Process.send_after(self(), :refresh_data, 5000)
    end
    socket
  end

  defp format_duration(ms) when ms >= 1000, do: "#{Float.round(ms / 1000, 1)}s"
  defp format_duration(ms), do: "#{ms}ms"

  defp format_timestamp(datetime) do
    Calendar.strftime(datetime, "%H:%M:%S")
  end

  defp truncate_sql(sql) when byte_size(sql) > 200 do
    String.slice(sql, 0, 200) <> "..."
  end
  defp truncate_sql(sql), do: sql

  defp icon(assigns) do
    ~H"""
    <svg class={@class} fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <%= case @name do %>
        <% "hero-clock" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
        <% "hero-chart-bar" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
        <% "hero-exclamation-triangle" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
        <% "hero-lightning-bolt" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
        <% "hero-check-circle" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
        <% _ -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
      <% end %>
    </svg>
    """
  end

  @doc """
  JavaScript hooks for charts and visualizations.
  """
  def __hooks__() do
    """
    export const TimelineChart = {
      mounted() {
        this.renderChart();
      },
      
      updated() {
        this.renderChart();
      },
      
      renderChart() {
        const data = JSON.parse(this.el.dataset.queries || '[]');
        // Chart.js or D3.js implementation would go here
        console.log('Rendering timeline with', data.length, 'points');
      }
    };
    
    export const TrendChart = {
      mounted() {
        this.renderTrend();
      },
      
      updated() {
        this.renderTrend();
      },
      
      renderTrend() {
        const values = JSON.parse(this.el.dataset.values || '[]');
        const color = this.el.dataset.color;
        const unit = this.el.dataset.unit;
        // Sparkline chart implementation
        console.log('Rendering trend chart', {values, color, unit});
      }
    };
    """
  end
end
