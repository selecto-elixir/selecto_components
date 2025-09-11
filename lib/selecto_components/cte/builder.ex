defmodule SelectoComponents.CTE.Builder do
  @moduledoc """
  Visual builder for Common Table Expressions with drag-and-drop interface.
  """

  use Phoenix.LiveComponent
  alias Phoenix.LiveView.JS

  def render(assigns) do
    ~H"""
    <div class="cte-builder" id={"cte-builder-#{@id}"}>
      <div class="bg-white rounded-lg shadow-lg">
        <div class="px-6 py-4 border-b bg-gray-50">
          <div class="flex items-center justify-between">
            <h3 class="text-lg font-semibold">CTE Builder</h3>
            <div class="flex space-x-2">
              <button
                type="button"
                phx-click="add_cte"
                phx-target={@myself}
                class="px-3 py-1 bg-blue-600 text-white rounded text-sm hover:bg-blue-700"
              >
                Add CTE
              </button>
              <button
                type="button"
                phx-click="validate_ctes"
                phx-target={@myself}
                class="px-3 py-1 bg-green-600 text-white rounded text-sm hover:bg-green-700"
              >
                Validate
              </button>
            </div>
          </div>
        </div>
        
        <div class="flex h-[600px]">
          <!-- CTE List Panel -->
          <div class="w-1/3 border-r p-4 overflow-y-auto">
            <h4 class="font-medium text-sm text-gray-700 mb-3">Available CTEs</h4>
            
            <div class="space-y-2">
              <%= for cte <- @ctes do %>
                <div
                  class={"p-3 border rounded cursor-pointer transition-colors #{if cte.id == @selected_cte_id, do: "bg-blue-50 border-blue-500", else: "hover:bg-gray-50"}"}
                  phx-click="select_cte"
                  phx-target={@myself}
                  phx-value-id={cte.id}
                  draggable="true"
                  phx-hook="DraggableCTE"
                  data-cte-id={cte.id}
                >
                  <div class="flex items-center justify-between">
                    <div>
                      <div class="font-medium"><%= cte.name %></div>
                      <div class="text-xs text-gray-500"><%= cte.type %></div>
                    </div>
                    <div class="flex space-x-1">
                      <button
                        type="button"
                        phx-click="duplicate_cte"
                        phx-target={@myself}
                        phx-value-id={cte.id}
                        class="p-1 text-gray-400 hover:text-gray-600"
                      >
                        <.icon name="hero-document-duplicate" class="w-4 h-4" />
                      </button>
                      <button
                        type="button"
                        phx-click="delete_cte"
                        phx-target={@myself}
                        phx-value-id={cte.id}
                        class="p-1 text-red-400 hover:text-red-600"
                      >
                        <.icon name="hero-trash" class="w-4 h-4" />
                      </button>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
            
            <%= if @ctes == [] do %>
              <div class="text-center py-8 text-gray-500">
                <p class="text-sm">No CTEs defined yet</p>
                <p class="text-xs mt-1">Click "Add CTE" to get started</p>
              </div>
            <% end %>
          </div>
          
          <!-- CTE Editor Panel -->
          <div class="flex-1 p-4">
            <%= if @selected_cte do %>
              <.cte_editor cte={@selected_cte} myself={@myself} schemas={@schemas} />
            <% else %>
              <div class="h-full flex items-center justify-center text-gray-500">
                <div class="text-center">
                  <.icon name="hero-cube-transparent" class="w-12 h-12 mx-auto mb-2" />
                  <p>Select a CTE to edit or create a new one</p>
                </div>
              </div>
            <% end %>
          </div>
        </div>
        
        <!-- Generated SQL Preview -->
        <div class="px-6 py-4 border-t bg-gray-50">
          <div class="flex items-center justify-between mb-2">
            <h4 class="font-medium text-sm text-gray-700">Generated SQL</h4>
            <button
              type="button"
              phx-click="copy_sql"
              phx-target={@myself}
              class="px-2 py-1 text-xs bg-gray-600 text-white rounded hover:bg-gray-700"
            >
              Copy SQL
            </button>
          </div>
          <pre class="bg-gray-900 text-gray-100 p-3 rounded text-xs overflow-x-auto">
<%= generate_sql(@ctes) %>
          </pre>
        </div>
      </div>
    </div>
    """
  end

  def cte_editor(assigns) do
    ~H"""
    <div class="cte-editor h-full flex flex-col">
      <div class="mb-4">
        <label class="block text-sm font-medium text-gray-700 mb-1">CTE Name</label>
        <input
          type="text"
          value={@cte.name}
          phx-blur="update_cte_name"
          phx-target={@myself}
          phx-value-id={@cte.id}
          class="w-full px-3 py-2 border border-gray-300 rounded-md"
        />
      </div>
      
      <div class="mb-4">
        <label class="block text-sm font-medium text-gray-700 mb-1">Type</label>
        <select
          phx-change="update_cte_type"
          phx-target={@myself}
          phx-value-id={@cte.id}
          class="w-full px-3 py-2 border border-gray-300 rounded-md"
        >
          <option value="standard" selected={@cte.type == "standard"}>Standard</option>
          <option value="recursive" selected={@cte.type == "recursive"}>Recursive</option>
          <option value="materialized" selected={@cte.type == "materialized"}>Materialized</option>
        </select>
      </div>
      
      <div class="flex-1 mb-4">
        <label class="block text-sm font-medium text-gray-700 mb-1">Query Builder</label>
        <div class="border border-gray-300 rounded-md p-4 h-full bg-gray-50">
          <.query_builder_section
            title="SELECT"
            items={@cte.select_fields}
            cte_id={@cte.id}
            section="select"
            myself={@myself}
          />
          
          <.query_builder_section
            title="FROM"
            items={@cte.from_tables}
            cte_id={@cte.id}
            section="from"
            myself={@myself}
          />
          
          <.query_builder_section
            title="WHERE"
            items={@cte.where_conditions}
            cte_id={@cte.id}
            section="where"
            myself={@myself}
          />
          
          <.query_builder_section
            title="GROUP BY"
            items={@cte.group_by}
            cte_id={@cte.id}
            section="group_by"
            myself={@myself}
          />
        </div>
      </div>
      
      <div class="mb-4">
        <label class="block text-sm font-medium text-gray-700 mb-1">Raw SQL (Advanced)</label>
        <textarea
          phx-blur="update_cte_sql"
          phx-target={@myself}
          phx-value-id={@cte.id}
          class="w-full px-3 py-2 border border-gray-300 rounded-md font-mono text-sm"
          rows="4"
        ><%= @cte.raw_sql %></textarea>
      </div>
      
      <div class="flex justify-between">
        <div class="text-sm text-gray-500">
          Dependencies: <%= Enum.join(@cte.dependencies, ", ") || "None" %>
        </div>
        <button
          type="button"
          phx-click="test_cte"
          phx-target={@myself}
          phx-value-id={@cte.id}
          class="px-3 py-1 bg-blue-600 text-white rounded text-sm hover:bg-blue-700"
        >
          Test Query
        </button>
      </div>
    </div>
    """
  end

  def query_builder_section(assigns) do
    ~H"""
    <div class="mb-3">
      <div class="flex items-center justify-between mb-1">
        <span class="text-xs font-medium text-gray-600"><%= @title %></span>
        <button
          type="button"
          phx-click="add_item"
          phx-target={@myself}
          phx-value-cte-id={@cte_id}
          phx-value-section={@section}
          class="text-blue-600 hover:text-blue-700"
        >
          <.icon name="hero-plus-circle" class="w-4 h-4" />
        </button>
      </div>
      <div class="space-y-1">
        <%= for {item, index} <- Enum.with_index(@items) do %>
          <div class="flex items-center space-x-2">
            <input
              type="text"
              value={item}
              phx-blur="update_item"
              phx-target={@myself}
              phx-value-cte-id={@cte_id}
              phx-value-section={@section}
              phx-value-index={index}
              class="flex-1 px-2 py-1 border border-gray-200 rounded text-sm"
              placeholder={"Enter #{String.downcase(@title)} clause"}
            />
            <button
              type="button"
              phx-click="remove_item"
              phx-target={@myself}
              phx-value-cte-id={@cte_id}
              phx-value-section={@section}
              phx-value-index={index}
              class="text-red-400 hover:text-red-600"
            >
              <.icon name="hero-x-circle" class="w-4 h-4" />
            </button>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  def mount(socket) do
    {:ok,
     assign(socket,
       id: Ecto.UUID.generate(),
       ctes: [],
       selected_cte_id: nil,
       selected_cte: nil,
       schemas: []
     )}
  end

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> maybe_select_cte()}
  end

  def handle_event("add_cte", _params, socket) do
    new_cte = %{
      id: Ecto.UUID.generate(),
      name: "cte_#{length(socket.assigns.ctes) + 1}",
      type: "standard",
      select_fields: ["*"],
      from_tables: [],
      where_conditions: [],
      group_by: [],
      dependencies: [],
      raw_sql: ""
    }
    
    {:noreply,
     socket
     |> assign(ctes: socket.assigns.ctes ++ [new_cte])
     |> assign(selected_cte_id: new_cte.id)
     |> maybe_select_cte()}
  end

  def handle_event("select_cte", %{"id" => id}, socket) do
    {:noreply,
     socket
     |> assign(selected_cte_id: id)
     |> maybe_select_cte()}
  end

  def handle_event("delete_cte", %{"id" => id}, socket) do
    ctes = Enum.reject(socket.assigns.ctes, &(&1.id == id))
    
    {:noreply,
     socket
     |> assign(ctes: ctes)
     |> assign(selected_cte_id: nil)
     |> assign(selected_cte: nil)}
  end

  def handle_event("update_cte_name", %{"id" => id, "value" => name}, socket) do
    {:noreply, update_cte(socket, id, &Map.put(&1, :name, name))}
  end

  def handle_event("update_cte_type", %{"id" => id, "value" => type}, socket) do
    {:noreply, update_cte(socket, id, &Map.put(&1, :type, type))}
  end

  def handle_event("add_item", params, socket) do
    %{"cte-id" => cte_id, "section" => section} = params
    section_atom = String.to_existing_atom(section)
    
    {:noreply,
     update_cte(socket, cte_id, fn cte ->
       current = Map.get(cte, section_atom, [])
       Map.put(cte, section_atom, current ++ [""])
     end)}
  end

  def handle_event("update_item", params, socket) do
    %{
      "cte-id" => cte_id,
      "section" => section,
      "index" => index,
      "value" => value
    } = params
    
    section_atom = String.to_existing_atom(section)
    index = String.to_integer(index)
    
    {:noreply,
     update_cte(socket, cte_id, fn cte ->
       items = Map.get(cte, section_atom, [])
       updated_items = List.replace_at(items, index, value)
       Map.put(cte, section_atom, updated_items)
     end)}
  end

  def handle_event("validate_ctes", _params, socket) do
    # Validate CTE definitions
    errors = validate_ctes(socket.assigns.ctes)
    
    if errors == [] do
      {:noreply, put_flash(socket, :info, "All CTEs are valid")}
    else
      {:noreply, put_flash(socket, :error, "Validation errors: #{Enum.join(errors, ", ")}")}
    end
  end

  def handle_event("copy_sql", _params, socket) do
    sql = generate_sql(socket.assigns.ctes)
    {:noreply, push_event(socket, "copy_to_clipboard", %{text: sql})}
  end

  # Private functions

  defp maybe_select_cte(socket) do
    if socket.assigns.selected_cte_id do
      selected_cte = Enum.find(socket.assigns.ctes, &(&1.id == socket.assigns.selected_cte_id))
      assign(socket, selected_cte: selected_cte)
    else
      socket
    end
  end

  defp update_cte(socket, id, update_fn) do
    ctes = Enum.map(socket.assigns.ctes, fn cte ->
      if cte.id == id, do: update_fn.(cte), else: cte
    end)
    
    socket
    |> assign(ctes: ctes)
    |> maybe_select_cte()
  end

  defp generate_sql(ctes) do
    if ctes == [] do
      "-- No CTEs defined"
    else
      cte_sql = 
        ctes
        |> Enum.map(&generate_cte_sql/1)
        |> Enum.join(",\n")
      
      "WITH #{cte_sql}\nSELECT * FROM #{List.last(ctes).name}"
    end
  end

  defp generate_cte_sql(cte) do
    if cte.raw_sql != "" do
      "#{cte.name} AS (\n  #{cte.raw_sql}\n)"
    else
      select = if cte.select_fields == [], do: "*", else: Enum.join(cte.select_fields, ", ")
      from = if cte.from_tables == [], do: "dual", else: Enum.join(cte.from_tables, ", ")
      where = if cte.where_conditions == [], do: "", else: "\n  WHERE #{Enum.join(cte.where_conditions, " AND ")}"
      group_by = if cte.group_by == [], do: "", else: "\n  GROUP BY #{Enum.join(cte.group_by, ", ")}"
      
      "#{cte.name} AS (\n  SELECT #{select}\n  FROM #{from}#{where}#{group_by}\n)"
    end
  end

  defp validate_ctes(ctes) do
    ctes
    |> Enum.flat_map(fn cte ->
      errors = []
      errors = if cte.name == "", do: ["CTE must have a name" | errors], else: errors
      errors = if cte.from_tables == [] && cte.raw_sql == "", do: ["#{cte.name} must have FROM clause" | errors], else: errors
      errors
    end)
  end

  defp icon(assigns) do
    ~H"""
    <svg class={@class} fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <%= case @name do %>
        <% "hero-document-duplicate" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7v8a2 2 0 002 2h6M8 7V5a2 2 0 012-2h4.586a1 1 0 01.707.293l4.414 4.414a1 1 0 01.293.707V15a2 2 0 01-2 2h-2M8 7H6a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2v-2" />
        <% "hero-trash" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
        <% "hero-plus-circle" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v3m0 0v3m0-3h3m-3 0H9m12 0a9 9 0 11-18 0 9 9 0 0118 0z" />
        <% "hero-x-circle" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z" />
        <% "hero-cube-transparent" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14 10l-2 1m0 0l-2-1m2 1v2.5M20 7l-2 1m2-1l-2-1m2 1v2.5M14 4l-2-1-2 1M4 7l2-1M4 7l2 1M4 7v2.5M12 21l-2-1m2 1l2-1m-2 1v-2.5M6 18l-2-1v-2.5M18 18l2-1v-2.5" />
        <% _ -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
      <% end %>
    </svg>
    """
  end

  defp put_flash(socket, _type, _message), do: socket

  @doc """
  JavaScript hooks for drag-and-drop functionality.
  """
  def __hooks__() do
    """
    export const DraggableCTE = {
      mounted() {
        this.el.addEventListener('dragstart', (e) => {
          e.dataTransfer.effectAllowed = 'move';
          e.dataTransfer.setData('text/plain', this.el.dataset.cteId);
          this.el.classList.add('opacity-50');
        });
        
        this.el.addEventListener('dragend', (e) => {
          this.el.classList.remove('opacity-50');
        });
      }
    };
    """
  end
end