defmodule SelectoComponents.EnhancedTable.ColumnManager do
  @moduledoc """
  Manages column resizing and reordering for tables with persistence.
  """
  
  use Phoenix.Component
  import Phoenix.LiveView
  alias SelectoComponents.EnhancedTable.Sorting
  
  @default_min_width 50
  @default_max_width 500
  @default_width 150
  
  @doc """
  Initializes column configuration with defaults.
  """
  def init_columns(socket, columns) when is_list(columns) do
    column_config = 
      columns
      |> Enum.with_index()
      |> Enum.map(fn {{id, name, _type}, index} ->
        {to_string(id), %{
          id: to_string(id),
          name: name,
          width: @default_width,
          min_width: @default_min_width,
          max_width: @default_max_width,
          order: index,
          visible: true,
          locked: false
        }}
      end)
      |> Map.new()
    
    assign(socket,
      column_config: column_config,
      column_order: Enum.map(columns, fn {id, _, _} -> to_string(id) end),
      resizing_column: nil,
      reordering_column: nil
    )
  end
  
  @doc """
  Updates column width during resize.
  """
  def resize_column(socket, column_id, new_width) do
    column_config = socket.assigns.column_config
    column = Map.get(column_config, column_id)
    
    if column do
      # Enforce min/max constraints
      constrained_width = 
        new_width
        |> max(column.min_width)
        |> min(column.max_width)
      
      updated_column = Map.put(column, :width, constrained_width)
      updated_config = Map.put(column_config, column_id, updated_column)
      
      assign(socket, column_config: updated_config)
    else
      socket
    end
  end
  
  @doc """
  Reorders columns by moving a column to a new position.
  """
  def reorder_columns(socket, from_id, to_id) do
    column_order = socket.assigns.column_order
    
    from_index = Enum.find_index(column_order, &(&1 == from_id))
    to_index = Enum.find_index(column_order, &(&1 == to_id))
    
    if from_index && to_index && from_index != to_index do
      # Remove the column from its current position
      {column, temp_order} = List.pop_at(column_order, from_index)
      
      # Insert at new position
      new_order = List.insert_at(temp_order, to_index, column)
      
      # Update order indices in column config
      updated_config = 
        new_order
        |> Enum.with_index()
        |> Enum.reduce(socket.assigns.column_config, fn {col_id, index}, acc ->
          put_in(acc[col_id].order, index)
        end)
      
      assign(socket,
        column_order: new_order,
        column_config: updated_config
      )
    else
      socket
    end
  end
  
  @doc """
  Toggles column visibility.
  """
  def toggle_column_visibility(socket, column_id) do
    column_config = socket.assigns.column_config
    
    if column = Map.get(column_config, column_id) do
      updated_column = Map.update!(column, :visible, &(!&1))
      updated_config = Map.put(column_config, column_id, updated_column)
      
      assign(socket, column_config: updated_config)
    else
      socket
    end
  end
  
  @doc """
  Resets columns to default configuration.
  """
  def reset_columns(socket, columns) do
    init_columns(socket, columns)
  end
  
  @doc """
  Component for resizable table header.
  """
  def resizable_header(assigns) do
    ~H"""
    <th
      class="relative px-2 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider select-none"
      style={"width: #{@column.width}px; min-width: #{@column.min_width}px; max-width: #{@column.max_width}px;"}
      data-column-id={@column.id}
    >
      <div 
        class="flex items-center justify-between cursor-move"
        draggable="true"
        phx-hook="ColumnReorder"
        id={"col-header-#{@column.id}"}
        data-column-id={@column.id}
      >
        <span class="truncate"><%= @column.name %></span>
        
        <%= if @sortable do %>
          <Sorting.sort_indicator column={@column.id} sort_by={@sort_by} show_position={false} />
        <% end %>
      </div>
      
      <%!-- Resize handle --%>
      <div
        class="absolute top-0 right-0 bottom-0 w-1 cursor-col-resize hover:bg-blue-500 transition-colors"
        phx-hook="ColumnResize"
        id={"resize-#{@column.id}"}
        data-column-id={@column.id}
      >
        <div class="absolute inset-y-0 -left-1 -right-1 z-10"></div>
      </div>
    </th>
    """
  end
  
  @doc """
  Component for column configuration panel.
  """
  def column_config_panel(assigns) do
    ~H"""
    <div class="column-config-panel p-4 bg-white rounded-lg shadow-lg">
      <h3 class="text-lg font-medium text-gray-900 mb-4">Column Configuration</h3>
      
      <div class="space-y-2 mb-4">
        <h4 class="text-sm font-medium text-gray-700">Visible Columns</h4>
        
        <div class="space-y-1 max-h-60 overflow-y-auto">
          <%= for column_id <- @column_order do %>
            <% column = @column_config[column_id] %>
            <div class="flex items-center p-2 hover:bg-gray-50 rounded">
              <input
                type="checkbox"
                id={"col-visible-#{column_id}"}
                checked={column.visible}
                phx-click="toggle_column_visibility"
                phx-value-column-id={column_id}
                class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
              />
              <label 
                for={"col-visible-#{column_id}"}
                class="ml-2 flex-1 text-sm text-gray-700 cursor-pointer"
              >
                <%= column.name %>
              </label>
              
              <div class="flex items-center space-x-1">
                <%!-- Move up button --%>
                <button
                  type="button"
                  phx-click="move_column_up"
                  phx-value-column-id={column_id}
                  disabled={column.order == 0}
                  class={"p-1 rounded #{
                    if column.order == 0 do
                      "text-gray-300 cursor-not-allowed"
                    else
                      "text-gray-500 hover:text-gray-700 hover:bg-gray-100"
                    end
                  }"}
                >
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7" />
                  </svg>
                </button>
                
                <%!-- Move down button --%>
                <button
                  type="button"
                  phx-click="move_column_down"
                  phx-value-column-id={column_id}
                  disabled={column.order == length(@column_order) - 1}
                  class={"p-1 rounded #{
                    if column.order == length(@column_order) - 1 do
                      "text-gray-300 cursor-not-allowed"
                    else
                      "text-gray-500 hover:text-gray-700 hover:bg-gray-100"
                    end
                  }"}
                >
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                  </svg>
                </button>
              </div>
            </div>
          <% end %>
        </div>
      </div>
      
      <div class="flex justify-between pt-4 border-t border-gray-200">
        <button
          type="button"
          phx-click="reset_columns"
          class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
        >
          Reset to Default
        </button>
        
        <button
          type="button"
          phx-click="close_column_config"
          class="px-4 py-2 text-sm font-medium text-white bg-blue-600 border border-transparent rounded-md hover:bg-blue-700"
        >
          Done
        </button>
      </div>
    </div>
    """
  end
  
  @doc """
  JavaScript hook for column resizing.
  """
  def resize_hook_js do
    """
    export const ColumnResize = {
      mounted() {
        this.columnId = this.el.dataset.columnId;
        this.startX = 0;
        this.startWidth = 0;
        this.currentWidth = 0;
        this.headerCell = this.el.closest('th');
        
        this.handleMouseDown = this.handleMouseDown.bind(this);
        this.handleMouseMove = this.handleMouseMove.bind(this);
        this.handleMouseUp = this.handleMouseUp.bind(this);
        this.handleTouchStart = this.handleTouchStart.bind(this);
        this.handleTouchMove = this.handleTouchMove.bind(this);
        this.handleTouchEnd = this.handleTouchEnd.bind(this);
        
        // Mouse events
        this.el.addEventListener('mousedown', this.handleMouseDown);
        
        // Touch events
        this.el.addEventListener('touchstart', this.handleTouchStart, { passive: false });
      },
      
      handleMouseDown(e) {
        e.preventDefault();
        e.stopPropagation();
        
        this.startX = e.clientX;
        this.startWidth = this.headerCell.offsetWidth;
        this.currentWidth = this.startWidth;
        
        document.addEventListener('mousemove', this.handleMouseMove);
        document.addEventListener('mouseup', this.handleMouseUp);
        
        this.headerCell.classList.add('resizing');
        document.body.style.cursor = 'col-resize';
        document.body.style.userSelect = 'none';
      },
      
      handleMouseMove(e) {
        const diff = e.clientX - this.startX;
        this.currentWidth = Math.max(50, this.startWidth + diff);
        
        this.headerCell.style.width = `${this.currentWidth}px`;
        
        // Show resize indicator
        this.showResizeIndicator(this.currentWidth);
      },
      
      handleMouseUp(e) {
        document.removeEventListener('mousemove', this.handleMouseMove);
        document.removeEventListener('mouseup', this.handleMouseUp);
        
        this.headerCell.classList.remove('resizing');
        document.body.style.cursor = '';
        document.body.style.userSelect = '';
        
        // Send resize event to server
        this.pushEvent('resize_column', {
          column_id: this.columnId,
          width: this.currentWidth
        });
        
        this.hideResizeIndicator();
      },
      
      handleTouchStart(e) {
        e.preventDefault();
        const touch = e.touches[0];
        
        this.startX = touch.clientX;
        this.startWidth = this.headerCell.offsetWidth;
        this.currentWidth = this.startWidth;
        
        document.addEventListener('touchmove', this.handleTouchMove, { passive: false });
        document.addEventListener('touchend', this.handleTouchEnd);
        
        this.headerCell.classList.add('resizing');
      },
      
      handleTouchMove(e) {
        e.preventDefault();
        const touch = e.touches[0];
        const diff = touch.clientX - this.startX;
        
        this.currentWidth = Math.max(50, this.startWidth + diff);
        this.headerCell.style.width = `${this.currentWidth}px`;
        
        this.showResizeIndicator(this.currentWidth);
      },
      
      handleTouchEnd(e) {
        document.removeEventListener('touchmove', this.handleTouchMove);
        document.removeEventListener('touchend', this.handleTouchEnd);
        
        this.headerCell.classList.remove('resizing');
        
        this.pushEvent('resize_column', {
          column_id: this.columnId,
          width: this.currentWidth
        });
        
        this.hideResizeIndicator();
      },
      
      showResizeIndicator(width) {
        if (!this.indicator) {
          this.indicator = document.createElement('div');
          this.indicator.className = 'resize-indicator';
          this.indicator.style.cssText = `
            position: fixed;
            background: rgba(59, 130, 246, 0.5);
            border: 1px solid #3B82F6;
            padding: 2px 8px;
            border-radius: 4px;
            font-size: 12px;
            color: white;
            pointer-events: none;
            z-index: 9999;
          `;
          document.body.appendChild(this.indicator);
        }
        
        this.indicator.textContent = `${Math.round(width)}px`;
        this.indicator.style.left = `${event.clientX + 10}px`;
        this.indicator.style.top = `${event.clientY - 30}px`;
      },
      
      hideResizeIndicator() {
        if (this.indicator) {
          this.indicator.remove();
          this.indicator = null;
        }
      },
      
      destroyed() {
        this.el.removeEventListener('mousedown', this.handleMouseDown);
        this.el.removeEventListener('touchstart', this.handleTouchStart);
        document.removeEventListener('mousemove', this.handleMouseMove);
        document.removeEventListener('mouseup', this.handleMouseUp);
        document.removeEventListener('touchmove', this.handleTouchMove);
        document.removeEventListener('touchend', this.handleTouchEnd);
        this.hideResizeIndicator();
      }
    };
    """
  end
  
  @doc """
  JavaScript hook for column reordering.
  """
  def reorder_hook_js do
    """
    export const ColumnReorder = {
      mounted() {
        this.columnId = this.el.dataset.columnId;
        this.dragImage = null;
        
        this.handleDragStart = this.handleDragStart.bind(this);
        this.handleDragEnd = this.handleDragEnd.bind(this);
        this.handleDragOver = this.handleDragOver.bind(this);
        this.handleDrop = this.handleDrop.bind(this);
        
        this.el.addEventListener('dragstart', this.handleDragStart);
        this.el.addEventListener('dragend', this.handleDragEnd);
        this.el.addEventListener('dragover', this.handleDragOver);
        this.el.addEventListener('drop', this.handleDrop);
      },
      
      handleDragStart(e) {
        e.dataTransfer.effectAllowed = 'move';
        e.dataTransfer.setData('text/plain', this.columnId);
        
        // Create custom drag image
        this.createDragImage();
        if (this.dragImage) {
          e.dataTransfer.setDragImage(this.dragImage, 0, 0);
        }
        
        this.el.classList.add('dragging');
        
        // Mark all headers as potential drop targets
        document.querySelectorAll('[data-column-id]').forEach(el => {
          if (el !== this.el) {
            el.classList.add('drop-target');
          }
        });
      },
      
      handleDragEnd(e) {
        this.el.classList.remove('dragging');
        
        // Clean up drop targets
        document.querySelectorAll('.drop-target').forEach(el => {
          el.classList.remove('drop-target', 'drag-over');
        });
        
        if (this.dragImage) {
          this.dragImage.remove();
          this.dragImage = null;
        }
      },
      
      handleDragOver(e) {
        if (e.preventDefault) {
          e.preventDefault();
        }
        
        e.dataTransfer.dropEffect = 'move';
        
        const target = e.currentTarget.closest('[data-column-id]');
        if (target && target !== this.el) {
          target.classList.add('drag-over');
        }
        
        return false;
      },
      
      handleDrop(e) {
        if (e.stopPropagation) {
          e.stopPropagation();
        }
        
        const fromId = e.dataTransfer.getData('text/plain');
        const toId = this.columnId;
        
        if (fromId && toId && fromId !== toId) {
          this.pushEvent('reorder_columns', {
            from_id: fromId,
            to_id: toId
          });
        }
        
        return false;
      },
      
      createDragImage() {
        const rect = this.el.getBoundingClientRect();
        this.dragImage = document.createElement('div');
        this.dragImage.className = 'column-drag-image';
        this.dragImage.style.cssText = `
          position: absolute;
          top: -1000px;
          left: -1000px;
          width: ${rect.width}px;
          padding: 8px;
          background: white;
          border: 2px solid #3B82F6;
          border-radius: 4px;
          box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
          opacity: 0.9;
        `;
        this.dragImage.textContent = this.el.textContent;
        document.body.appendChild(this.dragImage);
      },
      
      destroyed() {
        this.el.removeEventListener('dragstart', this.handleDragStart);
        this.el.removeEventListener('dragend', this.handleDragEnd);
        this.el.removeEventListener('dragover', this.handleDragOver);
        this.el.removeEventListener('drop', this.handleDrop);
        
        if (this.dragImage) {
          this.dragImage.remove();
        }
      }
    };
    """
  end
end