defmodule SelectoComponents.Performance.VirtualScroll do
  @moduledoc """
  Virtual scrolling component for efficiently rendering large datasets.
  Only renders visible rows to maintain performance with thousands of records.
  """
  
  use Phoenix.LiveComponent
  
  @default_row_height 48
  @default_buffer_size 5
  @default_viewport_height 600
  
  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(
       viewport_height: @default_viewport_height,
       scroll_top: 0,
       row_height: @default_row_height,
       buffer_size: @default_buffer_size,
       visible_start: 0,
       visible_end: 20,
       total_rows: 0,
       rows: [],
       rendered_rows: [],
       loading: false,
       row_heights: %{},
       variable_height: false,
       keyboard_focus: nil,
       last_scroll_time: System.system_time(:millisecond)
     )}
  end
  
  @impl true
  def update(assigns, socket) do
    socket = 
      socket
      |> assign(assigns)
      |> update_dimensions()
      |> calculate_visible_range()
      |> prepare_rendered_rows()
    
    {:ok, socket}
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <div 
      id={@id}
      class="virtual-scroll-container"
      phx-hook="VirtualScroll"
      data-row-height={@row_height}
      data-buffer-size={@buffer_size}
      data-variable-height={@variable_height}
    >
      <div 
        class="virtual-scroll-viewport"
        style={"height: #{@viewport_height}px; overflow-y: auto; position: relative;"}
        phx-scroll="handle_scroll"
        phx-target={@myself}
      >
        <%!-- Total height spacer --%>
        <div 
          class="virtual-scroll-spacer"
          style={"height: #{calculate_total_height(@total_rows, @row_height, @row_heights, @variable_height)}px; position: relative;"}
        >
          <%!-- Rendered rows container --%>
          <div 
            class="virtual-scroll-content"
            style={"transform: translateY(#{@visible_start * @row_height}px);"}
          >
            <%= for {row, index} <- Enum.with_index(@rendered_rows, @visible_start) do %>
              <div 
                class="virtual-row"
                data-index={index}
                style={row_style(index, @row_height, @row_heights, @variable_height)}
                phx-hook="VirtualRow"
                id={"virtual-row-#{index}"}
              >
                <%= render_row(assigns, row, index) %>
              </div>
            <% end %>
          </div>
        </div>
        
        <%!-- Loading indicator --%>
        <%= if @loading do %>
          <div class="absolute inset-x-0 bottom-0 p-4 bg-white/90 backdrop-blur">
            <div class="flex items-center justify-center space-x-2">
              <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-blue-600"></div>
              <span class="text-sm text-gray-600">Loading more...</span>
            </div>
          </div>
        <% end %>
      </div>
      
      <%!-- Scroll position indicator --%>
      <div class="virtual-scroll-indicator mt-2 text-xs text-gray-500">
        Showing rows <%= @visible_start + 1 %> - <%= min(@visible_end, @total_rows) %> of <%= @total_rows %>
      </div>
    </div>
    """
  end
  
  @impl true
  def handle_event("handle_scroll", %{"scrollTop" => scroll_top, "scrollHeight" => scroll_height}, socket) do
    current_time = System.system_time(:millisecond)
    
    # Throttle scroll events
    if current_time - socket.assigns.last_scroll_time > 16 do  # ~60fps
      socket = 
        socket
        |> assign(
          scroll_top: scroll_top,
          last_scroll_time: current_time
        )
        |> calculate_visible_range()
        |> prepare_rendered_rows()
        |> maybe_load_more_data(scroll_top, scroll_height)
      
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end
  
  @impl true
  def handle_event("measure_row", %{"index" => index, "height" => height}, socket) do
    if socket.assigns.variable_height do
      row_heights = Map.put(socket.assigns.row_heights, index, height)
      
      socket = 
        socket
        |> assign(row_heights: row_heights)
        |> recalculate_positions()
      
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end
  
  @impl true
  def handle_event("keyboard_navigate", %{"key" => key}, socket) do
    socket = handle_keyboard_navigation(socket, key)
    {:noreply, socket}
  end
  
  # Private functions
  
  defp update_dimensions(socket) do
    visible_rows = div(socket.assigns.viewport_height, socket.assigns.row_height)
    
    assign(socket, visible_rows: visible_rows)
  end
  
  defp calculate_visible_range(socket) do
    scroll_top = socket.assigns.scroll_top || 0
    row_height = socket.assigns.row_height
    buffer_size = socket.assigns.buffer_size
    viewport_height = socket.assigns.viewport_height
    
    first_visible = div(scroll_top, row_height)
    visible_count = div(viewport_height, row_height) + 1
    
    visible_start = max(0, first_visible - buffer_size)
    visible_end = min(
      socket.assigns.total_rows,
      first_visible + visible_count + buffer_size
    )
    
    assign(socket,
      visible_start: visible_start,
      visible_end: visible_end
    )
  end
  
  defp prepare_rendered_rows(socket) do
    start_idx = socket.assigns.visible_start
    end_idx = socket.assigns.visible_end
    
    rendered_rows = 
      socket.assigns.rows
      |> Enum.slice(start_idx..(end_idx - 1))
    
    assign(socket, rendered_rows: rendered_rows)
  end
  
  defp maybe_load_more_data(socket, scroll_top, scroll_height) do
    viewport_height = socket.assigns.viewport_height
    threshold = scroll_height - viewport_height - 200  # Load when 200px from bottom
    
    if scroll_top > threshold and not socket.assigns.loading do
      send(self(), {:load_more_data, socket.assigns.visible_end})
      assign(socket, loading: true)
    else
      socket
    end
  end
  
  defp calculate_total_height(total_rows, row_height, _row_heights, false) do
    total_rows * row_height
  end
  defp calculate_total_height(total_rows, default_height, row_heights, true) do
    Enum.reduce(0..(total_rows - 1), 0, fn index, acc ->
      acc + Map.get(row_heights, index, default_height)
    end)
  end
  
  defp row_style(index, row_height, _row_heights, false) do
    "height: #{row_height}px; position: absolute; top: 0; left: 0; right: 0;"
  end
  defp row_style(index, default_height, row_heights, true) do
    height = Map.get(row_heights, index, default_height)
    top = calculate_row_top(index, default_height, row_heights)
    "height: #{height}px; position: absolute; top: #{top}px; left: 0; right: 0;"
  end
  
  defp calculate_row_top(index, default_height, row_heights) do
    Enum.reduce(0..(index - 1), 0, fn i, acc ->
      acc + Map.get(row_heights, i, default_height)
    end)
  end
  
  defp recalculate_positions(socket) do
    # Trigger re-render with new positions
    socket
    |> calculate_visible_range()
    |> prepare_rendered_rows()
  end
  
  defp render_row(assigns, row, index) do
    assigns =
      assigns
      |> assign(:row, row)
      |> assign(:index, index)

    ~H"""
    <div class="flex items-center p-2 border-b border-gray-200 hover:bg-gray-50">
      <%= if @render_slot do %>
        <%= render_slot(@render_slot, @row) %>
      <% else %>
        <%= for column <- @columns do %>
          <div class="flex-1 px-2">
            <%= Map.get(@row, column.field) %>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end
  
  defp handle_keyboard_navigation(socket, "ArrowDown") do
    current_focus = socket.assigns.keyboard_focus || -1
    new_focus = min(current_focus + 1, socket.assigns.total_rows - 1)
    
    socket
    |> assign(keyboard_focus: new_focus)
    |> ensure_row_visible(new_focus)
  end
  
  defp handle_keyboard_navigation(socket, "ArrowUp") do
    current_focus = socket.assigns.keyboard_focus || 0
    new_focus = max(current_focus - 1, 0)
    
    socket
    |> assign(keyboard_focus: new_focus)
    |> ensure_row_visible(new_focus)
  end
  
  defp handle_keyboard_navigation(socket, "PageDown") do
    current_focus = socket.assigns.keyboard_focus || 0
    page_size = div(socket.assigns.viewport_height, socket.assigns.row_height)
    new_focus = min(current_focus + page_size, socket.assigns.total_rows - 1)
    
    socket
    |> assign(keyboard_focus: new_focus)
    |> ensure_row_visible(new_focus)
  end
  
  defp handle_keyboard_navigation(socket, "PageUp") do
    current_focus = socket.assigns.keyboard_focus || 0
    page_size = div(socket.assigns.viewport_height, socket.assigns.row_height)
    new_focus = max(current_focus - page_size, 0)
    
    socket
    |> assign(keyboard_focus: new_focus)
    |> ensure_row_visible(new_focus)
  end
  
  defp handle_keyboard_navigation(socket, "Home") do
    socket
    |> assign(keyboard_focus: 0)
    |> ensure_row_visible(0)
  end
  
  defp handle_keyboard_navigation(socket, "End") do
    last_row = socket.assigns.total_rows - 1
    
    socket
    |> assign(keyboard_focus: last_row)
    |> ensure_row_visible(last_row)
  end
  
  defp handle_keyboard_navigation(socket, _), do: socket
  
  defp ensure_row_visible(socket, row_index) do
    row_top = row_index * socket.assigns.row_height
    row_bottom = row_top + socket.assigns.row_height
    scroll_top = socket.assigns.scroll_top
    viewport_bottom = scroll_top + socket.assigns.viewport_height
    
    new_scroll_top = 
      cond do
        row_top < scroll_top -> row_top
        row_bottom > viewport_bottom -> row_bottom - socket.assigns.viewport_height
        true -> scroll_top
      end
    
    if new_scroll_top != scroll_top do
      socket
      |> assign(scroll_top: new_scroll_top)
      |> push_event("scroll_to", %{top: new_scroll_top})
      |> calculate_visible_range()
      |> prepare_rendered_rows()
    else
      socket
    end
  end
  
  @doc """
  JavaScript hooks for virtual scrolling.
  """
  def __hooks__() do
    %{
      "VirtualScroll" => %{
        mounted: """
        this.viewport = this.el.querySelector('.virtual-scroll-viewport');
        this.content = this.el.querySelector('.virtual-scroll-content');
        this.rowHeight = parseInt(this.el.dataset.rowHeight || '48');
        this.bufferSize = parseInt(this.el.dataset.bufferSize || '5');
        this.variableHeight = this.el.dataset.variableHeight === 'true';
        this.scrollTimeout = null;
        this.rafId = null;
        
        // Handle scroll events with RAF for smooth performance
        this.handleScroll = () => {
          if (this.rafId) {
            cancelAnimationFrame(this.rafId);
          }
          
          this.rafId = requestAnimationFrame(() => {
            const scrollTop = this.viewport.scrollTop;
            const scrollHeight = this.viewport.scrollHeight;
            
            this.pushEvent('handle_scroll', {
              scrollTop: scrollTop,
              scrollHeight: scrollHeight
            });
          });
        };
        
        // Keyboard navigation
        this.handleKeydown = (e) => {
          const keys = ['ArrowUp', 'ArrowDown', 'PageUp', 'PageDown', 'Home', 'End'];
          
          if (keys.includes(e.key)) {
            e.preventDefault();
            this.pushEvent('keyboard_navigate', { key: e.key });
          }
        };
        
        // Smooth scroll to position
        this.scrollTo = (top) => {
          this.viewport.scrollTo({
            top: top,
            behavior: 'smooth'
          });
        };
        
        // Handle scroll to events from server
        this.handleEvent('scroll_to', ({top}) => {
          this.scrollTo(top);
        });
        
        // Intersection observer for visible rows
        this.observeVisibleRows = () => {
          const options = {
            root: this.viewport,
            rootMargin: '100px',
            threshold: 0
          };
          
          this.observer = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
              if (entry.isIntersecting) {
                entry.target.classList.add('is-visible');
              } else {
                entry.target.classList.remove('is-visible');
              }
            });
          }, options);
          
          // Observe all rows
          this.el.querySelectorAll('.virtual-row').forEach(row => {
            this.observer.observe(row);
          });
        };
        
        // Add event listeners
        this.viewport.addEventListener('scroll', this.handleScroll, { passive: true });
        this.el.addEventListener('keydown', this.handleKeydown);
        
        // Start observing
        this.observeVisibleRows();
        
        // Measure rows if variable height
        if (this.variableHeight) {
          this.measureRows();
        }
        """,
        
        updated: """
        // Re-observe rows after update
        if (this.observer) {
          this.observer.disconnect();
          this.observeVisibleRows();
        }
        
        // Re-measure if needed
        if (this.variableHeight) {
          this.measureRows();
        }
        """,
        
        destroyed: """
        this.viewport.removeEventListener('scroll', this.handleScroll);
        this.el.removeEventListener('keydown', this.handleKeydown);
        
        if (this.observer) {
          this.observer.disconnect();
        }
        
        if (this.rafId) {
          cancelAnimationFrame(this.rafId);
        }
        
        if (this.scrollTimeout) {
          clearTimeout(this.scrollTimeout);
        }
        """
      },
      
      "VirtualRow" => %{
        mounted: """
        this.index = parseInt(this.el.dataset.index);
        
        // Measure row height if needed
        if (this.el.closest('[data-variable-height="true"]')) {
          const height = this.el.offsetHeight;
          this.pushEventTo(this.el.closest('.virtual-scroll-container'), 'measure_row', {
            index: this.index,
            height: height
          });
        }
        
        // Handle row focus
        this.el.setAttribute('tabindex', '-1');
        
        this.handleFocus = () => {
          this.pushEventTo(this.el.closest('.virtual-scroll-container'), 'row_focused', {
            index: this.index
          });
        };
        
        this.el.addEventListener('focus', this.handleFocus);
        """,
        
        destroyed: """
        this.el.removeEventListener('focus', this.handleFocus);
        """
      }
    }
  end
end