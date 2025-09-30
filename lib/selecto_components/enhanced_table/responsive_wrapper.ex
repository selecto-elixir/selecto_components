defmodule SelectoComponents.EnhancedTable.ResponsiveWrapper do
  @moduledoc """
  Provides responsive wrapper functionality for tables.
  Implements mobile-friendly layouts, horizontal scrolling, and touch interactions.
  """
  
  use Phoenix.LiveComponent
  
  @breakpoints %{
    mobile: 640,
    tablet: 768,
    desktop: 1024,
    wide: 1280
  }
  
  def render(assigns) do
    ~H"""
    <div class="responsive-table-wrapper" id={"responsive-wrapper-#{@id}"}>
      <!-- Mobile View Controls -->
      <div class="mobile-controls mb-4 lg:hidden">
        <div class="flex justify-between items-center">
          <button
            type="button"
            phx-click="toggle_mobile_layout"
            phx-target={@myself}
            class="px-3 py-2 bg-gray-100 rounded text-sm"
          >
            <%= mobile_layout_icon(@mobile_layout) %>
            <span class="ml-2"><%= mobile_layout_label(@mobile_layout) %></span>
          </button>
          
          <button
            type="button"
            phx-click="toggle_column_selector"
            phx-target={@myself}
            class="px-3 py-2 bg-gray-100 rounded text-sm"
          >
            <svg class="w-4 h-4 inline" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4"></path>
            </svg>
            Columns
          </button>
        </div>
        
        <!-- Column Selector Dropdown -->
        <%= if @show_column_selector do %>
          <div class="mt-2 p-3 bg-white border rounded-lg shadow-lg">
            <h4 class="text-sm font-semibold mb-2">Visible Columns</h4>
            <div class="space-y-1">
              <%= for {col_id, col_name} <- @available_columns do %>
                <label class="flex items-center">
                  <input
                    type="checkbox"
                    phx-click="toggle_column"
                    phx-target={@myself}
                    phx-value-column={col_id}
                    checked={Map.get(@column_visibility, col_id, true)}
                    class="rounded mr-2"
                  />
                  <span class="text-sm"><%= col_name %></span>
                </label>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
      
      <!-- Table Container -->
      <div 
        class={"responsive-table-container #{responsive_container_classes(@viewport_size)}"}
        id={"table-container-#{@id}"}
        phx-hook="ResponsiveTable"
        data-viewport-size={@viewport_size}
        data-sticky-header={@sticky_header}
      >
        <%= case @mobile_layout do %>
          <% :card -> %>
            <.render_card_layout data={@data} columns={@visible_columns} myself={@myself} />
          
          <% :stacked -> %>
            <.render_stacked_layout data={@data} columns={@visible_columns} myself={@myself} />
          
          <% _ -> %>
            <!-- Horizontal scrollable table -->
            <div class="overflow-x-auto" id={"scroll-container-#{@id}"}>
              <table class="min-w-full divide-y divide-gray-200">
                <.render_sticky_header columns={@visible_columns} sticky={@sticky_header} />
                <.render_table_body data={@data} columns={@visible_columns} />
              </table>
              
              <!-- Scroll Indicators -->
              <div class="scroll-indicators hidden sm:block">
                <div 
                  id={"scroll-left-#{@id}"}
                  class="scroll-indicator-left"
                  phx-hook="ScrollIndicator"
                  data-direction="left"
                />
                <div 
                  id={"scroll-right-#{@id}"}
                  class="scroll-indicator-right"
                  phx-hook="ScrollIndicator"
                  data-direction="right"
                />
              </div>
            </div>
        <% end %>
      </div>
      
      <!-- Pagination for Mobile -->
      <%= if @viewport_size in [:mobile, :tablet] && @pagination do %>
        <.mobile_pagination pagination={@pagination} myself={@myself} />
      <% end %>
    </div>
    """
  end
  
  defp render_card_layout(assigns) do
    ~H"""
    <div class="space-y-4">
      <%= for row <- @data do %>
        <div class="bg-white p-4 rounded-lg shadow border">
          <%= for {col_id, col_name} <- @columns do %>
            <div class="flex justify-between py-2 border-b last:border-0">
              <span class="text-sm font-medium text-gray-500"><%= col_name %></span>
              <span class="text-sm text-gray-900"><%= Map.get(row, col_id) %></span>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
  
  defp render_stacked_layout(assigns) do
    ~H"""
    <div class="space-y-2">
      <%= for row <- @data do %>
        <div class="bg-white border rounded">
          <div class="p-3 bg-gray-50 font-medium">
            <%= Map.get(row, elem(List.first(@columns), 0)) %>
          </div>
          <div class="p-3 space-y-1">
            <%= for {col_id, col_name} <- Enum.drop(@columns, 1) do %>
              <div class="flex justify-between text-sm">
                <span class="text-gray-500"><%= col_name %>:</span>
                <span class="text-gray-900"><%= Map.get(row, col_id) %></span>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
  
  defp render_sticky_header(assigns) do
    ~H"""
    <thead class={"bg-gray-50 #{if @sticky, do: "sticky top-0 z-10"}"}>
      <tr>
        <%= for {col_id, col_name} <- @columns do %>
          <th 
            scope="col"
            class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
          >
            <%= col_name %>
          </th>
        <% end %>
      </tr>
    </thead>
    """
  end
  
  defp render_table_body(assigns) do
    ~H"""
    <tbody class="bg-white divide-y divide-gray-200">
      <%= for row <- @data do %>
        <tr class="hover:bg-gray-50">
          <%= for {col_id, _col_name} <- @columns do %>
            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
              <%= Map.get(row, col_id) %>
            </td>
          <% end %>
        </tr>
      <% end %>
    </tbody>
    """
  end
  
  defp mobile_pagination(assigns) do
    ~H"""
    <div class="mt-4 flex justify-between items-center">
      <button
        phx-click="prev_page"
        phx-target={@myself}
        disabled={@pagination.page <= 1}
        class="px-4 py-2 bg-gray-100 rounded disabled:opacity-50"
      >
        Previous
      </button>
      
      <span class="text-sm text-gray-700">
        Page <%= @pagination.page %> of <%= @pagination.total_pages %>
      </span>
      
      <button
        phx-click="next_page"
        phx-target={@myself}
        disabled={@pagination.page >= @pagination.total_pages}
        class="px-4 py-2 bg-gray-100 rounded disabled:opacity-50"
      >
        Next
      </button>
    </div>
    """
  end
  
  def mount(socket) do
    {:ok,
     socket
     |> assign(
       id: Ecto.UUID.generate(),
       viewport_size: :desktop,
       mobile_layout: :horizontal,
       sticky_header: true,
       show_column_selector: false,
       column_visibility: %{},
       available_columns: [],
       visible_columns: [],
       data: [],
       pagination: nil
     )}
  end
  
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> detect_viewport_size()
     |> update_visible_columns()}
  end
  
  def handle_event("toggle_mobile_layout", _params, socket) do
    layouts = [:horizontal, :stacked, :card]
    current_index = Enum.find_index(layouts, &(&1 == socket.assigns.mobile_layout))
    next_layout = Enum.at(layouts, rem(current_index + 1, length(layouts)))
    
    {:noreply, assign(socket, mobile_layout: next_layout)}
  end
  
  def handle_event("toggle_column_selector", _params, socket) do
    {:noreply, update(socket, :show_column_selector, &(!&1))}
  end
  
  def handle_event("toggle_column", %{"column" => column_id}, socket) do
    visibility = Map.update(
      socket.assigns.column_visibility,
      column_id,
      false,
      &(!&1)
    )
    
    {:noreply,
     socket
     |> assign(column_visibility: visibility)
     |> update_visible_columns()}
  end
  
  def handle_event("viewport_changed", %{"width" => width}, socket) do
    viewport_size = determine_viewport_size(width)
    
    {:noreply,
     socket
     |> assign(viewport_size: viewport_size)
     |> apply_responsive_defaults()}
  end
  
  def handle_event("prev_page", _params, socket) do
    if socket.assigns.pagination && socket.assigns.pagination.page > 1 do
      send(self(), {:change_page, socket.assigns.pagination.page - 1})
    end
    {:noreply, socket}
  end
  
  def handle_event("next_page", _params, socket) do
    pagination = socket.assigns.pagination
    if pagination && pagination.page < pagination.total_pages do
      send(self(), {:change_page, pagination.page + 1})
    end
    {:noreply, socket}
  end
  
  defp detect_viewport_size(socket) do
    # This would be updated via JavaScript hook
    socket
  end
  
  defp update_visible_columns(socket) do
    all_columns = socket.assigns.available_columns
    visibility = socket.assigns.column_visibility
    
    visible = Enum.filter(all_columns, fn {col_id, _} ->
      Map.get(visibility, col_id, true)
    end)
    
    assign(socket, visible_columns: visible)
  end
  
  defp determine_viewport_size(width) when is_integer(width) do
    cond do
      width < @breakpoints.mobile -> :mobile
      width < @breakpoints.tablet -> :tablet
      width < @breakpoints.desktop -> :tablet
      true -> :desktop
    end
  end
  
  defp apply_responsive_defaults(socket) do
    case socket.assigns.viewport_size do
      :mobile ->
        socket
        |> assign(mobile_layout: :card)
        |> apply_mobile_column_priorities()
        
      :tablet ->
        socket
        |> assign(mobile_layout: :horizontal)
        |> apply_tablet_column_priorities()
        
      _ ->
        socket
        |> assign(mobile_layout: :horizontal)
        |> show_all_columns()
    end
  end
  
  defp apply_mobile_column_priorities(socket) do
    # Show only high-priority columns on mobile
    priority_columns = get_priority_columns(socket.assigns.available_columns, :high)
    visibility = Map.new(socket.assigns.available_columns, fn {col_id, _} ->
      {col_id, col_id in priority_columns}
    end)
    
    assign(socket, column_visibility: visibility)
  end
  
  defp apply_tablet_column_priorities(socket) do
    # Show high and medium priority columns on tablet
    priority_columns = get_priority_columns(socket.assigns.available_columns, :medium)
    visibility = Map.new(socket.assigns.available_columns, fn {col_id, _} ->
      {col_id, col_id in priority_columns}
    end)
    
    assign(socket, column_visibility: visibility)
  end
  
  defp show_all_columns(socket) do
    visibility = Map.new(socket.assigns.available_columns, fn {col_id, _} ->
      {col_id, true}
    end)
    
    assign(socket, column_visibility: visibility)
  end
  
  defp get_priority_columns(columns, min_priority) do
    # This would be configured based on column metadata
    # For now, return first few columns based on priority
    case min_priority do
      :high -> columns |> Enum.take(3) |> Enum.map(&elem(&1, 0))
      :medium -> columns |> Enum.take(5) |> Enum.map(&elem(&1, 0))
      _ -> Enum.map(columns, &elem(&1, 0))
    end
  end
  
  defp responsive_container_classes(viewport_size) do
    base = "transition-all duration-300"
    
    case viewport_size do
      :mobile -> "#{base} px-2"
      :tablet -> "#{base} px-4"
      _ -> "#{base} px-6"
    end
  end
  
  defp mobile_layout_icon(layout) do
    case layout do
      :card ->
        ~s(<svg class="w-4 h-4 inline" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"></path>
        </svg>)
        
      :stacked ->
        ~s(<svg class="w-4 h-4 inline" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 10h16M4 14h16M4 18h16"></path>
        </svg>)
        
      _ ->
        ~s(<svg class="w-4 h-4 inline" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 10h18M3 14h18m-9-4v8m-7 0h14a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"></path>
        </svg>)
    end
  end
  
  defp mobile_layout_label(layout) do
    case layout do
      :card -> "Card View"
      :stacked -> "Stacked View"
      _ -> "Table View"
    end
  end
  
  @doc """
  JavaScript hooks for responsive behavior.
  """
  def __hooks__() do
    %{
      "ResponsiveTable" => """
      export default {
        mounted() {
          this.handleResize = this.handleResize.bind(this);
          this.handleScroll = this.handleScroll.bind(this);
          this.handleOrientationChange = this.handleOrientationChange.bind(this);
          
          // Initial setup
          this.setupViewport();
          this.setupScrollIndicators();
          this.setupTouchHandling();
          
          // Event listeners
          window.addEventListener('resize', this.handleResize);
          window.addEventListener('orientationchange', this.handleOrientationChange);
          this.el.addEventListener('scroll', this.handleScroll);
        },
        
        destroyed() {
          window.removeEventListener('resize', this.handleResize);
          window.removeEventListener('orientationchange', this.handleOrientationChange);
          this.el.removeEventListener('scroll', this.handleScroll);
        },
        
        setupViewport() {
          this.sendViewportSize();
        },
        
        setupScrollIndicators() {
          const container = this.el.querySelector('.overflow-x-auto');
          if (!container) return;
          
          this.updateScrollIndicators(container);
        },
        
        setupTouchHandling() {
          // Enhanced touch scrolling for mobile
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
        },
        
        handleResize() {
          clearTimeout(this.resizeTimeout);
          this.resizeTimeout = setTimeout(() => {
            this.sendViewportSize();
            this.setupScrollIndicators();
          }, 250);
        },
        
        handleOrientationChange() {
          setTimeout(() => {
            this.sendViewportSize();
            this.setupScrollIndicators();
          }, 100);
        },
        
        handleScroll(e) {
          this.updateScrollIndicators(e.target);
        },
        
        sendViewportSize() {
          const width = window.innerWidth;
          this.pushEventTo(this.el, 'viewport_changed', { width });
        },
        
        updateScrollIndicators(container) {
          const leftIndicator = this.el.querySelector('.scroll-indicator-left');
          const rightIndicator = this.el.querySelector('.scroll-indicator-right');
          
          if (!leftIndicator || !rightIndicator) return;
          
          const scrollLeft = container.scrollLeft;
          const scrollWidth = container.scrollWidth;
          const clientWidth = container.clientWidth;
          
          // Show/hide indicators based on scroll position
          if (scrollLeft > 0) {
            leftIndicator.classList.add('active');
          } else {
            leftIndicator.classList.remove('active');
          }
          
          if (scrollLeft < scrollWidth - clientWidth - 1) {
            rightIndicator.classList.add('active');
          } else {
            rightIndicator.classList.remove('active');
          }
        }
      }
      """,
      
      "ScrollIndicator" => """
      export default {
        mounted() {
          const direction = this.el.dataset.direction;
          const container = this.el.closest('.overflow-x-auto');
          
          this.el.addEventListener('click', () => {
            if (!container) return;
            
            const scrollAmount = container.clientWidth * 0.8;
            const currentScroll = container.scrollLeft;
            
            if (direction === 'left') {
              container.scrollTo({
                left: Math.max(0, currentScroll - scrollAmount),
                behavior: 'smooth'
              });
            } else {
              container.scrollTo({
                left: currentScroll + scrollAmount,
                behavior: 'smooth'
              });
            }
          });
        }
      }
      """
    }
  end
  
  @doc """
  CSS styles for responsive tables.
  """
  def styles() do
    """
    <style>
      .responsive-table-container {
        @apply relative;
      }
      
      .scroll-indicator-left,
      .scroll-indicator-right {
        @apply absolute top-1/2 transform -translate-y-1/2 z-20;
        @apply w-8 h-8 bg-white rounded-full shadow-lg;
        @apply flex items-center justify-center cursor-pointer;
        @apply opacity-0 transition-opacity duration-200;
      }
      
      .scroll-indicator-left {
        @apply left-2;
      }
      
      .scroll-indicator-right {
        @apply right-2;
      }
      
      .scroll-indicator-left.active,
      .scroll-indicator-right.active {
        @apply opacity-100;
      }
      
      .scroll-indicator-left:hover,
      .scroll-indicator-right:hover {
        @apply bg-gray-100;
      }
      
      /* Sticky header styles */
      thead.sticky {
        @apply shadow-sm;
      }
      
      /* Mobile-specific styles */
      @media (max-width: 640px) {
        .responsive-table-container {
          @apply -mx-2;
        }
        
        table {
          @apply text-sm;
        }
        
        th, td {
          @apply px-3 py-2;
        }
      }
      
      /* Touch-friendly tap targets */
      @media (hover: none) {
        button, a, .clickable {
          @apply min-h-[44px] min-w-[44px];
        }
      }
      
      /* Landscape orientation adjustments */
      @media (orientation: landscape) and (max-height: 500px) {
        thead.sticky {
          @apply top-0;
        }
        
        .mobile-controls {
          @apply sticky top-0 z-30 bg-white;
        }
      }
    </style>
    """
  end
end