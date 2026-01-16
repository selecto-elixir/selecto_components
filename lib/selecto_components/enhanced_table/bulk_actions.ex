defmodule SelectoComponents.EnhancedTable.BulkActions do
  @moduledoc """
  Bulk actions interface for performing operations on multiple selected records.
  """
  
  use Phoenix.LiveComponent
  alias SelectoComponents.EnhancedTable.RowSelection
  alias Phoenix.LiveView.JS
  
  @impl true
  def mount(socket) do
    {:ok, 
      socket
      |> RowSelection.init_selection()
      |> assign(
        bulk_action: nil,
        processing: false,
        processed_count: 0,
        total_to_process: 0,
        errors: [],
        show_confirmation: false,
        confirmation_message: nil
      )
    }
  end
  
  @impl true
  def update(assigns, socket) do
    actions = assigns[:actions] || default_actions()
    
    socket = 
      socket
      |> assign(assigns)
      |> assign(actions: actions)
    
    {:ok, socket}
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class="bulk-actions-container" phx-hook="BulkActions">
      <%!-- Bulk Actions Toolbar --%>
      <div class="flex items-center justify-between px-4 py-2 bg-gray-50 border-b">
        <div class="flex items-center space-x-4">
          <%!-- Selection Info --%>
          <%= if @selection_count > 0 do %>
            <div class="flex items-center space-x-2">
              <span class="text-sm font-medium text-gray-700">
                <%= @selection_count %> selected
              </span>
              <button
                type="button"
                class="text-sm text-blue-600 hover:text-blue-800"
                phx-click="clear_selection"
                phx-target={@myself}
              >
                Clear
              </button>
            </div>
          <% end %>
          
          <%!-- Actions Dropdown --%>
          <div class="relative">
            <button
              type="button"
              class={"px-4 py-2 bg-white border rounded-lg flex items-center space-x-2 #{if @selection_count == 0, do: "opacity-50 cursor-not-allowed", else: "hover:bg-gray-50"}"}
              disabled={@selection_count == 0}
              phx-click={toggle_actions_menu()}
            >
              <svg class="w-5 h-5 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                  d="M12 5v.01M12 12v.01M12 19v.01M12 6a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2z" />
              </svg>
              <span class="text-sm font-medium">Bulk Actions</span>
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
              </svg>
            </button>
            
            <div 
              id="bulk-actions-menu"
              class="hidden absolute left-0 mt-2 w-56 bg-white rounded-lg shadow-lg border border-gray-200 z-20"
            >
              <%= for action <- @actions do %>
                <%= render_action_item(assigns, action) %>
              <% end %>
            </div>
          </div>
        </div>
        
        <%!-- Quick Actions --%>
        <div class="flex items-center space-x-2">
          <%= for action <- Enum.filter(@actions, & &1.quick_action) do %>
            <button
              type="button"
              class={"px-3 py-1.5 text-sm rounded-lg flex items-center space-x-1 #{action_button_class(action, @selection_count)}"}
              disabled={@selection_count == 0 || @processing}
              phx-click="execute_action"
              phx-value-action={action.id}
              phx-target={@myself}
            >
              <%= if action.icon do %>
                <%= Phoenix.HTML.raw(action.icon) %>
              <% end %>
              <span><%= action.label %></span>
            </button>
          <% end %>
        </div>
      </div>
      
      <%!-- Progress Bar --%>
      <%= if @processing do %>
        <div class="px-4 py-2 bg-blue-50 border-b border-blue-200">
          <div class="flex items-center justify-between mb-2">
            <span class="text-sm font-medium text-blue-900">
              Processing <%= @processed_count %> of <%= @total_to_process %> items...
            </span>
            <button
              type="button"
              class="text-sm text-blue-600 hover:text-blue-800"
              phx-click="cancel_processing"
              phx-target={@myself}
            >
              Cancel
            </button>
          </div>
          <div class="w-full bg-blue-200 rounded-full h-2">
            <div 
              class="bg-blue-600 h-2 rounded-full transition-all duration-300"
              style={"width: #{progress_percentage(@processed_count, @total_to_process)}%"}
            ></div>
          </div>
        </div>
      <% end %>
      
      <%!-- Error Display --%>
      <%= if length(@errors) > 0 do %>
        <div class="px-4 py-2 bg-red-50 border-b border-red-200">
          <div class="flex items-start">
            <svg class="w-5 h-5 text-red-600 mr-2 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
            </svg>
            <div class="flex-1">
              <p class="text-sm font-medium text-red-900">
                <%= length(@errors) %> <%= if length(@errors) == 1, do: "error", else: "errors" %> occurred
              </p>
              <ul class="mt-1 text-sm text-red-700">
                <%= for error <- Enum.take(@errors, 3) do %>
                  <li>• <%= error %></li>
                <% end %>
                <%= if length(@errors) > 3 do %>
                  <li class="text-red-600">...and <%= length(@errors) - 3 %> more</li>
                <% end %>
              </ul>
            </div>
            <button
              type="button"
              class="text-red-600 hover:text-red-800"
              phx-click="dismiss_errors"
              phx-target={@myself}
            >
              <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
              </svg>
            </button>
          </div>
        </div>
      <% end %>
      
      <%!-- Confirmation Dialog --%>
      <%= if @show_confirmation do %>
        <div id="confirmation-dialog" class="fixed inset-0 z-50 overflow-y-auto" phx-hook="ConfirmationDialog">
          <div class="flex items-center justify-center min-h-screen px-4">
            <div class="fixed inset-0 bg-gray-500 bg-opacity-75" phx-click="cancel_action" phx-target={@myself}></div>
            
            <div class="relative bg-white rounded-lg shadow-xl max-w-md w-full">
              <div class="px-6 py-4">
                <div class="flex items-start">
                  <div class="flex-shrink-0">
                    <svg class="w-6 h-6 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                        d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                    </svg>
                  </div>
                  <div class="ml-3 flex-1">
                    <h3 class="text-lg font-medium text-gray-900">Confirm Bulk Action</h3>
                    <p class="mt-2 text-sm text-gray-500">
                      <%= @confirmation_message %>
                    </p>
                    <p class="mt-2 text-sm font-medium text-gray-700">
                      This will affect <%= @selection_count %> <%= if @selection_count == 1, do: "item", else: "items" %>.
                    </p>
                  </div>
                </div>
              </div>
              
              <div class="px-6 py-4 bg-gray-50 flex justify-end space-x-2">
                <button
                  type="button"
                  class="px-4 py-2 border border-gray-300 rounded-lg text-sm font-medium text-gray-700 hover:bg-gray-100"
                  phx-click="cancel_action"
                  phx-target={@myself}
                >
                  Cancel
                </button>
                <button
                  type="button"
                  class="px-4 py-2 bg-red-600 text-white rounded-lg text-sm font-medium hover:bg-red-700"
                  phx-click="confirm_action"
                  phx-target={@myself}
                >
                  Confirm
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
  
  defp render_action_item(assigns, action) do
    assigns = assign(assigns, :action, action)
    
    ~H"""
    <div class={if @action.divider, do: "border-t border-gray-200", else: ""}>
      <button
        type="button"
        class="w-full text-left px-4 py-2 text-sm hover:bg-gray-100 flex items-center space-x-2"
        phx-click="execute_action"
        phx-value-action={@action.id}
        phx-target={@myself}
      >
        <%= if @action.icon do %>
          <span class={@action.icon_class || "text-gray-500"}>
            <%= Phoenix.HTML.raw(@action.icon) %>
          </span>
        <% end %>
        <span class={@action.text_class || "text-gray-700"}><%= @action.label %></span>
        <%= if @action.badge do %>
          <span class="ml-auto px-2 py-0.5 text-xs bg-gray-200 rounded-full">
            <%= @action.badge %>
          </span>
        <% end %>
      </button>
      <%= if @action.description do %>
        <p class="px-4 pb-2 text-xs text-gray-500"><%= @action.description %></p>
      <% end %>
    </div>
    """
  end
  
  # Event handlers
  
  @impl true
  def handle_event("execute_action", %{"action" => action_id}, socket) do
    action = Enum.find(socket.assigns.actions, & &1.id == action_id)
    
    if action && action.requires_confirmation do
      {:noreply, 
        socket
        |> assign(
          show_confirmation: true,
          confirmation_message: action.confirmation_message || "Are you sure you want to perform this action?",
          bulk_action: action
        )
      }
    else
      {:noreply, execute_bulk_action(socket, action)}
    end
  end
  
  def handle_event("confirm_action", _params, socket) do
    {:noreply, 
      socket
      |> assign(show_confirmation: false)
      |> execute_bulk_action(socket.assigns.bulk_action)
    }
  end
  
  def handle_event("cancel_action", _params, socket) do
    {:noreply, assign(socket, show_confirmation: false, bulk_action: nil)}
  end
  
  def handle_event("cancel_processing", _params, socket) do
    send(self(), :cancel_bulk_processing)
    {:noreply, assign(socket, processing: false)}
  end
  
  def handle_event("dismiss_errors", _params, socket) do
    {:noreply, assign(socket, errors: [])}
  end
  
  def handle_event("toggle_row_selection", %{"id" => row_id}, socket) do
    {:noreply, RowSelection.toggle_row_selection(socket, row_id)}
  end
  
  def handle_event("select_all", _params, socket) do
    all_ids = get_all_row_ids(socket)
    {:noreply, RowSelection.select_all_rows(socket, all_ids)}
  end
  
  def handle_event("select_none", _params, socket) do
    {:noreply, RowSelection.clear_selection(socket)}
  end
  
  def handle_event("clear_selection", _params, socket) do
    {:noreply, RowSelection.clear_selection(socket)}
  end
  
  def handle_event("invert_selection", _params, socket) do
    all_ids = get_all_row_ids(socket)
    {:noreply, RowSelection.invert_selection(socket, all_ids)}
  end
  
  def handle_event("select_range", %{"from" => from_id, "to" => to_id}, socket) do
    all_ids = get_all_row_ids(socket)
    {:noreply, RowSelection.select_range(socket, from_id, to_id, all_ids)}
  end
  
  # Bulk action execution
  
  defp execute_bulk_action(socket, nil), do: socket
  defp execute_bulk_action(socket, action) do
    selected_ids = RowSelection.get_selected_ids(socket)
    
    if length(selected_ids) > 0 do
      socket
      |> assign(
        processing: true,
        processed_count: 0,
        total_to_process: length(selected_ids),
        errors: []
      )
      |> start_batch_processing(action, selected_ids)
    else
      socket
    end
  end
  
  defp start_batch_processing(socket, action, selected_ids) do
    batch_size = action[:batch_size] || 10
    batches = Enum.chunk_every(selected_ids, batch_size)
    
    # Send first batch for processing
    send(self(), {:process_batch, action, batches, 0})
    
    socket
  end
  
  @impl true
  def handle_info({:process_batch, action, batches, index}, socket) do
    if index < length(batches) do
      batch = Enum.at(batches, index)
      
      # Process batch
      case process_batch(action, batch) do
        {:ok, _results} ->
          new_count = socket.assigns.processed_count + length(batch)
          
          socket = assign(socket, processed_count: new_count)
          
          # Schedule next batch
          if index + 1 < length(batches) do
            Process.send_after(self(), {:process_batch, action, batches, index + 1}, 100)
          else
            # All done
            send(self(), :bulk_processing_complete)
          end
          
          {:noreply, socket}
          
        {:error, errors} ->
          {:noreply, 
            socket
            |> assign(errors: socket.assigns.errors ++ errors)
            |> assign(processing: false)
          }
      end
    else
      {:noreply, socket}
    end
  end
  
  def handle_info(:bulk_processing_complete, socket) do
    send(self(), {:bulk_action_complete, socket.assigns.bulk_action})
    
    {:noreply,
      socket
      |> assign(processing: false)
      |> RowSelection.clear_selection()
    }
  end
  
  def handle_info(:cancel_bulk_processing, socket) do
    {:noreply, assign(socket, processing: false)}
  end
  
  # Helper functions
  
  defp process_batch(action, batch_ids) do
    # Call the configured action handler if available, otherwise return success
    case action do
      %{handler: handler} when is_function(handler, 1) ->
        # Call custom handler function
        handler.(batch_ids)

      %{handler: {module, function}} when is_atom(module) and is_atom(function) ->
        # Call module function
        apply(module, function, [batch_ids])

      %{id: action_id} ->
        # Send to parent process for handling
        send(self(), {:bulk_action_process_batch, action_id, batch_ids})
        # Return success - actual processing happens in parent
        {:ok, batch_ids}

      _ ->
        {:ok, batch_ids}
    end
  end

  defp get_all_row_ids(socket) do
    # Get row IDs from various possible sources
    cond do
      # Explicitly provided all_row_ids
      is_list(socket.assigns[:all_row_ids]) and length(socket.assigns[:all_row_ids]) > 0 ->
        socket.assigns[:all_row_ids]

      # Extract from rows data (list of maps with id field)
      is_list(socket.assigns[:rows]) ->
        extract_ids_from_rows(socket.assigns[:rows])

      # Extract from query results (Selecto format)
      is_map(socket.assigns[:query_results]) ->
        extract_ids_from_query_results(socket.assigns[:query_results])

      # Extract from stream data
      is_map(socket.assigns[:streams]) and is_map(socket.assigns[:streams][:rows]) ->
        # Streams store data differently, try to extract
        extract_ids_from_stream(socket.assigns[:streams][:rows])

      # Ask parent component for IDs
      true ->
        send(self(), {:request_all_row_ids, self()})
        # Return empty list, parent will send back the IDs
        []
    end
  end

  defp extract_ids_from_rows(rows) when is_list(rows) do
    rows
    |> Enum.map(fn
      %{id: id} -> id
      %{"id" => id} -> id
      row when is_map(row) ->
        Map.get(row, :id) || Map.get(row, "id") || Map.get(row, :_id) || Map.get(row, "_id")
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end
  defp extract_ids_from_rows(_), do: []

  defp extract_ids_from_query_results(%{rows: rows, columns: columns}) do
    # Find id column index
    id_index = Enum.find_index(columns, fn col ->
      col_str = to_string(col)
      col_str in ["id", "_id", "pk", "primary_key"]
    end) || 0

    rows
    |> Enum.map(fn row ->
      case row do
        row when is_list(row) -> Enum.at(row, id_index)
        row when is_tuple(row) -> elem(row, id_index)
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end
  defp extract_ids_from_query_results(_), do: []

  defp extract_ids_from_stream(stream_data) when is_map(stream_data) do
    # Phoenix streams store items with DOM IDs as keys
    stream_data
    |> Map.values()
    |> Enum.map(fn
      %{id: id} -> id
      %{"id" => id} -> id
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end
  defp extract_ids_from_stream(_), do: []

  @doc """
  Set all row IDs for selection operations.

  Call this from the parent component to provide IDs for select all functionality.

  ## Example

      def handle_info({:request_all_row_ids, pid}, socket) do
        ids = Enum.map(socket.assigns.rows, & &1.id)
        send_update(SelectoComponents.EnhancedTable.BulkActions,
          id: "bulk-actions",
          all_row_ids: ids
        )
        {:noreply, socket}
      end
  """
  def set_all_row_ids(component_id, row_ids) do
    Phoenix.LiveView.send_update(__MODULE__, id: component_id, all_row_ids: row_ids)
  end
  
  defp default_actions do
    [
      %{
        id: "export",
        label: "Export",
        icon: ~s(<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"></path></svg>),
        quick_action: true,
        requires_confirmation: false
      },
      %{
        id: "delete",
        label: "Delete",
        icon: ~s(<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path></svg>),
        icon_class: "text-red-500",
        text_class: "text-red-700",
        quick_action: true,
        requires_confirmation: true,
        confirmation_message: "This will permanently delete the selected items. This action cannot be undone."
      },
      %{
        divider: true,
        id: "archive",
        label: "Archive",
        description: "Move to archive",
        requires_confirmation: true
      },
      %{
        id: "duplicate",
        label: "Duplicate",
        requires_confirmation: false
      },
      %{
        id: "merge",
        label: "Merge",
        badge: "Beta",
        requires_confirmation: true
      }
    ]
  end
  
  defp action_button_class(action, selection_count) do
    base = "transition-colors"
    
    disabled = if selection_count == 0 do
      "opacity-50 cursor-not-allowed"
    else
      ""
    end
    
    color = case action.id do
      "delete" -> "bg-red-100 text-red-700 hover:bg-red-200"
      "export" -> "bg-green-100 text-green-700 hover:bg-green-200"
      _ -> "bg-gray-100 text-gray-700 hover:bg-gray-200"
    end
    
    "#{base} #{color} #{disabled}"
  end
  
  defp progress_percentage(0, 0), do: 0
  defp progress_percentage(processed, total) do
    round(processed / total * 100)
  end
  
  defp toggle_actions_menu do
    JS.toggle(
      to: "#bulk-actions-menu",
      in: {"ease-out duration-100", "opacity-0 scale-95", "opacity-100 scale-100"},
      out: {"ease-in duration-75", "opacity-100 scale-100", "opacity-0 scale-95"}
    )
  end
  
  @doc """
  JavaScript hooks for bulk actions.
  """
  def __hooks__() do
    %{
      "BulkActions" => %{
        mounted: """
        // Handle keyboard shortcuts
        this.handleKeydown = (e) => {
          // Delete key for delete action
          if (e.key === 'Delete' && !e.target.matches('input, textarea')) {
            const selectedCount = parseInt(this.el.dataset.selectedCount || '0');
            if (selectedCount > 0) {
              e.preventDefault();
              this.pushEventTo(this.el, 'execute_action', {action: 'delete'});
            }
          }
        };
        
        document.addEventListener('keydown', this.handleKeydown);
        """,
        
        destroyed: """
        document.removeEventListener('keydown', this.handleKeydown);
        """
      },
      
      "ConfirmationDialog" => %{
        mounted: """
        // Focus on confirm button
        const confirmBtn = this.el.querySelector('button[phx-click="confirm_action"]');
        if (confirmBtn) {
          confirmBtn.focus();
        }
        
        // Handle ESC key
        this.handleKeydown = (e) => {
          if (e.key === 'Escape') {
            this.pushEventTo(this.el, 'cancel_action', {});
          }
        };
        
        document.addEventListener('keydown', this.handleKeydown);
        """,
        
        destroyed: """
        document.removeEventListener('keydown', this.handleKeydown);
        """
      }
    }
  end
end