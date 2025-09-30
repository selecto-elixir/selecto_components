defmodule SelectoComponents.Filter.NumericRangeFilter do
  @moduledoc """
  Provides numeric range filtering with sliders and input fields.
  """
  
  use Phoenix.Component
  
  @doc """
  Numeric range filter component with slider and inputs.
  """
  def numeric_range_filter(assigns) do
    min = assigns[:min] || 0
    max = assigns[:max] || 100
    current_min = assigns[:current_min] || min
    current_max = assigns[:current_max] || max
    step = assigns[:step] || 1
    
    assigns = 
      assigns
      |> assign(:min, min)
      |> assign(:max, max)
      |> assign(:current_min, current_min)
      |> assign(:current_max, current_max)
      |> assign(:step, step)
    
    ~H"""
    <div class="numeric-range-filter" phx-hook="NumericRangeFilter" id={@id}>
      <div class="space-y-2">
        <%!-- Range display --%>
        <div class="flex items-center justify-between text-sm">
          <span class="text-gray-600"><%= @label || "Range" %></span>
          <span class="font-medium">
            <%= format_number(@current_min, @format) %> - <%= format_number(@current_max, @format) %>
          </span>
        </div>
        
        <%!-- Dual range slider --%>
        <div class="relative" style="height: 40px;">
          <div class="absolute w-full h-2 bg-gray-200 rounded-full top-4"></div>
          <div 
            class="absolute h-2 bg-blue-500 rounded-full top-4"
            style={"left: #{calculate_position(@current_min, @min, @max)}%; width: #{calculate_width(@current_min, @current_max, @min, @max)}%;"}
          ></div>
          
          <%!-- Min slider --%>
          <input
            type="range"
            name={@field <> "_min"}
            id={@field <> "_min"}
            min={@min}
            max={@max}
            step={@step}
            value={@current_min}
            class="absolute w-full pointer-events-none appearance-none bg-transparent slider-thumb-min"
            style="z-index: 3;"
            phx-change="numeric_range_changed"
            phx-value-field={@field}
            phx-value-type="min"
          />
          
          <%!-- Max slider --%>
          <input
            type="range"
            name={@field <> "_max"}
            id={@field <> "_max"}
            min={@min}
            max={@max}
            step={@step}
            value={@current_max}
            class="absolute w-full pointer-events-none appearance-none bg-transparent slider-thumb-max"
            style="z-index: 4;"
            phx-change="numeric_range_changed"
            phx-value-field={@field}
            phx-value-type="max"
          />
        </div>
        
        <%!-- Number inputs --%>
        <div class="flex items-center space-x-2">
          <input
            type="number"
            name={@field <> "_input_min"}
            id={@field <> "_input_min"}
            min={@min}
            max={@max}
            step={@step}
            value={@current_min}
            class="block w-24 rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
            phx-change="numeric_input_changed"
            phx-value-field={@field}
            phx-value-type="min"
          />
          <span class="text-gray-500">to</span>
          <input
            type="number"
            name={@field <> "_input_max"}
            id={@field <> "_input_max"}
            min={@min}
            max={@max}
            step={@step}
            value={@current_max}
            class="block w-24 rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
            phx-change="numeric_input_changed"
            phx-value-field={@field}
            phx-value-type="max"
          />
          
          <%!-- Reset button --%>
          <%= if @current_min != @min || @current_max != @max do %>
            <button
              type="button"
              class="text-gray-400 hover:text-gray-600"
              phx-click="reset_numeric_filter"
              phx-value-field={@field}
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
              </svg>
            </button>
          <% end %>
        </div>
        
        <%!-- Visual indicator --%>
        <%= if @current_min != @min || @current_max != @max do %>
          <div class="text-xs text-blue-600">
            Active filter: <%= format_number(@current_min, @format) %> - <%= format_number(@current_max, @format) %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
  
  @doc """
  Build filter expression for Selecto.
  """
  def build_filter_expression(field, min_value, max_value, original_min, original_max) do
    filters = []
    
    filters = if min_value && min_value > original_min do
      filters ++ ["#{field} >= ?", min_value]
    else
      filters
    end
    
    filters = if max_value && max_value < original_max do
      filters ++ ["#{field} <= ?", max_value]
    else
      filters
    end
    
    if filters == [], do: nil, else: filters
  end
  
  # Helper functions
  
  defp format_number(value, :currency) do
    "$#{:erlang.float_to_binary(value / 1, decimals: 2)}"
  end
  
  defp format_number(value, :percentage) do
    "#{value}%"
  end
  
  defp format_number(value, _) do
    to_string(value)
  end
  
  defp calculate_position(value, min, max) do
    ((value - min) / (max - min) * 100) |> round()
  end
  
  defp calculate_width(current_min, current_max, min, max) do
    range = max - min
    width = ((current_max - current_min) / range * 100) |> round()
    max(0, width)
  end
  
  @doc """
  JavaScript hooks for numeric range filter.
  """
  def js_hooks do
    """
    export const NumericRangeFilter = {
      mounted() {
        this.minSlider = this.el.querySelector('[name$="_min"]');
        this.maxSlider = this.el.querySelector('[name$="_max"]');
        this.minInput = this.el.querySelector('[name$="_input_min"]');
        this.maxInput = this.el.querySelector('[name$="_input_max"]');
        
        // Enable pointer events only on thumb
        if (this.minSlider) {
          this.minSlider.style.pointerEvents = 'auto';
          this.minSlider.addEventListener('input', () => this.updateRange('min'));
        }
        
        if (this.maxSlider) {
          this.maxSlider.style.pointerEvents = 'auto';
          this.maxSlider.addEventListener('input', () => this.updateRange('max'));
        }
        
        // Sync inputs with sliders
        if (this.minInput) {
          this.minInput.addEventListener('input', () => this.updateSlider('min'));
        }
        
        if (this.maxInput) {
          this.maxInput.addEventListener('input', () => this.updateSlider('max'));
        }
      },
      
      updateRange(type) {
        const minVal = parseFloat(this.minSlider.value);
        const maxVal = parseFloat(this.maxSlider.value);
        
        if (type === 'min' && minVal >= maxVal) {
          this.minSlider.value = maxVal - parseFloat(this.minSlider.step);
        } else if (type === 'max' && maxVal <= minVal) {
          this.maxSlider.value = minVal + parseFloat(this.maxSlider.step);
        }
        
        // Update input values
        if (this.minInput) this.minInput.value = this.minSlider.value;
        if (this.maxInput) this.maxInput.value = this.maxSlider.value;
      },
      
      updateSlider(type) {
        if (type === 'min' && this.minSlider) {
          this.minSlider.value = this.minInput.value;
        } else if (type === 'max' && this.maxSlider) {
          this.maxSlider.value = this.maxInput.value;
        }
      }
    };
    """
  end
  
  @doc """
  CSS styles for range sliders.
  """
  def slider_styles do
    """
    /* Custom slider thumb styles */
    .slider-thumb-min::-webkit-slider-thumb,
    .slider-thumb-max::-webkit-slider-thumb {
      appearance: none;
      width: 20px;
      height: 20px;
      border-radius: 50%;
      background: #3B82F6;
      cursor: pointer;
      border: 2px solid white;
      box-shadow: 0 2px 4px rgba(0,0,0,0.2);
      pointer-events: auto;
    }
    
    .slider-thumb-min::-moz-range-thumb,
    .slider-thumb-max::-moz-range-thumb {
      width: 20px;
      height: 20px;
      border-radius: 50%;
      background: #3B82F6;
      cursor: pointer;
      border: 2px solid white;
      box-shadow: 0 2px 4px rgba(0,0,0,0.2);
      pointer-events: auto;
    }
    
    /* Track styles */
    .slider-thumb-min::-webkit-slider-runnable-track,
    .slider-thumb-max::-webkit-slider-runnable-track {
      width: 100%;
      height: 8px;
      cursor: pointer;
      background: transparent;
    }
    
    .slider-thumb-min::-moz-range-track,
    .slider-thumb-max::-moz-range-track {
      width: 100%;
      height: 8px;
      cursor: pointer;
      background: transparent;
    }
    """
  end
end