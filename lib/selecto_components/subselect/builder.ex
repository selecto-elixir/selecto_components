defmodule SelectoComponents.Subselect.Builder do
  @moduledoc """
  Visual builder for creating and managing subselects/subqueries.
  """

  use Phoenix.LiveComponent
  alias Phoenix.LiveView.JS

  def render(assigns) do
    ~H"""
    <div class="subselect-builder" id={"subselect-builder-#{@id}"}>
      <div class="bg-white rounded-lg shadow-lg">
        <!-- Header -->
        <div class="px-6 py-4 border-b bg-gray-50">
          <div class="flex items-center justify-between">
            <h3 class="text-lg font-semibold">Subquery Builder</h3>
            <div class="flex space-x-2">
              <button
                type="button"
                phx-click="add_subquery"
                phx-target={@myself}
                class="px-3 py-1 bg-blue-600 text-white rounded text-sm hover:bg-blue-700"
              >
                <.icon name="hero-plus" class="w-4 h-4 inline mr-1" />
                Add Subquery
              </button>
              <button
                type="button"
                phx-click="validate_query"
                phx-target={@myself}
                class="px-3 py-1 bg-green-600 text-white rounded text-sm hover:bg-green-700"
              >
                <.icon name="hero-check" class="w-4 h-4 inline mr-1" />
                Validate
              </button>
            </div>
          </div>
        </div>
        
        <div class="flex h-[600px]">
          <!-- Query Components Panel -->
          <div class="w-1/4 border-r p-4 bg-gray-50 overflow-y-auto">
            <h4 class="font-medium text-sm text-gray-700 mb-3">Query Components</h4>
            
            <div class="space-y-3">
              <.component_group title="Basic">
                <.draggable_component
                  type="select"
                  label="SELECT"
                  icon="hero-view-columns"
                  description="Choose fields"
                />
                <.draggable_component
                  type="from"
                  label="FROM"
                  icon="hero-table-cells"
                  description="Select table"
                />
                <.draggable_component
                  type="where"
                  label="WHERE"
                  icon="hero-funnel"
                  description="Filter rows"
                />
              </.component_group>
              
              <.component_group title="Advanced">
                <.draggable_component
                  type="join"
                  label="JOIN"
                  icon="hero-link"
                  description="Join tables"
                />
                <.draggable_component
                  type="group"
                  label="GROUP BY"
                  icon="hero-rectangle-group"
                  description="Group results"
                />
                <.draggable_component
                  type="having"
                  label="HAVING"
                  icon="hero-adjustments-horizontal"
                  description="Filter groups"
                />
              </.component_group>
              
              <.component_group title="Operators">
                <.draggable_component
                  type="exists"
                  label="EXISTS"
                  icon="hero-check-circle"
                  description="Check existence"
                />
                <.draggable_component
                  type="in"
                  label="IN"
                  icon="hero-arrow-down-on-square"
                  description="Value in set"
                />
                <.draggable_component
                  type="not_exists"
                  label="NOT EXISTS"
                  icon="hero-x-circle"
                  description="Check non-existence"
                />
              </.component_group>
            </div>
          </div>
          
          <!-- Query Builder Canvas -->
          <div class="flex-1 p-4">
            <div
              class="h-full border-2 border-dashed border-gray-300 rounded-lg p-4 bg-white"
              id={"query-canvas-#{@id}"}
              phx-hook="QueryCanvas"
              phx-drop="drop_component"
              phx-target={@myself}
            >
              <%= if @query_structure == %{} do %>
                <div class="h-full flex items-center justify-center text-gray-400">
                  <div class="text-center">
                    <.icon name="hero-cursor-arrow-rays" class="w-12 h-12 mx-auto mb-2" />
                    <p class="text-sm">Drag components here to build your query</p>
                  </div>
                </div>
              <% else %>
                <.query_structure structure={@query_structure} myself={@myself} />
              <% end %>
            </div>
          </div>
          
          <!-- Properties Panel -->
          <div class="w-1/3 border-l p-4 bg-gray-50">
            <%= if @selected_component do %>
              <.component_properties
                component={@selected_component}
                myself={@myself}
                schemas={@schemas}
              />
            <% else %>
              <div class="text-center py-8 text-gray-500">
                <.icon name="hero-cog-6-tooth" class="w-8 h-8 mx-auto mb-2" />
                <p class="text-sm">Select a component to configure</p>
              </div>
            <% end %>
          </div>
        </div>
        
        <!-- SQL Preview -->
        <div class="px-6 py-4 border-t bg-gray-50">
          <div class="flex items-center justify-between mb-2">
            <h4 class="font-medium text-sm text-gray-700">Generated SQL</h4>
            <div class="flex space-x-2">
              <button
                type="button"
                phx-click="copy_sql"
                phx-target={@myself}
                class="px-2 py-1 text-xs bg-gray-600 text-white rounded hover:bg-gray-700"
              >
                Copy
              </button>
              <button
                type="button"
                phx-click="test_query"
                phx-target={@myself}
                class="px-2 py-1 text-xs bg-blue-600 text-white rounded hover:bg-blue-700"
              >
                Test
              </button>
            </div>
          </div>
          <pre class="bg-gray-900 text-gray-100 p-3 rounded text-xs overflow-x-auto">
<%= generate_sql(@query_structure) %>
          </pre>
        </div>
      </div>
    </div>
    """
  end

  def component_group(assigns) do
    ~H"""
    <div class="component-group">
      <h5 class="text-xs font-medium text-gray-600 mb-2"><%= @title %></h5>
      <div class="space-y-1">
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end

  def draggable_component(assigns) do
    ~H"""
    <div
      id={"draggable-#{@type}"}
      class="draggable-component bg-white border rounded p-2 cursor-move hover:shadow-md transition-shadow"
      draggable="true"
      phx-hook="DraggableComponent"
      data-type={@type}
      data-label={@label}
    >
      <div class="flex items-center space-x-2">
        <.icon name={@icon} class="w-4 h-4 text-gray-500" />
        <div class="flex-1">
          <div class="text-sm font-medium"><%= @label %></div>
          <div class="text-xs text-gray-500"><%= @description %></div>
        </div>
      </div>
    </div>
    """
  end

  def query_structure(assigns) do
    ~H"""
    <div class="query-structure space-y-3">
      <%= for {type, config} <- @structure do %>
        <.query_component
          id={config.id}
          type={type}
          config={config}
          myself={@myself}
        />
      <% end %>
    </div>
    """
  end

  def query_component(assigns) do
    ~H"""
    <div
      class="query-component bg-blue-50 border border-blue-200 rounded p-3"
      phx-click="select_component"
      phx-target={@myself}
      phx-value-id={@id}
    >
      <div class="flex items-center justify-between">
        <div class="flex items-center space-x-2">
          <span class="text-sm font-medium text-blue-700">
            <%= String.upcase(to_string(@type)) %>
          </span>
          <span class="text-sm text-gray-600">
            <%= format_component_config(@config) %>
          </span>
        </div>
        <button
          type="button"
          phx-click="remove_component"
          phx-target={@myself}
          phx-value-id={@id}
          class="text-red-500 hover:text-red-700"
        >
          <.icon name="hero-x-mark" class="w-4 h-4" />
        </button>
      </div>
      
      <%= if @config[:subquery] do %>
        <div class="mt-2 ml-4 p-2 bg-white rounded border border-gray-200">
          <.query_structure structure={@config.subquery} myself={@myself} />
        </div>
      <% end %>
    </div>
    """
  end

  def component_properties(assigns) do
    ~H"""
    <div class="component-properties">
      <h4 class="font-medium text-sm text-gray-700 mb-3">
        <%= String.upcase(@component.type) %> Properties
      </h4>
      
      <div class="space-y-4">
        <%= case @component.type do %>
          <% "select" -> %>
            <.select_properties component={@component} myself={@myself} schemas={@schemas} />
          <% "from" -> %>
            <.from_properties component={@component} myself={@myself} schemas={@schemas} />
          <% "where" -> %>
            <.where_properties component={@component} myself={@myself} />
          <% "join" -> %>
            <.join_properties component={@component} myself={@myself} schemas={@schemas} />
          <% "group" -> %>
            <.group_properties component={@component} myself={@myself} />
          <% "exists" -> %>
            <.exists_properties component={@component} myself={@myself} />
          <% _ -> %>
            <p class="text-sm text-gray-500">No properties available</p>
        <% end %>
      </div>
      
      <div class="mt-6 pt-4 border-t">
        <button
          type="button"
          phx-click="apply_properties"
          phx-target={@myself}
          class="w-full px-3 py-2 bg-blue-600 text-white rounded text-sm hover:bg-blue-700"
        >
          Apply Changes
        </button>
      </div>
    </div>
    """
  end

  def select_properties(assigns) do
    ~H"""
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-1">Fields</label>
      <div class="space-y-2">
        <%= for {field, index} <- Enum.with_index(@component.config[:fields] || []) do %>
          <div class="flex items-center space-x-2">
            <input
              type="text"
              value={field}
              phx-blur="update_field"
              phx-target={@myself}
              phx-value-index={index}
              class="flex-1 px-2 py-1 border border-gray-300 rounded text-sm"
            />
            <button
              type="button"
              phx-click="remove_field"
              phx-target={@myself}
              phx-value-index={index}
              class="text-red-500 hover:text-red-700"
            >
              <.icon name="hero-x-mark" class="w-4 h-4" />
            </button>
          </div>
        <% end %>
      </div>
      <button
        type="button"
        phx-click="add_field"
        phx-target={@myself}
        class="mt-2 text-sm text-blue-600 hover:text-blue-700"
      >
        + Add Field
      </button>
      
      <div class="mt-4">
        <label class="flex items-center">
          <input
            type="checkbox"
            checked={@component.config[:distinct]}
            phx-change="toggle_distinct"
            phx-target={@myself}
            class="mr-2"
          />
          <span class="text-sm">DISTINCT</span>
        </label>
      </div>
    </div>
    """
  end

  def from_properties(assigns) do
    ~H"""
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-1">Table/Subquery</label>
      <select
        phx-change="update_table"
        phx-target={@myself}
        class="w-full px-3 py-2 border border-gray-300 rounded text-sm"
      >
        <option value="">Select a table...</option>
        <%= for schema <- @schemas do %>
          <option value={schema.table} selected={@component.config[:table] == schema.table}>
            <%= schema.table %>
          </option>
        <% end %>
        <option value="__subquery__" selected={@component.config[:table] == "__subquery__"}>
          (Subquery)
        </option>
      </select>
      
      <div class="mt-3">
        <label class="block text-sm font-medium text-gray-700 mb-1">Alias</label>
        <input
          type="text"
          value={@component.config[:alias]}
          phx-blur="update_alias"
          phx-target={@myself}
          class="w-full px-3 py-2 border border-gray-300 rounded text-sm"
          placeholder="Optional alias"
        />
      </div>
    </div>
    """
  end

  def where_properties(assigns) do
    ~H"""
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-1">Conditions</label>
      <div class="space-y-2">
        <%= for {condition, index} <- Enum.with_index(@component.config[:conditions] || []) do %>
          <div class="border rounded p-2">
            <div class="flex items-center space-x-2 mb-2">
              <input
                type="text"
                value={condition.field}
                phx-blur="update_condition_field"
                phx-target={@myself}
                phx-value-index={index}
                class="flex-1 px-2 py-1 border border-gray-200 rounded text-sm"
                placeholder="Field"
              />
              <select
                phx-change="update_condition_operator"
                phx-target={@myself}
                phx-value-index={index}
                class="px-2 py-1 border border-gray-200 rounded text-sm"
              >
                <option value="=" selected={condition.operator == "="} >=</option>
                <option value="!=" selected={condition.operator == "!="}>!=</option>
                <option value=">" selected={condition.operator == ">"}>&gt;</option>
                <option value=">=" selected={condition.operator == ">="}>&gt;=</option>
                <option value="<" selected={condition.operator == "<"}>&lt;</option>
                <option value="<=" selected={condition.operator == "<="}>&lt;=</option>
                <option value="IN" selected={condition.operator == "IN"}>IN</option>
                <option value="LIKE" selected={condition.operator == "LIKE"}>LIKE</option>
              </select>
              <button
                type="button"
                phx-click="remove_condition"
                phx-target={@myself}
                phx-value-index={index}
                class="text-red-500 hover:text-red-700"
              >
                <.icon name="hero-trash" class="w-4 h-4" />
              </button>
            </div>
            <input
              type="text"
              value={condition.value}
              phx-blur="update_condition_value"
              phx-target={@myself}
              phx-value-index={index}
              class="w-full px-2 py-1 border border-gray-200 rounded text-sm"
              placeholder="Value or subquery"
            />
          </div>
        <% end %>
      </div>
      <button
        type="button"
        phx-click="add_condition"
        phx-target={@myself}
        class="mt-2 text-sm text-blue-600 hover:text-blue-700"
      >
        + Add Condition
      </button>
    </div>
    """
  end

  defp join_properties(assigns) do
    ~H"""
    <div class="space-y-4">
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Join Type</label>
        <select
          phx-change="update_component_config"
          phx-target={@myself}
          name="join_type"
          class="w-full px-3 py-2 border border-gray-200 rounded"
        >
          <option value="INNER">INNER JOIN</option>
          <option value="LEFT">LEFT JOIN</option>
          <option value="RIGHT">RIGHT JOIN</option>
          <option value="FULL">FULL OUTER JOIN</option>
        </select>
      </div>
      
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Join Table</label>
        <select
          phx-change="update_component_config"
          phx-target={@myself}
          name="join_table"
          class="w-full px-3 py-2 border border-gray-200 rounded"
        >
          <option value="">Select table...</option>
          <%= for schema <- @schemas do %>
            <option value={schema.__schema__(:source)}><%= schema.__schema__(:source) %></option>
          <% end %>
        </select>
      </div>
      
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Join Condition</label>
        <input
          type="text"
          phx-change="update_component_config"
          phx-target={@myself}
          name="join_on"
          placeholder="e.g., t1.id = t2.foreign_id"
          class="w-full px-3 py-2 border border-gray-200 rounded"
        />
      </div>
    </div>
    """
  end

  defp group_properties(assigns) do
    ~H"""
    <div class="space-y-4">
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Group By Fields</label>
        <input
          type="text"
          phx-change="update_component_config"
          phx-target={@myself}
          name="group_fields"
          placeholder="e.g., category, status"
          class="w-full px-3 py-2 border border-gray-200 rounded"
        />
      </div>
      
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Having Clause</label>
        <input
          type="text"
          phx-change="update_component_config"
          phx-target={@myself}
          name="having"
          placeholder="e.g., COUNT(*) > 10"
          class="w-full px-3 py-2 border border-gray-200 rounded"
        />
      </div>
    </div>
    """
  end

  defp exists_properties(assigns) do
    ~H"""
    <div class="space-y-4">
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Exists Type</label>
        <select
          phx-change="update_component_config"
          phx-target={@myself}
          name="exists_type"
          class="w-full px-3 py-2 border border-gray-200 rounded"
        >
          <option value="EXISTS">EXISTS</option>
          <option value="NOT EXISTS">NOT EXISTS</option>
        </select>
      </div>
      
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Subquery</label>
        <textarea
          phx-change="update_component_config"
          phx-target={@myself}
          name="subquery"
          rows="4"
          placeholder="SELECT 1 FROM table WHERE ..."
          class="w-full px-3 py-2 border border-gray-200 rounded"
        />
      </div>
    </div>
    """
  end

  def mount(socket) do
    {:ok,
     socket
     |> assign(
       id: Ecto.UUID.generate(),
       query_structure: %{},
       selected_component: nil,
       schemas: [],
       validation_errors: []
     )}
  end

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  def handle_event("add_subquery", _params, socket) do
    component = %{
      id: Ecto.UUID.generate(),
      type: "select",
      config: %{fields: ["*"]}
    }
    
    query_structure = Map.put(socket.assigns.query_structure, :select, component)
    
    {:noreply, assign(socket, query_structure: query_structure, selected_component: component)}
  end

  def handle_event("drop_component", %{"type" => type}, socket) do
    component = %{
      id: Ecto.UUID.generate(),
      type: type,
      config: default_config(type)
    }
    
    query_structure = Map.put(socket.assigns.query_structure, String.to_atom(type), component)
    
    {:noreply, assign(socket, query_structure: query_structure)}
  end

  def handle_event("select_component", %{"id" => id}, socket) do
    component = find_component(socket.assigns.query_structure, id)
    {:noreply, assign(socket, selected_component: component)}
  end

  def handle_event("remove_component", %{"id" => id}, socket) do
    query_structure = remove_component(socket.assigns.query_structure, id)
    {:noreply, assign(socket, query_structure: query_structure, selected_component: nil)}
  end

  def handle_event("validate_query", _params, socket) do
    errors = validate_query_structure(socket.assigns.query_structure)
    
    if errors == [] do
      {:noreply, put_flash(socket, :info, "Query is valid!")}
    else
      {:noreply, assign(socket, validation_errors: errors)}
    end
  end

  def handle_event("copy_sql", _params, socket) do
    sql = generate_sql(socket.assigns.query_structure)
    {:noreply, push_event(socket, "copy_to_clipboard", %{text: sql})}
  end

  def handle_event("test_query", _params, socket) do
    send(self(), {:test_subquery, socket.assigns.query_structure})
    {:noreply, socket}
  end

  # Helper functions

  defp default_config("select"), do: %{fields: ["*"], distinct: false}
  defp default_config("from"), do: %{table: nil, alias: nil}
  defp default_config("where"), do: %{conditions: []}
  defp default_config("join"), do: %{type: "INNER", table: nil, on: nil}
  defp default_config("group"), do: %{fields: []}
  defp default_config("having"), do: %{conditions: []}
  defp default_config("exists"), do: %{subquery: %{}}
  defp default_config(_), do: %{}

  defp find_component(structure, id) do
    Enum.find_value(structure, fn {_type, component} ->
      if component.id == id, do: component
    end)
  end

  defp remove_component(structure, id) do
    Enum.reduce(structure, %{}, fn {type, component}, acc ->
      if component.id != id do
        Map.put(acc, type, component)
      else
        acc
      end
    end)
  end

  defp validate_query_structure(structure) do
    errors = []
    
    errors = if !Map.has_key?(structure, :select) do
      ["SELECT clause is required" | errors]
    else
      errors
    end
    
    errors = if !Map.has_key?(structure, :from) do
      ["FROM clause is required" | errors]
    else
      errors
    end
    
    errors
  end

  defp generate_sql(%{} = structure) when map_size(structure) == 0 do
    "-- Empty query"
  end

  defp generate_sql(structure) do
    parts = []
    
    parts = if select = structure[:select] do
      fields = Enum.join(select.config[:fields] || ["*"], ", ")
      distinct = if select.config[:distinct], do: "DISTINCT ", else: ""
      ["SELECT #{distinct}#{fields}" | parts]
    else
      parts
    end
    
    parts = if from = structure[:from] do
      table = from.config[:table] || "dual"
      alias_part = if from.config[:alias], do: " AS #{from.config[:alias]}", else: ""
      parts ++ ["FROM #{table}#{alias_part}"]
    else
      parts
    end
    
    parts = if where = structure[:where] do
      conditions = 
        where.config[:conditions]
        |> Enum.map(&format_condition/1)
        |> Enum.join(" AND ")
      
      if conditions != "" do
        parts ++ ["WHERE #{conditions}"]
      else
        parts
      end
    else
      parts
    end
    
    Enum.join(parts, "\n")
  end

  defp format_condition(%{field: field, operator: op, value: value}) do
    "#{field} #{op} #{format_value(value)}"
  end
  defp format_condition(_), do: ""

  defp format_value(value) when is_binary(value) do
    if String.starts_with?(value, "(") do
      value
    else
      "'#{value}'"
    end
  end
  defp format_value(value), do: to_string(value)

  defp format_component_config(config) do
    cond do
      config[:fields] -> Enum.join(config[:fields] || [], ", ")
      config[:table] -> config[:table]
      config[:conditions] -> "#{length(config[:conditions] || [])} conditions"
      true -> ""
    end
  end

  defp icon(assigns) do
    ~H"""
    <svg class={@class} fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <%= case @name do %>
        <% "hero-plus" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
        <% "hero-check" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
        <% "hero-view-columns" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 4.5v15m6-15v15m-10.875 0h15.75c.621 0 1.125-.504 1.125-1.125V5.625c0-.621-.504-1.125-1.125-1.125H4.125C3.504 4.5 3 5.004 3 5.625v12.75c0 .621.504 1.125 1.125 1.125z" />
        <% "hero-table-cells" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3.375 19.5h17.25m-17.25 0a1.125 1.125 0 01-1.125-1.125M3.375 19.5h7.5c.621 0 1.125-.504 1.125-1.125m-9.75 0V5.625m0 12.75v-1.5c0-.621.504-1.125 1.125-1.125m18.375 2.625V5.625m0 12.75c0 .621-.504 1.125-1.125 1.125m1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125m0 3.75h-7.5A1.125 1.125 0 0112 18.375m9.75-12.75c0-.621-.504-1.125-1.125-1.125H3.375c-.621 0-1.125.504-1.125 1.125m19.5 0v1.5c0 .621-.504 1.125-1.125 1.125M2.25 5.625v1.5c0 .621.504 1.125 1.125 1.125m0 0h17.25m-17.25 0h7.5c.621 0 1.125.504 1.125 1.125M3.375 8.25c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125m17.25-3.75h-7.5c-.621 0-1.125.504-1.125 1.125m8.625-1.125c.621 0 1.125.504 1.125 1.125v1.5c0 .621-.504 1.125-1.125 1.125m-17.25 0h7.5m-7.5 0c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125M12 10.875v-1.5m0 1.5c0 .621-.504 1.125-1.125 1.125M12 10.875c0 .621.504 1.125 1.125 1.125m-2.25 0c.621 0 1.125.504 1.125 1.125M13.125 12h7.5m-7.5 0c-.621 0-1.125.504-1.125 1.125M20.625 12c.621 0 1.125.504 1.125 1.125v1.5c0 .621-.504 1.125-1.125 1.125m-17.25 0h7.5M12 14.625v-1.5m0 1.5c0 .621-.504 1.125-1.125 1.125M12 14.625c0 .621.504 1.125 1.125 1.125m-2.25 0c.621 0 1.125.504 1.125 1.125m0 1.5v-1.5m0 0c0-.621.504-1.125 1.125-1.125m0 0h7.5" />
        <% "hero-funnel" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 3c2.755 0 5.455.232 8.083.678.533.09.917.556.917 1.096v1.044a2.25 2.25 0 01-.659 1.591l-5.432 5.432a2.25 2.25 0 00-.659 1.591v2.927a2.25 2.25 0 01-1.244 2.013L9.75 21v-6.568a2.25 2.25 0 00-.659-1.591L3.659 7.409A2.25 2.25 0 013 5.818V4.774c0-.54.384-1.006.917-1.096A48.32 48.32 0 0112 3z" />
        <% "hero-link" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.19 8.688a4.5 4.5 0 011.242 7.244l-4.5 4.5a4.5 4.5 0 01-6.364-6.364l1.757-1.757m13.35-.622l1.757-1.757a4.5 4.5 0 00-6.364-6.364l-4.5 4.5a4.5 4.5 0 001.242 7.244" />
        <% "hero-rectangle-group" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.25 7.125C2.25 6.504 2.754 6 3.375 6h6c.621 0 1.125.504 1.125 1.125v3.75c0 .621-.504 1.125-1.125 1.125h-6a1.125 1.125 0 01-1.125-1.125v-3.75zM14.25 8.625c0-.621.504-1.125 1.125-1.125h5.25c.621 0 1.125.504 1.125 1.125v8.25c0 .621-.504 1.125-1.125 1.125h-5.25a1.125 1.125 0 01-1.125-1.125v-8.25zM3.75 16.125c0-.621.504-1.125 1.125-1.125h5.25c.621 0 1.125.504 1.125 1.125v2.25c0 .621-.504 1.125-1.125 1.125h-5.25a1.125 1.125 0 01-1.125-1.125v-2.25z" />
        <% "hero-adjustments-horizontal" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.5 6h9.75M10.5 6a1.5 1.5 0 11-3 0m3 0a1.5 1.5 0 10-3 0M3.75 6H7.5m3 12h9.75m-9.75 0a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m-3.75 0H7.5m9-6h3.75m-3.75 0a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m-9.75 0h9.75" />
        <% "hero-check-circle" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
        <% "hero-arrow-down-on-square" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 8.25H7.5a2.25 2.25 0 00-2.25 2.25v9a2.25 2.25 0 002.25 2.25h9a2.25 2.25 0 002.25-2.25v-9a2.25 2.25 0 00-2.25-2.25H15M9 12l3 3m0 0l3-3m-3 3V2.25" />
        <% "hero-x-circle" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.75 9.75l4.5 4.5m0-4.5l-4.5 4.5M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
        <% "hero-cursor-arrow-rays" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.042 21.672L13.684 16.6m0 0l-2.51 2.225.569-9.47 5.227 7.917-3.286-.672zM12 2.25V4.5m5.834.166l-1.591 1.591M20.25 10.5H18M7.757 14.743l-1.59 1.59M6 10.5H3.75m4.007-4.243l-1.59-1.59" />
        <% "hero-cog-6-tooth" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.594 3.94c.09-.542.56-.94 1.11-.94h2.593c.55 0 1.02.398 1.11.94l.213 1.281c.063.374.313.686.645.87.074.04.147.083.22.127.324.196.72.257 1.075.124l1.217-.456a1.125 1.125 0 011.37.49l1.296 2.247a1.125 1.125 0 01-.26 1.431l-1.003.827c-.293.24-.438.613-.431.992a6.759 6.759 0 010 .255c-.007.378.138.75.43.99l1.005.828c.424.35.534.954.26 1.43l-1.298 2.247a1.125 1.125 0 01-1.369.491l-1.217-.456c-.355-.133-.75-.072-1.076.124a6.57 6.57 0 01-.22.128c-.331.183-.581.495-.644.869l-.213 1.28c-.09.543-.56.941-1.11.941h-2.594c-.55 0-1.02-.398-1.11-.94l-.213-1.281c-.062-.374-.312-.686-.644-.87a6.52 6.52 0 01-.22-.127c-.325-.196-.72-.257-1.076-.124l-1.217.456a1.125 1.125 0 01-1.369-.49l-1.297-2.247a1.125 1.125 0 01.26-1.431l1.004-.827c.292-.24.437-.613.43-.992a6.932 6.932 0 010-.255c.007-.378-.138-.75-.43-.99l-1.004-.828a1.125 1.125 0 01-.26-1.43l1.297-2.247a1.125 1.125 0 011.37-.491l1.216.456c.356.133.751.072 1.076-.124.072-.044.146-.087.22-.128.332-.183.582-.495.644-.869l.214-1.281z" />
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
        <% "hero-x-mark" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
        <% "hero-trash" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0" />
        <% _ -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
      <% end %>
    </svg>
    """
  end

  @doc """
  JavaScript hooks for drag-and-drop functionality.
  """
  def __hooks__() do
    """
    export const DraggableComponent = {
      mounted() {
        this.el.addEventListener('dragstart', (e) => {
          e.dataTransfer.effectAllowed = 'copy';
          e.dataTransfer.setData('component-type', this.el.dataset.type);
          e.dataTransfer.setData('component-label', this.el.dataset.label);
          this.el.classList.add('opacity-50');
        });
        
        this.el.addEventListener('dragend', () => {
          this.el.classList.remove('opacity-50');
        });
      }
    };
    
    export const QueryCanvas = {
      mounted() {
        this.el.addEventListener('dragover', (e) => {
          e.preventDefault();
          e.dataTransfer.dropEffect = 'copy';
          this.el.classList.add('bg-blue-50');
        });
        
        this.el.addEventListener('dragleave', () => {
          this.el.classList.remove('bg-blue-50');
        });
        
        this.el.addEventListener('drop', (e) => {
          e.preventDefault();
          this.el.classList.remove('bg-blue-50');
          
          const type = e.dataTransfer.getData('component-type');
          if (type) {
            this.pushEvent('drop_component', {type: type});
          }
        });
      }
    };
    """
  end
end