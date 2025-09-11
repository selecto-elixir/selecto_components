defmodule SelectoComponents.EnhancedTable.Virtualization do
  @moduledoc """
  Provides virtual scrolling functionality for efficiently handling large datasets.
  Only renders visible rows to maintain performance with thousands of records.
  """
  
  use Phoenix.Component
  import Phoenix.LiveView
  
  @default_row_height 48
  @default_buffer_size 5
  @default_overscan 3
  
  @doc """
  Initialize virtualization state in the socket.
  """
  def init_virtualization(socket, total_rows) do
    assign(socket,
      virtual_scroll: %{
        total_rows: total_rows,
        viewport_height: 600,
        scroll_top: 0,
        row_height: @default_row_height,
        visible_start: 0,
        visible_end: calculate_visible_end(0, 600, @default_row_height),
        buffer_size: @default_buffer_size,
        overscan: @default_overscan,
        loading: false,
        row_heights: %{}  # For variable row heights
      }
    )
  end
  
  @doc """
  Virtual scroll container component.
  """
  def virtual_scroll_container(assigns) do
    ~H"""
    <div
      class="virtual-scroll-container relative overflow-auto"
      phx-hook="VirtualScroll"
      id={assigns[:id] || "virtual-scroll-#{System.unique_integer([:positive])}"}
      data-row-height={@row_height || @default_row_height}
      data-total-rows={@total_rows}
      data-buffer-size={@buffer_size || @default_buffer_size}
      data-overscan={@overscan || @default_overscan}
      style={"height: #{@viewport_height || 600}px;"}
    >
      <%!-- Total height spacer --%>
      <div
        class="virtual-scroll-spacer"
        style={"height: #{calculate_total_height(@total_rows, @row_height || @default_row_height)}px; position: relative;"}
      >
        <%!-- Visible rows container --%>
        <div
          class="virtual-scroll-content"
          style={"transform: translateY(#{calculate_offset(@visible_start, @row_height || @default_row_height)}px);"}
        >
          <%= render_slot(@inner_block, %{
            visible_rows: @visible_rows,
            start_index: @visible_start,
            end_index: @visible_end
          }) %>
        </div>
      </div>
      
      <%= if @loading do %>
        <.loading_indicator />
      <% end %>
    </div>
    """
  end
  
  @doc """
  Virtual table component optimized for large datasets.
  """
  def virtual_table(assigns) do
    visible_range = calculate_visible_range(assigns)
    visible_rows = slice_rows(assigns.rows, visible_range)
    
    assigns = 
      assigns
      |> assign(:visible_range, visible_range)
      |> assign(:visible_rows, visible_rows)
    
    ~H"""
    <.virtual_scroll_container
      id={@id}
      total_rows={length(@rows)}
      row_height={@row_height || @default_row_height}
      viewport_height={@viewport_height}
      visible_start={@visible_range.start}
      visible_end={@visible_range.end}
      visible_rows={@visible_rows}
      loading={@loading}
    >
      <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-gray-50 sticky top-0 z-10">
          <%= render_slot(@header) %>
        </thead>
        <tbody class="bg-white divide-y divide-gray-200">
          <%= for {row, index} <- Enum.with_index(@visible_rows, @visible_range.start) do %>
            <tr
              data-row-index={index}
              class="hover:bg-gray-50"
              style={"height: #{@row_height || @default_row_height}px;"}
            >
              <%= render_slot(@row, {row, index}) %>
            </tr>
          <% end %>
        </tbody>
      </table>
    </.virtual_scroll_container>
    """
  end
  
  @doc """
  Loading indicator for data fetching.
  """
  def loading_indicator(assigns) do
    ~H"""
    <div class="absolute inset-0 bg-white bg-opacity-75 flex items-center justify-center">
      <div class="flex items-center space-x-2">
        <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
        <span class="text-gray-600">Loading...</span>
      </div>
    </div>
    """
  end
  
  @doc """
  Handle scroll events and update visible range.
  """
  def handle_scroll(socket, %{"scrollTop" => scroll_top, "viewportHeight" => viewport_height}) do
    virtual = socket.assigns.virtual_scroll
    row_height = virtual.row_height
    total_rows = virtual.total_rows
    
    # Calculate new visible range with overscan
    visible_start = max(0, div(scroll_top, row_height) - virtual.overscan)
    visible_end = min(
      total_rows - 1,
      visible_start + div(viewport_height, row_height) + virtual.overscan * 2
    )
    
    virtual = %{virtual |
      scroll_top: scroll_top,
      viewport_height: viewport_height,
      visible_start: visible_start,
      visible_end: visible_end
    }
    
    socket = assign(socket, virtual_scroll: virtual)
    
    # Check if we need to load more data
    if should_load_more?(virtual) do
      send(self(), {:load_more_data, visible_end})
    end
    
    socket
  end
  
  @doc """
  Update row height for variable height rows.
  """
  def update_row_height(socket, row_index, height) do
    virtual = socket.assigns.virtual_scroll
    row_heights = Map.put(virtual.row_heights, row_index, height)
    
    virtual = %{virtual | row_heights: row_heights}
    assign(socket, virtual_scroll: virtual)
  end
  
  @doc """
  JavaScript hooks for virtual scrolling.
  """
  def js_hooks do
    """
    export const VirtualScroll = {
      mounted() {
        this.rowHeight = parseInt(this.el.dataset.rowHeight) || 48;
        this.totalRows = parseInt(this.el.dataset.totalRows) || 0;
        this.bufferSize = parseInt(this.el.dataset.bufferSize) || 5;
        this.overscan = parseInt(this.el.dataset.overscan) || 3;
        
        this.scrollHandler = this.handleScroll.bind(this);
        this.resizeHandler = this.handleResize.bind(this);
        this.keyHandler = this.handleKeyboard.bind(this);
        
        // Set up scroll listener with throttling
        this.el.addEventListener('scroll', this.throttle(this.scrollHandler, 16));
        window.addEventListener('resize', this.debounce(this.resizeHandler, 250));
        this.el.addEventListener('keydown', this.keyHandler);
        
        // Initial measurement
        this.measureViewport();
        
        // Set up Intersection Observer for variable row heights
        if (this.el.dataset.variableHeight === 'true') {
          this.setupRowHeightObserver();
        }
      },
      
      destroyed() {
        this.el.removeEventListener('scroll', this.scrollHandler);
        window.removeEventListener('resize', this.resizeHandler);
        this.el.removeEventListener('keydown', this.keyHandler);
        
        if (this.rowObserver) {
          this.rowObserver.disconnect();
        }
      },
      
      handleScroll() {
        const scrollTop = this.el.scrollTop;
        const viewportHeight = this.el.clientHeight;
        
        this.pushEvent('virtual_scroll', {
          scrollTop: scrollTop,
          viewportHeight: viewportHeight
        });
      },
      
      handleResize() {
        this.measureViewport();
      },
      
      measureViewport() {
        const rect = this.el.getBoundingClientRect();
        this.pushEvent('viewport_measured', {
          width: rect.width,
          height: rect.height
        });
      },
      
      handleKeyboard(e) {
        const rows = this.el.querySelectorAll('tr[data-row-index]');
        const currentIndex = this.getCurrentFocusIndex(rows);
        let newIndex = currentIndex;
        
        switch(e.key) {
          case 'ArrowDown':
            e.preventDefault();
            newIndex = Math.min(currentIndex + 1, rows.length - 1);
            break;
          case 'ArrowUp':
            e.preventDefault();
            newIndex = Math.max(currentIndex - 1, 0);
            break;
          case 'PageDown':
            e.preventDefault();
            newIndex = Math.min(currentIndex + 10, rows.length - 1);
            break;
          case 'PageUp':
            e.preventDefault();
            newIndex = Math.max(currentIndex - 10, 0);
            break;
          case 'Home':
            if (e.ctrlKey) {
              e.preventDefault();
              newIndex = 0;
              this.el.scrollTop = 0;
            }
            break;
          case 'End':
            if (e.ctrlKey) {
              e.preventDefault();
              newIndex = rows.length - 1;
              this.el.scrollTop = this.el.scrollHeight;
            }
            break;
        }
        
        if (newIndex !== currentIndex && rows[newIndex]) {
          this.focusRow(rows[newIndex]);
        }
      },
      
      getCurrentFocusIndex(rows) {
        for (let i = 0; i < rows.length; i++) {
          if (rows[i].contains(document.activeElement)) {
            return i;
          }
        }
        return 0;
      },
      
      focusRow(row) {
        // Find first focusable element in row
        const focusable = row.querySelector('button, a, input, select, textarea, [tabindex]');
        if (focusable) {
          focusable.focus();
        } else {
          row.setAttribute('tabindex', '0');
          row.focus();
        }
        
        // Ensure row is visible
        const rowTop = row.offsetTop;
        const rowBottom = rowTop + row.offsetHeight;
        const scrollTop = this.el.scrollTop;
        const scrollBottom = scrollTop + this.el.clientHeight;
        
        if (rowTop < scrollTop) {
          this.el.scrollTop = rowTop;
        } else if (rowBottom > scrollBottom) {
          this.el.scrollTop = rowBottom - this.el.clientHeight;
        }
      },
      
      setupRowHeightObserver() {
        this.rowObserver = new IntersectionObserver((entries) => {
          entries.forEach(entry => {
            if (entry.isIntersecting) {
              const row = entry.target;
              const index = parseInt(row.dataset.rowIndex);
              const height = row.getBoundingClientRect().height;
              
              if (height !== this.rowHeight) {
                this.pushEvent('row_height_changed', {
                  index: index,
                  height: height
                });
              }
            }
          });
        }, {
          root: this.el,
          rootMargin: '100px'
        });
        
        // Observe all rows
        this.el.querySelectorAll('tr[data-row-index]').forEach(row => {
          this.rowObserver.observe(row);
        });
      },
      
      throttle(func, limit) {
        let inThrottle;
        return function() {
          const args = arguments;
          const context = this;
          if (!inThrottle) {
            func.apply(context, args);
            inThrottle = true;
            setTimeout(() => inThrottle = false, limit);
          }
        }
      },
      
      debounce(func, wait) {
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
    };
    """
  end
  
  # Private helper functions
  
  defp calculate_visible_range(assigns) do
    scroll_top = Map.get(assigns, :scroll_top, 0)
    viewport_height = Map.get(assigns, :viewport_height, 600)
    row_height = Map.get(assigns, :row_height, @default_row_height)
    overscan = Map.get(assigns, :overscan, @default_overscan)
    total_rows = length(assigns.rows)
    
    start_index = max(0, div(scroll_top, row_height) - overscan)
    visible_count = div(viewport_height, row_height) + overscan * 2
    end_index = min(start_index + visible_count, total_rows - 1)
    
    %{start: start_index, end: end_index, count: end_index - start_index + 1}
  end
  
  defp slice_rows(rows, %{start: start_idx, count: count}) do
    rows
    |> Enum.drop(start_idx)
    |> Enum.take(count)
  end
  
  defp calculate_total_height(total_rows, row_height) do
    total_rows * row_height
  end
  
  defp calculate_offset(start_index, row_height) do
    start_index * row_height
  end
  
  defp calculate_visible_end(start, viewport_height, row_height) do
    start + div(viewport_height, row_height) + @default_overscan
  end
  
  defp should_load_more?(virtual) do
    # Load more when scrolled to within 20% of the end
    scroll_percentage = virtual.scroll_top / (virtual.total_rows * virtual.row_height)
    scroll_percentage > 0.8 and not virtual.loading
  end
  
  @doc """
  CSS styles for virtual scrolling.
  """
  def virtual_scroll_styles do
    """
    .virtual-scroll-container {
      position: relative;
      overflow-y: auto;
      overflow-x: hidden;
      -webkit-overflow-scrolling: touch;
    }
    
    .virtual-scroll-spacer {
      position: relative;
      width: 100%;
    }
    
    .virtual-scroll-content {
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
      will-change: transform;
    }
    
    /* Smooth scrolling */
    .virtual-scroll-container {
      scroll-behavior: smooth;
    }
    
    /* Prevent layout shift */
    .virtual-scroll-container table {
      table-layout: fixed;
    }
    
    /* Focus styles for keyboard navigation */
    .virtual-scroll-container tr:focus {
      outline: 2px solid #3B82F6;
      outline-offset: -2px;
    }
    
    /* Loading state */
    .virtual-scroll-loading {
      pointer-events: none;
      opacity: 0.6;
    }
    """
  end
end