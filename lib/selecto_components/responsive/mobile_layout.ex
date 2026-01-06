defmodule SelectoComponents.Responsive.MobileLayout do
  @moduledoc """
  Mobile-optimized layout components for responsive tables and data views.
  """

  use Phoenix.Component
  alias Phoenix.LiveView.JS
  alias SelectoComponents.SafeAtom
  
  @doc """
  Mobile stacked view for table data.
  Each row is displayed as a stacked card with label-value pairs.
  """
  def stacked_view(assigns) do
    ~H"""
    <div class="mobile-stacked-view space-y-2">
      <%= for row <- @rows do %>
        <div class="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden">
          <div class="p-4 space-y-3">
            <%= for {column, index} <- Enum.with_index(@columns) do %>
              <%= if index == 0 do %>
                <div class="font-medium text-gray-900">
                  <%= get_value(row, column.field) %>
                </div>
              <% else %>
                <div class="flex justify-between items-start text-sm">
                  <span class="text-gray-500 font-medium min-w-[40%]">
                    <%= column.label %>
                  </span>
                  <span class="text-gray-900 text-right">
                    <%= get_value(row, column.field) %>
                  </span>
                </div>
              <% end %>
            <% end %>
          </div>
          
          <%= if assigns[:actions] do %>
            <div class="bg-gray-50 px-4 py-2 border-t border-gray-200">
              <.mobile_actions row={row} actions={@actions} />
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
  
  @doc """
  Mobile accordion view for hierarchical data.
  """
  def accordion_view(assigns) do
    ~H"""
    <div class="mobile-accordion-view" phx-hook="MobileAccordion" id={"accordion-#{@id}"}>
      <%= for {row, index} <- Enum.with_index(@rows) do %>
        <div class="border-b border-gray-200 last:border-b-0">
          <button
            type="button"
            class="w-full px-4 py-3 flex items-center justify-between bg-white hover:bg-gray-50"
            phx-click={JS.toggle(to: "#accordion-content-#{index}")}
          >
            <div class="flex-1 text-left">
              <div class="font-medium text-gray-900">
                <%= get_primary_value(row, @columns) %>
              </div>
              <div class="text-sm text-gray-500">
                <%= get_secondary_value(row, @columns) %>
              </div>
            </div>
            <svg 
              class="w-5 h-5 text-gray-400 transform transition-transform accordion-icon"
              fill="none" 
              stroke="currentColor" 
              viewBox="0 0 24 24"
            >
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
            </svg>
          </button>
          
          <div id={"accordion-content-#{index}"} class="hidden">
            <div class="px-4 py-3 bg-gray-50 space-y-2">
              <%= for column <- Enum.drop(@columns, 2) do %>
                <div class="flex justify-between text-sm">
                  <span class="text-gray-500"><%= column.label %></span>
                  <span class="text-gray-900"><%= get_value(row, column.field) %></span>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
  
  @doc """
  Mobile swipeable cards view.
  """
  def swipeable_cards(assigns) do
    ~H"""
    <div 
      class="mobile-swipeable-cards"
      phx-hook="SwipeableCards"
      id={"swipeable-#{@id}"}
      data-current="0"
    >
      <div class="relative overflow-hidden">
        <div class="flex transition-transform duration-300 swipe-container">
          <%= for row <- @rows do %>
            <div class="w-full flex-shrink-0 p-4">
              <div class="bg-white rounded-lg shadow-lg p-6">
                <%= for column <- @columns do %>
                  <div class="mb-3">
                    <div class="text-xs text-gray-500 uppercase tracking-wide">
                      <%= column.label %>
                    </div>
                    <div class="text-gray-900 mt-1">
                      <%= get_value(row, column.field) %>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
        
        <%!-- Navigation dots --%>
        <div class="flex justify-center space-x-2 mt-4">
          <%= for index <- 0..(length(@rows) - 1) do %>
            <button
              class="w-2 h-2 rounded-full bg-gray-300 swipe-dot"
              data-index={index}
              phx-click="go_to_card"
              phx-value-index={index}
            />
          <% end %>
        </div>
      </div>
    </div>
    """
  end
  
  @doc """
  Mobile-optimized action buttons.
  """
  def mobile_actions(assigns) do
    ~H"""
    <div class="flex space-x-2">
      <%= for action <- @actions do %>
        <button
          type="button"
          class={[
            "flex-1 px-3 py-1.5 text-sm font-medium rounded-md",
            action_class(action.type)
          ]}
          phx-click={action.event}
          phx-value-id={@row.id}
        >
          <%= if action[:icon] do %>
            <span class="inline-block w-4 h-4 mr-1">
              <%= action.icon %>
            </span>
          <% end %>
          <%= action.label %>
        </button>
      <% end %>
    </div>
    """
  end
  
  @doc """
  Mobile filter bar that collapses to save space.
  """
  def mobile_filter_bar(assigns) do
    ~H"""
    <div class="mobile-filter-bar bg-white border-b border-gray-200">
      <div class="px-4 py-2">
        <button
          type="button"
          class="w-full flex items-center justify-between text-sm"
          phx-click={JS.toggle(to: "#mobile-filter-content")}
        >
          <span class="font-medium text-gray-700">
            Filters
            <%= if @active_filter_count > 0 do %>
              <span class="ml-2 bg-blue-100 text-blue-800 px-2 py-0.5 rounded-full text-xs">
                <%= @active_filter_count %>
              </span>
            <% end %>
          </span>
          <svg class="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
          </svg>
        </button>
      </div>
      
      <div id="mobile-filter-content" class="hidden border-t border-gray-200">
        <div class="p-4 space-y-3">
          <%= render_slot(@inner_block) %>
        </div>
      </div>
    </div>
    """
  end
  
  @doc """
  Floating action button for mobile interfaces.
  """
  def floating_action_button(assigns) do
    assigns = 
      assigns
      |> assign_new(:position, fn -> "bottom-right" end)
      |> assign_new(:color, fn -> "blue" end)
    
    ~H"""
    <div class={fab_position_class(@position)}>
      <button
        type="button"
        class={[
          "w-14 h-14 rounded-full shadow-lg flex items-center justify-center",
          "transform transition-transform active:scale-95",
          fab_color_class(@color)
        ]}
        phx-click={@click}
      >
        <%= render_slot(@inner_block) %>
      </button>
    </div>
    """
  end
  
  # Helper functions
  
  defp get_value(row, field) when is_atom(field) do
    Map.get(row, field, "-")
  end
  defp get_value(row, field) when is_binary(field) do
    get_nested_value(row, String.split(field, "."))
  end
  
  defp get_nested_value(data, []), do: data
  defp get_nested_value(nil, _), do: "-"
  defp get_nested_value(data, [key | rest]) do
    # Use SafeAtom.to_existing to prevent atom table exhaustion
    case SafeAtom.to_existing(key) do
      nil ->
        "-"

      key_atom ->
        case Map.get(data, key_atom) do
          nil -> "-"
          value -> get_nested_value(value, rest)
        end
    end
  end
  
  defp get_primary_value(row, columns) do
    case Enum.at(columns, 0) do
      nil -> "-"
      column -> get_value(row, column.field)
    end
  end
  
  defp get_secondary_value(row, columns) do
    case Enum.at(columns, 1) do
      nil -> ""
      column -> get_value(row, column.field)
    end
  end
  
  defp action_class("primary"), do: "bg-blue-600 text-white hover:bg-blue-700"
  defp action_class("secondary"), do: "bg-gray-200 text-gray-700 hover:bg-gray-300"
  defp action_class("danger"), do: "bg-red-600 text-white hover:bg-red-700"
  defp action_class(_), do: "bg-gray-200 text-gray-700 hover:bg-gray-300"
  
  defp fab_position_class("bottom-right"), do: "fixed bottom-4 right-4 z-50"
  defp fab_position_class("bottom-left"), do: "fixed bottom-4 left-4 z-50"
  defp fab_position_class("bottom-center"), do: "fixed bottom-4 left-1/2 -translate-x-1/2 z-50"
  defp fab_position_class(_), do: "fixed bottom-4 right-4 z-50"
  
  defp fab_color_class("blue"), do: "bg-blue-600 text-white hover:bg-blue-700"
  defp fab_color_class("green"), do: "bg-green-600 text-white hover:bg-green-700"
  defp fab_color_class("red"), do: "bg-red-600 text-white hover:bg-red-700"
  defp fab_color_class(_), do: "bg-blue-600 text-white hover:bg-blue-700"
  
  @doc """
  JavaScript hooks for mobile layout components.
  """
  def __hooks__() do
    %{
      "MobileAccordion" => %{
        mounted: """
        // Handle accordion state
        this.el.addEventListener('click', (e) => {
          const button = e.target.closest('button');
          if (!button) return;
          
          const icon = button.querySelector('.accordion-icon');
          if (icon) {
            icon.classList.toggle('rotate-180');
          }
        });
        """
      },
      
      "SwipeableCards" => %{
        mounted: """
        this.current = parseInt(this.el.dataset.current || '0');
        this.container = this.el.querySelector('.swipe-container');
        this.cards = this.el.querySelectorAll('.swipe-container > div');
        this.dots = this.el.querySelectorAll('.swipe-dot');
        this.startX = 0;
        this.currentX = 0;
        this.isDragging = false;
        
        // Update dots
        this.updateDots = () => {
          this.dots.forEach((dot, index) => {
            dot.classList.toggle('bg-blue-600', index === this.current);
            dot.classList.toggle('bg-gray-300', index !== this.current);
          });
        };
        
        // Go to specific card
        this.goToCard = (index) => {
          this.current = Math.max(0, Math.min(index, this.cards.length - 1));
          const offset = -this.current * 100;
          this.container.style.transform = `translateX(${offset}%)`;
          this.updateDots();
        };
        
        // Handle touch events
        this.handleTouchStart = (e) => {
          this.isDragging = true;
          this.startX = e.touches[0].clientX;
        };
        
        this.handleTouchMove = (e) => {
          if (!this.isDragging) return;
          this.currentX = e.touches[0].clientX;
        };
        
        this.handleTouchEnd = (e) => {
          if (!this.isDragging) return;
          this.isDragging = false;
          
          const diff = this.startX - this.currentX;
          const threshold = 50;
          
          if (Math.abs(diff) > threshold) {
            if (diff > 0 && this.current < this.cards.length - 1) {
              this.goToCard(this.current + 1);
            } else if (diff < 0 && this.current > 0) {
              this.goToCard(this.current - 1);
            }
          }
        };
        
        // Handle dot clicks
        this.handleEvent('go_to_card', ({index}) => {
          this.goToCard(parseInt(index));
        });
        
        // Add event listeners
        this.el.addEventListener('touchstart', this.handleTouchStart);
        this.el.addEventListener('touchmove', this.handleTouchMove);
        this.el.addEventListener('touchend', this.handleTouchEnd);
        
        // Initialize
        this.updateDots();
        """,
        
        destroyed: """
        this.el.removeEventListener('touchstart', this.handleTouchStart);
        this.el.removeEventListener('touchmove', this.handleTouchMove);
        this.el.removeEventListener('touchend', this.handleTouchEnd);
        """
      }
    }
  end
end