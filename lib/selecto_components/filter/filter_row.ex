defmodule SelectoComponents.Filter.FilterRow do
  @moduledoc """
  Individual filter row component with inline editing capabilities.
  """
  
  use Phoenix.Component
  
  def filter_row(assigns) do
    assigns = assign_new(assigns, :editing, fn -> false end)
    
    ~H"""
    <div class="filter-row group">
      <%= if @editing do %>
        <.editing_row {assigns} />
      <% else %>
        <.display_row {assigns} />
      <% end %>
    </div>
    """
  end
  
  defp display_row(assigns) do
    ~H"""
    <div class="flex items-center p-3 bg-white rounded-lg border border-gray-200 hover:border-gray-300 transition-all duration-150">
      <div class="flex-1 flex items-center space-x-4">
        <%!-- Field --%>
        <div class="min-w-[150px]">
          <span class="text-sm font-medium text-gray-700">
            <%= @field_name %>
          </span>
        </div>
        
        <%!-- Operator --%>
        <div class="min-w-[120px]">
          <span class="text-sm text-gray-600">
            <%= format_operator(@operator) %>
          </span>
        </div>
        
        <%!-- Value --%>
        <div class="flex-1">
          <%= if @operator in ["IS NULL", "IS NOT NULL"] do %>
            <span class="text-sm text-gray-400 italic">-</span>
          <% else %>
            <span class="text-sm text-gray-900 font-mono">
              <%= @value || "-" %>
            </span>
          <% end %>
        </div>
      </div>
      
      <%!-- Actions --%>
      <div class="flex items-center space-x-1 opacity-0 group-hover:opacity-100 transition-opacity duration-150">
        <%!-- Edit button --%>
        <button
          type="button"
          phx-click="edit_filter"
          phx-value-filter-id={@filter_id}
          phx-target={@target}
          class="p-1.5 text-gray-400 hover:text-blue-600 hover:bg-blue-50 rounded-md transition-colors duration-150"
          title="Edit filter"
        >
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                  d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
          </svg>
        </button>
        
        <%!-- Duplicate button --%>
        <button
          type="button"
          phx-click="duplicate_filter"
          phx-value-filter-id={@filter_id}
          phx-target={@target}
          class="p-1.5 text-gray-400 hover:text-green-600 hover:bg-green-50 rounded-md transition-colors duration-150"
          title="Duplicate filter"
        >
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                  d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
          </svg>
        </button>
        
        <%!-- Remove button --%>
        <button
          type="button"
          phx-click="remove_filter"
          phx-value-filter-id={@filter_id}
          phx-target={@target}
          class="p-1.5 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-md transition-colors duration-150"
          title="Remove filter"
        >
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>
    </div>
    """
  end
  
  defp editing_row(assigns) do
    ~H"""
    <div class="flex items-center p-3 bg-blue-50 rounded-lg border-2 border-blue-300">
      <div class="flex-1 flex items-center space-x-3">
        <%!-- Field selector --%>
        <select
          phx-change="update_filter_field"
          phx-value-filter-id={@filter_id}
          phx-target={@target}
          name="field"
          class="block rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
        >
          <%= for {field_id, field_config} <- @available_fields do %>
            <option value={field_id} selected={field_id == @field}>
              <%= field_config.name %>
            </option>
          <% end %>
        </select>
        
        <%!-- Operator selector --%>
        <select
          phx-change="update_filter_operator"
          phx-value-filter-id={@filter_id}
          phx-target={@target}
          name="operator"
          class="block rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
        >
          <%= for {op_value, op_label} <- operator_options() do %>
            <option value={op_value} selected={op_value == @operator}>
              <%= op_label %>
            </option>
          <% end %>
        </select>
        
        <%!-- Value input --%>
        <%= if @operator not in ["IS NULL", "IS NOT NULL"] do %>
          <input
            type="text"
            phx-change="update_filter_value"
            phx-value-filter-id={@filter_id}
            phx-target={@target}
            name="value"
            value={@value}
            placeholder="Enter value..."
            class="block flex-1 rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
          />
        <% else %>
          <div class="flex-1 text-sm text-gray-500 italic">No value needed</div>
        <% end %>
      </div>
      
      <%!-- Save/Cancel buttons --%>
      <div class="flex items-center space-x-2 ml-3">
        <button
          type="button"
          phx-click="save_filter_edit"
          phx-value-filter-id={@filter_id}
          phx-target={@target}
          class="px-3 py-1.5 bg-blue-600 text-white text-sm font-medium rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
        >
          Save
        </button>
        
        <button
          type="button"
          phx-click="cancel_filter_edit"
          phx-value-filter-id={@filter_id}
          phx-target={@target}
          class="px-3 py-1.5 bg-white text-gray-700 text-sm font-medium rounded-md border border-gray-300 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
        >
          Cancel
        </button>
      </div>
    </div>
    """
  end
  
  # Helper functions
  
  defp format_operator(operator) do
    case operator do
      "=" -> "equals"
      "!=" -> "not equals"
      ">" -> "greater than"
      ">=" -> "greater or equal"
      "<" -> "less than"
      "<=" -> "less or equal"
      "LIKE" -> "contains"
      "NOT LIKE" -> "does not contain"
      "IS NULL" -> "is empty"
      "IS NOT NULL" -> "is not empty"
      "IN" -> "is one of"
      "NOT IN" -> "is not one of"
      "BETWEEN" -> "between"
      _ -> operator
    end
  end
  
  defp operator_options do
    [
      {"=", "Equals"},
      {"!=", "Not Equals"},
      {">", "Greater Than"},
      {">=", "Greater or Equal"},
      {"<", "Less Than"},
      {"<=", "Less or Equal"},
      {"LIKE", "Contains"},
      {"NOT LIKE", "Does Not Contain"},
      {"IS NULL", "Is Empty"},
      {"IS NOT NULL", "Is Not Empty"},
      {"IN", "Is One Of"},
      {"NOT IN", "Is Not One Of"},
      {"BETWEEN", "Between"}
    ]
  end
  
  @doc """
  Animation component for filter addition/removal.
  """
  def filter_animation(assigns) do
    ~H"""
    <div
      class="filter-animation"
      phx-mounted={JS.transition({"ease-out duration-300", "opacity-0 scale-95", "opacity-100 scale-100"})}
      phx-remove={JS.transition({"ease-in duration-200", "opacity-100 scale-100", "opacity-0 scale-95"})}
    >
      <%= render_slot(@inner_block) %>
    </div>
    """
  end
  
  @doc """
  Quick filter templates for common patterns.
  """
  def filter_templates do
    [
      %{
        name: "Today",
        field: "created_at",
        operator: "BETWEEN",
        value: {Date.utc_today(), Date.utc_today()}
      },
      %{
        name: "This Week",
        field: "created_at",
        operator: "BETWEEN",
        value: {Date.beginning_of_week(Date.utc_today()), Date.end_of_week(Date.utc_today())}
      },
      %{
        name: "This Month",
        field: "created_at",
        operator: "BETWEEN",
        value: {Date.beginning_of_month(Date.utc_today()), Date.end_of_month(Date.utc_today())}
      },
      %{
        name: "Active",
        field: "status",
        operator: "=",
        value: "active"
      },
      %{
        name: "Has Value",
        field: nil,  # To be selected
        operator: "IS NOT NULL",
        value: nil
      },
      %{
        name: "Is Empty",
        field: nil,  # To be selected
        operator: "IS NULL",
        value: nil
      }
    ]
  end
end