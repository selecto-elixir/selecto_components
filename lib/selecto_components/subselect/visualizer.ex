defmodule SelectoComponents.Subselect.Visualizer do
  @moduledoc """
  Visualizes nested subqueries with interactive tree structure.
  """

  use Phoenix.Component
  import Phoenix.LiveView
  alias Phoenix.LiveView.JS

  @doc """
  Renders a visual tree of nested subqueries.
  """
  def subquery_tree(assigns) do
    assigns = assign_defaults(assigns)
    
    ~H"""
    <div class="subquery-visualizer" id={"subquery-viz-#{@id}"}>
      <div class="bg-white rounded-lg shadow-lg">
        <div class="px-6 py-4 border-b bg-gray-50">
          <div class="flex items-center justify-between">
            <h3 class="text-lg font-semibold">Query Structure</h3>
            <div class="flex space-x-2">
              <button
                type="button"
                phx-click="expand_all"
                class="px-3 py-1 bg-gray-600 text-white rounded text-sm hover:bg-gray-700"
              >
                Expand All
              </button>
              <button
                type="button"
                phx-click="collapse_all"
                class="px-3 py-1 bg-gray-600 text-white rounded text-sm hover:bg-gray-700"
              >
                Collapse All
              </button>
            </div>
          </div>
        </div>
        
        <div class="p-6">
          <div class="query-tree">
            <.query_node
              query={@query}
              level={0}
              expanded={@expanded_nodes}
              selected={@selected_node}
            />
          </div>
          
          <%= if @selected_node do %>
            <div class="mt-6 p-4 bg-gray-50 rounded-lg">
              <h4 class="font-medium text-sm text-gray-700 mb-3">Query Details</h4>
              <.query_details query={@selected_node} />
            </div>
          <% end %>
        </div>
        
        <!-- Performance Indicators -->
        <div class="px-6 py-4 border-t bg-gray-50">
          <h4 class="font-medium text-sm text-gray-700 mb-3">Performance Analysis</h4>
          <div class="grid grid-cols-3 gap-4">
            <.performance_metric
              label="Complexity"
              value={@complexity_score}
              max={10}
              color={complexity_color(@complexity_score)}
            />
            <.performance_metric
              label="Nesting Depth"
              value={@nesting_depth}
              max={5}
              color={depth_color(@nesting_depth)}
            />
            <.performance_metric
              label="Subqueries"
              value={@subquery_count}
              max={20}
              color={count_color(@subquery_count)}
            />
          </div>
        </div>
      </div>
    </div>
    """
  end

  def query_node(assigns) do
    node_id = generate_node_id(assigns.query)
    is_expanded = MapSet.member?(assigns.expanded, node_id)
    is_selected = assigns.selected && assigns.selected.id == assigns.query.id
    has_children = has_subqueries?(assigns.query)
    
    ~H"""
    <div class={"query-node ml-#{@level * 4}"}>
      <div
        class={"flex items-center p-2 rounded cursor-pointer transition-colors #{if is_selected, do: "bg-blue-100", else: "hover:bg-gray-100"}"}
        phx-click="select_node"
        phx-value-id={assigns.query.id}
      >
        <%= if has_children do %>
          <button
            type="button"
            phx-click="toggle_node"
            phx-value-id={node_id}
            class="mr-2"
          >
            <.icon
              name={if is_expanded, do: "hero-chevron-down", else: "hero-chevron-right"}
              class="w-4 h-4 text-gray-500"
            />
          </button>
        <% else %>
          <div class="w-6"></div>
        <% end %>
        
        <div class={"query-type-badge px-2 py-1 rounded text-xs font-medium mr-2 #{type_badge_color(assigns.query.type)}"}>
          <%= String.upcase(assigns.query.type) %>
        </div>
        
        <div class="flex-1">
          <div class="text-sm font-medium"><%= query_label(assigns.query) %></div>
          <div class="text-xs text-gray-500"><%= query_summary(assigns.query) %></div>
        </div>
        
        <%= if assigns.query.performance do %>
          <div class="ml-2">
            <.performance_badge performance={assigns.query.performance} />
          </div>
        <% end %>
      </div>
      
      <%= if is_expanded && has_children do %>
        <div class="ml-4 mt-1">
          <%= for subquery <- get_subqueries(assigns.query) do %>
            <.query_node
              query={subquery}
              level={@level + 1}
              expanded={@expanded}
              selected={@selected}
            />
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  def query_details(assigns) do
    ~H"""
    <div class="query-details space-y-3">
      <div>
        <label class="text-xs text-gray-600">Type</label>
        <p class="text-sm font-medium"><%= String.upcase(@query.type) %></p>
      </div>
      
      <%= if @query.sql do %>
        <div>
          <label class="text-xs text-gray-600">SQL</label>
          <pre class="mt-1 p-2 bg-gray-900 text-gray-100 rounded text-xs overflow-x-auto">
