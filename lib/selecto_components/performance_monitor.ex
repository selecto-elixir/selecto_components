defmodule SelectoComponents.PerformanceMonitor do
  @moduledoc """
  LiveView component for visualizing Selecto query performance metrics.
  
  Provides real-time performance monitoring with:
  - Query execution timeline
  - Performance metrics dashboard
  - Slow query log viewer
  - Cache hit rate visualization
  - Query pattern analysis
  - EXPLAIN plan viewer
  """
  
  use SelectoComponents.Web, :live_component
  
  alias Selecto.Performance.{MetricsCollector, QueryAnalyzer, QueryCache, Optimizer}
  
  @impl true
  def mount(socket) do
    if connected?(socket) do
      # Subscribe to telemetry events
      :telemetry.attach(
        "#{__MODULE__}-#{socket.id}",
        [:selecto, :query, :complete],
        &handle_query_complete/4,
        socket.id
      )
      
      # Start periodic stats refresh
      Process.send_after(self(), :refresh_stats, 1000)
    end
    
    {:ok, socket
      |> assign(initial_assigns())
      |> load_metrics()}
  end
  
  @impl true
  def update(assigns, socket) do
    {:ok, socket
      |> assign(assigns)
      |> load_metrics()}
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <div class="selecto-performance-monitor">
      <div class="performance-header">
        <h2 class="text-xl font-bold">Query Performance Monitor</h2>
        <div class="performance-controls">
          <button phx-click="refresh" phx-target={@myself} class="btn btn-sm">
            <.icon name="hero-arrow-path" class="w-4 h-4" /> Refresh
          </button>
          <button phx-click="clear_cache" phx-target={@myself} class="btn btn-sm">
            <.icon name="hero-trash" class="w-4 h-4" /> Clear Cache
          </button>
          <button phx-click="export_metrics" phx-target={@myself} class="btn btn-sm">
            <.icon name="hero-arrow-down-tray" class="w-4 h-4" /> Export
          </button>
        </div>
      </div>
      
      <div class="performance-dashboard grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 my-4">
        <.metric_card title="Total Queries" value={@stats.total_queries} icon="hero-server-stack" />
        <.metric_card title="Avg Response Time" value="#{Float.round(@stats.avg_execution_time || 0, 2)}ms" icon="hero-clock" />
        <.metric_card title="Cache Hit Rate" value="#{@cache_stats.hit_rate}%" icon="hero-chart-pie" color="green" />
        <.metric_card title="Active Connections" value={@connection_count} icon="hero-link" />
      </div>
      
      <div class="performance-tabs">
        <.tabs>
          <:tab id="timeline" label="Timeline" active={@active_tab == "timeline"} phx-click="set_tab" phx-value-tab="timeline" phx-target={@myself}>
            <.query_timeline queries={@recent_queries} />
          </:tab>
          
          <:tab id="slow_queries" label="Slow Queries" active={@active_tab == "slow_queries"} phx-click="set_tab" phx-value-tab="slow_queries" phx-target={@myself}>
            <.slow_queries_table queries={@slow_queries} threshold={@slow_query_threshold} />
          </:tab>
          
          <:tab id="patterns" label="Query Patterns" active={@active_tab == "patterns"} phx-click="set_tab" phx-value-tab="patterns" phx-target={@myself}>
            <.query_patterns patterns={@query_patterns} />
          </:tab>
          
          <:tab id="cache" label="Cache Analytics" active={@active_tab == "cache"} phx-click="set_tab" phx-value-tab="cache" phx-target={@myself}>
            <.cache_analytics stats={@cache_stats} />
          </:tab>
          
          <:tab id="explain" label="Query Analyzer" active={@active_tab == "explain"} phx-click="set_tab" phx-value-tab="explain" phx-target={@myself}>
            <.query_analyzer selected_query={@selected_query} analysis={@query_analysis} />
          </:tab>
        </.tabs>
      </div>
      
      <%= if @show_optimization_modal do %>
        <.optimization_modal query={@optimization_query} suggestions={@optimization_suggestions} />
      <% end %>
    </div>
    """
  end
  
  # Component Parts
  
  attr :title, :string, required: true
  attr :value, :any, required: true
  attr :icon, :string, required: true
  attr :color, :string, default: "blue"
  
  defp metric_card(assigns) do
    ~H"""
    <div class="metric-card bg-white rounded-lg shadow p-4">
      <div class="flex items-center justify-between">
        <div>
          <p class="text-sm text-gray-600"><%= @title %></p>
          <p class="text-2xl font-bold text-gray-900"><%= @value %></p>
        </div>
        <div class={"p-3 rounded-full bg-#{@color}-100"}>
          <.icon name={@icon} class={"w-6 h-6 text-#{@color}-600"} />
        </div>
      </div>
    </div>
    """
  end
  
  attr :queries, :list, required: true
  
  defp query_timeline(assigns) do
    ~H"""
    <div class="query-timeline">
      <div class="timeline-header flex justify-between items-center mb-4">
        <h3 class="text-lg font-semibold">Recent Query Execution</h3>
        <select phx-change="set_timeline_range" phx-target={@myself} class="form-select">
          <option value="1m">Last 1 minute</option>
          <option value="5m" selected>Last 5 minutes</option>
          <option value="15m">Last 15 minutes</option>
          <option value="1h">Last 1 hour</option>
        </select>
      </div>
      
      <div class="timeline-chart" phx-hook="QueryTimeline" id="query-timeline-chart">
        <canvas id="timeline-canvas" class="w-full h-64"></canvas>
      </div>
      
      <div class="timeline-legend flex gap-4 mt-4">
        <span class="flex items-center gap-1">
          <span class="w-3 h-3 bg-green-500 rounded"></span> Fast (&lt;50ms)
        </span>
        <span class="flex items-center gap-1">
          <span class="w-3 h-3 bg-yellow-500 rounded"></span> Normal (50-200ms)
        </span>
        <span class="flex items-center gap-1">
          <span class="w-3 h-3 bg-red-500 rounded"></span> Slow (&gt;200ms)
        </span>
      </div>
    </div>
    """
  end
  
  attr :queries, :list, required: true
  attr :threshold, :integer, required: true
  
  defp slow_queries_table(assigns) do
    ~H"""
    <div class="slow-queries">
      <div class="table-header flex justify-between items-center mb-4">
        <h3 class="text-lg font-semibold">Slow Queries (>&gt;<%= @threshold %>ms)</h3>
        <input type="range" min="50" max="1000" step="50" value={@threshold}
               phx-change="set_slow_threshold" phx-target={@myself}
               class="w-32" />
      </div>
      
      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Time
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Duration
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Query
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Rows
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Actions
              </th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <%= for {query_id, query} <- @queries do %>
              <tr>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  <%= format_timestamp(query.started_at) %>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <span class={"inline-flex px-2 py-1 text-xs font-semibold rounded-full #{duration_color(query.execution_time)}"}>
                    <%= query.execution_time %>ms
                  </span>
                </td>
                <td class="px-6 py-4 text-sm text-gray-900">
                  <code class="text-xs truncate block max-w-md" title={query.query_info[:sql]}>
                    <%= truncate_sql(query.query_info[:sql]) %>
                  </code>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  <%= query.row_count || "-" %>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                  <button phx-click="analyze_query" phx-value-id={query_id} phx-target={@myself}
                          class="text-indigo-600 hover:text-indigo-900 mr-2">
                    Analyze
                  </button>
                  <button phx-click="optimize_query" phx-value-id={query_id} phx-target={@myself}
                          class="text-green-600 hover:text-green-900">
                    Optimize
                  </button>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end
  
  attr :patterns, :list, required: true
  
  defp query_patterns(assigns) do
    ~H"""
    <div class="query-patterns">
      <h3 class="text-lg font-semibold mb-4">Common Query Patterns</h3>
      
      <div class="patterns-grid grid grid-cols-1 md:grid-cols-2 gap-4">
        <%= for pattern <- @patterns do %>
          <div class="pattern-card bg-white rounded-lg border p-4">
            <div class="pattern-header flex justify-between items-start mb-2">
              <h4 class="font-medium">Pattern #<%= pattern_id(pattern) %></h4>
              <span class="text-sm text-gray-500"><%= pattern.count %> queries</span>
            </div>
            
            <div class="pattern-details space-y-2">
              <div class="flex justify-between">
                <span class="text-sm text-gray-600">Avg Time:</span>
                <span class="text-sm font-medium"><%= Float.round(pattern.avg_execution_time, 2) %>ms</span>
              </div>
              <div class="flex justify-between">
                <span class="text-sm text-gray-600">Total Time:</span>
                <span class="text-sm font-medium"><%= Float.round(pattern.total_time, 2) %>ms</span>
              </div>
              
              <div class="pattern-structure mt-2 pt-2 border-t">
                <p class="text-xs text-gray-500">
                  SELECT: <%= pattern.pattern.select_count %> fields,
                  FILTER: <%= pattern.pattern.filter_count %>,
                  JOIN: <%= pattern.pattern.join_count %>,
                  GROUP: <%= pattern.pattern.group_count %>
                  <%= if pattern.pattern.has_cte, do: ", CTE" %>
                  <%= if pattern.pattern.has_subquery, do: ", SUBQUERY" %>
                </p>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
  
  attr :stats, :map, required: true
  
  defp cache_analytics(assigns) do
    ~H"""
    <div class="cache-analytics">
      <div class="cache-overview grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
        <div class="cache-stat">
          <h4 class="text-sm font-medium text-gray-600">Cache Size</h4>
          <p class="text-2xl font-bold"><%= @stats.cache_size %> / <%= @stats.max_size %></p>
          <div class="w-full bg-gray-200 rounded-full h-2 mt-2">
            <div class="bg-blue-600 h-2 rounded-full" style={"width: #{cache_usage_percent(@stats)}%"}></div>
          </div>
        </div>
        
        <div class="cache-stat">
          <h4 class="text-sm font-medium text-gray-600">Hit Rate</h4>
          <p class="text-2xl font-bold"><%= @stats.hit_rate %>%</p>
          <p class="text-xs text-gray-500 mt-1">
            <%= @stats.hits %> hits / <%= @stats.misses %> misses
          </p>
        </div>
        
        <div class="cache-stat">
          <h4 class="text-sm font-medium text-gray-600">Memory Usage</h4>
          <p class="text-2xl font-bold"><%= format_bytes(@stats.memory_usage) %></p>
          <p class="text-xs text-gray-500 mt-1">
            Avg: <%= format_bytes(@stats.avg_entry_size) %> per entry
          </p>
        </div>
      </div>
      
      <div class="cache-chart" phx-hook="CacheHitRateChart" id="cache-hit-rate-chart">
        <canvas id="cache-chart-canvas" class="w-full h-48"></canvas>
      </div>
      
      <div class="cache-actions mt-4 flex gap-2">
        <button phx-click="warm_cache" phx-target={@myself} class="btn btn-sm">
          <.icon name="hero-fire" class="w-4 h-4" /> Warm Cache
        </button>
        <button phx-click="invalidate_cache" phx-target={@myself} class="btn btn-sm">
          <.icon name="hero-x-mark" class="w-4 h-4" /> Invalidate Stale
        </button>
      </div>
    </div>
    """
  end
  
  attr :selected_query, :map, default: nil
  attr :analysis, :map, default: nil
  
  defp query_analyzer(assigns) do
    ~H"""
    <div class="query-analyzer">
      <div class="analyzer-input mb-4">
        <label class="block text-sm font-medium text-gray-700 mb-2">
          Paste SQL or select from recent queries
        </label>
        <textarea 
          phx-blur="analyze_sql" 
          phx-target={@myself}
          class="w-full h-32 p-2 border rounded-md font-mono text-sm"
          placeholder="SELECT * FROM ..."
        ><%= @selected_query && @selected_query.sql %></textarea>
      </div>
      
      <%= if @analysis do %>
        <div class="analysis-results">
          <div class="analysis-summary bg-gray-50 rounded-lg p-4 mb-4">
            <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
              <div>
                <p class="text-xs text-gray-600">Execution Time</p>
                <p class="font-semibold"><%= @analysis.execution_time %>ms</p>
              </div>
              <div>
                <p class="text-xs text-gray-600">Planning Time</p>
                <p class="font-semibold"><%= @analysis.planning_time %>ms</p>
              </div>
              <div>
                <p class="text-xs text-gray-600">Total Cost</p>
                <p class="font-semibold"><%= @analysis.total_cost %></p>
              </div>
              <div>
                <p class="text-xs text-gray-600">Rows</p>
                <p class="font-semibold"><%= @analysis.actual_rows %></p>
              </div>
            </div>
          </div>
          
          <%= if @analysis.suggestions != [] do %>
            <div class="suggestions bg-yellow-50 border-l-4 border-yellow-400 p-4 mb-4">
              <h4 class="font-semibold text-yellow-800 mb-2">Optimization Suggestions</h4>
              <ul class="list-disc list-inside space-y-1">
                <%= for suggestion <- @analysis.suggestions do %>
                  <li class="text-sm text-yellow-700"><%= suggestion %></li>
                <% end %>
              </ul>
            </div>
          <% end %>
          
          <div class="explain-plan">
            <h4 class="font-semibold mb-2">Execution Plan</h4>
            <pre class="bg-gray-900 text-gray-100 p-4 rounded-lg overflow-x-auto text-xs">
              <%= format_explain_plan(@analysis.plan) %>
            </pre>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
  
  # Event Handlers
  
  @impl true
  def handle_event("refresh", _params, socket) do
    {:noreply, load_metrics(socket)}
  end
  
  @impl true
  def handle_event("clear_cache", _params, socket) do
    QueryCache.clear()
    {:noreply, socket |> put_flash(:info, "Cache cleared") |> load_metrics()}
  end
  
  @impl true
  def handle_event("export_metrics", _params, socket) do
    {:ok, csv_data} = MetricsCollector.export_metrics(:csv)
    
    {:noreply, socket
      |> push_event("download", %{
        data: csv_data,
        filename: "query_metrics_#{Date.utc_today()}.csv",
        mime_type: "text/csv"
      })}
  end
  
  @impl true
  def handle_event("set_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, active_tab: tab)}
  end
  
  @impl true
  def handle_event("set_timeline_range", %{"value" => range}, socket) do
    {:noreply, socket
      |> assign(timeline_range: range)
      |> load_recent_queries()}
  end
  
  @impl true
  def handle_event("set_slow_threshold", %{"value" => threshold}, socket) do
    threshold = String.to_integer(threshold)
    {:noreply, socket
      |> assign(slow_query_threshold: threshold)
      |> load_slow_queries()}
  end
  
  @impl true
  def handle_event("analyze_query", %{"id" => query_id}, socket) do
    case MetricsCollector.get_query_metrics(query_id) do
      {:ok, query} ->
        # Run EXPLAIN ANALYZE on the query
        {:ok, analysis} = analyze_stored_query(query)
        
        {:noreply, socket
          |> assign(selected_query: query, query_analysis: analysis)
          |> assign(active_tab: "explain")}
      
      _ ->
        {:noreply, socket}
    end
  end
  
  @impl true
  def handle_event("optimize_query", %{"id" => query_id}, socket) do
    case MetricsCollector.get_query_metrics(query_id) do
      {:ok, query} ->
        # Get optimization suggestions
        {:ok, suggestions} = get_optimization_suggestions(query)
        
        {:noreply, socket
          |> assign(optimization_query: query, optimization_suggestions: suggestions)
          |> assign(show_optimization_modal: true)}
      
      _ ->
        {:noreply, socket}
    end
  end
  
  @impl true
  def handle_info(:refresh_stats, socket) do
    if connected?(socket) do
      Process.send_after(self(), :refresh_stats, 5000)
      {:noreply, load_metrics(socket)}
    else
      {:noreply, socket}
    end
  end
  
  # Private Functions
  
  defp initial_assigns do
    %{
      stats: %{total_queries: 0, avg_execution_time: 0},
      cache_stats: %{hit_rate: 0, hits: 0, misses: 0, cache_size: 0, max_size: 1000},
      recent_queries: [],
      slow_queries: [],
      query_patterns: [],
      connection_count: 0,
      active_tab: "timeline",
      timeline_range: "5m",
      slow_query_threshold: 100,
      selected_query: nil,
      query_analysis: nil,
      optimization_query: nil,
      optimization_suggestions: [],
      show_optimization_modal: false
    }
  end
  
  defp load_metrics(socket) do
    socket
    |> load_stats()
    |> load_cache_stats()
    |> load_recent_queries()
    |> load_slow_queries()
    |> load_query_patterns()
  end
  
  defp load_stats(socket) do
    stats = MetricsCollector.get_stats()
    assign(socket, stats: stats)
  end
  
  defp load_cache_stats(socket) do
    cache_stats = QueryCache.stats()
    assign(socket, cache_stats: cache_stats)
  end
  
  defp load_recent_queries(socket) do
    range = parse_time_range(socket.assigns.timeline_range)
    queries = MetricsCollector.get_stats(time_range: {:last, range, :milliseconds})
    assign(socket, recent_queries: queries)
  end
  
  defp load_slow_queries(socket) do
    slow_queries = MetricsCollector.get_slow_queries(
      threshold: socket.assigns.slow_query_threshold,
      limit: 20
    )
    assign(socket, slow_queries: slow_queries)
  end
  
  defp load_query_patterns(socket) do
    patterns = MetricsCollector.get_query_patterns(limit: 10)
    assign(socket, query_patterns: patterns)
  end
  
  defp parse_time_range("1m"), do: 60_000
  defp parse_time_range("5m"), do: 300_000
  defp parse_time_range("15m"), do: 900_000
  defp parse_time_range("1h"), do: 3_600_000
  defp parse_time_range(_), do: 300_000
  
  defp format_timestamp(timestamp) do
    # Format timestamp for display
    DateTime.from_unix!(timestamp, :millisecond)
    |> Calendar.strftime("%H:%M:%S")
  end
  
  defp truncate_sql(sql) when is_binary(sql) do
    String.slice(sql, 0, 100) <> if(String.length(sql) > 100, do: "...", else: "")
  end
  defp truncate_sql(_), do: ""
  
  defp duration_color(duration) when duration < 50, do: "bg-green-100 text-green-800"
  defp duration_color(duration) when duration < 200, do: "bg-yellow-100 text-yellow-800"
  defp duration_color(_), do: "bg-red-100 text-red-800"
  
  defp pattern_id(pattern) do
    :erlang.phash2(pattern.pattern, 1000)
  end
  
  defp cache_usage_percent(%{cache_size: size, max_size: max}) when max > 0 do
    Float.round(size / max * 100, 1)
  end
  defp cache_usage_percent(_), do: 0
  
  defp format_bytes(bytes) when is_number(bytes) do
    cond do
      bytes < 1024 -> "#{bytes} B"
      bytes < 1024 * 1024 -> "#{Float.round(bytes / 1024, 1)} KB"
      bytes < 1024 * 1024 * 1024 -> "#{Float.round(bytes / (1024 * 1024), 1)} MB"
      true -> "#{Float.round(bytes / (1024 * 1024 * 1024), 1)} GB"
    end
  end
  defp format_bytes(_), do: "0 B"
  
  defp format_explain_plan(plan) when is_map(plan) do
    Jason.encode!(plan, pretty: true)
  end
  defp format_explain_plan(plan), do: inspect(plan, pretty: true)
  
  defp analyze_stored_query(query) do
    # Reconstruct selecto from stored query info
    # This is simplified - real implementation would need to store more context
    {:ok, %{
      execution_time: query.execution_time,
      planning_time: 0,
      total_cost: 0,
      actual_rows: query.row_count || 0,
      suggestions: [],
      plan: %{}
    }}
  end
  
  defp get_optimization_suggestions(query) do
    # Get suggestions based on query metrics
    suggestions = []
    
    suggestions = if query.execution_time > 500 do
      ["Query is very slow - consider adding indexes" | suggestions]
    else
      suggestions
    end
    
    {:ok, suggestions}
  end
  
  defp handle_query_complete(_event_name, measurements, metadata, socket_id) do
    # Handle telemetry events
    # This would update the live metrics in real-time
    send_update(__MODULE__, id: socket_id, action: :query_completed, measurements: measurements)
  end
end