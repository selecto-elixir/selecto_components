defmodule SelectoComponents.EnhancedTable.InlineEdit do
  @moduledoc """
  Provides inline editing capabilities for table cells with validation and optimistic updates.
  """
  
  use Phoenix.Component
  
  @doc """
  Initialize inline editing state for a component.
  """
  def init_inline_edit(socket) do
    socket
    |> assign(
      editing_cells: %{},
      edit_history: [],
      edit_history_index: 0,
      pending_changes: %{},
      validation_errors: %{}
    )
  end
  
  @doc """
  Handle cell edit activation.
  """
  def activate_cell_edit(socket, cell_id, initial_value) do
    editing_cells = Map.put(socket.assigns.editing_cells, cell_id, %{
      original_value: initial_value,
      current_value: initial_value,
      started_at: System.system_time(:second)
    })
    
    assign(socket, editing_cells: editing_cells)
  end
  
  @doc """
  Handle cell value update.
  """
  def update_cell_value(socket, cell_id, new_value) do
    case validate_cell_value(socket, cell_id, new_value) do
      {:ok, validated_value} ->
        editing_cells = 
          Map.update!(socket.assigns.editing_cells, cell_id, fn edit ->
            Map.put(edit, :current_value, validated_value)
          end)
        
        socket
        |> assign(editing_cells: editing_cells)
        |> assign(validation_errors: Map.delete(socket.assigns.validation_errors, cell_id))
        
      # {:error, error_message} ->
      #   assign(socket,
      #     validation_errors: Map.put(socket.assigns.validation_errors, cell_id, error_message)
      #   )
    end
  end
  
  @doc """
  Commit cell edit with optimistic update.
  """
  def commit_cell_edit(socket, cell_id) do
    case Map.get(socket.assigns.editing_cells, cell_id) do
      nil -> 
        socket
        
      edit_data ->
        # Add to history for undo/redo
        history_entry = %{
          cell_id: cell_id,
          old_value: edit_data.original_value,
          new_value: edit_data.current_value,
          timestamp: System.system_time(:second)
        }
        
        # Update history (truncate forward history if we're not at the end)
        history = Enum.take(socket.assigns.edit_history, socket.assigns.edit_history_index)
        new_history = history ++ [history_entry]
        
        # Add to pending changes for batch processing
        pending_changes = Map.put(
          socket.assigns.pending_changes,
          cell_id,
          edit_data.current_value
        )
        
        socket
        |> assign(
          editing_cells: Map.delete(socket.assigns.editing_cells, cell_id),
          edit_history: new_history,
          edit_history_index: length(new_history),
          pending_changes: pending_changes
        )
        |> apply_optimistic_update(cell_id, edit_data.current_value)
    end
  end
  
  @doc """
  Cancel cell edit.
  """
  def cancel_cell_edit(socket, cell_id) do
    socket
    |> assign(
      editing_cells: Map.delete(socket.assigns.editing_cells, cell_id),
      validation_errors: Map.delete(socket.assigns.validation_errors, cell_id)
    )
  end
  
  @doc """
  Undo last edit.
  """
  def undo_edit(socket) do
    if socket.assigns.edit_history_index > 0 do
      new_index = socket.assigns.edit_history_index - 1
      history_entry = Enum.at(socket.assigns.edit_history, new_index)
      
      socket
      |> assign(edit_history_index: new_index)
      |> rollback_change(history_entry)
    else
      socket
    end
  end
  
  @doc """
  Redo previously undone edit.
  """
  def redo_edit(socket) do
    if socket.assigns.edit_history_index < length(socket.assigns.edit_history) do
      history_entry = Enum.at(socket.assigns.edit_history, socket.assigns.edit_history_index)
      new_index = socket.assigns.edit_history_index + 1
      
      socket
      |> assign(edit_history_index: new_index)
      |> apply_change(history_entry)
    else
      socket
    end
  end
  
  @doc """
  Batch save all pending changes.
  """
  def save_pending_changes(socket) do
    if map_size(socket.assigns.pending_changes) > 0 do
      # Send batch update to server
      send(self(), {:batch_update, socket.assigns.pending_changes})
      
      assign(socket, pending_changes: %{})
    else
      socket
    end
  end
  
  @doc """
  Inline edit cell component.
  """
  def inline_edit_cell(assigns) do
    ~H"""
    <div 
      class="inline-edit-cell relative"
      phx-hook="InlineEditCell"
      id={@id}
      data-field={@field}
      data-row-id={@row_id}
      data-type={@type}
    >
      <%= if Map.has_key?(@editing_cells, @id) do %>
        <div class="edit-mode">
          <%= render_edit_input(assigns) %>
          <%= if Map.has_key?(@validation_errors, @id) do %>
            <div class="absolute z-10 mt-1 p-1 bg-red-100 border border-red-300 rounded text-xs text-red-700">
              <%= @validation_errors[@id] %>
            </div>
          <% end %>
        </div>
      <% else %>
        <div 
          class="view-mode cursor-pointer hover:bg-gray-50 px-2 py-1 rounded"
          phx-dblclick="activate_edit"
          phx-value-cell-id={@id}
          phx-value-value={@value}
          phx-target={@target}
        >
          <%= format_display_value(@value, @type) %>
          <%= if Map.has_key?(@pending_changes, @id) do %>
            <span class="ml-1 text-xs text-blue-600" title="Pending save">●</span>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
  
  # Render appropriate input based on data type
  defp render_edit_input(%{type: :boolean} = assigns) do
    ~H"""
    <select
      class="w-full px-2 py-1 text-sm border border-blue-500 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
      phx-blur="commit_edit"
      phx-change="update_edit"
      phx-value-cell-id={@id}
      phx-target={@target}
      autofocus
    >
      <option value="true" selected={@editing_cells[@id].current_value == true}>True</option>
      <option value="false" selected={@editing_cells[@id].current_value == false}>False</option>
    </select>
    """
  end
  
  defp render_edit_input(%{type: :number} = assigns) do
    ~H"""
    <input
      type="number"
      value={@editing_cells[@id].current_value}
      class="w-full px-2 py-1 text-sm border border-blue-500 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
      phx-blur="commit_edit"
      phx-keyup="handle_edit_key"
      phx-change="update_edit"
      phx-value-cell-id={@id}
      phx-target={@target}
      autofocus
    />
    """
  end
  
  defp render_edit_input(%{type: :date} = assigns) do
    ~H"""
    <input
      type="date"
      value={@editing_cells[@id].current_value}
      class="w-full px-2 py-1 text-sm border border-blue-500 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
      phx-blur="commit_edit"
      phx-change="update_edit"
      phx-value-cell-id={@id}
      phx-target={@target}
      autofocus
    />
    """
  end
  
  defp render_edit_input(assigns) do
    ~H"""
    <input
      type="text"
      value={@editing_cells[@id].current_value}
      class="w-full px-2 py-1 text-sm border border-blue-500 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
      phx-blur="commit_edit"
      phx-keyup="handle_edit_key"
      phx-change="update_edit"
      phx-value-cell-id={@id}
      phx-target={@target}
      autofocus
    />
    """
  end
  
  # Validation
  defp validate_cell_value(_socket, _cell_id, value) do
    # Get field configuration and apply validation rules
    # This would be customized based on domain/schema
    {:ok, value}
  end

  # Apply optimistic update to UI
  defp apply_optimistic_update(socket, _cell_id, _new_value) do
    # Update the data in the socket assigns
    # This would update the actual data being displayed
    socket
  end
  
  # Rollback a change (for undo)
  defp rollback_change(socket, %{cell_id: cell_id, old_value: old_value}) do
    apply_optimistic_update(socket, cell_id, old_value)
  end
  
  # Apply a change (for redo)
  defp apply_change(socket, %{cell_id: cell_id, new_value: new_value}) do
    apply_optimistic_update(socket, cell_id, new_value)
  end
  
  # Format value for display
  defp format_display_value(nil, _type), do: "-"
  defp format_display_value(value, :currency) do
    "$#{:erlang.float_to_binary(value / 1.0, decimals: 2)}"
  end
  defp format_display_value(value, :percentage) do
    "#{value}%"
  end
  defp format_display_value(value, :boolean) do
    if value, do: "✓", else: "✗"
  end
  defp format_display_value(%{__struct__: Date} = date, :date) do
    Calendar.strftime(date, "%Y-%m-%d")
  end
  defp format_display_value(value, _type) do
    to_string(value)
  end
  
  @doc """
  JavaScript hooks for inline editing.
  """
  def __hooks__() do
    %{
      "InlineEditCell" => %{
        mounted: """
        this.handleKeyPress = this.handleKeyPress.bind(this);
        this.handleDoubleClick = this.handleDoubleClick.bind(this);
        
        // Setup double-click handler
        const viewMode = this.el.querySelector('.view-mode');
        if (viewMode) {
          viewMode.addEventListener('dblclick', this.handleDoubleClick);
        }
        
        // Setup keyboard handler for edit mode
        const input = this.el.querySelector('input, select');
        if (input) {
          input.addEventListener('keydown', this.handleKeyPress);
          input.focus();
          // Select all text on focus for text inputs
          if (input.type === 'text' || input.type === 'number') {
            input.select();
          }
        }
        """,
        
        updated: """
        // Re-setup handlers after update
        this.mounted();
        """,
        
        handleKeyPress: """
        function(e) {
          const cellId = this.el.dataset.cellId || this.el.id;
          
          if (e.key === 'Enter') {
            e.preventDefault();
            this.pushEventTo(this.el.dataset.target || this.el, 'commit_edit', {
              cell_id: cellId
            });
          } else if (e.key === 'Escape') {
            e.preventDefault();
            this.pushEventTo(this.el.dataset.target || this.el, 'cancel_edit', {
              cell_id: cellId
            });
          } else if (e.key === 'Tab') {
            // Allow tab to move to next cell
            const direction = e.shiftKey ? 'prev' : 'next';
            this.pushEventTo(this.el.dataset.target || this.el, 'tab_to_cell', {
              cell_id: cellId,
              direction: direction
            });
          }
        }
        """,
        
        handleDoubleClick: """
        function(e) {
          // Double-click is handled by phx-dblclick attribute
          // This is here for any additional JS-side handling needed
        }
        """
      }
    }
  end
end