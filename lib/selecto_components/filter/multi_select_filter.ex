defmodule SelectoComponents.Filter.MultiSelectFilter do
  @moduledoc """
  Provides multi-select filtering for categorical data with search and bulk actions.
  """
  
  use Phoenix.Component
  import Phoenix.LiveView
  
  @doc """
  Multi-select filter component with search and checkboxes.
  """
  def multi_select_filter(assigns) do
    ~H"""
    <div class="multi-select-filter" phx-hook="MultiSelectFilter" id={@id}>
      <div class="relative">
        <%!-- Selected items display --%>
        <div 
          class="min-h-[38px] px-3 py-2 border border-gray-300 rounded-md shadow-sm cursor-pointer bg-white hover:border-gray-400"
          phx-click="toggle_dropdown"
          phx-value-field={@field}
        >
          <%= if length(@selected) > 0 do %>
            <div class="flex flex-wrap gap-1">
              <%= for item <- Enum.take(@selected, 3) do %>
                <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-800">
                  <%= item %>
                  <button
                    type="button"
                    class="ml-1 inline-flex text-blue-400 hover:text-blue-600"
                    phx-click="remove_selected"
                    phx-value-field={@field}
                    phx-value-item={item}
                  >
                    <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd"/>
                    </svg>
                  </button>
                </span>
              <% end %>
              <%= if length(@selected) > 3 do %>
                <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-gray-100 text-gray-800">
                  +<%= length(@selected) - 3 %> more
                </span>
              <% end %>
            </div>
          <% else %>
            <span class="text-gray-400">Select <%= @label || "items" %>...</span>
          <% end %>
        </div>
        
        <%!-- Dropdown menu --%>
        <div 
          class={"absolute z-10 mt-1 w-full bg-white shadow-lg rounded-md border border-gray-200 #{if @dropdown_open, do: "", else: "hidden"}"}
          id={@field <> "_dropdown"}
        >
          <%!-- Search input --%>
          <div class="p-2 border-b border-gray-200">
            <input
              type="text"
              placeholder="Search..."
              class="w-full px-3 py-1 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-1 focus:ring-blue-500"
              phx-keyup="search_options"
              phx-value-field={@field}
              phx-debounce="300"
            />
          </div>
          
          <%!-- Bulk actions --%>
          <div class="px-2 py-1 border-b border-gray-200 flex items-center justify-between">
            <div class="text-xs text-gray-600">
              <%= length(@selected) %> of <%= length(@options) %> selected
            </div>
            <div class="space-x-2">
              <button
                type="button"
                class="text-xs text-blue-600 hover:text-blue-800"
                phx-click="select_all"
                phx-value-field={@field}
              >
                Select All
              </button>
              <button
                type="button"
                class="text-xs text-blue-600 hover:text-blue-800"
                phx-click="clear_all"
                phx-value-field={@field}
              >
                Clear All
              </button>
            </div>
          </div>
          
          <%!-- Options list --%>
          <div class="max-h-60 overflow-y-auto">
            <%= for {option, count} <- @filtered_options do %>
              <label class="flex items-center px-3 py-2 hover:bg-gray-50 cursor-pointer">
                <input
                  type="checkbox"
                  class="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                  checked={option in @selected}
                  phx-click="toggle_option"
                  phx-value-field={@field}
                  phx-value-option={option}
                />
                <span class="ml-2 text-sm text-gray-700 flex-1"><%= option %></span>
                <%= if count do %>
                  <span class="text-xs text-gray-500">(<%= count %>)</span>
                <% end %>
              </label>
            <% end %>
            
            <%= if @filtered_options == [] do %>
              <div class="px-3 py-2 text-sm text-gray-500">No options found</div>
            <% end %>
          </div>
          
          <%!-- Apply button --%>
          <div class="p-2 border-t border-gray-200">
            <button
              type="button"
              class="w-full px-3 py-1.5 bg-blue-600 text-white text-sm font-medium rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
              phx-click="apply_multi_select"
              phx-value-field={@field}
            >
              Apply Filter
            </button>
          </div>
        </div>
      </div>
      
      <%!-- Visual indicator --%>
      <%= if length(@selected) > 0 do %>
        <div class="mt-1 text-xs text-blue-600">
          Filtering by <%= length(@selected) %> <%= if length(@selected) == 1, do: "value", else: "values" %>
        </div>
      <% end %>
    </div>
    """
  end
  
  @doc """
  Build filter expression for Selecto.
  """
  def build_filter_expression(_field, []), do: nil
  def build_filter_expression(field, selected_values) do
    placeholders = Enum.map(selected_values, fn _ -> "?" end) |> Enum.join(", ")
    ["#{field} IN (#{placeholders})"] ++ selected_values
  end
  
  @doc """
  Get unique values with counts from data.
  """
  def get_options_with_counts(data, field) do
    data
    |> Enum.map(& Map.get(&1, field))
    |> Enum.filter(& &1)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_value, count} -> -count end)
  end
  
  @doc """
  Filter options based on search term.
  """
  def filter_options(options, search_term) when search_term in [nil, ""], do: options
  def filter_options(options, search_term) do
    term = String.downcase(search_term)
    Enum.filter(options, fn {option, _count} ->
      String.downcase(to_string(option)) |> String.contains?(term)
    end)
  end
  
  @doc """
  JavaScript hooks for multi-select filter.
  """
  def js_hooks do
    """
    export const MultiSelectFilter = {
      mounted() {
        this.dropdown = this.el.querySelector('[id$="_dropdown"]');
        this.handleOutsideClick = this.handleOutsideClick.bind(this);
        
        // Close dropdown on outside click
        document.addEventListener('click', this.handleOutsideClick);
        
        // Prevent dropdown from closing when clicking inside
        if (this.dropdown) {
          this.dropdown.addEventListener('click', (e) => {
            e.stopPropagation();
          });
        }
        
        // Handle keyboard navigation
        this.el.addEventListener('keydown', (e) => {
          if (e.key === 'Escape' && !this.dropdown?.classList.contains('hidden')) {
            this.pushEvent('close_dropdown', {field: this.el.id});
          }
        });
      },
      
      destroyed() {
        document.removeEventListener('click', this.handleOutsideClick);
      },
      
      handleOutsideClick(e) {
        if (!this.el.contains(e.target) && !this.dropdown?.classList.contains('hidden')) {
          this.pushEvent('close_dropdown', {field: this.el.id});
        }
      }
    };
    """
  end
end