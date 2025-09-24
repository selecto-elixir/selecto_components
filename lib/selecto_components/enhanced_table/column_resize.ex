defmodule SelectoComponents.EnhancedTable.ColumnResize do
  @moduledoc """
  Provides column resizing functionality for tables with drag-to-resize handles.
  """
  
  use Phoenix.Component
  alias Phoenix.LiveView.JS
  
  @doc """
  Initialize column resize state.
  """
  def init_column_resize(socket) do
    socket
    |> assign(
      column_widths: %{},
      min_column_width: 50,
      max_column_width: 500,
      resizing_column: nil,
      resize_start_x: nil,
      resize_start_width: nil
    )
  end
  
  @doc """
  Start resizing a column.
  """
  def start_resize(socket, column_id, start_x, current_width) do
    socket
    |> assign(
      resizing_column: column_id,
      resize_start_x: start_x,
      resize_start_width: current_width || 100
    )
  end
  
  @doc """
  Update column width during resize.
  """
  def update_resize(socket, current_x) do
    if socket.assigns.resizing_column do
      delta = current_x - socket.assigns.resize_start_x
      new_width = socket.assigns.resize_start_width + delta
      
      # Enforce min/max constraints
      new_width = 
        new_width
        |> max(socket.assigns.min_column_width)
        |> min(socket.assigns.max_column_width)
      
      column_widths = Map.put(
        socket.assigns.column_widths,
        socket.assigns.resizing_column,
        new_width
      )
      
      socket
      |> assign(column_widths: column_widths)
      |> Phoenix.LiveView.push_event("column_resized", %{
        column: socket.assigns.resizing_column,
        width: new_width
      })
    else
      socket
    end
  end
  
  @doc """
  End column resize operation.
  """
  def end_resize(socket) do
    socket
    |> assign(
      resizing_column: nil,
      resize_start_x: nil,
      resize_start_width: nil
    )
    |> save_column_configuration()
  end
  
  @doc """
  Reset column widths to defaults.
  """
  def reset_column_widths(socket) do
    socket
    |> assign(column_widths: %{})
    |> Phoenix.LiveView.push_event("reset_column_widths", %{})
    |> save_column_configuration()
  end
  
  @doc """
  Column resize handle component.
  """
  def resize_handle(assigns) do
    ~H"""
    <div
      class="absolute top-0 right-0 w-1 h-full cursor-col-resize group hover:bg-blue-400 transition-colors"
      phx-hook="ColumnResizeHandle"
      data-column={@column}
      id={"resize-handle-#{@column}"}
    >
      <div class="absolute top-0 right-0 w-4 h-full -mr-2" />
    </div>
    """
  end
  
  @doc """
  Resizable column header component.
  """
  def resizable_header(assigns) do
    assigns = 
      assigns
      |> assign_new(:width, fn -> nil end)
      |> assign_new(:min_width, fn -> 50 end)
      |> assign_new(:max_width, fn -> 500 end)
    
    ~H"""
    <th
      class="relative px-3 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
      style={if @width, do: "width: #{@width}px", else: nil}
      data-column={@column}
    >
      <div class="flex items-center justify-between">
        <span class="truncate"><%= @label %></span>
        <%= render_slot(@inner_block) %>
      </div>
      <.resize_handle column={@column} />
    </th>
    """
  end
  
  @doc """
  Get column width.
  """
  def get_column_width(socket, column_id) do
    Map.get(socket.assigns.column_widths, column_id)
  end
  
  @doc """
  Set column width.
  """
  def set_column_width(socket, column_id, width) do
    column_widths = Map.put(socket.assigns.column_widths, column_id, width)
    
    socket
    |> assign(column_widths: column_widths)
    |> save_column_configuration()
  end
  
  @doc """
  Load column configuration from storage.
  """
  def load_column_configuration(socket, table_id) do
    # In a real app, this would load from database or localStorage
    socket
  end
  
  # Private functions
  
  defp save_column_configuration(socket) do
    # In a real app, this would save to database or localStorage
    send(self(), {:column_configuration_changed, socket.assigns.column_widths})
    socket
  end
  
  @doc """
  JavaScript hooks for column resizing.
  """
  def __hooks__() do
    %{
      "ColumnResizeHandle" => %{
        mounted: """
        this.columnId = this.el.dataset.column;
        this.isResizing = false;
        this.startX = 0;
        this.startWidth = 0;
        
        // Start resize on mousedown
        this.handleMouseDown = (e) => {
          e.preventDefault();
          e.stopPropagation();
          
          this.isResizing = true;
          this.startX = e.clientX;
          
          const th = this.el.closest('th');
          this.startWidth = th.offsetWidth;
          
          document.body.style.cursor = 'col-resize';
          document.body.style.userSelect = 'none';
          
          // Add overlay to prevent text selection
          this.overlay = document.createElement('div');
          this.overlay.style.position = 'fixed';
          this.overlay.style.top = '0';
          this.overlay.style.left = '0';
          this.overlay.style.right = '0';
          this.overlay.style.bottom = '0';
          this.overlay.style.zIndex = '9999';
          this.overlay.style.cursor = 'col-resize';
          document.body.appendChild(this.overlay);
          
          this.pushEvent('start_resize', {
            column: this.columnId,
            start_x: this.startX,
            current_width: this.startWidth
          });
        };
        
        // Update resize on mousemove
        this.handleMouseMove = (e) => {
          if (!this.isResizing) return;
          
          const currentX = e.clientX;
          const delta = currentX - this.startX;
          const newWidth = Math.max(50, Math.min(500, this.startWidth + delta));
          
          // Update column width immediately for smooth feedback
          const th = document.querySelector(`th[data-column="${this.columnId}"]`);
          if (th) {
            th.style.width = `${newWidth}px`;
          }
          
          // Throttle server updates
          if (!this.updateTimeout) {
            this.updateTimeout = setTimeout(() => {
              this.pushEvent('update_resize', { current_x: currentX });
              this.updateTimeout = null;
            }, 50);
          }
        };
        
        // End resize on mouseup
        this.handleMouseUp = (e) => {
          if (!this.isResizing) return;
          
          this.isResizing = false;
          document.body.style.cursor = '';
          document.body.style.userSelect = '';
          
          if (this.overlay) {
            document.body.removeChild(this.overlay);
            this.overlay = null;
          }
          
          this.pushEvent('end_resize', {});
        };
        
        // Touch support
        this.handleTouchStart = (e) => {
          const touch = e.touches[0];
          this.handleMouseDown({ 
            preventDefault: () => e.preventDefault(),
            stopPropagation: () => e.stopPropagation(),
            clientX: touch.clientX 
          });
        };
        
        this.handleTouchMove = (e) => {
          if (!this.isResizing) return;
          const touch = e.touches[0];
          this.handleMouseMove({ clientX: touch.clientX });
        };
        
        this.handleTouchEnd = (e) => {
          this.handleMouseUp(e);
        };
        
        // Add event listeners
        this.el.addEventListener('mousedown', this.handleMouseDown);
        document.addEventListener('mousemove', this.handleMouseMove);
        document.addEventListener('mouseup', this.handleMouseUp);
        
        // Touch events
        this.el.addEventListener('touchstart', this.handleTouchStart);
        document.addEventListener('touchmove', this.handleTouchMove);
        document.addEventListener('touchend', this.handleTouchEnd);
        
        // Handle column width updates from server
        this.handleEvent('column_resized', ({column, width}) => {
          if (column === this.columnId) {
            const th = document.querySelector(`th[data-column="${column}"]`);
            if (th) {
              th.style.width = `${width}px`;
            }
          }
        });
        
        this.handleEvent('reset_column_widths', () => {
          const th = document.querySelector(`th[data-column="${this.columnId}"]`);
          if (th) {
            th.style.width = '';
          }
        });
        """,
        
        destroyed: """
        this.el.removeEventListener('mousedown', this.handleMouseDown);
        document.removeEventListener('mousemove', this.handleMouseMove);
        document.removeEventListener('mouseup', this.handleMouseUp);
        this.el.removeEventListener('touchstart', this.handleTouchStart);
        document.removeEventListener('touchmove', this.handleTouchMove);
        document.removeEventListener('touchend', this.handleTouchEnd);
        
        if (this.overlay && this.overlay.parentNode) {
          document.body.removeChild(this.overlay);
        }
        
        if (this.updateTimeout) {
          clearTimeout(this.updateTimeout);
        }
        """
      }
    }
  end
end