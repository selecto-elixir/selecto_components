defmodule SelectoComponents.EnhancedTable.Virtualization do
  @moduledoc """
  Virtual scrolling implementation for efficient rendering of large datasets.
  Only renders visible rows while maintaining smooth scrolling experience.
  """
  
  use Phoenix.LiveComponent
  
  @default_row_height 48
  @default_buffer_size 5
  @default_page_size 50
  @default_overscan 3
  @default_viewport_height 600
  
  def render(assigns) do
    ~H"""
    <div class="virtual-scroll-wrapper" id={"virtual-wrapper-#{@id}"}>
      <!-- Virtual Scroll Info Bar -->
      <%= if @show_info do %>
        <div class="virtual-scroll-info bg-gray-50 px-4 py-2 text-sm text-gray-600 flex justify-between items-center">
          <span>
            Showing rows <%= @visible_start + 1 %> - <%= min(@visible_end, @total_rows) %> of <%= @total_rows %>
          </span>
          <span class="text-xs text-gray-500">
            Rendered: <%= @rendered_count %> | Buffer: <%= @buffer_size %>
          </span>
        </div>
      <% end %>
      
      <!-- Main Virtual Scroll Container -->
      <div
        id={"virtual-scroll-#{@id}"}
        class="virtual-scroll-viewport relative overflow-y-auto"
        phx-hook="VirtualScroll"
        data-row-height={@row_height}
        data-total-rows={@total_rows}
        data-overscan={@overscan}
        data-buffer-size={@buffer_size}
        style={"height: #{@viewport_height}px;"}
      >
        <!-- Total Height Spacer -->
        <div 
          class="virtual-scroll-spacer"
          style={"height: #{calculate_total_height(@total_rows, @row_height, @row_heights)}px; position: relative;"}
        >
          <!-- Visible Rows Container -->
          <div
            class="virtual-scroll-content"
            style={"transform: translateY(#{@scroll_offset}px);"}
          >
            <%= for index <- @visible_start..(@visible_end - 1) do %>
              <% row = get_row(@data, index, @row_cache) %>
              <%= if row do %>
                <div
                  id={"virtual-row-#{@id}-#{index}"}
                  class="virtual-row"
                  data-row-index={index}
                  style={"height: #{get_row_height(index, @row_height, @row_heights)}px;"}
                >
                  <%= if @row_renderer do %>
                    <%= @row_renderer.(row, index, @columns) %>
                  <% else %>
                    <.default_row_renderer row={row} columns={@columns} index={index} />
                  <% end %>
                </div>
              <% end %>
            <% end %>
          </div>
          
          <!-- Loading Indicators -->
          <%= if @loading_top do %>
            <div class="loading-indicator-top absolute top-0 left-0 right-0 flex justify-center py-2">
              <.loading_spinner />
            </div>
          <% end %>
          
          <%= if @loading_bottom do %>
            <div class="loading-indicator-bottom absolute bottom-0 left-0 right-0 flex justify-center py-2">
              <.loading_spinner />
            </div>
          <% end %>
        </div>
      </div>
      
      <!-- Scroll Bar Indicator -->
      <%= if @show_scroll_indicator do %>
        <div class="virtual-scroll-indicator absolute right-0 top-0 w-2 bg-gray-200" style={"height: #{@viewport_height}px;"}>
          <div 
            class="scroll-thumb bg-gray-600 rounded"
            style={"height: #{calculate_thumb_height(@viewport_height, @total_rows, @row_height)}px; transform: translateY(#{calculate_thumb_position(@scroll_top, @viewport_height, @total_rows, @row_height)}px);"}
          />
        </div>
      <% end %>
      
      <!-- Jump Controls -->
      <%= if @show_jump_control do %>
        <div class="virtual-scroll-controls mt-2 flex items-center gap-2">
          <input
            type="number"
            phx-blur="jump_to_row"
            phx-target={@myself}
            placeholder="Row #"
            min="1"
            max={@total_rows}
            class="w-24 px-2 py-1 text-sm border rounded"
          />
          <button
            type="button"
            phx-click="scroll_to_top"
            phx-target={@myself}
            class="px-3 py-1 text-sm bg-gray-100 rounded hover:bg-gray-200"
          >
            Top
          </button>
          <button
            type="button"
            phx-click="scroll_to_bottom"
            phx-target={@myself}
            class="px-3 py-1 text-sm bg-gray-100 rounded hover:bg-gray-200"
          >
            Bottom
          </button>
        </div>
      <% end %>
    </div>
    """
  end
  
  defp default_row_renderer(assigns) do
    ~H"""
    <div class="virtual-row-content flex items-center px-4 py-2 border-b hover:bg-gray-50">
      <%= for {col_id, col_name} <- @columns do %>
        <div class="flex-1 truncate">
          <%= Map.get(@row, col_id, "") %>
        </div>
      <% end %>
      <span class="text-xs text-gray-400 ml-2">#<%= @index + 1 %></span>
    </div>
    """
  end
  
  defp loading_spinner(assigns) do
    ~H"""
    <div class="animate-spin rounded-full h-6 w-6 border-b-2 border-gray-900"></div>
    """
  end
  
  def mount(socket) do
    {:ok,
     socket
     |> assign(
       id: Ecto.UUID.generate(),
       data: [],
       columns: [],
       total_rows: 0,
       viewport_height: @default_viewport_height,
       row_height: @default_row_height,
       row_heights: %{},
       buffer_size: @default_buffer_size,
       overscan: @default_overscan,
       scroll_top: 0,
       scroll_offset: 0,
       visible_start: 0,
       visible_end: 0,
       rendered_count: 0,
       row_cache: %{},
       loading_top: false,
       loading_bottom: false,
       show_info: true,
       show_scroll_indicator: false,
       show_jump_control: true,
       row_renderer: nil
     )}
  end
  
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> maybe_init_data()
     |> calculate_visible_range()
     |> update_metrics()}
  end
  
  def handle_event("viewport_scroll", %{"scrollTop" => scroll_top}, socket) do
    {:noreply,
     socket
     |> assign(scroll_top: scroll_top)
     |> calculate_visible_range()
     |> maybe_load_more_data()}
  end
  
  def handle_event("jump_to_row", %{"value" => row_str}, socket) do
    case Integer.parse(row_str) do
      {row_num, _} when row_num > 0 and row_num <= socket.assigns.total_rows ->
        {:noreply, jump_to_row(socket, row_num - 1)}
      _ ->
        {:noreply, socket}
    end
  end
  
  def handle_event("scroll_to_top", _params, socket) do
    {:noreply, jump_to_row(socket, 0)}
  end
  
  def handle_event("scroll_to_bottom", _params, socket) do
    {:noreply, jump_to_row(socket, socket.assigns.total_rows - 1)}
  end
  
  def handle_event("row_height_measured", %{"index" => index, "height" => height}, socket) do
    row_heights = Map.put(socket.assigns.row_heights, index, height)
    
    {:noreply,
     socket
     |> assign(row_heights: row_heights)
     |> recalculate_offsets()}
  end
  
  # Initialize data if needed
  defp maybe_init_data(socket) do
    if socket.assigns[:data] && is_list(socket.assigns.data) do
      total_rows = length(socket.assigns.data)
      assign(socket, total_rows: total_rows)
    else
      socket
    end
  end
  
  # Calculate which rows should be visible
  defp calculate_visible_range(socket) do
    %{
      scroll_top: scroll_top,
      viewport_height: viewport_height,
      row_height: row_height,
      total_rows: total_rows,
      overscan: overscan
    } = socket.assigns
    
    if total_rows == 0 do
      assign(socket,
        visible_start: 0,
        visible_end: 0,
        rendered_count: 0,
        scroll_offset: 0
      )
    else
      # Calculate visible range with overscan
      first_visible = div(scroll_top, row_height)
      last_visible = div(scroll_top + viewport_height, row_height)
      
      visible_start = max(0, first_visible - overscan)
      visible_end = min(total_rows, last_visible + overscan + 1)
      
      scroll_offset = visible_start * row_height
      
      assign(socket,
        visible_start: visible_start,
        visible_end: visible_end,
        rendered_count: visible_end - visible_start,
        scroll_offset: scroll_offset
      )
    end
  end
  
  # Get row from data or cache
  defp get_row(data, index, _cache) when is_list(data) do
    Enum.at(data, index)
  end
  
  defp get_row(_data, index, cache) do
    Map.get(cache, index)
  end
  
  # Get row height
  defp get_row_height(index, default_height, row_heights) do
    Map.get(row_heights, index, default_height)
  end
  
  # Calculate total scrollable height
  defp calculate_total_height(total_rows, row_height, row_heights) when map_size(row_heights) == 0 do
    total_rows * row_height
  end
  
  defp calculate_total_height(total_rows, default_height, row_heights) do
    # Sum custom heights and add default for remaining
    custom_height = Enum.reduce(row_heights, 0, fn {_idx, height}, acc -> acc + height end)
    remaining_rows = total_rows - map_size(row_heights)
    custom_height + (remaining_rows * default_height)
  end
  
  # Jump to specific row
  defp jump_to_row(socket, row_index) do
    row_height = socket.assigns.row_height
    scroll_top = row_index * row_height
    
    socket
    |> assign(scroll_top: scroll_top)
    |> calculate_visible_range()
    |> push_event("scroll_to", %{top: scroll_top})
  end
  
  # Check if more data needs to be loaded
  defp maybe_load_more_data(socket) do
    %{
      visible_end: visible_end,
      total_rows: total_rows,
      buffer_size: buffer_size
    } = socket.assigns
    
    if visible_end + buffer_size >= total_rows && not socket.assigns.loading_bottom do
      send(self(), {:load_more_rows, :bottom})
      assign(socket, loading_bottom: true)
    else
      socket
    end
  end
  
  # Recalculate offsets when row heights change
  defp recalculate_offsets(socket) do
    calculate_visible_range(socket)
  end
  
  # Update performance metrics
  defp update_metrics(socket) do
    assign(socket, last_update: System.monotonic_time(:millisecond))
  end
  
  # Calculate scroll thumb size
  defp calculate_thumb_height(viewport_height, total_rows, row_height) do
    total_height = total_rows * row_height
    if total_height > 0 do
      max(20, div(viewport_height * viewport_height, total_height))
    else
      viewport_height
    end
  end
  
  # Calculate scroll thumb position
  defp calculate_thumb_position(scroll_top, viewport_height, total_rows, row_height) do
    total_height = total_rows * row_height
    scrollable_height = total_height - viewport_height
    
    if scrollable_height > 0 do
      thumb_height = calculate_thumb_height(viewport_height, total_rows, row_height)
      track_height = viewport_height - thumb_height
      div(scroll_top * track_height, scrollable_height)
    else
      0
    end
  end
  
  @doc """
  JavaScript hooks for virtual scrolling.
  """
  def __hooks__() do
    %{
      "VirtualScroll" => """
      export default {
        mounted() {
          this.scrollTop = 0;
          this.ticking = false;
          this.scrollTimer = null;
          
          // Setup scroll listener with RAF throttling
          this.handleScroll = this.handleScroll.bind(this);
          this.el.addEventListener('scroll', this.handleScroll);
          
          // Keyboard navigation
          this.handleKeydown = this.handleKeydown.bind(this);
          this.el.addEventListener('keydown', this.handleKeydown);
          this.el.tabIndex = 0; // Make focusable
          
          // Handle scroll-to events
          this.handleEvent('scroll_to', ({top}) => {
            this.el.scrollTop = top;
          });
        },
        
        destroyed() {
          this.el.removeEventListener('scroll', this.handleScroll);
          this.el.removeEventListener('keydown', this.handleKeydown);
          if (this.scrollTimer) {
            clearTimeout(this.scrollTimer);
          }
        },
        
        handleScroll(e) {
          const scrollTop = e.target.scrollTop;
          
          // Throttle using RAF
          if (!this.ticking) {
            requestAnimationFrame(() => {
              this.pushEventTo(this.el, 'viewport_scroll', {
                scrollTop: scrollTop
              });
              this.ticking = false;
            });
            this.ticking = true;
          }
          
          // Store for keyboard nav
          this.scrollTop = scrollTop;
        },
        
        handleKeydown(e) {
          const rowHeight = parseInt(this.el.dataset.rowHeight) || 48;
          const viewportHeight = this.el.clientHeight;
          let newScrollTop = this.scrollTop;
          
          switch(e.key) {
            case 'ArrowUp':
              e.preventDefault();
              newScrollTop = Math.max(0, this.scrollTop - rowHeight);
              break;
            case 'ArrowDown':
              e.preventDefault();
              newScrollTop = this.scrollTop + rowHeight;
              break;
            case 'PageUp':
              e.preventDefault();
              newScrollTop = Math.max(0, this.scrollTop - viewportHeight);
              break;
            case 'PageDown':
              e.preventDefault();
              newScrollTop = this.scrollTop + viewportHeight;
              break;
            case 'Home':
              if (e.ctrlKey) {
                e.preventDefault();
                newScrollTop = 0;
              }
              break;
            case 'End':
              if (e.ctrlKey) {
                e.preventDefault();
                const spacer = this.el.querySelector('.virtual-scroll-spacer');
                if (spacer) {
                  newScrollTop = spacer.offsetHeight - viewportHeight;
                }
              }
              break;
          }
          
          if (newScrollTop !== this.scrollTop) {
            this.el.scrollTop = newScrollTop;
          }
        }
      }
      """
    }
  end
  
  @doc """
  Helper to set up virtual scrolling for a dataset.
  """
  def setup_virtual_scroll(socket, data, columns, opts \\ []) do
    socket
    |> assign(
      data: data,
      columns: columns,
      total_rows: length(data),
      viewport_height: Keyword.get(opts, :viewport_height, @default_viewport_height),
      row_height: Keyword.get(opts, :row_height, @default_row_height),
      show_info: Keyword.get(opts, :show_info, true),
      show_jump_control: Keyword.get(opts, :show_jump_control, true)
    )
    |> calculate_visible_range()
  end
end