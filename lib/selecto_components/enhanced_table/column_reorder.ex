defmodule SelectoComponents.EnhancedTable.ColumnReorder do
  @moduledoc """
  Provides drag-and-drop column reordering functionality for tables.
  """
  
  use Phoenix.Component
  alias Phoenix.LiveView.JS
  
  @doc """
  Initialize column reorder state.
  """
  def init_column_reorder(socket) do
    socket
    |> assign(
      column_order: [],
      original_column_order: [],
      dragging_column: nil,
      drag_over_column: nil,
      drag_placeholder_position: nil
    )
  end
  
  @doc """
  Set initial column order.
  """
  def set_column_order(socket, columns) do
    column_ids = Enum.map(columns, & &1.id)
    
    socket
    |> assign(
      column_order: column_ids,
      original_column_order: column_ids
    )
  end
  
  @doc """
  Start dragging a column.
  """
  def start_column_drag(socket, column_id) do
    socket
    |> assign(
      dragging_column: column_id,
      drag_over_column: nil,
      drag_placeholder_position: nil
    )
    |> Phoenix.LiveView.push_event("column_drag_start", %{column: column_id})
  end
  
  @doc """
  Handle drag over another column.
  """
  def column_drag_over(socket, target_column_id, position) do
    if socket.assigns.dragging_column && socket.assigns.dragging_column != target_column_id do
      socket
      |> assign(
        drag_over_column: target_column_id,
        drag_placeholder_position: position
      )
      |> Phoenix.LiveView.push_event("show_drop_indicator", %{
        target: target_column_id,
        position: position
      })
    else
      socket
    end
  end
  
  @doc """
  Drop column in new position.
  """
  def drop_column(socket, target_column_id, position) do
    dragging_column = socket.assigns.dragging_column
    
    if dragging_column && dragging_column != target_column_id do
      current_order = socket.assigns.column_order
      
      # Remove dragging column from current position
      without_dragging = Enum.reject(current_order, & &1 == dragging_column)
      
      # Find target index
      target_index = Enum.find_index(without_dragging, & &1 == target_column_id)
      
      # Insert at new position
      new_order = 
        if target_index do
          insert_index = if position == "after", do: target_index + 1, else: target_index
          List.insert_at(without_dragging, insert_index, dragging_column)
        else
          # If target not found, append to end
          without_dragging ++ [dragging_column]
        end
      
      socket
      |> assign(
        column_order: new_order,
        dragging_column: nil,
        drag_over_column: nil,
        drag_placeholder_position: nil
      )
      |> Phoenix.LiveView.push_event("column_order_changed", %{order: new_order})
      |> save_column_order()
    else
      end_column_drag(socket)
    end
  end
  
  @doc """
  End drag operation without dropping.
  """
  def end_column_drag(socket) do
    socket
    |> assign(
      dragging_column: nil,
      drag_over_column: nil,
      drag_placeholder_position: nil
    )
    |> Phoenix.LiveView.push_event("column_drag_end", %{})
  end
  
  @doc """
  Reset column order to original.
  """
  def reset_column_order(socket) do
    socket
    |> assign(column_order: socket.assigns.original_column_order)
    |> Phoenix.LiveView.push_event("column_order_changed", %{order: socket.assigns.original_column_order})
    |> save_column_order()
  end
  
  @doc """
  Get ordered columns based on current order.
  """
  def get_ordered_columns(columns, column_order) do
    if Enum.empty?(column_order) do
      columns
    else
      # Create a map for quick lookup
      column_map = Map.new(columns, & {&1.id, &1})
      
      # Order columns according to column_order
      ordered = 
        column_order
        |> Enum.map(&Map.get(column_map, &1))
        |> Enum.reject(&is_nil/1)
      
      # Add any new columns not in the order
      remaining = 
        columns
        |> Enum.reject(fn col -> col.id in column_order end)
      
      ordered ++ remaining
    end
  end
  
  @doc """
  Draggable column header component.
  """
  def draggable_header(assigns) do
    assigns = 
      assigns
      |> assign_new(:draggable, fn -> true end)
    
    ~H"""
    <th
      class={[
        "relative px-3 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider",
        @draggable && "cursor-move"
      ]}
      draggable={@draggable}
      phx-hook="DraggableColumn"
      data-column={@column}
      id={"draggable-header-#{@column}"}
    >
      <div class="flex items-center space-x-2">
        <%= if @draggable do %>
          <svg class="w-3 h-3 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                  d="M4 8h16M4 16h16" />
          </svg>
        <% end %>
        <span class="flex-1"><%= @label %></span>
        <%= render_slot(@inner_block) %>
      </div>
      <div 
        class="absolute inset-y-0 left-0 w-1 bg-blue-500 hidden"
        id={"drop-indicator-left-#{@column}"}
      />
      <div 
        class="absolute inset-y-0 right-0 w-1 bg-blue-500 hidden"
        id={"drop-indicator-right-#{@column}"}
      />
    </th>
    """
  end
  
  @doc """
  Column reorder controls component.
  """
  def reorder_controls(assigns) do
    ~H"""
    <div class="flex items-center space-x-2">
      <button
        type="button"
        class="text-sm text-gray-600 hover:text-gray-900"
        phx-click="reset_column_order"
        phx-target={@target}
      >
        Reset Order
      </button>
      
      <%= if @dragging_column do %>
        <span class="text-xs text-gray-500">
          Dragging: <%= @dragging_column %>
        </span>
      <% end %>
    </div>
    """
  end
  
  # Private functions
  
  defp save_column_order(socket) do
    # In a real app, this would save to database or localStorage
    send(self(), {:column_order_changed, socket.assigns.column_order})
    socket
  end
  
  @doc """
  JavaScript hooks for column reordering.
  """
  def __hooks__() do
    %{
      "DraggableColumn" => %{
        mounted: """
        this.columnId = this.el.dataset.column;
        this.dragImage = null;
        
        // Drag start
        this.handleDragStart = (e) => {
          e.dataTransfer.effectAllowed = 'move';
          e.dataTransfer.setData('text/plain', this.columnId);
          
          // Create custom drag image
          const dragImage = this.el.cloneNode(true);
          dragImage.style.position = 'absolute';
          dragImage.style.top = '-1000px';
          dragImage.style.opacity = '0.8';
          dragImage.style.backgroundColor = 'white';
          dragImage.style.border = '2px solid #3b82f6';
          dragImage.style.borderRadius = '4px';
          dragImage.style.padding = '8px';
          document.body.appendChild(dragImage);
          e.dataTransfer.setDragImage(dragImage, e.offsetX, e.offsetY);
          this.dragImage = dragImage;
          
          this.el.style.opacity = '0.4';
          
          this.pushEvent('start_column_drag', { column: this.columnId });
        };
        
        // Drag over
        this.handleDragOver = (e) => {
          e.preventDefault();
          e.dataTransfer.dropEffect = 'move';
          
          const rect = this.el.getBoundingClientRect();
          const midpoint = rect.left + rect.width / 2;
          const position = e.clientX < midpoint ? 'before' : 'after';
          
          // Hide all indicators first
          document.querySelectorAll('[id^="drop-indicator-"]').forEach(el => {
            el.classList.add('hidden');
          });
          
          // Show appropriate indicator
          const indicator = document.getElementById(
            `drop-indicator-${position === 'before' ? 'left' : 'right'}-${this.columnId}`
          );
          if (indicator) {
            indicator.classList.remove('hidden');
          }
          
          this.pushEvent('column_drag_over', {
            target: this.columnId,
            position: position
          });
        };
        
        // Drag leave
        this.handleDragLeave = (e) => {
          // Hide indicators when leaving
          document.querySelectorAll(`[id^="drop-indicator-"][id$="-${this.columnId}"]`).forEach(el => {
            el.classList.add('hidden');
          });
        };
        
        // Drop
        this.handleDrop = (e) => {
          e.preventDefault();
          e.stopPropagation();
          
          const draggedColumn = e.dataTransfer.getData('text/plain');
          
          if (draggedColumn && draggedColumn !== this.columnId) {
            const rect = this.el.getBoundingClientRect();
            const midpoint = rect.left + rect.width / 2;
            const position = e.clientX < midpoint ? 'before' : 'after';
            
            this.pushEvent('drop_column', {
              target: this.columnId,
              position: position
            });
          }
          
          // Hide all indicators
          document.querySelectorAll('[id^="drop-indicator-"]').forEach(el => {
            el.classList.add('hidden');
          });
        };
        
        // Drag end
        this.handleDragEnd = (e) => {
          this.el.style.opacity = '';
          
          if (this.dragImage && this.dragImage.parentNode) {
            document.body.removeChild(this.dragImage);
            this.dragImage = null;
          }
          
          // Hide all indicators
          document.querySelectorAll('[id^="drop-indicator-"]').forEach(el => {
            el.classList.add('hidden');
          });
          
          this.pushEvent('end_column_drag', {});
        };
        
        // Touch support
        this.touchItem = null;
        this.touchOffset = { x: 0, y: 0 };
        
        this.handleTouchStart = (e) => {
          const touch = e.touches[0];
          
          // Create draggable element for touch
          this.touchItem = this.el.cloneNode(true);
          this.touchItem.style.position = 'fixed';
          this.touchItem.style.opacity = '0.8';
          this.touchItem.style.backgroundColor = 'white';
          this.touchItem.style.border = '2px solid #3b82f6';
          this.touchItem.style.borderRadius = '4px';
          this.touchItem.style.padding = '8px';
          this.touchItem.style.pointerEvents = 'none';
          this.touchItem.style.zIndex = '9999';
          
          const rect = this.el.getBoundingClientRect();
          this.touchOffset.x = touch.clientX - rect.left;
          this.touchOffset.y = touch.clientY - rect.top;
          
          this.touchItem.style.left = `${touch.clientX - this.touchOffset.x}px`;
          this.touchItem.style.top = `${touch.clientY - this.touchOffset.y}px`;
          
          document.body.appendChild(this.touchItem);
          this.el.style.opacity = '0.4';
          
          this.pushEvent('start_column_drag', { column: this.columnId });
        };
        
        this.handleTouchMove = (e) => {
          if (!this.touchItem) return;
          
          e.preventDefault();
          const touch = e.touches[0];
          
          this.touchItem.style.left = `${touch.clientX - this.touchOffset.x}px`;
          this.touchItem.style.top = `${touch.clientY - this.touchOffset.y}px`;
          
          // Find element under touch point
          const elementBelow = document.elementFromPoint(touch.clientX, touch.clientY);
          if (elementBelow && elementBelow.dataset.column) {
            const rect = elementBelow.getBoundingClientRect();
            const midpoint = rect.left + rect.width / 2;
            const position = touch.clientX < midpoint ? 'before' : 'after';
            
            this.pushEvent('column_drag_over', {
              target: elementBelow.dataset.column,
              position: position
            });
          }
        };
        
        this.handleTouchEnd = (e) => {
          if (!this.touchItem) return;
          
          const touch = e.changedTouches[0];
          
          // Find element under touch point
          const elementBelow = document.elementFromPoint(touch.clientX, touch.clientY);
          if (elementBelow && elementBelow.dataset.column) {
            const rect = elementBelow.getBoundingClientRect();
            const midpoint = rect.left + rect.width / 2;
            const position = touch.clientX < midpoint ? 'before' : 'after';
            
            this.pushEvent('drop_column', {
              target: elementBelow.dataset.column,
              position: position
            });
          }
          
          // Clean up
          if (this.touchItem.parentNode) {
            document.body.removeChild(this.touchItem);
          }
          this.touchItem = null;
          this.el.style.opacity = '';
          
          this.pushEvent('end_column_drag', {});
        };
        
        // Add event listeners
        this.el.addEventListener('dragstart', this.handleDragStart);
        this.el.addEventListener('dragover', this.handleDragOver);
        this.el.addEventListener('dragleave', this.handleDragLeave);
        this.el.addEventListener('drop', this.handleDrop);
        this.el.addEventListener('dragend', this.handleDragEnd);
        
        // Touch events
        this.el.addEventListener('touchstart', this.handleTouchStart);
        this.el.addEventListener('touchmove', this.handleTouchMove);
        this.el.addEventListener('touchend', this.handleTouchEnd);
        
        // Handle events from server
        this.handleEvent('column_order_changed', ({order}) => {
          // Reorder DOM elements to match new order
          const parent = this.el.parentNode;
          const headers = Array.from(parent.querySelectorAll('th[data-column]'));
          const headerMap = new Map(headers.map(h => [h.dataset.column, h]));
          
          order.forEach(columnId => {
            const header = headerMap.get(columnId);
            if (header) {
              parent.appendChild(header);
            }
          });
        });
        """,
        
        destroyed: """
        this.el.removeEventListener('dragstart', this.handleDragStart);
        this.el.removeEventListener('dragover', this.handleDragOver);
        this.el.removeEventListener('dragleave', this.handleDragLeave);
        this.el.removeEventListener('drop', this.handleDrop);
        this.el.removeEventListener('dragend', this.handleDragEnd);
        this.el.removeEventListener('touchstart', this.handleTouchStart);
        this.el.removeEventListener('touchmove', this.handleTouchMove);
        this.el.removeEventListener('touchend', this.handleTouchEnd);
        
        if (this.dragImage && this.dragImage.parentNode) {
          document.body.removeChild(this.dragImage);
        }
        
        if (this.touchItem && this.touchItem.parentNode) {
          document.body.removeChild(this.touchItem);
        }
        """
      }
    }
  end
end