defmodule SelectoComponents.Query.QueryOptimizer do
  @moduledoc """
  Query optimization hints and analysis component for improving query performance.
  """
  
  use Phoenix.Component
  alias Phoenix.LiveView.JS
  
  @doc """
  Query optimizer component with performance analysis and suggestions.
  """
  def query_optimizer(assigns) do
    assigns = 
      assigns
      |> assign_new(:query, fn -> %{} end)
      |> assign_new(:execution_plan, fn -> nil end)
      |> assign_new(:statistics, fn -> %{} end)
      |> assign_new(:suggestions, fn -> [] end)
    
    ~H"""
    <div class="query-optimizer space-y-4">
      <%!-- Performance Score --%>
      <div class="bg-white rounded-lg border border-gray-200 p-4">
        <div class="flex items-center justify-between mb-3">
          <h3 class="text-sm font-medium text-gray-700">Performance Score</h3>
          <.performance_badge score={calculate_score(@query)} />
        </div>
        
        <div class="space-y-2">
          <.performance_metric 
            label="Query Complexity"
            value={@statistics[:complexity] || "Low"}
            status={complexity_status(@statistics[:complexity])}
          />
          <.performance_metric 
            label="Estimated Cost"
            value={format_cost(@statistics[:cost])}
            status={cost_status(@statistics[:cost])}
          />
          <.performance_metric 
            label="Index Usage"
            value={@statistics[:index_usage] || "Unknown"}
            status={index_status(@statistics[:index_usage])}
          />
          <.performance_metric 
            label="Estimated Rows"
            value={format_number(@statistics[:estimated_rows])}
            status={:neutral}
          />
        </div>
      </div>
      
      <%!-- Execution Plan Visualization --%>
      <%= if @execution_plan do %>
        <div class="bg-gray-50 rounded-lg p-4">
          <h3 class="text-sm font-medium text-gray-700 mb-3">Execution Plan</h3>
          <.execution_plan_tree plan={@execution_plan} />
        </div>
      <% end %>
      
      <%!-- Optimization Suggestions --%>
      <%= if not Enum.empty?(@suggestions) do %>
        <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
          <h3 class="text-sm font-medium text-blue-900 mb-3">
            Optimization Suggestions
          </h3>
          <div class="space-y-2">
            <%= for suggestion <- @suggestions do %>
              <.suggestion_item suggestion={suggestion} />
            <% end %>
          </div>
        </div>
      <% end %>
      
      <%!-- Query Rewrite Suggestions --%>
      <div class="bg-white rounded-lg border border-gray-200 p-4">
        <h3 class="text-sm font-medium text-gray-700 mb-3">
          Query Rewrite Options
        </h3>
        <div class="space-y-2">
          <.rewrite_option 
            type="use_exists"
            applicable={check_exists_rewrite(@query)}
            description="Replace IN with EXISTS for better performance"
          />
          <.rewrite_option 
            type="push_down_predicates"
            applicable={check_predicate_pushdown(@query)}
            description="Move WHERE conditions closer to data source"
          />
          <.rewrite_option 
            type="eliminate_distinct"
            applicable={check_distinct_elimination(@query)}
            description="Remove unnecessary DISTINCT operations"
          />
          <.rewrite_option 
            type="combine_subqueries"
            applicable={check_subquery_combination(@query)}
            description="Combine multiple subqueries into JOINs"
          />
        </div>
      </div>
    </div>
    """
  end
  
  @doc """
  Performance badge component.
  """
  def performance_badge(assigns) do
    {color, text} = case assigns.score do
      score when score >= 80 -> {"green", "Excellent"}
      score when score >= 60 -> {"yellow", "Good"}
      score when score >= 40 -> {"orange", "Fair"}
      _ -> {"red", "Poor"}
    end
    
    assigns = 
      assigns
      |> assign(:color, color)
      |> assign(:text, text)
    
    ~H"""
    <div class={[
      "px-3 py-1 rounded-full text-sm font-medium",
      @color == "green" && "bg-green-100 text-green-800",
      @color == "yellow" && "bg-yellow-100 text-yellow-800",
      @color == "orange" && "bg-orange-100 text-orange-800",
      @color == "red" && "bg-red-100 text-red-800"
    ]}>
      <%= @text %> (<%= @score %>/100)
    </div>
    """
  end
  
  @doc """
  Performance metric display.
  """
  def performance_metric(assigns) do
    ~H"""
    <div class="flex items-center justify-between">
      <span class="text-sm text-gray-600"><%= @label %></span>
      <div class="flex items-center space-x-2">
        <span class="text-sm font-medium text-gray-900"><%= @value %></span>
        <.status_indicator status={@status} />
      </div>
    </div>
    """
  end
  
  @doc """
  Status indicator component.
  """
  def status_indicator(assigns) do
    ~H"""
    <%= case @status do %>
      <% :good -> %>
        <svg class="w-4 h-4 text-green-500" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" />
        </svg>
      <% :warning -> %>
        <svg class="w-4 h-4 text-yellow-500" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" />
        </svg>
      <% :bad -> %>
        <svg class="w-4 h-4 text-red-500" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" />
        </svg>
      <% _ -> %>
        <div class="w-4 h-4 bg-gray-300 rounded-full"></div>
    <% end %>
    """
  end
  
  @doc """
  Execution plan tree visualization.
  """
  def execution_plan_tree(assigns) do
    ~H"""
    <div class="execution-plan font-mono text-xs">
      <.plan_node node={@plan} level={0} />
    </div>
    """
  end
  
  def plan_node(assigns) do
    ~H"""
    <div class="plan-node">
      <div 
        class="flex items-start hover:bg-gray-100 rounded px-2 py-1"
        style={"margin-left: #{@level * 20}px"}
      >
        <span class="text-gray-500 mr-2">→</span>
        <div class="flex-1">
          <span class="font-medium text-gray-700"><%= @node.operation %></span>
          <%= if @node[:cost] do %>
            <span class="ml-2 text-gray-500">(cost=<%= @node.cost %>)</span>
          <% end %>
          <%= if @node[:rows] do %>
            <span class="ml-2 text-gray-500">(rows=<%= @node.rows %>)</span>
          <% end %>
          
          <%= if @node[:details] do %>
            <div class="text-gray-600 mt-1"><%= @node.details %></div>
          <% end %>
        </div>
      </div>
      
      <%= for child <- @node[:children] || [] do %>
        <.plan_node node={child} level={@level + 1} />
      <% end %>
    </div>
    """
  end
  
  @doc """
  Suggestion item component.
  """
  def suggestion_item(assigns) do
    ~H"""
    <div class="flex items-start space-x-2">
      <div class={[
        "mt-0.5 w-5 h-5 rounded-full flex items-center justify-center text-xs text-white",
        priority_color(@suggestion.priority)
      ]}>
        <%= priority_number(@suggestion.priority) %>
      </div>
      <div class="flex-1">
        <div class="text-sm font-medium text-gray-900">
          <%= @suggestion.title %>
        </div>
        <div class="text-xs text-gray-600 mt-1">
          <%= @suggestion.description %>
        </div>
        <%= if @suggestion[:sql_example] do %>
          <div class="mt-2 p-2 bg-gray-900 text-gray-100 rounded text-xs font-mono">
            <%= @suggestion.sql_example %>
          </div>
        <% end %>
        <%= if @suggestion[:action] do %>
          <button
            type="button"
            class="mt-2 text-xs text-blue-600 hover:text-blue-800"
            phx-click={@suggestion.action}
          >
            Apply Suggestion →
          </button>
        <% end %>
      </div>
    </div>
    """
  end
  
  @doc """
  Query rewrite option component.
  """
  def rewrite_option(assigns) do
    ~H"""
    <div class="flex items-center justify-between p-2 rounded hover:bg-gray-50">
      <div class="flex items-center space-x-3">
        <%= if @applicable do %>
          <div class="w-2 h-2 bg-green-400 rounded-full"></div>
        <% else %>
          <div class="w-2 h-2 bg-gray-300 rounded-full"></div>
        <% end %>
        <div>
          <div class="text-sm font-medium text-gray-700">
            <%= humanize_rewrite_type(@type) %>
          </div>
          <div class="text-xs text-gray-500">
            <%= @description %>
          </div>
        </div>
      </div>
      <%= if @applicable do %>
        <button
          type="button"
          class="px-3 py-1 text-xs bg-blue-100 text-blue-700 hover:bg-blue-200 rounded"
          phx-click="apply_rewrite"
          phx-value-type={@type}
        >
          Apply
        </button>
      <% end %>
    </div>
    """
  end
  
  # Helper functions
  
  defp calculate_score(query) do
    base_score = 100
    
    # Deduct points for various issues
    score = base_score
    score = if uses_select_star?(query), do: score - 10, else: score
    score = if has_missing_indexes?(query), do: score - 20, else: score
    score = if has_expensive_operations?(query), do: score - 15, else: score
    score = if has_cartesian_join?(query), do: score - 30, else: score
    score = if too_many_joins?(query), do: score - 10, else: score
    
    max(0, score)
  end
  
  defp uses_select_star?(query) do
    "*" in (query[:select] || [])
  end
  
  defp has_missing_indexes?(query) do
    # Check if WHERE columns have indexes
    query[:where] && length(query[:where]) > 2
  end
  
  defp has_expensive_operations?(query) do
    # Check for DISTINCT, GROUP BY without indexes, etc
    query[:distinct] || (query[:group_by] && length(query[:group_by]) > 3)
  end
  
  defp has_cartesian_join?(query) do
    # Check for joins without conditions
    Enum.any?(query[:joins] || [], fn join ->
      !join[:on]
    end)
  end
  
  defp too_many_joins?(query) do
    length(query[:joins] || []) > 5
  end
  
  defp complexity_status("High"), do: :bad
  defp complexity_status("Medium"), do: :warning
  defp complexity_status("Low"), do: :good
  defp complexity_status(_), do: :neutral
  
  defp cost_status(nil), do: :neutral
  defp cost_status(cost) when cost < 100, do: :good
  defp cost_status(cost) when cost < 1000, do: :warning
  defp cost_status(_), do: :bad
  
  defp index_status("Full"), do: :good
  defp index_status("Partial"), do: :warning
  defp index_status("None"), do: :bad
  defp index_status(_), do: :neutral
  
  defp format_cost(nil), do: "N/A"
  defp format_cost(cost) when cost < 1000, do: "#{cost}"
  defp format_cost(cost), do: "#{Float.round(cost / 1000, 1)}K"
  
  defp format_number(nil), do: "N/A"
  defp format_number(n) when n < 1000, do: "#{n}"
  defp format_number(n) when n < 1_000_000, do: "#{Float.round(n / 1000, 1)}K"
  defp format_number(n), do: "#{Float.round(n / 1_000_000, 1)}M"
  
  defp priority_color(:high), do: "bg-red-500"
  defp priority_color(:medium), do: "bg-yellow-500"
  defp priority_color(:low), do: "bg-blue-500"
  defp priority_color(_), do: "bg-gray-500"
  
  defp priority_number(:high), do: "1"
  defp priority_number(:medium), do: "2"
  defp priority_number(:low), do: "3"
  defp priority_number(_), do: "?"
  
  defp check_exists_rewrite(query) do
    # Check if IN can be replaced with EXISTS
    Enum.any?(query[:where] || [], fn condition ->
      condition[:operator] == "IN" && condition[:subquery]
    end)
  end
  
  defp check_predicate_pushdown(query) do
    # Check if predicates can be pushed down to subqueries
    not Enum.empty?(query[:subqueries] || []) && not Enum.empty?(query[:where] || [])
  end
  
  defp check_distinct_elimination(query) do
    # Check if DISTINCT is unnecessary
    query[:distinct] && query[:unique_key]
  end
  
  defp check_subquery_combination(query) do
    # Check if multiple subqueries can be combined
    length(query[:subqueries] || []) > 1
  end
  
  defp humanize_rewrite_type(type) do
    type
    |> to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end