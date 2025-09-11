defmodule SelectoComponents.Query.SubselectBuilder do
  @moduledoc """
  Visual subquery builder component for creating and managing nested queries.
  """
  
  use Phoenix.LiveComponent
  alias Phoenix.LiveView.JS
  
  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(
       query_tree: %{
         id: generate_id(),
         type: :main,
         select: [],
         from: nil,
         where: [],
         joins: [],
         group_by: [],
         order_by: [],
         subqueries: []
       },
       selected_node: nil,
       drag_source: nil,
       drag_target: nil,
       preview_sql: "",
       performance_hints: [],
       saved_templates: []
     )}
  end
  
  @impl true
  def update(assigns, socket) do
    socket = 
      socket
      |> assign(assigns)
      |> update_preview()
      |> analyze_performance()
    
    {:ok, socket}
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <div 
      id={@id}
      class="subselect-builder"
      phx-hook="SubselectBuilder"
    >
      <div class="grid grid-cols-12 gap-4 h-[600px]">
        <%!-- Left Panel: Query Tree --%>
        <div class="col-span-4 bg-gray-50 rounded-lg p-4 overflow-y-auto">
          <h3 class="text-sm font-medium text-gray-700 mb-3">Query Structure</h3>
          <.query_tree_node 
            node={@query_tree}
            selected_id={@selected_node}
            level={0}
            target={@myself}
          />
        </div>
        
        <%!-- Center Panel: Visual Builder --%>
        <div class="col-span-5 bg-white rounded-lg border border-gray-200 p-4">
          <div class="flex items-center justify-between mb-4">
            <h3 class="text-sm font-medium text-gray-700">Visual Query Builder</h3>
            <div class="flex space-x-2">
              <button
                type="button"
                class="px-3 py-1 text-xs bg-blue-100 text-blue-700 hover:bg-blue-200 rounded"
                phx-click="add_subquery"
                phx-target={@myself}
              >
                + Add Subquery
              </button>
              <button
                type="button"
                class="px-3 py-1 text-xs bg-gray-100 text-gray-700 hover:bg-gray-200 rounded"
                phx-click="clear_query"
                phx-target={@myself}
              >
                Clear
              </button>
            </div>
          </div>
          
          <div class="space-y-4">
            <%!-- Visual query canvas --%>
            <div 
              class="query-canvas border-2 border-dashed border-gray-300 rounded-lg p-4 min-h-[400px]"
              phx-drop="drop_component"
              phx-dragover="dragover_canvas"
              phx-target={@myself}
            >
              <.visual_query_builder 
                query={get_selected_query(@query_tree, @selected_node)}
                target={@myself}
              />
            </div>
            
            <%!-- Component palette --%>
            <div class="border-t pt-4">
              <h4 class="text-xs text-gray-500 uppercase mb-2">Drag components to canvas</h4>
              <div class="grid grid-cols-4 gap-2">
                <.draggable_component type="select" label="SELECT" />
                <.draggable_component type="from" label="FROM" />
                <.draggable_component type="where" label="WHERE" />
                <.draggable_component type="join" label="JOIN" />
                <.draggable_component type="group" label="GROUP BY" />
                <.draggable_component type="having" label="HAVING" />
                <.draggable_component type="order" label="ORDER BY" />
                <.draggable_component type="subquery" label="SUBQUERY" />
              </div>
            </div>
          </div>
        </div>
        
        <%!-- Right Panel: Preview & Hints --%>
        <div class="col-span-3 space-y-4">
          <%!-- SQL Preview --%>
          <div class="bg-gray-900 text-gray-100 rounded-lg p-4">
            <h3 class="text-xs uppercase text-gray-400 mb-2">SQL Preview</h3>
            <pre class="text-xs font-mono overflow-x-auto"><%= @preview_sql %></pre>
            <button
              type="button"
              class="mt-2 text-xs text-blue-400 hover:text-blue-300"
              phx-click={JS.dispatch("copy_to_clipboard", detail: %{text: @preview_sql})}
            >
              Copy SQL
            </button>
          </div>
          
          <%!-- Performance Hints --%>
          <%= if not Enum.empty?(@performance_hints) do %>
            <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
              <h3 class="text-xs font-medium text-yellow-800 mb-2">
                Performance Hints
              </h3>
              <ul class="space-y-1">
                <%= for hint <- @performance_hints do %>
                  <li class="text-xs text-yellow-700 flex items-start">
                    <span class="text-yellow-500 mr-1">•</span>
                    <%= hint %>
                  </li>
                <% end %>
              </ul>
            </div>
          <% end %>
          
          <%!-- Saved Templates --%>
          <div class="bg-white border border-gray-200 rounded-lg p-4">
            <h3 class="text-xs font-medium text-gray-700 mb-2">Templates</h3>
            <div class="space-y-1">
              <%= for template <- @saved_templates do %>
                <button
                  type="button"
                  class="w-full text-left px-2 py-1 text-xs hover:bg-gray-50 rounded"
                  phx-click="load_template"
                  phx-value-id={template.id}
                  phx-target={@myself}
                >
                  <%= template.name %>
                </button>
              <% end %>
              <button
                type="button"
                class="w-full px-2 py-1 text-xs text-blue-600 hover:bg-blue-50 rounded"
                phx-click="save_as_template"
                phx-target={@myself}
              >
                + Save as Template
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
  
  @doc """
  Query tree node component for hierarchical display.
  """
  def query_tree_node(assigns) do
    ~H"""
    <div class="query-tree-node">
      <div 
        class={[
          "flex items-center px-2 py-1 rounded cursor-pointer",
          @selected_id == @node.id && "bg-blue-100",
          @selected_id != @node.id && "hover:bg-gray-100"
        ]}
        style={"padding-left: #{@level * 20 + 8}px"}
        phx-click="select_node"
        phx-value-id={@node.id}
        phx-target={@target}
      >
        <%= if not Enum.empty?(@node[:subqueries] || []) do %>
          <svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z" />
          </svg>
        <% end %>
        
        <span class="text-xs">
          <%= query_node_label(@node) %>
        </span>
        
        <%= if @node.type == :subquery do %>
          <button
            type="button"
            class="ml-auto text-red-400 hover:text-red-600"
            phx-click="remove_subquery"
            phx-value-id={@node.id}
            phx-target={@target}
          >
            <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        <% end %>
      </div>
      
      <%= for subquery <- @node[:subqueries] || [] do %>
        <.query_tree_node 
          node={subquery}
          selected_id={@selected_id}
          level={@level + 1}
          target={@target}
        />
      <% end %>
    </div>
    """
  end
  
  @doc """
  Visual query builder component.
  """
  def visual_query_builder(assigns) do
    ~H"""
    <div class="visual-query space-y-3">
      <%!-- SELECT clause --%>
      <%= if not Enum.empty?(@query[:select] || []) do %>
        <div class="query-clause">
          <div class="text-xs font-medium text-gray-600 mb-1">SELECT</div>
          <div class="flex flex-wrap gap-1">
            <%= for field <- @query[:select] || [] do %>
              <span class="px-2 py-1 bg-blue-100 text-blue-700 text-xs rounded">
                <%= field %>
                <button
                  type="button"
                  class="ml-1 text-blue-500"
                  phx-click="remove_field"
                  phx-value-clause="select"
                  phx-value-field={field}
                  phx-target={@target}
                >
                  ×
                </button>
              </span>
            <% end %>
          </div>
        </div>
      <% end %>
      
      <%!-- FROM clause --%>
      <%= if @query[:from] do %>
        <div class="query-clause">
          <div class="text-xs font-medium text-gray-600 mb-1">FROM</div>
          <div class="px-2 py-1 bg-green-100 text-green-700 text-xs rounded inline-block">
            <%= @query.from %>
          </div>
        </div>
      <% end %>
      
      <%!-- WHERE clause --%>
      <%= if not Enum.empty?(@query[:where] || []) do %>
        <div class="query-clause">
          <div class="text-xs font-medium text-gray-600 mb-1">WHERE</div>
          <div class="space-y-1">
            <%= for condition <- @query[:where] || [] do %>
              <div class="px-2 py-1 bg-yellow-100 text-yellow-700 text-xs rounded">
                <%= format_condition(condition) %>
                <button
                  type="button"
                  class="ml-1 text-yellow-600"
                  phx-click="remove_condition"
                  phx-value-id={condition[:id]}
                  phx-target={@target}
                >
                  ×
                </button>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
      
      <%!-- Subqueries --%>
      <%= if not Enum.empty?(@query[:subqueries] || []) do %>
        <div class="query-clause">
          <div class="text-xs font-medium text-gray-600 mb-1">SUBQUERIES</div>
          <div class="space-y-2">
            <%= for subquery <- @query[:subqueries] || [] do %>
              <div class="border-l-4 border-purple-400 bg-purple-50 p-2 rounded">
                <div class="text-xs text-purple-700">
                  <%= subquery[:alias] || "Subquery" %>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
  
  @doc """
  Draggable component for the palette.
  """
  def draggable_component(assigns) do
    ~H"""
    <div
      draggable="true"
      class="px-3 py-2 bg-gray-100 text-gray-700 text-xs text-center rounded cursor-move hover:bg-gray-200"
      phx-hook="DraggableQueryComponent"
      data-type={@type}
      id={"component-#{@type}"}
    >
      <%= @label %>
    </div>
    """
  end
  
  @impl true
  def handle_event("select_node", %{"id" => id}, socket) do
    {:noreply, assign(socket, selected_node: id)}
  end
  
  @impl true
  def handle_event("add_subquery", _, socket) do
    new_subquery = %{
      id: generate_id(),
      type: :subquery,
      alias: "sub_#{:rand.uniform(1000)}",
      select: [],
      from: nil,
      where: [],
      subqueries: []
    }
    
    socket = update_selected_query(socket, fn query ->
      Map.update(query, :subqueries, [new_subquery], &(&1 ++ [new_subquery]))
    end)
    
    {:noreply, socket |> update_preview() |> analyze_performance()}
  end
  
  @impl true
  def handle_event("remove_subquery", %{"id" => id}, socket) do
    socket = update_selected_query(socket, fn query ->
      Map.update(query, :subqueries, [], fn subqueries ->
        Enum.reject(subqueries, & &1.id == id)
      end)
    end)
    
    {:noreply, socket |> update_preview() |> analyze_performance()}
  end
  
  @impl true
  def handle_event("drop_component", %{"type" => type, "target" => _target}, socket) do
    socket = handle_component_drop(socket, type)
    {:noreply, socket |> update_preview() |> analyze_performance()}
  end
  
  @impl true
  def handle_event("save_as_template", _, socket) do
    template = %{
      id: generate_id(),
      name: "Template #{length(socket.assigns.saved_templates) + 1}",
      query: socket.assigns.query_tree,
      created_at: DateTime.utc_now()
    }
    
    {:noreply, update(socket, :saved_templates, &(&1 ++ [template]))}
  end
  
  @impl true
  def handle_event("load_template", %{"id" => id}, socket) do
    template = Enum.find(socket.assigns.saved_templates, & &1.id == id)
    
    if template do
      {:noreply, 
       socket
       |> assign(query_tree: template.query)
       |> update_preview()
       |> analyze_performance()}
    else
      {:noreply, socket}
    end
  end
  
  # Private functions
  
  defp generate_id do
    "node_#{:rand.uniform(100000)}"
  end
  
  defp get_selected_query(tree, nil), do: tree
  defp get_selected_query(tree, selected_id) do
    find_query_by_id(tree, selected_id) || tree
  end
  
  defp find_query_by_id(query, id) do
    if query.id == id do
      query
    else
      Enum.find_value(query[:subqueries] || [], fn sub ->
        find_query_by_id(sub, id)
      end)
    end
  end
  
  defp update_selected_query(socket, update_fn) do
    selected_id = socket.assigns.selected_node
    query_tree = update_query_node(socket.assigns.query_tree, selected_id, update_fn)
    assign(socket, query_tree: query_tree)
  end
  
  defp update_query_node(query, nil, update_fn), do: update_fn.(query)
  defp update_query_node(query, selected_id, update_fn) do
    if query.id == selected_id do
      update_fn.(query)
    else
      Map.update(query, :subqueries, [], fn subqueries ->
        Enum.map(subqueries, &update_query_node(&1, selected_id, update_fn))
      end)
    end
  end
  
  defp handle_component_drop(socket, "select") do
    # Add field selection dialog
    update_selected_query(socket, fn query ->
      Map.update(query, :select, ["*"], &(&1 ++ ["new_field"]))
    end)
  end
  
  defp handle_component_drop(socket, "from") do
    update_selected_query(socket, fn query ->
      Map.put(query, :from, "table_name")
    end)
  end
  
  defp handle_component_drop(socket, "where") do
    update_selected_query(socket, fn query ->
      condition = %{
        id: generate_id(),
        field: "field",
        operator: "=",
        value: "value"
      }
      Map.update(query, :where, [condition], &(&1 ++ [condition]))
    end)
  end
  
  defp handle_component_drop(socket, "subquery") do
    handle_event("add_subquery", %{}, socket) |> elem(1)
  end
  
  defp handle_component_drop(socket, _type), do: socket
  
  defp update_preview(socket) do
    sql = generate_sql(socket.assigns.query_tree)
    assign(socket, preview_sql: sql)
  end
  
  defp generate_sql(query) do
    select = if query[:select], do: "SELECT #{Enum.join(query.select, ", ")}", else: "SELECT *"
    from = if query[:from], do: "\nFROM #{query.from}", else: ""
    
    where = 
      if not Enum.empty?(query[:where] || []) do
        conditions = Enum.map(query[:where], &format_condition/1)
        "\nWHERE #{Enum.join(conditions, " AND ")}"
      else
        ""
      end
    
    subqueries = 
      if not Enum.empty?(query[:subqueries] || []) do
        subs = Enum.map(query[:subqueries], fn sub ->
          "\n-- Subquery: #{sub[:alias]}\n(#{generate_sql(sub)}) AS #{sub[:alias]}"
        end)
        Enum.join(subs, ",\n")
      else
        ""
      end
    
    "#{select}#{from}#{where}#{subqueries}"
  end
  
  defp format_condition(%{field: field, operator: op, value: value}) do
    "#{field} #{op} '#{value}'"
  end
  defp format_condition(_), do: "condition"
  
  defp analyze_performance(socket) do
    hints = []
    query = socket.assigns.query_tree
    
    hints = 
      hints
      |> check_missing_indexes(query)
      |> check_subquery_performance(query)
      |> check_select_star(query)
    
    assign(socket, performance_hints: hints)
  end
  
  defp check_missing_indexes(hints, query) do
    if query[:where] && Enum.empty?(query[:where]) == false do
      hints ++ ["Consider adding indexes on WHERE clause columns"]
    else
      hints
    end
  end
  
  defp check_subquery_performance(hints, query) do
    subquery_count = length(query[:subqueries] || [])
    if subquery_count > 2 do
      hints ++ ["Multiple subqueries detected. Consider using JOINs for better performance"]
    else
      hints
    end
  end
  
  defp check_select_star(hints, query) do
    if "*" in (query[:select] || []) do
      hints ++ ["Avoid SELECT *. Specify only needed columns"]
    else
      hints
    end
  end
  
  defp query_node_label(%{type: :main}), do: "Main Query"
  defp query_node_label(%{type: :subquery, alias: alias}), do: "Subquery: #{alias}"
  defp query_node_label(_), do: "Query"
  
  @doc """
  JavaScript hooks for subselect builder.
  """
  def __hooks__() do
    %{
      "SubselectBuilder" => %{
        mounted: """
        // Initialize drag and drop
        this.draggedElement = null;
        this.draggedData = null;
        
        // Copy to clipboard
        this.el.addEventListener('copy_to_clipboard', (e) => {
          navigator.clipboard.writeText(e.detail.text);
          
          // Show copied feedback
          const button = e.target;
          const originalText = button.textContent;
          button.textContent = 'Copied!';
          setTimeout(() => {
            button.textContent = originalText;
          }, 2000);
        });
        """
      },
      
      "DraggableQueryComponent" => %{
        mounted: """
        this.el.addEventListener('dragstart', (e) => {
          e.dataTransfer.effectAllowed = 'copy';
          e.dataTransfer.setData('component-type', this.el.dataset.type);
          this.el.classList.add('opacity-50');
        });
        
        this.el.addEventListener('dragend', (e) => {
          this.el.classList.remove('opacity-50');
        });
        """
      }
    }
  end
end