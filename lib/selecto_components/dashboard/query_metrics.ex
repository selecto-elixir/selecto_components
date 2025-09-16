defmodule SelectoComponents.Dashboard.QueryMetrics do
  @moduledoc """
  LiveComponent for displaying Selecto query performance metrics.
  """

  use Phoenix.LiveComponent
  alias SelectoComponents.Performance.MetricsCollector

  @impl true
  def mount(socket) do
    {:ok, assign(socket, time_range: "1h")}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> fetch_and_assign_metrics()

    if connected?(socket) && !Map.get(socket.assigns, :timer_ref) do
      timer_ref = Process.send_after(self(), {:refresh_metrics, socket.assigns.id}, 2000)
      {:ok, assign(socket, timer_ref: timer_ref)}
    else
      {:ok, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="selecto-query-metrics p-4 bg-white rounded-lg shadow">
      <div class="flex justify-between items-center mb-6">
        <h2 class="text-2xl font-bold text-gray-900">Query Performance Metrics</h2>
        <div class="flex gap-2">
          <select phx-change="change_time_range" phx-target={@myself} name="range"
                  class="px-3 py-1 border border-gray-300 rounded-md text-sm">
            <option value="5m" selected={@time_range == "5m"}>Last 5 min</option>
            <option value="15m" selected={@time_range == "15m"}>Last 15 min</option>
            <option value="1h" selected={@time_range == "1h"}>Last hour</option>
            <option value="24h" selected={@time_range == "24h"}>Last 24 hours</option>
          </select>
          <button phx-click="clear_metrics" phx-target={@myself}
                  class="px-3 py-1 bg-red-500 hover:bg-red-600 text-white rounded-md text-sm">
            Clear
          </button>
        </div>
      </div>

      <!-- Summary Cards -->
      <div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
        <div class="bg-blue-50 p-4 rounded-lg">
          <div class="text-sm text-blue-600 font-medium">Total Queries</div>
          <div class="text-2xl font-bold text-blue-900"><%= @metrics.total_queries %></div>
        </div>

        <div class="bg-green-50 p-4 rounded-lg">
          <div class="text-sm text-green-600 font-medium">Avg Response</div>
          <div class="text-2xl font-bold text-green-900"><%= format_duration(@metrics.avg_execution_time) %></div>
        </div>

        <div class="bg-purple-50 p-4 rounded-lg">
          <div class="text-sm text-purple-600 font-medium">Cache Hit Rate</div>
          <div class="text-2xl font-bold text-purple-900"><%= format_percentage(@metrics.cache_hit_rate) %></div>
        </div>

        <div class={"#{error_bg_class(@metrics.error_rate)} p-4 rounded-lg"}>
          <div class={"text-sm #{error_text_class(@metrics.error_rate)} font-medium"}>Error Rate</div>
          <div class={"text-2xl font-bold #{error_text_class(@metrics.error_rate)}"}>
            <%= format_percentage(@metrics.error_rate) %>
          </div>
        </div>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
        <!-- Query Distribution -->
        <div class="border border-gray-200 rounded-lg p-4">
          <h3 class="font-semibold text-gray-900 mb-3">Query Distribution</h3>
          <table class="w-full text-sm">
            <thead class="text-xs text-gray-700 uppercase bg-gray-50">
              <tr>
                <th class="px-3 py-2 text-left">View Mode</th>
                <th class="px-3 py-2 text-right">Count</th>
                <th class="px-3 py-2 text-right">Avg Time</th>
              </tr>
            </thead>
            <tbody>
              <%= for {mode, stats} <- @metrics.by_view_mode do %>
                <tr class="border-b">
                  <td class="px-3 py-2"><%= mode %></td>
                  <td class="px-3 py-2 text-right"><%= stats.count %></td>
                  <td class="px-3 py-2 text-right">
                    <span class={"px-2 py-1 text-xs rounded #{time_badge_class(stats.avg_time)}"}>
                      <%= format_duration(stats.avg_time) %>
                    </span>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>

        <!-- Performance Stats -->
        <div class="border border-gray-200 rounded-lg p-4">
          <h3 class="font-semibold text-gray-900 mb-3">Performance Stats</h3>
          <div class="space-y-2">
            <div class="flex justify-between">
              <span class="text-sm text-gray-600">P50 (Median)</span>
              <span class="text-sm font-mono"><%= format_duration(@metrics.p50) %></span>
            </div>
            <div class="flex justify-between">
              <span class="text-sm text-gray-600">P95</span>
              <span class="text-sm font-mono"><%= format_duration(@metrics.p95) %></span>
            </div>
            <div class="flex justify-between">
              <span class="text-sm text-gray-600">P99</span>
              <span class="text-sm font-mono"><%= format_duration(@metrics.p99) %></span>
            </div>
            <div class="flex justify-between">
              <span class="text-sm text-gray-600">Max</span>
              <span class="text-sm font-mono font-semibold"><%= format_duration(@metrics.max_time) %></span>
            </div>
          </div>
        </div>
      </div>

      <!-- Slow Queries -->
      <div class="border border-gray-200 rounded-lg p-4">
        <h3 class="font-semibold text-gray-900 mb-3">Slowest Queries</h3>
        <%= if @slow_queries == [] do %>
          <p class="text-sm text-gray-500 italic">No slow queries detected</p>
        <% else %>
          <div class="overflow-x-auto">
            <table class="w-full text-sm">
              <thead class="text-xs text-gray-700 uppercase bg-gray-50">
                <tr>
                  <th class="px-3 py-2 text-left">Query</th>
                  <th class="px-3 py-2 text-right">Time</th>
                  <th class="px-3 py-2 text-right">Rows</th>
                  <th class="px-3 py-2 text-left">View</th>
                  <th class="px-3 py-2 text-right">When</th>
                </tr>
              </thead>
              <tbody>
                <%= for query <- @slow_queries do %>
                  <tr class="border-b hover:bg-gray-50">
                    <td class="px-3 py-2 max-w-md">
                      <div class="font-mono text-xs truncate" title={query.query}>
                        <%= truncate_query(query.query) %>
                      </div>
                    </td>
                    <td class="px-3 py-2 text-right">
                      <span class={"px-2 py-1 text-xs rounded #{time_badge_class(query.execution_time)}"}>
                        <%= format_duration(query.execution_time) %>
                      </span>
                    </td>
                    <td class="px-3 py-2 text-right">
                      <%= Map.get(query.opts || %{}, :rows_returned, "-") %>
                    </td>
                    <td class="px-3 py-2">
                      <%= Map.get(query.opts || %{}, :view_mode, "-") %>
                    </td>
                    <td class="px-3 py-2 text-right text-xs text-gray-500">
                      <%= format_timestamp(query.timestamp) %>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("change_time_range", %{"range" => range}, socket) do
    socket = socket
    |> assign(:time_range, range)
    |> fetch_and_assign_metrics()
    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_metrics", _params, socket) do
    MetricsCollector.clear_metrics()
    socket = fetch_and_assign_metrics(socket)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:refresh_metrics, id}, socket) when socket.assigns.id == id do
    socket = fetch_and_assign_metrics(socket)
    timer_ref = Process.send_after(self(), {:refresh_metrics, id}, 2000)
    {:noreply, assign(socket, timer_ref: timer_ref)}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  # Private functions
  defp fetch_and_assign_metrics(socket) do
    time_range = socket.assigns[:time_range] || "1h"
    metrics = MetricsCollector.get_metrics(time_range)
    slow_queries = MetricsCollector.get_slow_queries(500, 10)

    socket
    |> assign(:metrics, metrics || default_metrics())
    |> assign(:slow_queries, slow_queries || [])
  end

  defp default_metrics do
    %{
      total_queries: 0,
      avg_execution_time: 0,
      cache_hit_rate: 0,
      error_rate: 0,
      by_view_mode: %{},
      p50: 0,
      p95: 0,
      p99: 0,
      max_time: 0
    }
  end

  defp format_duration(nil), do: "-"
  defp format_duration(ms) when ms < 1, do: "< 1ms"
  defp format_duration(ms) when ms < 1000, do: "#{round(ms)}ms"
  defp format_duration(ms), do: "#{Float.round(ms / 1000, 2)}s"

  defp format_percentage(nil), do: "0%"
  defp format_percentage(rate), do: "#{Float.round(rate * 100, 1)}%"

  defp format_timestamp(nil), do: "-"
  defp format_timestamp(timestamp) do
    case DateTime.from_unix(timestamp, :millisecond) do
      {:ok, dt} -> Calendar.strftime(dt, "%H:%M:%S")
      _ -> "-"
    end
  end

  defp truncate_query(query) when is_binary(query) do
    if String.length(query) > 80 do
      String.slice(query, 0, 80) <> "..."
    else
      query
    end
  end
  defp truncate_query(_), do: "-"

  defp error_bg_class(nil), do: "bg-gray-50"
  defp error_bg_class(rate) when rate > 0.1, do: "bg-red-50"
  defp error_bg_class(rate) when rate > 0.05, do: "bg-yellow-50"
  defp error_bg_class(_), do: "bg-gray-50"

  defp error_text_class(nil), do: "text-gray-600"
  defp error_text_class(rate) when rate > 0.1, do: "text-red-600"
  defp error_text_class(rate) when rate > 0.05, do: "text-yellow-600"
  defp error_text_class(_), do: "text-gray-600"

  defp time_badge_class(ms) when is_number(ms) and ms > 1000, do: "bg-red-100 text-red-800"
  defp time_badge_class(ms) when is_number(ms) and ms > 500, do: "bg-yellow-100 text-yellow-800"
  defp time_badge_class(_), do: "bg-green-100 text-green-800"
end