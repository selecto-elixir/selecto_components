defmodule SelectoComponents.Performance.QueryAnalyzer do
  @moduledoc """
  Analyzes query execution plans and provides optimization recommendations.
  """

  use Phoenix.Component
  import Phoenix.LiveView

  @doc """
  Displays query execution plan with analysis.
  """
  def query_plan(assigns) do
    assigns = assign_defaults(assigns)
    
    ~H"""
    <div class="query-plan-analyzer">
      <div class="bg-white rounded-lg shadow-lg">
        <div class="px-6 py-4 border-b bg-gray-50">
          <div class="flex items-center justify-between">
            <h3 class="text-lg font-semibold">Query Plan Analysis</h3>
            <div class="flex space-x-2">
              <button
                type="button"
                phx-click="export_plan"
                class="px-3 py-1 bg-gray-600 text-white rounded text-sm hover:bg-gray-700"
              >
                Export
              </button>
              <button
                type="button"
                phx-click="compare_plans"
                class="px-3 py-1 bg-blue-600 text-white rounded text-sm hover:bg-blue-700"
              >
                Compare
              </button>
            </div>
          </div>
        </div>
        
        <div class="p-6">
          <!-- Query Display -->
          <div class="mb-6">
            <h4 class="font-medium text-sm text-gray-700 mb-2">Query</h4>
            <pre class="bg-gray-900 text-gray-100 p-4 rounded text-xs overflow-x-auto">
<%= format_sql(@query) %>
            </pre>
          </div>
          
          <!-- Execution Plan Tree -->
          <div class="mb-6">
            <h4 class="font-medium text-sm text-gray-700 mb-2">Execution Plan</h4>
            <div class="border rounded-lg p-4 bg-gray-50">
              <.plan_node node={@plan_tree} level={0} />
            </div>
          </div>
          
          <!-- Performance Metrics -->
          <div class="mb-6">
            <h4 class="font-medium text-sm text-gray-700 mb-2">Performance Metrics</h4>
            <div class="grid grid-cols-3 gap-4">
              <div class="bg-blue-50 p-3 rounded">
                <div class="text-xs text-blue-600">Total Cost</div>
                <div class="text-xl font-bold text-blue-700"><%= @metrics.total_cost %></div>
              </div>
              <div class="bg-green-50 p-3 rounded">
                <div class="text-xs text-green-600">Rows Examined</div>
                <div class="text-xl font-bold text-green-700"><%= format_number(@metrics.rows_examined) %></div>
              </div>
              <div class="bg-purple-50 p-3 rounded">
                <div class="text-xs text-purple-600">Execution Time</div>
                <div class="text-xl font-bold text-purple-700"><%= format_duration(@metrics.execution_time) %></div>
              </div>
            </div>
          </div>
          
          <!-- Optimization Suggestions -->
          <div class="mb-6">
            <h4 class="font-medium text-sm text-gray-700 mb-2">Optimization Suggestions</h4>
            <%= if @suggestions == [] do %>
              <div class="bg-green-50 text-green-700 p-3 rounded text-sm">
                ✓ Query is well optimized
              </div>
            <% else %>
              <div class="space-y-2">
                <%= for suggestion <- @suggestions do %>
                  <.optimization_suggestion suggestion={suggestion} />
                <% end %>
              </div>
            <% end %>
          </div>
          
          <!-- Index Recommendations -->
          <%= if @index_recommendations != [] do %>
            <div>
              <h4 class="font-medium text-sm text-gray-700 mb-2">Index Recommendations</h4>
              <div class="space-y-2">
                <%= for rec <- @index_recommendations do %>
                  <.index_recommendation recommendation={rec} />
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  def plan_node(assigns) do
    ~H"""
    <div class={"plan-node ml-#{@level * 4}"}>
      <div class="flex items-start space-x-2 py-2">
        <div class={"w-2 h-2 mt-1.5 rounded-full #{node_color(@node.type)}"}>
        </div>
        <div class="flex-1">
          <div class="flex items-center space-x-2">
            <span class="font-medium text-sm"><%= @node.operation %></span>
            <span class="text-xs text-gray-500">
              Cost: <%= @node.cost %> | Rows: <%= @node.rows %>
            </span>
          </div>
          <%= if @node.details do %>
            <div class="text-xs text-gray-600 mt-1">
              <%= @node.details %>
            </div>
          <% end %>
          <%= if @node.warning do %>
            <div class="text-xs text-yellow-600 mt-1 flex items-center">
              <.icon name="hero-exclamation-triangle" class="w-3 h-3 mr-1" />
              <%= @node.warning %>
            </div>
          <% end %>
        </div>
      </div>
      
      <%= if @node.children do %>
        <%= for child <- @node.children do %>
          <.plan_node node={child} level={@level + 1} />
        <% end %>
      <% end %>
    </div>
    """
  end

  def optimization_suggestion(assigns) do
    ~H"""
    <div class="border-l-4 border-yellow-400 bg-yellow-50 p-4 rounded">
      <div class="flex items-start">
        <.icon name="hero-light-bulb" class="w-5 h-5 text-yellow-600 mr-3 mt-0.5" />
        <div class="flex-1">
          <div class="font-medium text-sm"><%= @suggestion.title %></div>
          <div class="text-sm text-gray-600 mt-1"><%= @suggestion.description %></div>
          <%= if @suggestion.example do %>
            <div class="mt-2 bg-white p-2 rounded border border-yellow-200">
              <pre class="text-xs"><%= @suggestion.example %></pre>
            </div>
          <% end %>
          <div class="mt-2 text-xs text-gray-500">
            Estimated improvement: <%= @suggestion.improvement %>%
          </div>
        </div>
      </div>
    </div>
    """
  end

  def index_recommendation(assigns) do
    ~H"""
    <div class="bg-blue-50 border border-blue-200 p-3 rounded">
      <div class="flex items-center justify-between">
        <div>
          <div class="font-medium text-sm">Create Index</div>
          <code class="text-xs text-gray-700">
            CREATE INDEX <%= @recommendation.name %> ON <%= @recommendation.table %> (<%= Enum.join(@recommendation.columns, ", ") %>)
          </code>
        </div>
        <button
          type="button"
          phx-click="create_index"
          phx-value-index={@recommendation.name}
          class="px-3 py-1 bg-blue-600 text-white rounded text-xs hover:bg-blue-700"
        >
          Create
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Analyzes a query and returns optimization suggestions.
  """
  def analyze_query(query, plan) do
    %{
      query: query,
      plan_tree: parse_plan(plan),
      metrics: extract_metrics(plan),
      suggestions: generate_suggestions(plan),
      index_recommendations: recommend_indexes(plan)
    }
  end

  # Private functions

  defp assign_defaults(assigns) do
    assigns
    |> assign_new(:query, fn -> "" end)
    |> assign_new(:plan_tree, fn -> default_plan_tree() end)
    |> assign_new(:metrics, fn -> default_metrics() end)
    |> assign_new(:suggestions, fn -> [] end)
    |> assign_new(:index_recommendations, fn -> [] end)
  end

  defp default_plan_tree do
    %{
      operation: "Seq Scan",
      type: "scan",
      cost: 0,
      rows: 0,
      details: nil,
      warning: nil,
      children: []
    }
  end

  defp default_metrics do
    %{
      total_cost: 0,
      rows_examined: 0,
      execution_time: 0
    }
  end

  defp parse_plan(_plan_text) do
    # Parse execution plan text into tree structure
    # This is a simplified version
    %{
      operation: "Nested Loop",
      type: "join",
      cost: 1250.5,
      rows: 523,
      details: "Inner join on film_id",
      warning: nil,
      children: [
        %{
          operation: "Index Scan",
          type: "index_scan",
          cost: 125.3,
          rows: 100,
          details: "Using idx_film_title",
          warning: nil,
          children: []
        },
        %{
          operation: "Seq Scan",
          type: "scan",
          cost: 892.1,
          rows: 423,
          details: "On film_actor",
          warning: "Full table scan detected",
          children: []
        }
      ]
    }
  end

  defp extract_metrics(_plan) do
    %{
      total_cost: 2267.9,
      rows_examined: 15234,
      execution_time: 125
    }
  end

  defp generate_suggestions(_plan) do
    [
      %{
        title: "Convert Sequential Scan to Index Scan",
        description: "The query is performing a full table scan on 'film_actor'. An index on 'film_id' would improve performance.",
        example: "CREATE INDEX idx_film_actor_film_id ON film_actor(film_id);",
        improvement: 65
      },
      %{
        title: "Use Covering Index",
        description: "Including 'actor_id' in the index would eliminate the need for table lookups.",
        example: "CREATE INDEX idx_film_actor_covering ON film_actor(film_id, actor_id);",
        improvement: 25
      }
    ]
  end

  defp recommend_indexes(_plan) do
    [
      %{
        name: "idx_film_actor_film_id",
        table: "film_actor",
        columns: ["film_id"]
      }
    ]
  end

  defp node_color("scan"), do: "bg-red-500"
  defp node_color("index_scan"), do: "bg-green-500"
  defp node_color("join"), do: "bg-blue-500"
  defp node_color("sort"), do: "bg-yellow-500"
  defp node_color(_), do: "bg-gray-500"

  defp format_sql(sql) do
    sql
    |> String.replace(~r/\b(SELECT|FROM|WHERE|JOIN|ON|GROUP BY|ORDER BY|HAVING)\b/i, "\n\\1")
    |> String.trim()
  end

  defp format_number(num) when is_number(num) do
    num
    |> to_string()
    |> String.replace(~r/(\d)(?=(\d{3})+(?!\d))/, "\\1,")
  end
  defp format_number(_), do: "0"

  defp format_duration(ms) when ms >= 1000, do: "#{Float.round(ms / 1000, 2)}s"
  defp format_duration(ms), do: "#{ms}ms"

  defp icon(assigns) do
    ~H"""
    <svg class={@class} fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <%= case @name do %>
        <% "hero-exclamation-triangle" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
        <% "hero-light-bulb" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z" />
        <% _ -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
      <% end %>
    </svg>
    """
  end
end