defmodule SelectoComponents.CTE.Analyzer do
  @moduledoc """
  Analyzes CTE performance and provides optimization suggestions.
  """

  use Phoenix.Component
  import Phoenix.LiveView

  @doc """
  Displays CTE performance analysis and optimization suggestions.
  """
  def cte_analysis(assigns) do
    assigns = assign_defaults(assigns)
    
    ~H"""
    <div class="cte-analysis">
      <div class="bg-white rounded-lg shadow-lg">
        <div class="px-6 py-4 border-b bg-gray-50">
          <h3 class="text-lg font-semibold">CTE Analysis</h3>
        </div>
        
        <div class="p-6">
          <!-- Performance Metrics -->
          <div class="mb-6">
            <h4 class="font-medium text-sm text-gray-700 mb-3">Performance Metrics</h4>
            <div class="grid grid-cols-4 gap-4">
              <.metric_card
                title="Total Execution Time"
                value={format_duration(@metrics.total_time)}
                trend={@metrics.time_trend}
                color="blue"
              />
              <.metric_card
                title="Memory Usage"
                value={format_bytes(@metrics.memory_usage)}
                trend={@metrics.memory_trend}
                color="green"
              />
              <.metric_card
                title="Row Count"
                value={format_number(@metrics.row_count)}
                trend={nil}
                color="purple"
              />
              <.metric_card
                title="CTE Count"
                value={@metrics.cte_count}
                trend={nil}
                color="gray"
              />
            </div>
          </div>
          
          <!-- CTE Performance Breakdown -->
          <div class="mb-6">
            <h4 class="font-medium text-sm text-gray-700 mb-3">CTE Performance Breakdown</h4>
            <div class="space-y-2">
              <%= for cte <- @cte_metrics do %>
                <div class="flex items-center justify-between p-3 bg-gray-50 rounded">
                  <div class="flex items-center space-x-3">
                    <div class={"w-2 h-2 rounded-full #{performance_indicator_color(cte.performance_score)}"}>
                    </div>
                    <div>
                      <div class="font-medium"><%= cte.name %></div>
                      <div class="text-xs text-gray-500">
                        <%= format_duration(cte.execution_time) %> • 
                        <%= format_number(cte.row_count) %> rows
                      </div>
                    </div>
                  </div>
                  <div class="text-right">
                    <div class="text-sm font-medium"><%= cte.percentage %>%</div>
                    <div class="text-xs text-gray-500">of total time</div>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
          
          <!-- Optimization Suggestions -->
          <div class="mb-6">
            <h4 class="font-medium text-sm text-gray-700 mb-3">Optimization Suggestions</h4>
            <%= if @suggestions == [] do %>
              <div class="text-sm text-green-600 bg-green-50 p-3 rounded">
                ✓ No optimization suggestions. Your CTEs are performing well!
              </div>
            <% else %>
              <div class="space-y-2">
                <%= for suggestion <- @suggestions do %>
                  <.suggestion_card suggestion={suggestion} />
                <% end %>
              </div>
            <% end %>
          </div>
          
          <!-- Dependency Analysis -->
          <div>
            <h4 class="font-medium text-sm text-gray-700 mb-3">Dependency Analysis</h4>
            <div class="bg-gray-50 rounded p-4">
              <div class="grid grid-cols-2 gap-4 text-sm">
                <div>
                  <span class="text-gray-600">Max Dependency Depth:</span>
                  <span class="font-medium ml-2"><%= @dependency_analysis.max_depth %></span>
                </div>
                <div>
                  <span class="text-gray-600">Circular Dependencies:</span>
                  <span class="font-medium ml-2 <%= if @dependency_analysis.circular_deps > 0, do: "text-red-600", else: "text-green-600" %>">
                    <%= @dependency_analysis.circular_deps %>
                  </span>
                </div>
                <div>
                  <span class="text-gray-600">Unused CTEs:</span>
                  <span class="font-medium ml-2 <%= if @dependency_analysis.unused_ctes > 0, do: "text-yellow-600", else: "text-green-600" %>">
                    <%= @dependency_analysis.unused_ctes %>
                  </span>
                </div>
                <div>
                  <span class="text-gray-600">Reused CTEs:</span>
                  <span class="font-medium ml-2"><%= @dependency_analysis.reused_ctes %></span>
                </div>
              </div>
            </div>
          </div>
        </div>
        
        <div class="px-6 py-4 border-t bg-gray-50">
          <div class="flex justify-between">
            <button
              type="button"
              phx-click="export_analysis"
              class="px-4 py-2 bg-gray-600 text-white rounded hover:bg-gray-700"
            >
              Export Analysis
            </button>
            <button
              type="button"
              phx-click="apply_optimizations"
              class="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700"
              disabled={@suggestions == []}
            >
              Apply Optimizations
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def metric_card(assigns) do
    ~H"""
    <div class={"bg-#{@color}-50 p-4 rounded"}>
      <div class={"text-xs text-#{@color}-600 mb-1"}><%= @title %></div>
      <div class="flex items-baseline justify-between">
        <div class={"text-2xl font-bold text-#{@color}-700"}><%= @value %></div>
        <%= if @trend do %>
          <div class={"text-xs flex items-center #{trend_color(@trend)}"}>
            <%= if @trend > 0 do %>
              ↑ <%= @trend %>%
            <% else %>
              ↓ <%= abs(@trend) %>%
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  def suggestion_card(assigns) do
    ~H"""
    <div class={"border-l-4 #{suggestion_border_color(@suggestion.severity)} bg-white p-4 rounded shadow-sm"}>
      <div class="flex items-start">
        <div class={"mt-0.5 mr-3 #{suggestion_icon_color(@suggestion.severity)}"}>
          <.icon name={suggestion_icon(@suggestion.severity)} class="w-5 h-5" />
        </div>
        <div class="flex-1">
          <div class="font-medium text-sm"><%= @suggestion.title %></div>
          <div class="text-sm text-gray-600 mt-1"><%= @suggestion.description %></div>
          <%= if @suggestion.code_example do %>
            <div class="mt-2">
              <div class="text-xs text-gray-500 mb-1">Suggested change:</div>
              <pre class="bg-gray-100 p-2 rounded text-xs overflow-x-auto"><%= @suggestion.code_example %></pre>
            </div>
          <% end %>
          <div class="mt-2 flex items-center space-x-4 text-xs">
            <span class="text-gray-500">Impact: <%= @suggestion.impact %></span>
            <button
              type="button"
              phx-click="apply_suggestion"
              phx-value-id={@suggestion.id}
              class="text-blue-600 hover:text-blue-700"
            >
              Apply Fix
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Analysis functions

  @doc """
  Analyzes CTE query and returns performance metrics and suggestions.
  """
  def analyze_ctes(ctes, execution_data \\ %{}) do
    metrics = calculate_metrics(ctes, execution_data)
    cte_metrics = analyze_individual_ctes(ctes, execution_data)
    suggestions = generate_suggestions(ctes, cte_metrics)
    dependency_analysis = analyze_dependencies(ctes)
    
    %{
      metrics: metrics,
      cte_metrics: cte_metrics,
      suggestions: suggestions,
      dependency_analysis: dependency_analysis
    }
  end

  # Private functions

  defp assign_defaults(assigns) do
    assigns
    |> assign_new(:metrics, fn -> default_metrics() end)
    |> assign_new(:cte_metrics, fn -> [] end)
    |> assign_new(:suggestions, fn -> [] end)
    |> assign_new(:dependency_analysis, fn -> default_dependency_analysis() end)
  end

  defp default_metrics do
    %{
      total_time: 0,
      memory_usage: 0,
      row_count: 0,
      cte_count: 0,
      time_trend: 0,
      memory_trend: 0
    }
  end

  defp default_dependency_analysis do
    %{
      max_depth: 0,
      circular_deps: 0,
      unused_ctes: 0,
      reused_ctes: 0
    }
  end

  defp calculate_metrics(ctes, execution_data) do
    %{
      total_time: Map.get(execution_data, :total_time, 0),
      memory_usage: Map.get(execution_data, :memory_usage, 0),
      row_count: Map.get(execution_data, :row_count, 0),
      cte_count: length(ctes),
      time_trend: calculate_trend(execution_data, :time),
      memory_trend: calculate_trend(execution_data, :memory)
    }
  end

  defp analyze_individual_ctes(ctes, execution_data) do
    total_time = Map.get(execution_data, :total_time, 1)
    
    Enum.map(ctes, fn cte ->
      cte_data = Map.get(execution_data, cte.name, %{})
      execution_time = Map.get(cte_data, :execution_time, 0)
      
      %{
        name: cte.name,
        execution_time: execution_time,
        row_count: Map.get(cte_data, :row_count, 0),
        percentage: round(execution_time / total_time * 100),
        performance_score: calculate_performance_score(cte_data)
      }
    end)
  end

  defp generate_suggestions(ctes, cte_metrics) do
    suggestions = []
    
    # Check for slow CTEs
    suggestions = suggestions ++ check_slow_ctes(cte_metrics)
    
    # Check for large result sets
    suggestions = suggestions ++ check_large_results(cte_metrics)
    
    # Check for missing indexes
    suggestions = suggestions ++ check_missing_indexes(ctes)
    
    # Check for redundant CTEs
    suggestions = suggestions ++ check_redundant_ctes(ctes)
    
    suggestions
  end

  defp check_slow_ctes(cte_metrics) do
    cte_metrics
    |> Enum.filter(&(&1.execution_time > 1000))
    |> Enum.map(fn cte ->
      %{
        id: Ecto.UUID.generate(),
        severity: :warning,
        title: "Slow CTE: #{cte.name}",
        description: "This CTE takes #{format_duration(cte.execution_time)} to execute. Consider optimizing the query or adding indexes.",
        impact: "High",
        code_example: nil
      }
    end)
  end

  defp check_large_results(cte_metrics) do
    cte_metrics
    |> Enum.filter(&(&1.row_count > 10000))
    |> Enum.map(fn cte ->
      %{
        id: Ecto.UUID.generate(),
        severity: :info,
        title: "Large Result Set: #{cte.name}",
        description: "This CTE returns #{format_number(cte.row_count)} rows. Consider adding filters or pagination.",
        impact: "Medium",
        code_example: "WHERE created_at > CURRENT_DATE - INTERVAL '30 days'"
      }
    end)
  end

  defp check_missing_indexes(_ctes) do
    # This would analyze the query plans to detect missing indexes
    []
  end

  defp check_redundant_ctes(ctes) do
    # Check for CTEs with similar definitions
    duplicates = find_duplicate_definitions(ctes)
    
    Enum.map(duplicates, fn {cte1, cte2} ->
      %{
        id: Ecto.UUID.generate(),
        severity: :info,
        title: "Possible Redundant CTEs",
        description: "#{cte1.name} and #{cte2.name} have similar definitions. Consider combining them.",
        impact: "Low",
        code_example: nil
      }
    end)
  end

  defp find_duplicate_definitions(ctes) do
    # Simple check for CTEs with identical definitions
    ctes
    |> Enum.map(fn cte -> {cte, generate_cte_signature(cte)} end)
    |> Enum.group_by(fn {_cte, sig} -> sig end)
    |> Map.values()
    |> Enum.filter(&(length(&1) > 1))
    |> Enum.flat_map(fn group ->
      for {cte1, _} <- group, {cte2, _} <- group, cte1.name < cte2.name do
        {cte1, cte2}
      end
    end)
  end

  defp generate_cte_signature(cte) do
    # Generate a signature for comparison
    "#{cte.type}:#{Enum.join(cte.select_fields || [], ",")}:#{Enum.join(cte.from_tables || [], ",")}"
  end

  defp analyze_dependencies(ctes) do
    # Build dependency graph
    deps = build_dependency_map(ctes)
    
    %{
      max_depth: calculate_max_depth(deps),
      circular_deps: detect_circular_dependencies(deps),
      unused_ctes: count_unused_ctes(ctes, deps),
      reused_ctes: count_reused_ctes(deps)
    }
  end

  defp build_dependency_map(ctes) do
    Enum.reduce(ctes, %{}, fn cte, acc ->
      Map.put(acc, cte.name, cte.dependencies || [])
    end)
  end

  defp calculate_max_depth(deps) do
    if map_size(deps) == 0 do
      0
    else
      deps
      |> Map.keys()
      |> Enum.map(&calculate_node_depth(&1, deps, %{}))
      |> Enum.max()
    end
  end

  defp calculate_node_depth(node, deps, visited) do
    if Map.has_key?(visited, node) do
      0
    else
      node_deps = Map.get(deps, node, [])
      if node_deps == [] do
        1
      else
        visited = Map.put(visited, node, true)
        1 + Enum.max([0 | Enum.map(node_deps, &calculate_node_depth(&1, deps, visited))])
      end
    end
  end

  defp detect_circular_dependencies(deps) do
    # Simple cycle detection
    deps
    |> Map.keys()
    |> Enum.count(&has_cycle?(&1, deps, MapSet.new()))
  end

  defp has_cycle?(node, deps, visited) do
    if MapSet.member?(visited, node) do
      true
    else
      visited = MapSet.put(visited, node)
      node_deps = Map.get(deps, node, [])
      Enum.any?(node_deps, &has_cycle?(&1, deps, visited))
    end
  end

  defp count_unused_ctes(ctes, deps) do
    all_referenced = 
      deps
      |> Map.values()
      |> List.flatten()
      |> MapSet.new()
    
    ctes
    |> Enum.map(& &1.name)
    |> Enum.count(&(!MapSet.member?(all_referenced, &1)))
  end

  defp count_reused_ctes(deps) do
    deps
    |> Map.values()
    |> List.flatten()
    |> Enum.frequencies()
    |> Map.values()
    |> Enum.count(&(&1 > 1))
  end

  defp calculate_performance_score(cte_data) do
    # Simple scoring based on execution time
    time = Map.get(cte_data, :execution_time, 0)
    
    cond do
      time < 100 -> :good
      time < 500 -> :fair
      true -> :poor
    end
  end

  defp calculate_trend(_data, _type), do: 0

  defp performance_indicator_color(:good), do: "bg-green-500"
  defp performance_indicator_color(:fair), do: "bg-yellow-500"
  defp performance_indicator_color(:poor), do: "bg-red-500"
  defp performance_indicator_color(_), do: "bg-gray-500"

  defp trend_color(trend) when trend > 0, do: "text-red-600"
  defp trend_color(trend) when trend < 0, do: "text-green-600"
  defp trend_color(_), do: "text-gray-600"

  defp suggestion_border_color(:error), do: "border-red-500"
  defp suggestion_border_color(:warning), do: "border-yellow-500"
  defp suggestion_border_color(:info), do: "border-blue-500"
  defp suggestion_border_color(_), do: "border-gray-500"

  defp suggestion_icon_color(:error), do: "text-red-500"
  defp suggestion_icon_color(:warning), do: "text-yellow-500"
  defp suggestion_icon_color(:info), do: "text-blue-500"
  defp suggestion_icon_color(_), do: "text-gray-500"

  defp suggestion_icon(:error), do: "hero-x-circle"
  defp suggestion_icon(:warning), do: "hero-exclamation-triangle"
  defp suggestion_icon(:info), do: "hero-information-circle"
  defp suggestion_icon(_), do: "hero-question-mark-circle"

  defp format_duration(ms) when is_number(ms), do: "#{ms}ms"
  defp format_duration(_), do: "N/A"

  defp format_bytes(bytes) when is_number(bytes) do
    cond do
      bytes < 1024 -> "#{bytes} B"
      bytes < 1024 * 1024 -> "#{Float.round(bytes / 1024, 1)} KB"
      true -> "#{Float.round(bytes / (1024 * 1024), 1)} MB"
    end
  end
  defp format_bytes(_), do: "N/A"

  defp format_number(num) when is_number(num) do
    Number.Delimit.number_to_delimited(num)
  end
  defp format_number(_), do: "N/A"

  defp icon(assigns) do
    ~H"""
    <svg class={@class} fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <%= case @name do %>
        <% "hero-x-circle" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z" />
        <% "hero-exclamation-triangle" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
        <% "hero-information-circle" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
        <% _ -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.228 11.685A4 4 0 1112 4h0a4 4 0 010 8h0a4 4 0 01-3.772-2.685z" />
      <% end %>
    </svg>
    """
  end
end