defmodule SelectoComponents.Forms.InlineForm do
  @moduledoc """
  Inline form component that appears below tables for quick record addition.
  """
  
  use Phoenix.Component
  alias Phoenix.LiveView.JS
  
  @doc """
  Inline form that slides in below the table.
  """
  def inline_form(assigns) do
    ~H"""
    <div 
      id={@id}
      class="inline-form-container"
      phx-hook="InlineForm"
      data-expanded={@expanded}
    >
      <%!-- Toggle Button Row --%>
      <div class="border-t border-gray-200 bg-gray-50 px-4 py-2">
        <button
          type="button"
          class="flex items-center space-x-2 text-sm text-gray-600 hover:text-gray-900"
          phx-click={toggle_form(@id)}
        >
          <svg 
            class={"w-4 h-4 transition-transform #{if @expanded, do: "rotate-180", else: ""}"}
            fill="none" 
            stroke="currentColor" 
            viewBox="0 0 24 24"
          >
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
          </svg>
          <span><%= if @expanded, do: "Hide", else: "Show" %> Quick Add Form</span>
        </button>
      </div>
      
      <%!-- Form Container --%>
      <div 
        id={"#{@id}-form"}
        class={"overflow-hidden transition-all duration-300 #{if @expanded, do: "max-h-96", else: "max-h-0"}"}
      >
        <div class="p-4 bg-white border-t border-gray-200">
          <form phx-submit={@on_submit}>
            <%!-- Compact Grid Layout --%>
            <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-6 gap-3">
              <%= for field <- @fields do %>
                <div class={field_grid_class(field)}>
                  <%= render_compact_field(assigns, field) %>
                </div>
              <% end %>
              
              <%!-- Submit Button --%>
              <div class="flex items-end">
                <button
                  type="submit"
                  class="w-full px-3 py-2 bg-green-600 text-white text-sm rounded hover:bg-green-700 flex items-center justify-center space-x-1"
                  disabled={@submitting}
                >
                  <%= if @submitting do %>
                    <svg class="animate-spin h-4 w-4" fill="none" viewBox="0 0 24 24">
                      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                      <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                    </svg>
                  <% else %>
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
                    </svg>
                  <% end %>
                  <span>Add</span>
                </button>
              </div>
            </div>
            
            <%!-- Validation Summary --%>
            <%= if map_size(@errors) > 0 do %>
              <div class="mt-3 p-2 bg-red-50 border border-red-200 rounded">
                <p class="text-sm text-red-600">Please fix the errors above before submitting.</p>
              </div>
            <% end %>
          </form>
        </div>
      </div>
    </div>
    """
  end
  
  @doc """
  Bulk add form for adding multiple records at once.
  """
  def bulk_add_form(assigns) do
    ~H"""
    <div id={@id} class="bulk-add-form" phx-hook="BulkAddForm">
      <div class="bg-white rounded-lg shadow-sm border border-gray-200">
        <div class="px-4 py-3 border-b border-gray-200">
          <div class="flex items-center justify-between">
            <h3 class="text-lg font-medium text-gray-900">Bulk Add Records</h3>
            <div class="flex items-center space-x-2">
              <span class="text-sm text-gray-500">
                Adding <%= length(@rows) %> <%= if length(@rows) == 1, do: "record", else: "records" %>
              </span>
              <button
                type="button"
                class="text-blue-600 hover:text-blue-800 text-sm"
                phx-click="add_bulk_row"
                phx-target={@target}
              >
                + Add Row
              </button>
            </div>
          </div>
        </div>
        
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  #
                </th>
                <%= for field <- @fields do %>
                  <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    <%= field.label %>
                    <%= if field.required do %>
                      <span class="text-red-500">*</span>
                    <% end %>
                  </th>
                <% end %>
                <th class="px-3 py-2"></th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <%= for {row, index} <- Enum.with_index(@rows) do %>
                <tr class={if rem(index, 2) == 0, do: "bg-white", else: "bg-gray-50"}>
                  <td class="px-3 py-2 text-sm text-gray-500">
                    <%= index + 1 %>
                  </td>
                  <%= for field <- @fields do %>
                    <td class="px-3 py-2">
                      <%= render_bulk_field(assigns, field, row, index) %>
                    </td>
                  <% end %>
                  <td class="px-3 py-2">
                    <button
                      type="button"
                      class="text-red-600 hover:text-red-800"
                      phx-click="remove_bulk_row"
                      phx-value-index={index}
                      phx-target={@target}
                    >
                      <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                        <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
                      </svg>
                    </button>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
        
        <div class="px-4 py-3 bg-gray-50 border-t border-gray-200 flex items-center justify-between">
          <div class="flex items-center space-x-2">
            <button
              type="button"
              class="px-3 py-1.5 text-sm border border-gray-300 rounded hover:bg-gray-100"
              phx-click="clear_bulk_form"
              phx-target={@target}
            >
              Clear All
            </button>
            <button
              type="button"
              class="px-3 py-1.5 text-sm border border-gray-300 rounded hover:bg-gray-100"
              phx-click="paste_bulk_data"
              phx-target={@target}
            >
              Paste from Clipboard
            </button>
          </div>
          
          <button
            type="button"
            class="px-4 py-2 bg-blue-600 text-white text-sm rounded hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
            phx-click="submit_bulk_form"
            phx-target={@target}
            disabled={@submitting || length(@rows) == 0}
          >
            <%= if @submitting do %>
              Saving <%= length(@rows) %> records...
            <% else %>
              Save All Records
            <% end %>
          </button>
        </div>
      </div>
    </div>
    """
  end
  
  # Helper components for compact fields
  
  defp render_compact_field(assigns, field) do
    assigns = assign(assigns, :field, field)
    
    ~H"""
    <div>
      <label class="block text-xs font-medium text-gray-700 mb-1">
        <%= @field.label %>
        <%= if @field.required do %>
          <span class="text-red-500">*</span>
        <% end %>
      </label>
      
      <%= case @field.type do %>
        <% :select -> %>
          <select
            name={@field.name}
            class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500"
            required={@field.required}
          >
            <option value="">-</option>
            <%= for {label, value} <- @field.options do %>
              <option value={value}><%= label %></option>
            <% end %>
          </select>
          
        <% :boolean -> %>
          <input
            type="checkbox"
            name={@field.name}
            class="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
          />
          
        <% _ -> %>
          <input
            type={input_type(@field.type)}
            name={@field.name}
            placeholder={@field.placeholder}
            class="w-full px-2 py-1 text-sm border border-gray-300 rounded focus:ring-1 focus:ring-blue-500"
            required={@field.required}
          />
      <% end %>
      
      <%= if @errors[@field.name] do %>
        <p class="mt-0.5 text-xs text-red-600"><%= @errors[@field.name] %></p>
      <% end %>
    </div>
    """
  end
  
  defp render_bulk_field(assigns, field, row, row_index) do
    assigns = assign(assigns, field: field, row: row, row_index: row_index)
    
    ~H"""
    <%= case @field.type do %>
      <% :select -> %>
        <select
          class="w-full px-2 py-1 text-sm border border-gray-300 rounded"
          phx-change="update_bulk_field"
          phx-value-row={@row_index}
          phx-value-field={@field.name}
          phx-target={@target}
        >
          <option value="">-</option>
          <%= for {label, value} <- @field.options do %>
            <option value={value} selected={@row[@field.name] == value}>
              <%= label %>
            </option>
          <% end %>
        </select>
        
      <% :boolean -> %>
        <input
          type="checkbox"
          checked={@row[@field.name] == true}
          class="rounded border-gray-300 text-blue-600"
          phx-click="toggle_bulk_field"
          phx-value-row={@row_index}
          phx-value-field={@field.name}
          phx-target={@target}
        />
        
      <% _ -> %>
        <input
          type={input_type(@field.type)}
          value={@row[@field.name]}
          placeholder={@field.placeholder}
          class="w-full px-2 py-1 text-sm border border-gray-300 rounded"
          phx-change="update_bulk_field"
          phx-value-row={@row_index}
          phx-value-field={@field.name}
          phx-target={@target}
        />
    <% end %>
    """
  end
  
  # JavaScript functions
  
  defp toggle_form(id) do
    JS.toggle(
      to: "##{id}-form",
      in: {"ease-out duration-300", "opacity-0 max-h-0", "opacity-100 max-h-96"},
      out: {"ease-in duration-200", "opacity-100 max-h-96", "opacity-0 max-h-0"}
    )
    |> JS.toggle_class("rotate-180", to: "##{id} svg:first-child")
  end
  
  # Helper functions
  
  defp field_grid_class(%{type: :textarea}), do: "col-span-2"
  defp field_grid_class(%{size: :large}), do: "col-span-2"
  defp field_grid_class(_), do: ""
  
  defp input_type(:email), do: "email"
  defp input_type(:number), do: "number"
  defp input_type(:date), do: "date"
  defp input_type(:datetime), do: "datetime-local"
  defp input_type(:url), do: "url"
  defp input_type(:tel), do: "tel"
  defp input_type(_), do: "text"
  
  @doc """
  JavaScript hooks for inline forms.
  """
  def __hooks__() do
    %{
      "InlineForm" => %{
        mounted: """
        // Auto-focus first field when expanded
        this.handleExpanded = () => {
          if (this.el.dataset.expanded === 'true') {
            const firstInput = this.el.querySelector('input:not([type="hidden"]), select');
            if (firstInput) {
              setTimeout(() => firstInput.focus(), 300);
            }
          }
        };
        
        // Watch for expansion changes
        const observer = new MutationObserver(() => {
          this.handleExpanded();
        });
        
        observer.observe(this.el, {
          attributes: true,
          attributeFilter: ['data-expanded']
        });
        
        // Tab navigation between fields
        this.el.addEventListener('keydown', (e) => {
          if (e.key === 'Tab') {
            const inputs = Array.from(this.el.querySelectorAll('input, select, textarea, button[type="submit"]'));
            const currentIndex = inputs.indexOf(e.target);
            
            if (e.shiftKey && currentIndex === 0) {
              e.preventDefault();
              inputs[inputs.length - 1].focus();
            } else if (!e.shiftKey && currentIndex === inputs.length - 1) {
              e.preventDefault();
              inputs[0].focus();
            }
          }
        });
        """,
        
        destroyed: """
        if (this.observer) {
          this.observer.disconnect();
        }
        """
      },
      
      "BulkAddForm" => %{
        mounted: """
        // Handle paste from clipboard
        this.handlePaste = (e) => {
          e.preventDefault();
          const text = e.clipboardData.getData('text');
          
          // Parse CSV/TSV data
          const rows = text.split('\\n').map(row => row.split(/\\t|,/));
          
          // Send parsed data to server
          this.pushEventTo(this.el, 'paste_bulk_data', {rows: rows});
        };
        
        this.el.addEventListener('paste', this.handlePaste);
        
        // Auto-focus on new row
        this.handleNewRow = () => {
          const rows = this.el.querySelectorAll('tbody tr');
          if (rows.length > 0) {
            const lastRow = rows[rows.length - 1];
            const firstInput = lastRow.querySelector('input, select');
            if (firstInput) {
              firstInput.focus();
            }
          }
        };
        """,
        
        destroyed: """
        this.el.removeEventListener('paste', this.handlePaste);
        """
      }
    }
  end
end