<%= format_sql(@query.sql) %>
          </pre>
        </div>
      <% end %>
      
      <%= if @query.tables do %>
        <div>
          <label class="text-xs text-gray-600">Tables</label>
          <div class="mt-1 flex flex-wrap gap-1">
            <%= for table <- @query.tables do %>
              <span class="px-2 py-1 bg-gray-200 rounded text-xs"><%= table %></span>
            <% end %>
          </div>
        </div>
      <% end %>
      
      <%= if @query.conditions do %>
        <div>
          <label class="text-xs text-gray-600">Conditions</label>
          <ul class="mt-1 space-y-1">
            <%= for condition <- @query.conditions do %>
              <li class="text-sm text-gray-700">• <%= condition %></li>
            <% end %>
          </ul>
        </div>
      <% end %>
      
      <div class="flex space-x-2 pt-2">
        <button
          type="button"
          phx-click="optimize_query"
          phx-value-id={@query.id}
          class="px-3 py-1 bg-blue-600 text-white rounded text-xs hover:bg-blue-700"
        >
          Optimize
        </button>
        <button
          type="button"
          phx-click="extract_query"
          phx-value-id={@query.id}
          class="px-3 py-1 bg-gray-600 text-white rounded text-xs hover:bg-gray-700"
        >
          Extract as CTE
        </button>
      </div>
    </div>
    """
  end

  def performance_metric(assigns) do
    percentage = min(100, round(@value / @max * 100))
    
    ~H"""
    <div class="performance-metric">
      <div class="flex justify-between text-xs mb-1">
        <span class="text-gray-600"><%= @label %></span>
        <span class="font-medium"><%= @value %></span>
      </div>
      <div class="w-full bg-gray-200 rounded-full h-2">
        <div
          class={"h-2 rounded-full transition-all #{@color}"}
          style={"width: #{percentage}%"}
        >
        </div>
      </div>
    </div>
    """
  end

  def performance_badge(assigns) do
    {color, icon} = case assigns.performance.score do
      score when score >= 80 -> {"bg-green-100 text-green-700", "hero-check-circle"}
      score when score >= 60 -> {"bg-yellow-100 text-yellow-700", "hero-exclamation-triangle"}
      _ -> {"bg-red-100 text-red-700", "hero-x-circle"}
    end
    
    ~H"""
    <div class={"performance-badge px-2 py-1 rounded-full text-xs font-medium flex items-center #{color}"}>
      <.icon name={icon} class="w-3 h-3 mr-1" />
      <%= @performance.score %>%
    </div>
    """
  end

  @doc """
  Interactive query builder with drag-and-drop.
  """
  def query_builder(assigns) do
    ~H"""
    <div class="query-builder-container">
      <div class="grid grid-cols-2 gap-4">
        <!-- Available Queries -->
        <div class="bg-gray-50 rounded-lg p-4">
          <h4 class="font-medium text-sm text-gray-700 mb-3">Available Queries</h4>
          <div class="space-y-2">
            <%= for template <- @query_templates do %>
              <div
                class="query-template bg-white border rounded p-3 cursor-move hover:shadow-md transition-shadow"
                draggable="true"
                phx-hook="DraggableQuery"
                data-query-id={template.id}
              >
                <div class="flex items-center justify-between">
                  <div>
                    <div class="font-medium text-sm"><%= template.name %></div>
                    <div class="text-xs text-gray-500"><%= template.description %></div>
                  </div>
                  <.icon name="hero-arrows-pointing-out" class="w-4 h-4 text-gray-400" />
                </div>
              </div>
            <% end %>
          </div>
        </div>
        
        <!-- Query Composition Area -->
        <div class="bg-white border-2 border-dashed border-gray-300 rounded-lg p-4">
          <h4 class="font-medium text-sm text-gray-700 mb-3">Query Composition</h4>
          <div
            class="composition-area min-h-[200px]"
            id="query-composition"
            phx-hook="QueryComposition"
            phx-drop="drop_query"
          >
            <%= if @composed_query do %>
              <.composed_query_view query={@composed_query} />
            <% else %>
              <div class="text-center py-8 text-gray-400">
                <.icon name="hero-cursor-arrow-ripple" class="w-8 h-8 mx-auto mb-2" />
                <p class="text-sm">Drag queries here to compose</p>
              </div>
            <% end %>
          </div>
        </div>
      </div>
      
      <!-- Optimization Hints -->
      <%= if @optimization_hints != [] do %>
        <div class="mt-4 p-4 bg-yellow-50 border border-yellow-200 rounded-lg">
          <h4 class="font-medium text-sm text-yellow-800 mb-2">Optimization Hints</h4>
          <ul class="space-y-1">
            <%= for hint <- @optimization_hints do %>
              <li class="text-sm text-yellow-700 flex items-start">
                <.icon name="hero-light-bulb" class="w-4 h-4 mr-2 mt-0.5" />
                <%= hint %>
              </li>
            <% end %>
          </ul>
        </div>
      <% end %>
    </div>
    """
  end

  def composed_query_view(assigns) do
    ~H"""
    <div class="composed-query">
      <div class="bg-blue-50 border border-blue-200 rounded p-3">
        <div class="flex items-center justify-between mb-2">
          <span class="font-medium text-sm text-blue-700">Main Query</span>
          <button
            type="button"
            phx-click="clear_composition"
            class="text-red-500 hover:text-red-700"
          >
            <.icon name="hero-trash" class="w-4 h-4" />
          </button>
        </div>
        
        <div class="space-y-2">
          <%= for {position, subquery} <- @query.subqueries do %>
            <div class="ml-4 bg-white border border-gray-200 rounded p-2">
              <div class="flex items-center justify-between">
                <span class="text-xs text-gray-600"><%= position %></span>
                <span class="text-xs font-medium"><%= subquery.name %></span>
              </div>
            </div>
          <% end %>
        </div>
      </div>
      
      <div class="mt-3 flex space-x-2">
        <button
          type="button"
          phx-click="preview_composed"
          class="px-3 py-1 bg-blue-600 text-white rounded text-sm hover:bg-blue-700"
        >
          Preview SQL
        </button>
        <button
          type="button"
          phx-click="save_template"
          class="px-3 py-1 bg-gray-600 text-white rounded text-sm hover:bg-gray-700"
        >
          Save as Template
        </button>
      </div>
    </div>
    """
  end

  # Helper functions

  defp assign_defaults(assigns) do
    assigns
    |> assign_new(:id, fn -> Ecto.UUID.generate() end)
    |> assign_new(:query, fn -> default_query() end)
    |> assign_new(:expanded_nodes, fn -> MapSet.new() end)
    |> assign_new(:selected_node, fn -> nil end)
    |> assign_new(:complexity_score, fn -> 0 end)
    |> assign_new(:nesting_depth, fn -> 0 end)
    |> assign_new(:subquery_count, fn -> 0 end)
    |> assign_new(:query_templates, fn -> [] end)
    |> assign_new(:composed_query, fn -> nil end)
    |> assign_new(:optimization_hints, fn -> [] end)
  end

  defp default_query do
    %{
      id: Ecto.UUID.generate(),
      type: "select",
      sql: "SELECT * FROM table",
      tables: ["table"],
      conditions: [],
      subqueries: [],
      performance: nil
    }
  end

  defp generate_node_id(query), do: "node-#{query.id}"

  defp has_subqueries?(query) do
    query[:subqueries] && length(query.subqueries) > 0
  end

  defp get_subqueries(query), do: query[:subqueries] || []

  defp query_label(query) do
    case query.type do
      "select" -> "SELECT Query"
      "exists" -> "EXISTS Subquery"
      "in" -> "IN Subquery"
      "scalar" -> "Scalar Subquery"
      _ -> "Subquery"
    end
  end

  defp query_summary(query) do
    tables = if query[:tables], do: "From: #{Enum.join(query.tables, ", ")}", else: ""
    conditions = if query[:conditions] && length(query.conditions) > 0,
                 do: " | #{length(query.conditions)} conditions",
                 else: ""
    
    "#{tables}#{conditions}"
  end

  defp type_badge_color("select"), do: "bg-blue-100 text-blue-700"
  defp type_badge_color("exists"), do: "bg-green-100 text-green-700"
  defp type_badge_color("in"), do: "bg-purple-100 text-purple-700"
  defp type_badge_color("scalar"), do: "bg-yellow-100 text-yellow-700"
  defp type_badge_color(_), do: "bg-gray-100 text-gray-700"

  defp complexity_color(score) when score <= 3, do: "bg-green-500"
  defp complexity_color(score) when score <= 6, do: "bg-yellow-500"
  defp complexity_color(_), do: "bg-red-500"

  defp depth_color(depth) when depth <= 2, do: "bg-green-500"
  defp depth_color(depth) when depth <= 3, do: "bg-yellow-500"
  defp depth_color(_), do: "bg-red-500"

  defp count_color(count) when count <= 5, do: "bg-green-500"
  defp count_color(count) when count <= 10, do: "bg-yellow-500"
  defp count_color(_), do: "bg-red-500"

  defp format_sql(sql) do
    sql
    |> String.replace(~r/\b(SELECT|FROM|WHERE|JOIN|ON|GROUP BY|HAVING|ORDER BY)\b/i, "\n\\1")
    |> String.trim()
  end

  defp icon(assigns) do
    ~H"""
    <svg class={@class} fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <%= case @name do %>
        <% "hero-chevron-down" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
        <% "hero-chevron-right" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
        <% "hero-check-circle" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
        <% "hero-exclamation-triangle" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
        <% "hero-x-circle" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.75 9.75l4.5 4.5m0-4.5l-4.5 4.5M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
        <% "hero-arrows-pointing-out" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3.75 3.75v4.5m0-4.5h4.5m-4.5 0L9 9M3.75 20.25v-4.5m0 4.5h4.5m-4.5 0L9 15M20.25 3.75h-4.5m4.5 0v4.5m0-4.5L15 9m5.25 11.25h-4.5m4.5 0v-4.5m0 4.5L15 15" />
        <% "hero-cursor-arrow-ripple" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.042 21.672L13.684 16.6m0 0l-2.51 2.225.569-9.47 5.227 7.917-3.286-.672zM12 2.25V4.5m5.834.166l-1.591 1.591M20.25 10.5H18M7.757 14.743l-1.59 1.59M6 10.5H3.75m4.007-4.243l-1.59-1.59" />
        <% "hero-light-bulb" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z" />
        <% "hero-trash" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0" />
        <% _ -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
      <% end %>
    </svg>
    """
  end

  @doc """
  JavaScript hooks for query visualization and drag-and-drop.
  """
  def __hooks__() do
    """
    export const DraggableQuery = {
      mounted() {
        this.el.addEventListener('dragstart', (e) => {
          e.dataTransfer.effectAllowed = 'move';
          e.dataTransfer.setData('query-id', this.el.dataset.queryId);
          this.el.classList.add('opacity-50');
        });
        
        this.el.addEventListener('dragend', () => {
          this.el.classList.remove('opacity-50');
        });
      }
    };
    
    export const QueryComposition = {
      mounted() {
        this.el.addEventListener('dragover', (e) => {
          e.preventDefault();
          e.dataTransfer.dropEffect = 'move';
          this.el.classList.add('bg-blue-50');
        });
        
        this.el.addEventListener('dragleave', () => {
          this.el.classList.remove('bg-blue-50');
        });
        
        this.el.addEventListener('drop', (e) => {
          e.preventDefault();
          this.el.classList.remove('bg-blue-50');
          
          const queryId = e.dataTransfer.getData('query-id');
          if (queryId) {
            this.pushEvent('drop_query', {query_id: queryId});
          }
        });
      }
    };
    """
  end
end