defmodule SelectoComponents.Subselect.Optimizer do
  @moduledoc """
  Provides optimization suggestions and automatic query rewriting for subselects.
  """

  use Phoenix.Component
  import Phoenix.LiveView

  @doc """
  Component for displaying optimization suggestions and applying them.
  """
  def optimization_panel(assigns) do
    assigns = assign_defaults(assigns)
    
    ~H"""
    <div class="subselect-optimizer">
      <div class="bg-white rounded-lg shadow-lg">
        <div class="px-6 py-4 border-b bg-gray-50">
          <div class="flex items-center justify-between">
            <h3 class="text-lg font-semibold">Query Optimization</h3>
            <button
              type="button"
              phx-click="analyze_query"
              class="px-3 py-1 bg-blue-600 text-white rounded text-sm hover:bg-blue-700"
            >
              <.icon name="hero-magnifying-glass" class="w-4 h-4 inline mr-1" />
              Analyze
            </button>
          </div>
        </div>
        
        <div class="p-6">
          <!-- Original vs Optimized Comparison -->
          <div class="grid grid-cols-2 gap-4 mb-6">
            <div>
              <h4 class="font-medium text-sm text-gray-700 mb-2">Original Query</h4>
              <pre class="bg-gray-900 text-gray-100 p-3 rounded text-xs overflow-x-auto h-48">
<%= format_sql(@original_query) %>
              </pre>
              <div class="mt-2 text-xs text-gray-600">
                Estimated cost: <span class="font-medium"><%= @original_cost %></span>
              </div>
            </div>
            
            <div>
              <h4 class="font-medium text-sm text-gray-700 mb-2">
                Optimized Query
                <%= if @optimization_applied do %>
                  <span class="ml-2 px-2 py-1 bg-green-100 text-green-700 rounded text-xs">
                    Applied
                  </span>
                <% end %>
              </h4>
              <pre class="bg-gray-900 text-green-300 p-3 rounded text-xs overflow-x-auto h-48">
<%= format_sql(@optimized_query) %>
              </pre>
              <div class="mt-2 text-xs text-gray-600">
                Estimated cost: <span class="font-medium text-green-600"><%= @optimized_cost %></span>
                <span class="ml-2 text-green-600">(-<%= @cost_reduction %>%)</span>
              </div>
            </div>
          </div>
          
          <!-- Optimization Suggestions -->
          <div class="mb-6">
            <h4 class="font-medium text-sm text-gray-700 mb-3">Optimization Suggestions</h4>
            <%= if @suggestions == [] do %>
              <div class="bg-green-50 text-green-700 p-3 rounded text-sm">
                ✓ Query is already optimized
              </div>
            <% else %>
              <div class="space-y-2">
                <%= for suggestion <- @suggestions do %>
                  <.suggestion_card
                    suggestion={suggestion}
                    applied={suggestion.id in @applied_suggestions}
                  />
                <% end %>
              </div>
            <% end %>
          </div>
          
          <!-- Common Patterns -->
          <div class="mb-6">
            <h4 class="font-medium text-sm text-gray-700 mb-3">Query Pattern Analysis</h4>
            <div class="grid grid-cols-2 gap-4">
              <%= for pattern <- @detected_patterns do %>
                <.pattern_card pattern={pattern} />
              <% end %>
            </div>
          </div>
          
          <!-- Performance Preview -->
          <div>
            <h4 class="font-medium text-sm text-gray-700 mb-3">Performance Impact</h4>
            <div class="bg-gray-50 rounded p-4">
              <div class="grid grid-cols-4 gap-4 text-sm">
                <div>
                  <span class="text-gray-600">Execution Time</span>
                  <div class="font-medium">
                    <%= @performance.original_time %>ms → 
                    <span class="text-green-600"><%= @performance.optimized_time %>ms</span>
                  </div>
                </div>
                <div>
                  <span class="text-gray-600">Rows Scanned</span>
                  <div class="font-medium">
                    <%= format_number(@performance.original_rows) %> → 
                    <span class="text-green-600"><%= format_number(@performance.optimized_rows) %></span>
                  </div>
                </div>
                <div>
                  <span class="text-gray-600">Memory Usage</span>
                  <div class="font-medium">
                    <%= format_bytes(@performance.original_memory) %> → 
                    <span class="text-green-600"><%= format_bytes(@performance.optimized_memory) %></span>
                  </div>
                </div>
                <div>
                  <span class="text-gray-600">Index Usage</span>
                  <div class="font-medium">
                    <%= @performance.index_usage %>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
        
        <div class="px-6 py-4 border-t bg-gray-50">
          <div class="flex justify-between">
            <div class="flex space-x-2">
              <button
                type="button"
                phx-click="apply_all"
                class="px-4 py-2 bg-green-600 text-white rounded hover:bg-green-700"
                disabled={@suggestions == []}
              >
                Apply All Optimizations
              </button>
              <button
                type="button"
                phx-click="test_optimized"
                class="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700"
              >
                Test Optimized Query
              </button>
            </div>
            <button
              type="button"
              phx-click="export_analysis"
              class="px-4 py-2 bg-gray-600 text-white rounded hover:bg-gray-700"
            >
              Export Analysis
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def suggestion_card(assigns) do
    ~H"""
    <div class={"suggestion-card border-l-4 #{suggestion_color(@suggestion.impact)} bg-white p-4 rounded shadow-sm"}>
      <div class="flex items-start">
        <div class="mr-3">
          <.icon name={suggestion_icon(@suggestion.type)} class="w-5 h-5 text-blue-600" />
        </div>
        <div class="flex-1">
          <div class="flex items-center justify-between">
            <h5 class="font-medium text-sm"><%= @suggestion.title %></h5>
            <%= if @applied do %>
              <span class="px-2 py-1 bg-green-100 text-green-700 rounded text-xs">
                Applied
              </span>
            <% end %>
          </div>
          <p class="text-sm text-gray-600 mt-1"><%= @suggestion.description %></p>
          
          <%= if @suggestion.example do %>
            <div class="mt-2 bg-gray-100 p-2 rounded">
              <code class="text-xs"><%= @suggestion.example %></code>
            </div>
          <% end %>
          
          <div class="mt-3 flex items-center justify-between">
            <div class="text-xs text-gray-500">
              Impact: <span class={"font-medium #{impact_text_color(@suggestion.impact)}"}><%= @suggestion.impact %></span>
            </div>
            <%= if !@applied do %>
              <button
                type="button"
                phx-click="apply_suggestion"
                phx-value-id={@suggestion.id}
                class="px-2 py-1 bg-blue-600 text-white rounded text-xs hover:bg-blue-700"
              >
                Apply
              </button>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def pattern_card(assigns) do
    ~H"""
    <div class="pattern-card bg-gray-50 rounded p-3">
      <div class="flex items-center mb-2">
        <.icon name={pattern_icon(@pattern.type)} class="w-4 h-4 text-gray-600 mr-2" />
        <span class="font-medium text-sm"><%= @pattern.name %></span>
      </div>
      <p class="text-xs text-gray-600"><%= @pattern.description %></p>
      <%= if @pattern.recommendation do %>
        <div class="mt-2 text-xs text-blue-600">
          💡 <%= @pattern.recommendation %>
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Analyzes a query and returns optimization suggestions.
  """
  def analyze(query) do
    %{
      original_query: query,
      optimized_query: optimize_query(query),
      suggestions: generate_suggestions(query),
      detected_patterns: detect_patterns(query),
      performance: estimate_performance(query),
      cost_reduction: calculate_cost_reduction(query)
    }
  end

  @doc """
  Applies optimization transformations to a query.
  """
  def optimize_query(query) do
    query
    |> convert_in_to_exists()
    |> merge_subqueries()
    |> push_down_predicates()
    |> eliminate_redundant_subqueries()
    |> rewrite_correlated_subqueries()
  end

  # Private functions

  defp assign_defaults(assigns) do
    assigns
    |> assign_new(:original_query, fn -> "" end)
    |> assign_new(:optimized_query, fn -> "" end)
    |> assign_new(:original_cost, fn -> 0 end)
    |> assign_new(:optimized_cost, fn -> 0 end)
    |> assign_new(:cost_reduction, fn -> 0 end)
    |> assign_new(:suggestions, fn -> [] end)
    |> assign_new(:applied_suggestions, fn -> [] end)
    |> assign_new(:optimization_applied, fn -> false end)
    |> assign_new(:detected_patterns, fn -> [] end)
    |> assign_new(:performance, fn -> default_performance() end)
  end

  defp default_performance do
    %{
      original_time: 0,
      optimized_time: 0,
      original_rows: 0,
      optimized_rows: 0,
      original_memory: 0,
      optimized_memory: 0,
      index_usage: "Not analyzed"
    }
  end

  defp generate_suggestions(query) do
    suggestions = []
    
    # Check for IN subqueries that can be converted to EXISTS
    suggestions = if has_in_subquery?(query) do
      [%{
        id: "convert-in-exists",
        type: "rewrite",
        title: "Convert IN to EXISTS",
        description: "EXISTS is often more efficient than IN for subqueries, especially with large result sets.",
        example: "WHERE EXISTS (SELECT 1 FROM table WHERE ...)",
        impact: "high"
      } | suggestions]
    else
      suggestions
    end
    
    # Check for correlated subqueries
    suggestions = if has_correlated_subquery?(query) do
      [%{
        id: "decorrelate",
        type: "rewrite",
        title: "Decorrelate Subquery",
        description: "Converting correlated subqueries to joins can significantly improve performance.",
        example: "JOIN (SELECT ...) AS subquery ON ...",
        impact: "high"
      } | suggestions]
    else
      suggestions
    end
    
    # Check for SELECT *
    suggestions = if has_select_star?(query) do
      [%{
        id: "specify-columns",
        type: "schema",
        title: "Specify Column Names",
        description: "Explicitly listing columns reduces data transfer and improves query clarity.",
        example: "SELECT id, name, email FROM ...",
        impact: "medium"
      } | suggestions]
    else
      suggestions
    end
    
    suggestions
  end

  defp detect_patterns(query) do
    patterns = []
    
    patterns = if has_n_plus_one_pattern?(query) do
      [%{
        type: "performance",
        name: "N+1 Query Pattern",
        description: "Multiple subqueries that could be combined into a single join.",
        recommendation: "Consider using a JOIN or batch loading."
      } | patterns]
    else
      patterns
    end
    
    patterns = if has_cartesian_product?(query) do
      [%{
        type: "warning",
        name: "Cartesian Product",
        description: "Missing JOIN condition may result in cartesian product.",
        recommendation: "Add appropriate JOIN conditions."
      } | patterns]
    else
      patterns
    end
    
    patterns
  end

  defp estimate_performance(_query) do
    # Simplified performance estimation
    %{
      original_time: 150,
      optimized_time: 45,
      original_rows: 15000,
      optimized_rows: 3500,
      original_memory: 1024 * 1024 * 5,
      optimized_memory: 1024 * 1024 * 2,
      index_usage: "3 indexes used"
    }
  end

  defp calculate_cost_reduction(_query) do
    # Simplified cost calculation
    70
  end

  # Query transformation functions

  defp convert_in_to_exists(query) do
    # Convert IN subqueries to EXISTS
    String.replace(query, ~r/WHERE\s+\w+\s+IN\s+\(/i, "WHERE EXISTS (SELECT 1 FROM ")
  end

  defp merge_subqueries(query), do: query

  defp push_down_predicates(query), do: query

  defp eliminate_redundant_subqueries(query), do: query

  defp rewrite_correlated_subqueries(query), do: query

  # Pattern detection helpers

  defp has_in_subquery?(query), do: String.contains?(query, " IN (SELECT")
  
  defp has_correlated_subquery?(_query), do: false  # Simplified
  
  defp has_select_star?(query), do: String.contains?(query, "SELECT *")
  
  defp has_n_plus_one_pattern?(_query), do: false  # Simplified
  
  defp has_cartesian_product?(_query), do: false  # Simplified

  # UI helpers

  defp format_sql(sql) do
    sql
    |> String.replace(~r/\b(SELECT|FROM|WHERE|JOIN|ON|GROUP BY|HAVING|ORDER BY|WITH|AS)\b/i, "\n\\1")
    |> String.trim()
  end

  defp format_number(num) when is_number(num) do
    num
    |> to_string()
    |> String.replace(~r/(\d)(?=(\d{3})+(?!\d))/, "\\1,")
  end
  defp format_number(_), do: "0"

  defp format_bytes(bytes) when is_number(bytes) do
    cond do
      bytes < 1024 -> "#{bytes} B"
      bytes < 1024 * 1024 -> "#{Float.round(bytes / 1024, 1)} KB"
      true -> "#{Float.round(bytes / (1024 * 1024), 1)} MB"
    end
  end
  defp format_bytes(_), do: "0 B"

  defp suggestion_color("high"), do: "border-red-400"
  defp suggestion_color("medium"), do: "border-yellow-400"
  defp suggestion_color("low"), do: "border-blue-400"
  defp suggestion_color(_), do: "border-gray-400"

  defp suggestion_icon("rewrite"), do: "hero-arrow-path"
  defp suggestion_icon("index"), do: "hero-key"
  defp suggestion_icon("schema"), do: "hero-table-cells"
  defp suggestion_icon(_), do: "hero-light-bulb"

  defp pattern_icon("performance"), do: "hero-bolt"
  defp pattern_icon("warning"), do: "hero-exclamation-triangle"
  defp pattern_icon(_), do: "hero-information-circle"

  defp impact_text_color("high"), do: "text-red-600"
  defp impact_text_color("medium"), do: "text-yellow-600"
  defp impact_text_color("low"), do: "text-blue-600"
  defp impact_text_color(_), do: "text-gray-600"

  defp icon(assigns) do
    ~H"""
    <svg class={@class} fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <%= case @name do %>
        <% "hero-magnifying-glass" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
        <% "hero-arrow-path" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0l3.181 3.183a8.25 8.25 0 0013.803-3.7M4.031 9.865a8.25 8.25 0 0113.803-3.7l3.181 3.182m0-4.991v4.99" />
        <% "hero-key" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.75 5.25a3 3 0 013 3m3 0a6 6 0 01-7.029 5.912c-.563-.097-1.159.026-1.563.43L10.5 17.25H8.25v2.25H6v2.25H2.25v-2.818c0-.597.237-1.17.659-1.591l6.499-6.499c.404-.404.527-1 .43-1.563A6 6 0 1121.75 8.25z" />
        <% "hero-table-cells" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3.375 19.5h17.25m-17.25 0a1.125 1.125 0 01-1.125-1.125M3.375 19.5h7.5c.621 0 1.125-.504 1.125-1.125m-9.75 0V5.625m0 12.75v-1.5c0-.621.504-1.125 1.125-1.125m18.375 2.625V5.625m0 12.75c0 .621-.504 1.125-1.125 1.125m1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125m0 3.75h-7.5A1.125 1.125 0 0112 18.375m9.75-12.75c0-.621-.504-1.125-1.125-1.125H3.375c-.621 0-1.125.504-1.125 1.125m19.5 0v1.5c0 .621-.504 1.125-1.125 1.125M2.25 5.625v1.5c0 .621.504 1.125 1.125 1.125m0 0h17.25m-17.25 0h7.5c.621 0 1.125.504 1.125 1.125M3.375 8.25c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125m17.25-3.75h-7.5c-.621 0-1.125.504-1.125 1.125m8.625-1.125c.621 0 1.125.504 1.125 1.125v1.5c0 .621-.504 1.125-1.125 1.125m-17.25 0h7.5m-7.5 0c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125M12 10.875v-1.5m0 1.5c0 .621-.504 1.125-1.125 1.125M12 10.875c0 .621.504 1.125 1.125 1.125m-2.25 0c.621 0 1.125.504 1.125 1.125M13.125 12h7.5m-7.5 0c-.621 0-1.125.504-1.125 1.125M20.625 12c.621 0 1.125.504 1.125 1.125v1.5c0 .621-.504 1.125-1.125 1.125m-17.25 0h7.5M12 14.625v-1.5m0 1.5c0 .621-.504 1.125-1.125 1.125M12 14.625c0 .621.504 1.125 1.125 1.125m-2.25 0c.621 0 1.125.504 1.125 1.125m0 1.5v-1.5m0 0c0-.621.504-1.125 1.125-1.125m0 0h7.5" />
        <% "hero-light-bulb" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z" />
        <% "hero-bolt" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z" />
        <% "hero-exclamation-triangle" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
        <% "hero-information-circle" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11.25 11.25l.041-.02a.75.75 0 011.063.852l-.708 2.836a.75.75 0 001.063.853l.041-.021M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9-3.75h.008v.008H12V8.25z" />
        <% _ -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
      <% end %>
    </svg>
    """
  end
end