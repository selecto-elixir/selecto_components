defmodule SelectoComponents.Responsive.ResponsiveTable do
  @moduledoc """
  Responsive table component that adapts to different screen sizes with mobile-friendly features.
  """
  
  use Phoenix.Component
  alias Phoenix.LiveView.JS
  
  @doc """
  Initialize responsive table state.
  """
  def init_responsive_table(socket) do
    socket
    |> assign(
      view_mode: :desktop,  # :desktop, :tablet, :mobile
      column_priorities: %{},
      visible_columns: [],
      horizontal_scroll: false,
      sticky_header: true,
      touch_enabled: true,
      orientation: :portrait  # :portrait, :landscape
    )
  end
  
  @doc """
  Set column priorities for responsive display.
  Higher priority columns are shown first on small screens.
  """
  def set_column_priorities(socket, priorities) do
    socket
    |> assign(column_priorities: priorities)
    |> update_visible_columns()
  end
  
  @doc """
  Update view mode based on screen size.
  """
  def update_view_mode(socket, width) do
    mode = cond do
      width < 640 -> :mobile
      width < 1024 -> :tablet
      true -> :desktop
    end
    
    socket
    |> assign(view_mode: mode)
    |> update_visible_columns()
  end
  
  @doc """
  Update device orientation.
  """
  def update_orientation(socket, orientation) do
    socket
    |> assign(orientation: orientation)
    |> update_visible_columns()
  end
  
  @doc """
  Responsive table wrapper component.
  """
  def responsive_table(assigns) do
    assigns = 
      assigns
      |> assign_new(:id, fn -> "responsive-table-#{System.unique_integer([:positive])}" end)
      |> assign_new(:sticky_header, fn -> true end)
      |> assign_new(:mobile_view, fn -> :cards end)  # :cards, :stacked, :scroll
    
    ~H"""
    <div 
      id={@id}
      class="responsive-table-container"
      phx-hook="ResponsiveTable"
      data-sticky-header={@sticky_header}
      data-mobile-view={@mobile_view}
    >
      <div class={[
        "responsive-table-wrapper",
        @view_mode == :mobile && "mobile-view",
        @view_mode == :tablet && "tablet-view",
        @view_mode == :desktop && "desktop-view"
      ]}>
        <%= if @view_mode == :mobile && @mobile_view == :cards do %>
          <.mobile_card_view rows={@rows} columns={@columns} />
        <% else %>
          <div class="overflow-x-auto">
            <table class={[
              "min-w-full divide-y divide-gray-200",
              @sticky_header && "sticky-header"
            ]}>
              <thead class="bg-gray-50">
                <tr>
                  <%= for column <- get_visible_columns(@columns, @view_mode, @column_priorities) do %>
                    <.responsive_header column={column} view_mode={@view_mode} />
                  <% end %>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                <%= for row <- @rows do %>
                  <tr class="hover:bg-gray-50">
                    <%= for column <- get_visible_columns(@columns, @view_mode, @column_priorities) do %>
                      <.responsive_cell row={row} column={column} view_mode={@view_mode} />
                    <% end %>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% end %>
      </div>
      
      <%= if @view_mode != :desktop do %>
        <.column_selector 
          columns={@columns} 
          visible_columns={get_visible_columns(@columns, @view_mode, @column_priorities)}
          target={@myself}
        />
      <% end %>
    </div>
    """
  end
  
  @doc """
  Mobile card view component.
  """
  def mobile_card_view(assigns) do
    ~H"""
    <div class="space-y-4 p-4">
      <%= for row <- @rows do %>
        <div class="bg-white rounded-lg shadow p-4 space-y-2">
          <%= for column <- @columns do %>
            <div class="flex justify-between items-start">
              <span class="text-sm font-medium text-gray-500">
                <%= column.label %>:
              </span>
              <span class="text-sm text-gray-900 text-right ml-2">
                <%= get_value(row, column.field) %>
              </span>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
  
  @doc """
  Responsive header cell component.
  """
  def responsive_header(assigns) do
    ~H"""
    <th class={[
      "px-3 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider",
      "priority-#{@column[:priority] || 3}",
      @view_mode == :mobile && "text-xs",
      @view_mode == :tablet && "text-sm"
    ]}>
      <span class="truncate block max-w-xs">
        <%= @column.label %>
      </span>
    </th>
    """
  end
  
  @doc """
  Responsive table cell component.
  """
  def responsive_cell(assigns) do
    ~H"""
    <td class={[
      "px-3 py-2 text-sm text-gray-900",
      "priority-#{@column[:priority] || 3}",
      @view_mode == :mobile && "text-xs py-1",
      @view_mode == :tablet && "text-sm"
    ]}>
      <span class="truncate block max-w-xs">
        <%= get_value(@row, @column.field) %>
      </span>
    </td>
    """
  end
  
  @doc """
  Column selector for mobile/tablet views.
  """
  def column_selector(assigns) do
    ~H"""
    <div class="p-4 border-t border-gray-200">
      <button
        type="button"
        class="text-sm text-blue-600 hover:text-blue-800"
        phx-click={toggle_column_selector()}
      >
        Customize Columns
      </button>
      
      <div id="column-selector-menu" class="hidden mt-2 space-y-2">
        <%= for column <- @columns do %>
          <label class="flex items-center">
            <input
              type="checkbox"
              class="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
              checked={column in @visible_columns}
              phx-click="toggle_column_visibility"
              phx-value-column={column.id}
              phx-target={@target}
            />
            <span class="ml-2 text-sm text-gray-700">
              <%= column.label %>
            </span>
          </label>
        <% end %>
      </div>
    </div>
    """
  end
  
  @doc """
  Sticky header component for scrolling.
  """
  def sticky_header(assigns) do
    ~H"""
    <div class="sticky-header-container">
      <div class="sticky top-0 z-10 bg-white shadow-sm" id={"sticky-header-#{@id}"}>
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end
  
  # Helper functions
  
  defp get_visible_columns(columns, view_mode, priorities) do
    sorted_columns = 
      columns
      |> Enum.map(fn col -> 
        {col, Map.get(priorities, col.id, 3)}
      end)
      |> Enum.sort_by(fn {_col, priority} -> priority end, :desc)
      |> Enum.map(fn {col, _priority} -> col end)
    
    case view_mode do
      :mobile -> Enum.take(sorted_columns, 3)
      :tablet -> Enum.take(sorted_columns, 5)
      :desktop -> columns
    end
  end
  
  defp get_value(row, field) when is_atom(field) do
    Map.get(row, field, "-")
  end
  defp get_value(row, field) when is_binary(field) do
    field
    |> String.split(".")
    |> Enum.reduce(row, fn key, acc ->
      case acc do
        %{} = map -> Map.get(map, String.to_atom(key))
        _ -> nil
      end
    end)
    |> format_value()
  end
  
  defp format_value(nil), do: "-"
  defp format_value(value) when is_binary(value), do: value
  defp format_value(value), do: to_string(value)
  
  defp update_visible_columns(socket) do
    columns = socket.assigns[:columns] || []
    priorities = socket.assigns.column_priorities
    view_mode = socket.assigns.view_mode
    
    visible = get_visible_columns(columns, view_mode, priorities)
    assign(socket, visible_columns: visible)
  end
  
  defp toggle_column_selector do
    JS.toggle(
      to: "#column-selector-menu",
      in: {"ease-out duration-200", "opacity-0 translate-y-1", "opacity-100 translate-y-0"},
      out: {"ease-in duration-150", "opacity-100 translate-y-0", "opacity-0 translate-y-1"}
    )
  end
  
  @doc """
  JavaScript hooks for responsive table functionality.
  """
  def __hooks__() do
    %{
      "ResponsiveTable" => %{
        mounted: """
        // Initialize responsive behavior
        this.viewMode = 'desktop';
        this.orientation = 'portrait';
        this.resizeTimeout = null;
        this.touchStartX = null;
        this.touchStartY = null;
        
        // Detect initial screen size and orientation
        this.detectScreenSize = () => {
          const width = window.innerWidth;
          let mode;
          
          if (width < 640) {
            mode = 'mobile';
          } else if (width < 1024) {
            mode = 'tablet';
          } else {
            mode = 'desktop';
          }
          
          if (mode !== this.viewMode) {
            this.viewMode = mode;
            this.pushEvent('update_view_mode', { width: width });
          }
        };
        
        this.detectOrientation = () => {
          const orientation = window.innerWidth > window.innerHeight ? 'landscape' : 'portrait';
          
          if (orientation !== this.orientation) {
            this.orientation = orientation;
            this.pushEvent('update_orientation', { orientation: orientation });
          }
        };
        
        // Handle sticky header
        if (this.el.dataset.stickyHeader === 'true') {
          this.setupStickyHeader();
        }
        
        // Setup sticky header functionality
        this.setupStickyHeader = () => {
          const table = this.el.querySelector('table');
          const thead = table?.querySelector('thead');
          
          if (!thead) return;
          
          const observer = new IntersectionObserver(
            ([entry]) => {
              thead.classList.toggle('stuck', !entry.isIntersecting);
            },
            { threshold: [1] }
          );
          
          observer.observe(thead);
          
          this.cleanup = () => observer.disconnect();
        };
        
        // Touch gesture support for horizontal scrolling
        this.setupTouchScroll = () => {
          const scrollContainer = this.el.querySelector('.overflow-x-auto');
          if (!scrollContainer) return;
          
          let isScrolling = false;
          let startX = 0;
          let scrollLeft = 0;
          
          scrollContainer.addEventListener('touchstart', (e) => {
            isScrolling = true;
            startX = e.touches[0].pageX - scrollContainer.offsetLeft;
            scrollLeft = scrollContainer.scrollLeft;
          });
          
          scrollContainer.addEventListener('touchmove', (e) => {
            if (!isScrolling) return;
            e.preventDefault();
            const x = e.touches[0].pageX - scrollContainer.offsetLeft;
            const walk = (x - startX) * 2;
            scrollContainer.scrollLeft = scrollLeft - walk;
          });
          
          scrollContainer.addEventListener('touchend', () => {
            isScrolling = false;
          });
        };
        
        // Swipe gestures for navigation
        this.setupSwipeGestures = () => {
          this.el.addEventListener('touchstart', (e) => {
            this.touchStartX = e.touches[0].clientX;
            this.touchStartY = e.touches[0].clientY;
          });
          
          this.el.addEventListener('touchend', (e) => {
            if (!this.touchStartX || !this.touchStartY) return;
            
            const touchEndX = e.changedTouches[0].clientX;
            const touchEndY = e.changedTouches[0].clientY;
            
            const dx = touchEndX - this.touchStartX;
            const dy = touchEndY - this.touchStartY;
            
            // Only consider horizontal swipes
            if (Math.abs(dx) > Math.abs(dy) && Math.abs(dx) > 50) {
              if (dx > 0) {
                this.pushEvent('swipe', { direction: 'right' });
              } else {
                this.pushEvent('swipe', { direction: 'left' });
              }
            }
            
            this.touchStartX = null;
            this.touchStartY = null;
          });
        };
        
        // Handle column visibility toggle
        this.handleEvent('update_columns', ({visible}) => {
          // Update column visibility
          const columns = this.el.querySelectorAll('th, td');
          columns.forEach(col => {
            const columnId = col.dataset.column;
            if (columnId) {
              col.style.display = visible.includes(columnId) ? '' : 'none';
            }
          });
        });
        
        // Debounced resize handler
        this.handleResize = () => {
          clearTimeout(this.resizeTimeout);
          this.resizeTimeout = setTimeout(() => {
            this.detectScreenSize();
            this.detectOrientation();
          }, 150);
        };
        
        // CSS for responsive features
        this.injectStyles = () => {
          const style = document.createElement('style');
          style.textContent = `
            .responsive-table-wrapper.mobile-view th.priority-1,
            .responsive-table-wrapper.mobile-view td.priority-1,
            .responsive-table-wrapper.mobile-view th.priority-2,
            .responsive-table-wrapper.mobile-view td.priority-2 {
              display: none;
            }
            
            .responsive-table-wrapper.tablet-view th.priority-1,
            .responsive-table-wrapper.tablet-view td.priority-1 {
              display: none;
            }
            
            .sticky-header thead.stuck {
              position: sticky;
              top: 0;
              z-index: 10;
              box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            }
            
            @media (max-width: 639px) {
              .responsive-table-wrapper table {
                font-size: 0.875rem;
              }
              
              .responsive-table-wrapper th,
              .responsive-table-wrapper td {
                padding: 0.5rem;
              }
            }
            
            @media (orientation: landscape) and (max-width: 896px) {
              .responsive-table-wrapper {
                max-height: 60vh;
                overflow-y: auto;
              }
            }
          `;
          document.head.appendChild(style);
          this.styleElement = style;
        };
        
        // Initialize
        this.detectScreenSize();
        this.detectOrientation();
        this.setupTouchScroll();
        this.setupSwipeGestures();
        this.injectStyles();
        
        // Add event listeners
        window.addEventListener('resize', this.handleResize);
        window.addEventListener('orientationchange', this.handleResize);
        """,
        
        destroyed: """
        window.removeEventListener('resize', this.handleResize);
        window.removeEventListener('orientationchange', this.handleResize);
        
        if (this.cleanup) {
          this.cleanup();
        }
        
        if (this.resizeTimeout) {
          clearTimeout(this.resizeTimeout);
        }
        
        if (this.styleElement && this.styleElement.parentNode) {
          this.styleElement.parentNode.removeChild(this.styleElement);
        }
        """
      }
    }
  end
end