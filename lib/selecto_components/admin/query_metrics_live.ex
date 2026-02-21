defmodule SelectoComponents.Admin.QueryMetricsLive do
  @moduledoc """
  Real-time dashboard for query performance monitoring.

  Displays:
  - Circuit breaker status
  - Query timeout rates and counts
  - Slow query statistics
  - Connection pool utilization
  - Recent performance trends

  ## Usage

  Create a wrapper module in your app:

      defmodule MyAppWeb.Admin.QueryMetricsLive do
        use Phoenix.LiveView

        @repo MyApp.Repo
        @monitor MyApp.QueryTimeoutMonitor

        def mount(params, session, socket) do
          SelectoComponents.Admin.QueryMetricsLive.mount(
            params,
            session,
            socket,
            repo: @repo,
            monitor: @monitor
          )
        end

        def handle_info(msg, socket) do
          SelectoComponents.Admin.QueryMetricsLive.handle_info(msg, socket)
        end

        def render(assigns) do
          SelectoComponents.Admin.QueryMetricsLive.render(assigns)
        end
      end
  """

  use Phoenix.Component

  # Refresh every 5 seconds
  @refresh_interval 5_000

  def mount(_params, _session, socket, opts) do
    repo = Keyword.fetch!(opts, :repo)
    monitor = Keyword.fetch!(opts, :monitor)

    if Phoenix.LiveView.connected?(socket) do
      :timer.send_interval(@refresh_interval, self(), :update_metrics)
    end

    socket =
      socket
      |> assign(:page_title, "Query Performance Metrics")
      |> assign(:repo, repo)
      |> assign(:monitor, monitor)
      |> assign_metrics()

    {:ok, socket}
  end

  def handle_info(:update_metrics, socket) do
    {:noreply, assign_metrics(socket)}
  end

  defp assign_metrics(socket) do
    stats =
      try do
        Selecto.Performance.MetricsCollector.get_stats()
      rescue
        _ -> %{}
      end

    assign(socket, %{
      stats: stats,
      circuit_state: Map.get(stats, :circuit_state, :closed),
      circuit_state_class: circuit_state_class(Map.get(stats, :circuit_state, :closed)),
      total_queries: Map.get(stats, :total_queries, 0),
      timeout_count: Map.get(stats, :timeout_queries, 0),
      timeout_rate: Map.get(stats, :timeout_rate, 0.0),
      slow_query_count: Map.get(stats, :slow_queries, 0),
      slow_query_rate: Map.get(stats, :slow_query_rate, 0.0),
      very_slow_count: Map.get(stats, :very_slow_queries, 0),
      pool_size: Map.get(stats, :pool_size, 0),
      pool_available: Map.get(stats, :pool_available, 0),
      pool_utilization: Map.get(stats, :pool_utilization, 0.0),
      pool_saturation_events: Map.get(stats, :pool_saturation_events, 0),
      health_status: determine_health_status(stats),
      last_updated: DateTime.utc_now()
    })
  end

  defp circuit_state_class(:closed), do: "success"
  defp circuit_state_class(:half_open), do: "warning"
  defp circuit_state_class(:open), do: "error"
  defp circuit_state_class(_), do: "info"

  defp determine_health_status(stats) do
    cond do
      stats[:circuit_state] == :open -> :critical
      stats[:timeout_rate] > 10.0 -> :degraded
      stats[:pool_utilization] > 80.0 -> :warning
      stats[:slow_query_rate] > 20.0 -> :warning
      true -> :healthy
    end
  end

  defp health_message(:healthy), do: "All systems operational"
  defp health_message(:warning), do: "Performance degraded - monitor closely"
  defp health_message(:degraded), do: "High timeout rate - investigate queries"
  defp health_message(:critical), do: "Circuit breaker open - system protecting database"

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <!-- Header -->
      <div class="flex justify-between items-center mb-8">
        <div>
          <h1 class="text-3xl font-bold">Query Performance Metrics</h1>
          <p class="text-base-content/60 mt-1">
            Real-time database query monitoring and circuit breaker status
          </p>
        </div>
        <div class="text-right">
          <div class="text-sm text-base-content/60">Last updated</div>
          <div class="text-sm font-mono">
            {Calendar.strftime(@last_updated, "%H:%M:%S")}
          </div>
          <div class="text-xs text-base-content/40 mt-1">
            Auto-refresh every {div(@refresh_interval, 1000)}s
          </div>
        </div>
      </div>
      
    <!-- Overall Health Status -->
      <div class={"alert mb-6 shadow-lg " <> health_status_alert_class(@health_status)}>
        <div class="flex items-center gap-3">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
            class="stroke-current shrink-0 w-8 h-8"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d={health_status_icon_path(@health_status)}
            />
          </svg>
          <div>
            <h3 class="font-bold text-lg">
              System Health: {health_status_text(@health_status)}
            </h3>
            <div class="text-sm">{health_message(@health_status)}</div>
          </div>
        </div>
      </div>
      
    <!-- Circuit Breaker Status -->
      <div class="card bg-base-100 shadow-xl mb-6">
        <div class="card-body">
          <h2 class="card-title">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="1.5"
              stroke="currentColor"
              class="w-6 h-6"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M9.348 14.651a3.75 3.75 0 010-5.303m5.304 0a3.75 3.75 0 010 5.303m-7.425 2.122a6.75 6.75 0 010-9.546m9.546 0a6.75 6.75 0 010 9.546M5.106 18.894c-3.808-3.808-3.808-9.98 0-13.789m13.788 0c3.808 3.808 3.808 9.98 0 13.789"
              />
            </svg>
            Circuit Breaker Status
          </h2>

          <div class="flex items-center gap-4 mt-4">
            <div class={"badge badge-lg " <> circuit_badge_class(@circuit_state)}>
              {String.upcase(to_string(@circuit_state))}
            </div>

            <div class="text-sm text-base-content/70">
              {circuit_state_description(@circuit_state)}
            </div>
          </div>

          <div class="mt-4 text-sm text-base-content/60">
            <strong>Pool Saturation Events:</strong>
            {@pool_saturation_events}
            <span class="ml-2 text-xs">(Times circuit opened due to high utilization)</span>
          </div>
        </div>
      </div>
      
    <!-- Stats Grid -->
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
        <!-- Total Queries -->
        <div class="stat bg-base-100 shadow rounded-lg">
          <div class="stat-figure text-primary">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              class="inline-block w-8 h-8 stroke-current"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4"
              />
            </svg>
          </div>
          <div class="stat-title">Total Queries</div>
          <div class="stat-value text-primary">{@total_queries}</div>
          <div class="stat-desc">Since application start</div>
        </div>
        
    <!-- Timeout Rate -->
        <div class="stat bg-base-100 shadow rounded-lg">
          <div class="stat-figure text-error">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              class="inline-block w-8 h-8 stroke-current"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
              />
            </svg>
          </div>
          <div class="stat-title">Timeout Rate</div>
          <div class="stat-value text-error">{Float.round(@timeout_rate, 2)}%</div>
          <div class="stat-desc">{@timeout_count} timeouts total</div>
        </div>
        
    <!-- Slow Queries -->
        <div class="stat bg-base-100 shadow rounded-lg">
          <div class="stat-figure text-warning">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              class="inline-block w-8 h-8 stroke-current"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z"
              />
            </svg>
          </div>
          <div class="stat-title">Slow Query Rate</div>
          <div class="stat-value text-warning">{Float.round(@slow_query_rate, 2)}%</div>
          <div class="stat-desc">
            {@slow_query_count} slow ({@very_slow_count} very slow)
          </div>
        </div>
        
    <!-- Pool Utilization -->
        <div class="stat bg-base-100 shadow rounded-lg">
          <div class="stat-figure text-info">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              class="inline-block w-8 h-8 stroke-current"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M13 10V3L4 14h7v7l9-11h-7z"
              />
            </svg>
          </div>
          <div class="stat-title">Pool Utilization</div>
          <div class="stat-value text-info">{@pool_utilization}%</div>
          <div class="stat-desc">{@pool_available}/{@pool_size} available</div>
        </div>
      </div>
      
    <!-- Connection Pool Details -->
      <div class="card bg-base-100 shadow-xl mb-6">
        <div class="card-body">
          <h2 class="card-title">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="1.5"
              stroke="currentColor"
              class="w-6 h-6"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M5.25 8.25h15m-16.5 7.5h15m-1.8-13.5l-3.9 19.5m-2.1-19.5l-3.9 19.5"
              />
            </svg>
            Connection Pool Status
          </h2>

          <div class="mt-4">
            <div class="flex justify-between text-sm mb-2">
              <span>Pool Utilization</span>
              <span class="font-mono">{@pool_utilization}%</span>
            </div>
            <progress
              class={"progress " <> pool_progress_class(@pool_utilization)}
              value={@pool_utilization}
              max="100"
            >
            </progress>
          </div>

          <div class="grid grid-cols-3 gap-4 mt-4 text-sm">
            <div>
              <div class="text-base-content/60">Total Connections</div>
              <div class="text-2xl font-bold">{@pool_size}</div>
            </div>
            <div>
              <div class="text-base-content/60">Available</div>
              <div class="text-2xl font-bold text-success">{@pool_available}</div>
            </div>
            <div>
              <div class="text-base-content/60">In Use</div>
              <div class="text-2xl font-bold text-warning">{@pool_size - @pool_available}</div>
            </div>
          </div>
        </div>
      </div>
      
    <!-- Recommendations -->
      <%= if @health_status != :healthy do %>
        <div class="card bg-base-200 shadow-xl">
          <div class="card-body">
            <h2 class="card-title">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                fill="none"
                viewBox="0 0 24 24"
                stroke-width="1.5"
                stroke="currentColor"
                class="w-6 h-6"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M12 18v-5.25m0 0a6.01 6.01 0 001.5-.189m-1.5.189a6.01 6.01 0 01-1.5-.189m3.75 7.478a12.06 12.06 0 01-4.5 0m3.75 2.383a14.406 14.406 0 01-3 0M14.25 18v-.192c0-.983.658-1.823 1.508-2.316a7.5 7.5 0 10-7.517 0c.85.493 1.509 1.333 1.509 2.316V18"
                />
              </svg>
              Recommendations
            </h2>

            <ul class="list-disc list-inside space-y-2 text-sm mt-4">
              <%= if @circuit_state == :open do %>
                <li>Circuit breaker is open - new queries are being blocked</li>
                <li>Check for slow or stuck queries in the database</li>
                <li>Consider scaling connection pool or database resources</li>
              <% end %>

              <%= if @timeout_rate > 10.0 do %>
                <li>
                  High timeout rate ({Float.round(@timeout_rate, 1)}%) - investigate slow queries
                </li>
                <li>Review query complexity and add appropriate indexes</li>
                <li>Consider implementing query result caching</li>
              <% end %>

              <%= if @pool_utilization > 80.0 do %>
                <li>Pool utilization is high - consider increasing pool size</li>
                <li>Current pool size: {@pool_size} connections</li>
                <li>
                  Monitor for connection leaks or queries holding connections too long
                </li>
              <% end %>

              <%= if @slow_query_rate > 20.0 do %>
                <li>
                  Many slow queries ({Float.round(@slow_query_rate, 1)}%) - review query patterns
                </li>
                <li>Check logs for specific slow query examples</li>
                <li>Consider query optimization or data denormalization</li>
              <% end %>
            </ul>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Helper functions for CSS classes

  defp health_status_alert_class(:healthy), do: "alert-success"
  defp health_status_alert_class(:warning), do: "alert-warning"
  defp health_status_alert_class(:degraded), do: "alert-warning"
  defp health_status_alert_class(:critical), do: "alert-error"

  defp health_status_text(:healthy), do: "Healthy"
  defp health_status_text(:warning), do: "Warning"
  defp health_status_text(:degraded), do: "Degraded"
  defp health_status_text(:critical), do: "Critical"

  defp health_status_icon_path(:healthy),
    do: "M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"

  defp health_status_icon_path(:warning),
    do:
      "M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"

  defp health_status_icon_path(:degraded),
    do:
      "M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"

  defp health_status_icon_path(:critical),
    do: "M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z"

  defp circuit_badge_class(:closed), do: "badge-success"
  defp circuit_badge_class(:half_open), do: "badge-warning"
  defp circuit_badge_class(:open), do: "badge-error"

  defp circuit_state_description(:closed),
    do: "Normal operation - all queries allowed"

  defp circuit_state_description(:half_open),
    do: "Testing recovery - allowing limited queries"

  defp circuit_state_description(:open),
    do: "System overload - queries blocked to protect database"

  defp pool_progress_class(utilization) when utilization >= 90, do: "progress-error"
  defp pool_progress_class(utilization) when utilization >= 70, do: "progress-warning"
  defp pool_progress_class(_), do: "progress-success"
end
