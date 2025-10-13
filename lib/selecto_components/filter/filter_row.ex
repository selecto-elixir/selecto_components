defmodule SelectoComponents.Filter.FilterRow do
  @moduledoc """
  Individual filter row component with inline editing capabilities.
  """
  
  use Phoenix.Component
  alias SelectoComponents.Filter.MultiSelectFilter
  
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
          <%
            # Check if this field uses multi-select ID filtering (lookup/star/tag join modes)
            field_config = Map.get(@available_fields, @field, %{})

            # If filtering on an ID field (e.g. "category.id"), check if there's a display field with join_mode metadata
            field_config = find_join_mode_metadata(@selecto, @field, field_config)

            is_multi_select_id = Map.get(field_config, :filter_type) == :multi_select_id
          %>
          <%= if is_multi_select_id do %>
            <%!-- Multi-select filter component for lookup/star/tag join modes --%>
            <div class="flex-1">
              <.live_component
                module={MultiSelectFilter}
                id={"multi-select-#{@filter_id}"}
                filter_id={@filter_id}
                field={@field}
                field_config={field_config}
                selecto={Map.get(assigns, :selecto)}
                repo={Map.get(assigns, :repo)}
                value={@value}
              />
            </div>
          <% else %>
            <%!-- Standard text input for regular fields --%>
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
          <% end %>
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

  @doc """
  Find join mode metadata when filtering on ID field.

  When editing a filter on "category.id", look for "category.category_name"
  which has the join_mode metadata (filter_type: :multi_select_id, etc).
  """
  defp find_join_mode_metadata(nil, _field, field_config), do: field_config
  defp find_join_mode_metadata(selecto, field, field_config) when is_binary(field) do
    # Only process if field_name contains "." (qualified field)
    if String.contains?(field, ".") do
      [schema_name, field_part] = String.split(field, ".", parts: 2)

      # Check if this looks like an ID field
      if field_part in ["id", "category_id", "supplier_id", "shipper_id"] or String.ends_with?(field_part, "_id") do
        # Get the domain to search for join_mode fields
        domain = Selecto.domain(selecto)
        schema_atom = try do
          String.to_existing_atom(schema_name)
        rescue
          ArgumentError -> nil
        end

        if schema_atom do
          schema_config = get_in(domain, [:schemas, schema_atom])

          if schema_config do
            # Search through columns to find one with join_mode metadata matching this ID field
            columns = Map.get(schema_config, :columns, %{})

            found_field = Enum.find_value(columns, fn {_col_name, col_config} ->
              # Check if this column has join_mode and its id_field matches our field
              join_mode = Map.get(col_config, :join_mode)
              id_field = Map.get(col_config, :id_field)
              filter_type = Map.get(col_config, :filter_type)

              # Match if this column is configured for join mode and references our ID field
              if join_mode in [:lookup, :star, :tag] and filter_type == :multi_select_id and
                 (id_field == :id or Atom.to_string(id_field) == field_part) do
                col_config
              else
                nil
              end
            end)

            if found_field do
              # Merge the display field config with the original
              Map.merge(field_config, found_field)
            else
              field_config
            end
          else
            field_config
          end
        else
          field_config
        end
      else
        field_config
      end
    else
      field_config
    end
  end
  defp find_join_mode_metadata(_selecto, _field, field_config), do: field_config
end