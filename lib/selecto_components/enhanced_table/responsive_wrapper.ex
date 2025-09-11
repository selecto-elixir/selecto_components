defmodule SelectoComponents.EnhancedTable.ResponsiveWrapper do
  @moduledoc """
  Provides responsive wrapper functionality for tables.
  Implements mobile-friendly layouts, horizontal scrolling, and touch interactions.
  """
  
  use Phoenix.Component
  import Phoenix.LiveView
  alias SelectoComponents.EnhancedTable.Sorting
  
  @doc """
  Initialize responsive state in the socket.
  """
  def init_responsive_state(socket) do
    assign(socket,
      viewport_size: :desktop,  # :mobile, :tablet, :desktop
      column_visibility: %{},    # Which columns are visible
      scroll_position: 0,        # Current horizontal scroll position
      sticky_header: true,       # Whether header sticks during scroll
      mobile_layout: :horizontal # :horizontal, :stacked, :card
    )
  end
  
  @doc """
  Wrap a table in a responsive container.
  """
  def responsive_table(assigns) do
    ~H"""
    <div 
      class="relative overflow-x-auto shadow-md sm:rounded-lg responsive-table-container"
      phx-hook="ResponsiveTable"
      id={assigns[:id] || "responsive-table-#{System.unique_integer([:positive])}"}
      data-sticky-header={assigns[:sticky_header] || true}
      data-mobile-layout={assigns[:mobile_layout] || :horizontal}
    >
      <div class="min-w-full inline-block align-middle">
        <%= if mobile_layout?(assigns) == :card do %>
          <.mobile_card_layout {assigns} />
        <% else %>
          <div class="overflow-hidden">
            <%= render_slot(@inner_block) %>
          </div>
        <% end %>
      </div>
      
      <%= if show_scroll_indicators?(assigns) do %>
        <.scroll_indicators />
      <% end %>
    </div>
    """
  end
  
  @doc """
  Mobile card layout for small screens.
  """
  def mobile_card_layout(assigns) do
    ~H"""
    <div class="space-y-4 p-4">
      <%= for row <- @rows do %>
        <div class="bg-white rounded-lg shadow p-4 border border-gray-200">
          <%= for {col, idx} <- Enum.with_index(@columns) do %>
            <div class="flex justify-between py-2 border-b border-gray-100 last:border-0">
              <span class="font-medium text-gray-600 text-sm">
                <%= col.label %>:
              </span>
              <span class="text-gray-900 text-sm ml-2 text-right">
                <%= get_cell_value(row, col) %>
              </span>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
  
  @doc """
  Scroll indicators for horizontal scrolling.
  """
  def scroll_indicators(assigns) do
    ~H"""
    <div class="absolute top-0 left-0 h-full w-8 bg-gradient-to-r from-white to-transparent pointer-events-none opacity-0 transition-opacity duration-200" id="scroll-indicator-left"></div>
    <div class="absolute top-0 right-0 h-full w-8 bg-gradient-to-l from-white to-transparent pointer-events-none opacity-0 transition-opacity duration-200" id="scroll-indicator-right"></div>
    """
  end
  
  @doc """
  Handle viewport size changes.
  """
  def handle_viewport_change(socket, %{"width" => width, "height" => height}) do
    viewport_size = determine_viewport_size(width)
    visible_columns = determine_visible_columns(socket.assigns.columns, viewport_size)
    
    socket
    |> assign(viewport_size: viewport_size)
    |> assign(column_visibility: visible_columns)
    |> assign(viewport_width: width)
    |> assign(viewport_height: height)
  end
  
  @doc """
  Column priority configuration for responsive display.
  """
  def configure_column_priority(columns) do
    Enum.map(columns, fn col ->
      Map.merge(col, %{
        priority: Map.get(col, :priority, :normal),  # :essential, :important, :normal, :optional
        mobile_visible: Map.get(col, :mobile_visible, col.priority in [:essential, :important]),
        tablet_visible: Map.get(col, :tablet_visible, col.priority != :optional)
      })
    end)
  end
  
  @doc """
  Responsive column header component.
  """
  def responsive_header(assigns) do
    ~H"""
    <th
      class={header_classes(@viewport_size, @column)}
      data-column-id={@column.id}
      data-priority={@column.priority}
    >
      <div class="flex items-center justify-between">
        <span class={label_classes(@viewport_size)}>
          <%= if @viewport_size == :mobile && @column.short_label do %>
            <%= @column.short_label %>
          <% else %>
            <%= @column.label %>
          <% end %>
        </span>
        <%= if @sortable do %>
          <Sorting.sort_indicator column={@column.id} sort_by={assigns[:sort_by] || []} show_position={false} />
        <% end %>
      </div>
    </th>
    """
  end
  
  @doc """
  JavaScript hooks for responsive behavior.
  """
  def js_hooks do
    """
    export const ResponsiveTable = {
      mounted() {
        this.handleResize = this.handleResize.bind(this);
        this.handleScroll = this.handleScroll.bind(this);
        this.handleTouch = this.handleTouch.bind(this);
        
        // Initial setup
        this.setupViewport();
        this.setupScrollIndicators();
        this.setupTouchHandling();
        
        // Event listeners
        window.addEventListener('resize', this.handleResize);
        this.el.addEventListener('scroll', this.handleScroll);
      },
      
      destroyed() {
        window.removeEventListener('resize', this.handleResize);
        this.el.removeEventListener('scroll', this.handleScroll);
      },
      
      setupViewport() {
        const width = window.innerWidth;
        const height = window.innerHeight;
        this.pushEvent('viewport_change', {width, height});
      },
      
      handleResize: debounce(function() {
        this.setupViewport();
      }, 250),
      
      setupScrollIndicators() {
        const container = this.el.querySelector('.overflow-x-auto');
        if (!container) return;
        
        const updateIndicators = () => {
          const scrollLeft = container.scrollLeft;
          const scrollWidth = container.scrollWidth;
          const clientWidth = container.clientWidth;
          
          const leftIndicator = this.el.querySelector('#scroll-indicator-left');
          const rightIndicator = this.el.querySelector('#scroll-indicator-right');
          
          if (leftIndicator) {
            leftIndicator.style.opacity = scrollLeft > 0 ? '1' : '0';
          }
          
          if (rightIndicator) {
            rightIndicator.style.opacity = 
              scrollLeft < scrollWidth - clientWidth - 1 ? '1' : '0';
          }
        };
        
        container.addEventListener('scroll', updateIndicators);
        updateIndicators();
      },
      
      setupTouchHandling() {
        if (!('ontouchstart' in window)) return;
        
        let startX = 0;
        let scrollLeft = 0;
        const container = this.el.querySelector('.overflow-x-auto');
        
        if (!container) return;
        
        container.addEventListener('touchstart', (e) => {
          startX = e.touches[0].pageX - container.offsetLeft;
          scrollLeft = container.scrollLeft;
        });
        
        container.addEventListener('touchmove', (e) => {
          if (!startX) return;
          e.preventDefault();
          
          const x = e.touches[0].pageX - container.offsetLeft;
          const walk = (x - startX) * 2;
          container.scrollLeft = scrollLeft - walk;
        });
        
        container.addEventListener('touchend', () => {
          startX = 0;
        });
      },
      
      handleScroll() {
        const scrollTop = this.el.scrollTop;
        this.pushEvent('scroll_position', {top: scrollTop, left: this.el.scrollLeft});
      }
    };
    
    function debounce(func, wait) {
      let timeout;
      return function executedFunction(...args) {
        const later = () => {
          clearTimeout(timeout);
          func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
      };
    }
    """
  end
  
  # Private helper functions
  
  defp mobile_layout?(assigns) do
    Map.get(assigns, :mobile_layout, :horizontal)
  end
  
  defp show_scroll_indicators?(assigns) do
    Map.get(assigns, :show_scroll_indicators, true)
  end
  
  defp determine_viewport_size(width) when width < 640, do: :mobile
  defp determine_viewport_size(width) when width < 1024, do: :tablet
  defp determine_viewport_size(_), do: :desktop
  
  defp determine_visible_columns(columns, :mobile) do
    columns
    |> Enum.filter(& &1.mobile_visible)
    |> Enum.map(& {&1.id, true})
    |> Map.new()
  end
  
  defp determine_visible_columns(columns, :tablet) do
    columns
    |> Enum.filter(& &1.tablet_visible)
    |> Enum.map(& {&1.id, true})
    |> Map.new()
  end
  
  defp determine_visible_columns(columns, _) do
    columns
    |> Enum.map(& {&1.id, true})
    |> Map.new()
  end
  
  defp header_classes(:mobile, _column) do
    "px-2 py-2 text-xs font-medium tracking-wider text-left text-gray-700 uppercase bg-gray-50"
  end
  
  defp header_classes(:tablet, _column) do
    "px-4 py-3 text-xs font-medium tracking-wider text-left text-gray-700 uppercase bg-gray-50"
  end
  
  defp header_classes(_, _column) do
    "px-6 py-3 text-xs font-medium tracking-wider text-left text-gray-700 uppercase bg-gray-50"
  end
  
  defp label_classes(:mobile), do: "truncate max-w-[100px]"
  defp label_classes(:tablet), do: "truncate max-w-[150px]"
  defp label_classes(_), do: ""
  
  defp get_cell_value(row, column) do
    Map.get(row, column.field) || Map.get(row, column.id) || ""
  end
  
  @doc """
  CSS styles for responsive tables.
  """
  def responsive_styles do
    """
    .responsive-table-container {
      -webkit-overflow-scrolling: touch;
    }
    
    @media (max-width: 640px) {
      .responsive-table-container table {
        font-size: 0.875rem;
      }
      
      .responsive-table-container th,
      .responsive-table-container td {
        padding: 0.5rem;
      }
    }
    
    @media (max-width: 480px) {
      .responsive-table-container.card-layout table {
        display: none;
      }
      
      .responsive-table-container .mobile-cards {
        display: block;
      }
    }
    
    /* Sticky header */
    .responsive-table-container.sticky-header thead {
      position: sticky;
      top: 0;
      z-index: 10;
      background: white;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
    
    /* Horizontal scroll indicators */
    .scroll-indicator-active {
      opacity: 1 !important;
    }
    
    /* Touch-friendly tap targets */
    @media (pointer: coarse) {
      .responsive-table-container button,
      .responsive-table-container a {
        min-height: 44px;
        min-width: 44px;
      }
    }
    
    /* Landscape orientation adjustments */
    @media (orientation: landscape) and (max-height: 500px) {
      .responsive-table-container {
        max-height: calc(100vh - 100px);
      }
    }
    """
  end
end