defmodule SelectoComponents.EnhancedTable.ColumnManager do
  @moduledoc """
  Manages column resizing and reordering for tables with persistence.
  Provides drag-and-drop reordering and border-drag resizing functionality.
  """
  
  use Phoenix.LiveComponent
  alias Phoenix.LiveView.JS
  
  @default_min_width 50
  @default_max_width 500
  @default_width 150
  
  def render(assigns) do
    ~H"""
    <div class="column-manager" id={"column-manager-#{@id}"}>
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-lg font-semibold">Column Configuration</h3>
        <div class="flex gap-2">
          <button
            type="button"
            phx-click="reset_columns"
            phx-target={@myself}
            class="px-3 py-1 bg-gray-100 text-gray-700 rounded text-sm hover:bg-gray-200"
          >
            Reset to Default
          </button>
          <button
            type="button"
            phx-click="save_column_config"
            phx-target={@myself}
            class="px-3 py-1 bg-blue-600 text-white rounded text-sm hover:bg-blue-700"
          >
            Save Configuration
          </button>
        </div>
      </div>
      
      <div class="space-y-2">
        <div
          id={"columns-list-#{@id}"}
          phx-hook="ColumnReorder"
          data-columns={Jason.encode!(@column_order)}
        >
          <%= for column_id <- @column_order do %>
            <% column = Map.get(@column_config, column_id) %>
            <div
              class="column-item flex items-center gap-2 p-2 bg-white border rounded cursor-move"
              data-column-id={column_id}
              draggable="true"
            >
              <span class="drag-handle">
                <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"></path>
                </svg>
              </span>
              
              <input
                type="checkbox"
                phx-click="toggle_column_visibility"
                phx-target={@myself}
                phx-value-column={column_id}
                checked={column.visible}
                class="rounded"
              />
              
              <span class="flex-1"><%= column.name %></span>
              
              <div class="flex items-center gap-2">
                <label class="text-xs text-gray-500">Width:</label>
                <input
                  type="number"
                  phx-blur="update_column_width"
                  phx-target={@myself}
                  phx-value-column={column_id}
                  value={column.width}
                  min={column.min_width}
                  max={column.max_width}
                  class="w-20 px-2 py-1 text-sm border rounded"
                />
                
                <button
                  type="button"
                  phx-click="toggle_column_lock"
                  phx-target={@myself}
                  phx-value-column={column_id}
                  class={"p-1 rounded #{if column.locked, do: "text-blue-600", else: "text-gray-400"}"}
                  title={if column.locked, do: "Unlock column", else: "Lock column"}
                >
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <%= if column.locked do %>
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"></path>
                    <% else %>
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 11V7a4 4 0 118 0m-4 8v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2z"></path>
                    <% end %>
                  </svg>
                </button>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
  
  @doc """
  Renders resizable table headers.
  """
  def resizable_headers(assigns) do
    ~H"""
    <thead class="bg-gray-50">
      <tr>
        <%= for column_id <- @column_order do %>
          <% column = Map.get(@column_config, column_id) %>
          <%= if column.visible do %>
            <th
              id={"column-header-#{column_id}"}
              class="relative px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider select-none"
              style={"width: #{column.width}px; min-width: #{column.min_width}px; max-width: #{column.max_width}px"}
              data-column-id={column_id}
              phx-hook="ColumnHeader"
            >
              <div class="flex items-center justify-between">
                <span
                  class={"column-name #{unless column.locked, do: "cursor-move"}"}
                  draggable={!column.locked}
                >
                  <%= column.name %>
                </span>
                <%= if @sortable do %>
                  <button
                    phx-click="sort"
                    phx-value-field={column_id}
                    class="ml-2 text-gray-400 hover:text-gray-600"
                  >
                    <.sort_indicator field={column_id} sort_by={@sort_by} sort_order={@sort_order} />
                  </button>
                <% end %>
              </div>
              
              <div
                id={"resize-handle-#{column_id}"}
                class="resize-handle absolute top-0 right-0 bottom-0 w-1 cursor-col-resize hover:bg-blue-500"
                phx-hook="ResizeHandle"
                data-column-id={column_id}
              />
            </th>
          <% end %>
        <% end %>
      </tr>
    </thead>
    """
  end
  
  defp sort_indicator(assigns) do
    ~H"""
    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <%= if @sort_by == @field do %>
        <%= if @sort_order == :asc do %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7"></path>
        <% else %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path>
        <% end %>
      <% else %>
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16V4m0 0L3 8m4-4l4 4m6 0v12m0 0l4-4m-4 4l-4-4"></path>
      <% end %>
    </svg>
    """
  end
  
  def mount(socket) do
    {:ok,
     socket
     |> assign(
       id: Ecto.UUID.generate(),
       column_config: %{},
       column_order: [],
       resizing_column: nil,
       reordering_column: nil,
       sortable: false,
       sort_by: nil,
       sort_order: :asc
     )}
  end
  
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> maybe_init_columns()}
  end
  
  defp maybe_init_columns(socket) do
    if socket.assigns[:columns] && socket.assigns.column_config == %{} do
      init_columns(socket, socket.assigns.columns)
    else
      socket
    end
  end
  
  @doc """
  Initializes column configuration with defaults.
  """
  def init_columns(socket, columns) when is_list(columns) do
    column_config = 
      columns
      |> Enum.with_index()
      |> Enum.map(fn {col, index} ->
        # Handle both map format and tuple format
        {id, name, width, min_width, max_width} = case col do
          %{id: id, name: name, width: w, min_width: min, max_width: max} ->
            {id, name, w, min, max}
          %{id: id, name: name} ->
            {id, name, @default_width, @default_min_width, @default_max_width}
          {id, name, _type} ->
            {id, name, @default_width, @default_min_width, @default_max_width}
          {id, name} ->
            {id, name, @default_width, @default_min_width, @default_max_width}
        end
        
        {to_string(id), %{
          id: to_string(id),
          name: name,
          width: width,
          min_width: min_width,
          max_width: max_width,
          order: index,
          visible: true,
          locked: false
        }}
      end)
      |> Map.new()
    
    column_order = columns
      |> Enum.map(fn col ->
        case col do
          %{id: id} -> to_string(id)
          {id, _, _} -> to_string(id)
          {id, _} -> to_string(id)
        end
      end)
    
    assign(socket,
      column_config: column_config,
      column_order: column_order
    )
  end
  
  def handle_event("update_column_width", %{"column" => column_id, "value" => width_str}, socket) do
    width = String.to_integer(width_str)
    column = Map.get(socket.assigns.column_config, column_id)
    
    if column do
      clamped_width = 
        width
        |> max(column.min_width)
        |> min(column.max_width)
      
      updated_column = Map.put(column, :width, clamped_width)
      updated_config = Map.put(socket.assigns.column_config, column_id, updated_column)
      
      {:noreply, assign(socket, column_config: updated_config)}
    else
      {:noreply, socket}
    end
  end
  
  def handle_event("toggle_column_visibility", %{"column" => column_id}, socket) do
    column = Map.get(socket.assigns.column_config, column_id)
    
    if column do
      updated_column = Map.update!(column, :visible, &(!&1))
      updated_config = Map.put(socket.assigns.column_config, column_id, updated_column)
      
      {:noreply, assign(socket, column_config: updated_config)}
    else
      {:noreply, socket}
    end
  end
  
  def handle_event("toggle_column_lock", %{"column" => column_id}, socket) do
    column = Map.get(socket.assigns.column_config, column_id)
    
    if column do
      updated_column = Map.update!(column, :locked, &(!&1))
      updated_config = Map.put(socket.assigns.column_config, column_id, updated_column)
      
      {:noreply, assign(socket, column_config: updated_config)}
    else
      {:noreply, socket}
    end
  end
  
  def handle_event("reorder_columns", %{"order" => new_order}, socket) do
    # Validate that all columns are present
    if Enum.sort(new_order) == Enum.sort(socket.assigns.column_order) do
      {:noreply, assign(socket, column_order: new_order)}
    else
      {:noreply, socket}
    end
  end
  
  def handle_event("reset_columns", _params, socket) do
    if socket.assigns[:columns] do
      {:noreply, init_columns(socket, socket.assigns.columns)}
    else
      {:noreply, socket}
    end
  end
  
  def handle_event("save_column_config", _params, socket) do
    config_to_save = %{
      column_config: socket.assigns.column_config,
      column_order: socket.assigns.column_order
    }
    
    send(self(), {:save_column_config, config_to_save})
    {:noreply, put_flash(socket, :info, "Column configuration saved")}
  end
  
  @doc """
  JavaScript hooks for column resizing and reordering.
  """
  def __hooks__() do
    %{
      "ColumnReorder" => """
      export default {
        mounted() {
          this.setupDragAndDrop();
        },
        
        setupDragAndDrop() {
          const items = this.el.querySelectorAll('.column-item');
          let draggedElement = null;
          
          items.forEach(item => {
            item.addEventListener('dragstart', (e) => {
              const columnId = item.dataset.columnId;
              const column = this.getColumn(columnId);
              
              if (column && !column.locked) {
                draggedElement = item;
                e.dataTransfer.effectAllowed = 'move';
                e.dataTransfer.setData('text/html', item.innerHTML);
                item.classList.add('opacity-50');
              } else {
                e.preventDefault();
              }
            });
            
            item.addEventListener('dragend', (e) => {
              item.classList.remove('opacity-50');
            });
            
            item.addEventListener('dragover', (e) => {
              if (e.preventDefault) {
                e.preventDefault();
              }
              e.dataTransfer.dropEffect = 'move';
              
              const afterElement = this.getDragAfterElement(this.el, e.clientY);
              if (afterElement == null) {
                this.el.appendChild(draggedElement);
              } else {
                this.el.insertBefore(draggedElement, afterElement);
              }
            });
            
            item.addEventListener('drop', (e) => {
              if (e.stopPropagation) {
                e.stopPropagation();
              }
              
              const newOrder = Array.from(this.el.querySelectorAll('.column-item'))
                .map(el => el.dataset.columnId);
              
              this.pushEvent('reorder_columns', { order: newOrder });
              return false;
            });
          });
        },
        
        getDragAfterElement(container, y) {
          const draggableElements = [...container.querySelectorAll('.column-item:not(.opacity-50)')];
          
          return draggableElements.reduce((closest, child) => {
            const box = child.getBoundingClientRect();
            const offset = y - box.top - box.height / 2;
            
            if (offset < 0 && offset > closest.offset) {
              return { offset: offset, element: child };
            } else {
              return closest;
            }
          }, { offset: Number.NEGATIVE_INFINITY }).element;
        },
        
        getColumn(columnId) {
          const columns = JSON.parse(this.el.dataset.columns || '{}');
          return columns[columnId];
        }
      }
      """,
      
      "ResizeHandle" => """
      export default {
        mounted() {
          this.columnId = this.el.dataset.columnId;
          this.startX = 0;
          this.startWidth = 0;
          this.column = null;
          this.isResizing = false;
          
          this.el.addEventListener('mousedown', this.handleMouseDown.bind(this));
          this.el.addEventListener('touchstart', this.handleTouchStart.bind(this));
        },
        
        handleMouseDown(e) {
          e.preventDefault();
          this.startResize(e.clientX);
          
          document.addEventListener('mousemove', this.handleMouseMove.bind(this));
          document.addEventListener('mouseup', this.handleMouseUp.bind(this));
        },
        
        handleTouchStart(e) {
          e.preventDefault();
          const touch = e.touches[0];
          this.startResize(touch.clientX);
          
          document.addEventListener('touchmove', this.handleTouchMove.bind(this));
          document.addEventListener('touchend', this.handleTouchEnd.bind(this));
        },
        
        startResize(clientX) {
          this.isResizing = true;
          this.startX = clientX;
          this.column = this.el.closest('th');
          this.startWidth = this.column.offsetWidth;
          
          document.body.style.cursor = 'col-resize';
          this.column.classList.add('resizing');
        },
        
        handleMouseMove(e) {
          if (!this.isResizing) return;
          this.performResize(e.clientX);
        },
        
        handleTouchMove(e) {
          if (!this.isResizing) return;
          const touch = e.touches[0];
          this.performResize(touch.clientX);
        },
        
        performResize(clientX) {
          const diff = clientX - this.startX;
          const newWidth = this.startWidth + diff;
          
          // Apply constraints
          const minWidth = parseInt(this.column.style.minWidth) || 50;
          const maxWidth = parseInt(this.column.style.maxWidth) || 500;
          const clampedWidth = Math.max(minWidth, Math.min(maxWidth, newWidth));
          
          this.column.style.width = clampedWidth + 'px';
        },
        
        handleMouseUp(e) {
          this.stopResize();
          document.removeEventListener('mousemove', this.handleMouseMove.bind(this));
          document.removeEventListener('mouseup', this.handleMouseUp.bind(this));
        },
        
        handleTouchEnd(e) {
          this.stopResize();
          document.removeEventListener('touchmove', this.handleTouchMove.bind(this));
          document.removeEventListener('touchend', this.handleTouchEnd.bind(this));
        },
        
        stopResize() {
          if (!this.isResizing) return;
          
          this.isResizing = false;
          document.body.style.cursor = '';
          this.column.classList.remove('resizing');
          
          // Send new width to server
          const newWidth = this.column.offsetWidth;
          this.pushEventTo(this.el.closest('[phx-target]'), 'update_column_width', {
            column: this.columnId,
            value: newWidth.toString()
          });
        }
      }
      """,
      
      "ColumnHeader" => """
      export default {
        mounted() {
          this.columnId = this.el.dataset.columnId;
          this.setupReordering();
        },
        
        setupReordering() {
          const draggable = this.el.querySelector('[draggable="true"]');
          if (!draggable) return;
          
          draggable.addEventListener('dragstart', (e) => {
            e.dataTransfer.effectAllowed = 'move';
            e.dataTransfer.setData('columnId', this.columnId);
            this.el.classList.add('dragging');
          });
          
          draggable.addEventListener('dragend', (e) => {
            this.el.classList.remove('dragging');
          });
          
          this.el.addEventListener('dragover', (e) => {
            e.preventDefault();
            e.dataTransfer.dropEffect = 'move';
            this.el.classList.add('drag-over');
          });
          
          this.el.addEventListener('dragleave', (e) => {
            this.el.classList.remove('drag-over');
          });
          
          this.el.addEventListener('drop', (e) => {
            e.preventDefault();
            this.el.classList.remove('drag-over');
            
            const draggedColumnId = e.dataTransfer.getData('columnId');
            if (draggedColumnId && draggedColumnId !== this.columnId) {
              this.reorderColumns(draggedColumnId, this.columnId);
            }
          });
        },
        
        reorderColumns(fromId, toId) {
          const headers = Array.from(this.el.parentElement.children);
          const fromIndex = headers.findIndex(h => h.dataset.columnId === fromId);
          const toIndex = headers.findIndex(h => h.dataset.columnId === toId);
          
          if (fromIndex !== -1 && toIndex !== -1) {
            const newOrder = headers.map(h => h.dataset.columnId);
            newOrder.splice(fromIndex, 1);
            newOrder.splice(toIndex, 0, fromId);
            
            this.pushEventTo(this.el.closest('[phx-target]'), 'reorder_columns', {
              order: newOrder
            });
          }
        }
      }
      """
    }
  end
end