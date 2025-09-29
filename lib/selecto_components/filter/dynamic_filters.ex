defmodule SelectoComponents.Filter.DynamicFilters do
  @moduledoc """
  Dynamic filter management component with add/remove functionality and undo/redo support.
  """
  
  use Phoenix.LiveComponent
  
  # Generate unique IDs for filters
  defp generate_uuid do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16(case: :lower)
  end
  
  @max_undo_history 20
  
  def mount(socket) do
    {:ok, 
     socket
     |> assign(
       filter_history: [],
       redo_stack: [],
       show_add_filter: false,
       selected_field: nil,
       selected_operator: "=",
       filter_value: nil
     )}
  end
  
  def update(assigns, socket) do
    # Initialize filters if not present
    filters = assigns[:filters] || []
    
    socket = 
      socket
      |> assign(assigns)
      |> assign(filters: filters)
      |> maybe_init_history(filters)
    
    {:ok, socket}
  end
  
  defp maybe_init_history(socket, filters) do
    if socket.assigns[:filter_history] == [] do
      assign(socket, filter_history: [filters])
    else
      socket
    end
  end
  
  def render(assigns) do
    ~H"""
    <div class="dynamic-filters-container">
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-lg font-medium text-gray-900">Filters</h3>
        
        <div class="flex items-center space-x-2">
          <%!-- Undo/Redo buttons --%>
          <button
            type="button"
            phx-click="undo_filter"
            phx-target={@myself}
            disabled={length(@filter_history) <= 1}
            class={"p-1 rounded #{if length(@filter_history) <= 1, do: "text-gray-300 cursor-not-allowed", else: "text-gray-600 hover:text-gray-900 hover:bg-gray-100"}"}
            title="Undo (Ctrl+Z)"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 10h10a8 8 0 018 8v2M3 10l6 6m-6-6l6-6" />
            </svg>
          </button>
          
          <button
            type="button"
            phx-click="redo_filter"
            phx-target={@myself}
            disabled={@redo_stack == []}
            class={"p-1 rounded #{if @redo_stack == [], do: "text-gray-300 cursor-not-allowed", else: "text-gray-600 hover:text-gray-900 hover:bg-gray-100"}"}
            title="Redo (Ctrl+Y)"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 10H11a8 8 0 00-8 8v2m18-10l-6 6m6-6l-6-6" />
            </svg>
          </button>
          
          <div class="w-px h-6 bg-gray-300"></div>
          
          <%!-- Add Filter button --%>
          <button
            type="button"
            phx-click="toggle_add_filter"
            phx-target={@myself}
            class="inline-flex items-center px-3 py-1.5 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
          >
            <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
            </svg>
            Add Filter
          </button>
          
          <%!-- Add AND button --%>
          <button
            type="button"
            phx-click="add_conjunction"
            phx-value-type="AND"
            phx-target={@myself}
            disabled={@filters == []}
            class={"inline-flex items-center px-3 py-1.5 border text-sm font-medium rounded-md #{
              if @filters == [] do
                "border-gray-200 text-gray-400 bg-gray-50 cursor-not-allowed"
              else
                "border-gray-300 text-gray-700 bg-white hover:bg-gray-50"
              end
            } focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"}
          >
            AND
          </button>
          
          <%!-- Add OR button --%>
          <button
            type="button"
            phx-click="add_conjunction"
            phx-value-type="OR"
            phx-target={@myself}
            disabled={@filters == []}
            class={"inline-flex items-center px-3 py-1.5 border text-sm font-medium rounded-md #{
              if @filters == [] do
                "border-gray-200 text-gray-400 bg-gray-50 cursor-not-allowed"
              else
                "border-gray-300 text-gray-700 bg-white hover:bg-gray-50"
              end
            } focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"}
          >
            OR
          </button>
        </div>
      </div>
      
      <%!-- Add Filter Form --%>
      <%= if @show_add_filter do %>
        <div class="mb-4 p-4 bg-gray-50 rounded-lg border border-gray-200">
          <div class="grid grid-cols-4 gap-3">
            <%!-- Field selector --%>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Field</label>
              <select
                phx-change="select_field"
                phx-target={@myself}
                name="field"
                class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
              >
                <option value="">Select a field...</option>
                <%= for {field_id, field_config} <- @available_fields do %>
                  <option value={field_id} selected={@selected_field == field_id}>
                    <%= field_config.name %>
                  </option>
                <% end %>
              </select>
            </div>
            
            <%!-- Operator selector --%>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Operator</label>
              <select
                phx-change="select_operator"
                phx-target={@myself}
                name="operator"
                class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
              >
                <option value="=" selected={@selected_operator == "="}>Equals</option>
                <option value="!=" selected={@selected_operator == "!="}>Not Equals</option>
                <option value=">" selected={@selected_operator == ">"}>Greater Than</option>
                <option value=">=" selected={@selected_operator == ">="}>Greater or Equal</option>
                <option value="<" selected={@selected_operator == "<"}>Less Than</option>
                <option value="<=" selected={@selected_operator == "<="}>Less or Equal</option>
                <option value="LIKE" selected={@selected_operator == "LIKE"}>Contains</option>
                <option value="NOT LIKE" selected={@selected_operator == "NOT LIKE"}>Does Not Contain</option>
                <option value="IS NULL" selected={@selected_operator == "IS NULL"}>Is Empty</option>
                <option value="IS NOT NULL" selected={@selected_operator == "IS NOT NULL"}>Is Not Empty</option>
              </select>
            </div>
            
            <%!-- Value input --%>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Value</label>
              <%= if @selected_operator in ["IS NULL", "IS NOT NULL"] do %>
                <input
                  type="text"
                  disabled
                  placeholder="Not required"
                  class="block w-full rounded-md border-gray-300 bg-gray-100 shadow-sm sm:text-sm"
                />
              <% else %>
                <input
                  type="text"
                  phx-change="update_value"
                  phx-target={@myself}
                  name="value"
                  value={@filter_value}
                  placeholder="Enter value..."
                  class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                />
              <% end %>
            </div>
            
            <%!-- Action buttons --%>
            <div class="flex items-end space-x-2">
              <button
                type="button"
                phx-click="add_filter"
                phx-target={@myself}
                disabled={!@selected_field || (!@filter_value && @selected_operator not in ["IS NULL", "IS NOT NULL"])}
                class={"inline-flex items-center px-3 py-2 border border-transparent text-sm font-medium rounded-md text-white #{
                  if !@selected_field || (!@filter_value && @selected_operator not in ["IS NULL", "IS NOT NULL"]) do
                    "bg-gray-300 cursor-not-allowed"
                  else
                    "bg-green-600 hover:bg-green-700"
                  end
                } focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500"}
              >
                <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                </svg>
                Add
              </button>
              
              <button
                type="button"
                phx-click="cancel_add_filter"
                phx-target={@myself}
                class="inline-flex items-center px-3 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      <% end %>
      
      <%!-- Active Filters List --%>
      <div class="space-y-2">
        <%= if @filters == [] do %>
          <div class="text-center py-8 text-gray-500">
            No filters applied. Click "Add Filter" to get started.
          </div>
        <% else %>
          <%= for {{filter_id, section, filter_config}, index} <- Enum.with_index(@filters) do %>
            <%= if is_binary(filter_config) do %>
              <%!-- Conjunction (AND/OR) --%>
              <input type="hidden" name={"filters[#{filter_id}][uuid]"} value={filter_id} />
              <input type="hidden" name={"filters[#{filter_id}][section]"} value={section} />
              <input type="hidden" name={"filters[#{filter_id}][conjunction]"} value={filter_config} />
              <input type="hidden" name={"filters[#{filter_id}][is_section]"} value="Y" />
              <input type="hidden" name={"filters[#{filter_id}][index]"} value={to_string(index)} />
              
              <.conjunction_row
                filter_id={filter_id}
                conjunction={filter_config}
                target={@myself}
              />
            <% else %>
              <%!-- Regular filter --%>
              <input type="hidden" name={"filters[#{filter_id}][uuid]"} value={filter_id} />
              <input type="hidden" name={"filters[#{filter_id}][section]"} value={section} />
              <input type="hidden" name={"filters[#{filter_id}][filter]"} value={filter_config["filter"]} />
              <input type="hidden" name={"filters[#{filter_id}][comp]"} value={filter_config["comp"]} />
              <input type="hidden" name={"filters[#{filter_id}][value]"} value={filter_config["value"] || ""} />
              <input type="hidden" name={"filters[#{filter_id}][index]"} value={to_string(index)} />
              
              <.filter_row
                filter_id={filter_id}
                section={section}
                filter_config={filter_config}
                index={index}
                available_fields={@available_fields}
                target={@myself}
              />
            <% end %>
          <% end %>
        <% end %>
      </div>
      
      <%!-- Keyboard shortcut handler --%>
      <div
        id={"filter-keyboard-#{@id}"}
        phx-window-keydown="handle_keyboard"
        phx-target={@myself}
      />
    </div>
    """
  end
  
  def conjunction_row(assigns) do
    ~H"""
    <div class="flex items-center p-2 bg-gray-100 rounded-lg border border-gray-300">
      <div class="flex-1 flex items-center justify-center">
        <span class="px-4 py-1 bg-white text-gray-700 rounded-md font-semibold border border-gray-400">
          <%= @conjunction %>
        </span>
      </div>
      
      <%!-- Remove button --%>
      <button
        type="button"
        phx-click="remove_filter"
        phx-value-filter-id={@filter_id}
        phx-target={@target}
        class="ml-3 p-1.5 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-md transition-colors duration-150"
        title="Remove conjunction"
      >
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
        </svg>
      </button>
    </div>
    """
  end
  
  def filter_row(assigns) do
    field_name = get_field_name(assigns.filter_config, assigns.available_fields)
    operator_display = get_operator_display(assigns.filter_config["comp"] || "=")
    
    assigns = assign(assigns,
      field_name: field_name,
      operator_display: operator_display,
      is_conjunction: assigns.filter_config in ["AND", "OR"]
    )
    
    ~H"""
    <div class={"group flex items-center p-3 bg-white rounded-lg border #{
      if @is_conjunction do
        "border-gray-400 bg-gray-50"
      else
        "border-gray-200 hover:border-gray-300"
      end
    } transition-colors duration-150"}>
      
      <%= if @is_conjunction do %>
        <%!-- Conjunction row (AND/OR) --%>
        <div class="flex-1 flex items-center">
          <span class="px-3 py-1 bg-gray-200 text-gray-700 rounded-md font-medium">
            <%= @filter_config %>
          </span>
        </div>
      <% else %>
        <%!-- Regular filter row --%>
        <div class="flex-1 grid grid-cols-3 gap-3 items-center">
          <div>
            <span class="text-sm font-medium text-gray-700"><%= @field_name %></span>
          </div>
          
          <div>
            <span class="text-sm text-gray-600"><%= @operator_display %></span>
          </div>
          
          <div>
            <%= if @filter_config["comp"] in ["IS NULL", "IS NOT NULL"] do %>
              <span class="text-sm text-gray-400 italic">-</span>
            <% else %>
              <span class="text-sm text-gray-900"><%= @filter_config["value"] || "-" %></span>
            <% end %>
          </div>
        </div>
      <% end %>
      
      <%!-- Remove button --%>
      <button
        type="button"
        phx-click="remove_filter"
        phx-value-filter-id={@filter_id}
        phx-target={@target}
        class="ml-3 p-1.5 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-md transition-colors duration-150 opacity-0 group-hover:opacity-100 focus:opacity-100"
        title="Remove filter"
      >
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
        </svg>
      </button>
    </div>
    """
  end
  
  # Event Handlers
  
  def handle_event("toggle_add_filter", _, socket) do
    {:noreply, assign(socket, show_add_filter: !socket.assigns.show_add_filter)}
  end
  
  def handle_event("cancel_add_filter", _, socket) do
    {:noreply, reset_add_filter_form(socket)}
  end
  
  def handle_event("select_field", %{"field" => field}, socket) do
    {:noreply, assign(socket, selected_field: field)}
  end
  
  def handle_event("select_operator", %{"operator" => operator}, socket) do
    {:noreply, assign(socket, selected_operator: operator)}
  end
  
  def handle_event("update_value", %{"value" => value}, socket) do
    {:noreply, assign(socket, filter_value: value)}
  end
  
  def handle_event("add_filter", _, socket) do
    %{selected_field: field, selected_operator: operator, filter_value: value} = socket.assigns
    
    # Validate the filter
    if field && (value || operator in ["IS NULL", "IS NOT NULL"]) do
      new_filter = {
        generate_uuid(),
        "filters",
        %{
          "filter" => field,
          "comp" => operator,
          "value" => value || "",
          "section" => "filters"
        }
      }
      
      updated_filters = socket.assigns.filters ++ [new_filter]
      
      socket = 
        socket
        |> update_filters(updated_filters)
        |> reset_add_filter_form()
        |> push_filter_update()
      
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end
  
  def handle_event("remove_filter", %{"filter-id" => filter_id}, socket) do
    updated_filters = Enum.reject(socket.assigns.filters, fn {id, _, _} -> id == filter_id end)
    
    socket = 
      socket
      |> update_filters(updated_filters)
      |> push_filter_update()
    
    {:noreply, socket}
  end
  
  def handle_event("undo_filter", _, socket) do
    case socket.assigns.filter_history do
      [_current] -> 
        # Can't undo if only one state
        {:noreply, socket}
      
      [current | [previous | rest]] ->
        socket = 
          socket
          |> assign(
            filters: previous,
            filter_history: [previous | rest],
            redo_stack: [current | socket.assigns.redo_stack]
          )
          |> push_filter_update()
        
        {:noreply, socket}
    end
  end
  
  def handle_event("redo_filter", _, socket) do
    case socket.assigns.redo_stack do
      [] -> 
        {:noreply, socket}
      
      [next | rest] ->
        socket = 
          socket
          |> assign(
            filters: next,
            filter_history: [next | socket.assigns.filter_history],
            redo_stack: rest
          )
          |> push_filter_update()
        
        {:noreply, socket}
    end
  end
  
  def handle_event("handle_keyboard", %{"key" => "z", "ctrlKey" => true}, socket) do
    handle_event("undo_filter", %{}, socket)
  end
  
  def handle_event("handle_keyboard", %{"key" => "y", "ctrlKey" => true}, socket) do
    handle_event("redo_filter", %{}, socket)
  end
  
  def handle_event("handle_keyboard", _, socket) do
    {:noreply, socket}
  end
  
  def handle_event("add_conjunction", %{"type" => conjunction_type}, socket) do
    # Add a conjunction (AND/OR) to the filter list
    new_filter = {
      generate_uuid(),
      "filters",
      conjunction_type  # "AND" or "OR"
    }
    
    updated_filters = socket.assigns.filters ++ [new_filter]
    
    socket = 
      socket
      |> update_filters(updated_filters)
      |> push_filter_update()
    
    {:noreply, socket}
  end
  
  # Helper Functions
  
  defp update_filters(socket, new_filters) do
    # Add to history
    history = [new_filters | socket.assigns.filter_history] |> Enum.take(@max_undo_history)
    
    assign(socket,
      filters: new_filters,
      filter_history: history,
      redo_stack: []  # Clear redo stack on new action
    )
  end
  
  defp reset_add_filter_form(socket) do
    assign(socket,
      show_add_filter: false,
      selected_field: nil,
      selected_operator: "=",
      filter_value: nil
    )
  end
  
  defp push_filter_update(socket) do
    # Send the updated filters to the parent
    send(self(), {:filters_updated, socket.assigns.filters})
    socket
  end
  
  defp get_field_name(filter_config, available_fields) when is_map(filter_config) do
    field_id = filter_config["filter"]
    case Map.get(available_fields, field_id) do
      %{name: name} -> name
      _ -> field_id || "Unknown Field"
    end
  end
  defp get_field_name(_, _), do: "Unknown"
  
  defp get_operator_display(operator) do
    case operator do
      "=" -> "equals"
      "!=" -> "not equals"
      ">" -> "greater than"
      ">=" -> "greater or equal"
      "<" -> "less than"
      "<=" -> "less or equal"
      "LIKE" -> "contains"
      "NOT LIKE" -> "does not contain"
      "IS NULL" -> "is empty"
      "IS NOT NULL" -> "is not empty"
      _ -> operator
    end
  end
end