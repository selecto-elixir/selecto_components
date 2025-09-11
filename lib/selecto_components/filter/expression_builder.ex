defmodule SelectoComponents.Filter.ExpressionBuilder do
  @moduledoc """
  Provides a visual expression builder for creating complex filter conditions.
  """
  
  use Phoenix.Component
  import Phoenix.LiveView
  
  @operators %{
    text: [
      {"equals", "="},
      {"not equals", "!="},
      {"contains", "LIKE"},
      {"starts with", "LIKE"},
      {"ends with", "LIKE"},
      {"is empty", "IS NULL"},
      {"is not empty", "IS NOT NULL"}
    ],
    numeric: [
      {"equals", "="},
      {"not equals", "!="},
      {"greater than", ">"},
      {"greater or equal", ">="},
      {"less than", "<"},
      {"less or equal", "<="},
      {"between", "BETWEEN"},
      {"is null", "IS NULL"},
      {"is not null", "IS NOT NULL"}
    ],
    date: [
      {"equals", "="},
      {"not equals", "!="},
      {"after", ">"},
      {"after or on", ">="},
      {"before", "<"},
      {"before or on", "<="},
      {"between", "BETWEEN"},
      {"is null", "IS NULL"},
      {"is not null", "IS NOT NULL"}
    ],
    boolean: [
      {"is true", "= true"},
      {"is false", "= false"},
      {"is null", "IS NULL"},
      {"is not null", "IS NOT NULL"}
    ]
  }
  
  @doc """
  Expression builder component for complex filters.
  """
  def expression_builder(assigns) do
    ~H"""
    <div class="expression-builder" phx-hook="ExpressionBuilder" id={@id}>
      <div class="space-y-3">
        <%!-- Expression groups --%>
        <%= for {group, index} <- Enum.with_index(@expressions) do %>
          <div class="border border-gray-200 rounded-lg p-3 bg-gray-50">
            <%!-- Group header --%>
            <div class="flex items-center justify-between mb-2">
              <span class="text-sm font-medium text-gray-700">
                <%= if index == 0, do: "Where", else: group.conjunction %>
              </span>
              <button
                type="button"
                class="text-red-500 hover:text-red-700"
                phx-click="remove_expression_group"
                phx-value-index={index}
              >
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                </svg>
              </button>
            </div>
            
            <%!-- Conditions in group --%>
            <%= for {condition, cond_index} <- Enum.with_index(group.conditions) do %>
              <div class="flex items-center space-x-2 mb-2">
                <%= if cond_index > 0 do %>
                  <select
                    class="text-xs border-gray-300 rounded"
                    phx-change="update_condition_conjunction"
                    phx-value-group={index}
                    phx-value-condition={cond_index}
                  >
                    <option value="AND" selected={condition.conjunction == "AND"}>AND</option>
                    <option value="OR" selected={condition.conjunction == "OR"}>OR</option>
                  </select>
                <% end %>
                
                <%!-- Field selector --%>
                <select
                  class="flex-1 border-gray-300 rounded-md text-sm"
                  phx-change="update_condition_field"
                  phx-value-group={index}
                  phx-value-condition={cond_index}
                >
                  <option value="">Select field...</option>
                  <%= for field <- @available_fields do %>
                    <option value={field.name} selected={condition.field == field.name}>
                      <%= field.label %>
                    </option>
                  <% end %>
                </select>
                
                <%!-- Operator selector --%>
                <select
                  class="border-gray-300 rounded-md text-sm"
                  phx-change="update_condition_operator"
                  phx-value-group={index}
                  phx-value-condition={cond_index}
                  disabled={!condition.field}
                >
                  <%= for {label, value} <- get_operators_for_type(condition.field_type) do %>
                    <option value={value} selected={condition.operator == value}>
                      <%= label %>
                    </option>
                  <% end %>
                </select>
                
                <%!-- Value input --%>
                <%= render_value_input(condition, index, cond_index) %>
                
                <%!-- Remove condition --%>
                <button
                  type="button"
                  class="text-red-500 hover:text-red-700"
                  phx-click="remove_condition"
                  phx-value-group={index}
                  phx-value-condition={cond_index}
                >
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path>
                  </svg>
                </button>
              </div>
            <% end %>
            
            <%!-- Add condition button --%>
            <button
              type="button"
              class="text-sm text-blue-600 hover:text-blue-800"
              phx-click="add_condition"
              phx-value-group={index}
            >
              + Add condition
            </button>
          </div>
        <% end %>
        
        <%!-- Add group button --%>
        <div class="flex items-center space-x-2">
          <button
            type="button"
            class="px-3 py-1.5 bg-white border border-gray-300 rounded-md text-sm font-medium text-gray-700 hover:bg-gray-50"
            phx-click="add_expression_group"
            phx-value-conjunction="AND"
          >
            + Add AND group
          </button>
          <button
            type="button"
            class="px-3 py-1.5 bg-white border border-gray-300 rounded-md text-sm font-medium text-gray-700 hover:bg-gray-50"
            phx-click="add_expression_group"
            phx-value-conjunction="OR"
          >
            + Add OR group
          </button>
        </div>
        
        <%!-- Preview --%>
        <%= if @expressions != [] do %>
          <div class="mt-3 p-3 bg-gray-100 rounded-md">
            <div class="text-xs font-mono text-gray-600">
              <%= build_sql_preview(@expressions) %>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
  
  @doc """
  Render appropriate value input based on operator.
  """
  def render_value_input(%{operator: op} = condition, group_index, cond_index) 
      when op in ["IS NULL", "IS NOT NULL"] do
    assigns = %{
      condition: condition,
      group_index: group_index,
      cond_index: cond_index
    }
    
    ~H"""
    <span class="text-sm text-gray-500 italic">no value needed</span>
    """
  end
  
  def render_value_input(%{operator: "BETWEEN"} = condition, group_index, cond_index) do
    assigns = %{
      condition: condition,
      group_index: group_index,
      cond_index: cond_index
    }
    
    ~H"""
    <div class="flex items-center space-x-1">
      <input
        type={input_type_for(@condition.field_type)}
        class="w-24 border-gray-300 rounded-md text-sm"
        value={@condition.value1}
        phx-change="update_condition_value"
        phx-value-group={@group_index}
        phx-value-condition={@cond_index}
        phx-value-value-type="value1"
      />
      <span class="text-gray-500 text-sm">and</span>
      <input
        type={input_type_for(@condition.field_type)}
        class="w-24 border-gray-300 rounded-md text-sm"
        value={@condition.value2}
        phx-change="update_condition_value"
        phx-value-group={@group_index}
        phx-value-condition={@cond_index}
        phx-value-value-type="value2"
      />
    </div>
    """
  end
  
  def render_value_input(%{field_type: :boolean} = condition, group_index, cond_index) do
    assigns = %{
      condition: condition,
      group_index: group_index,
      cond_index: cond_index
    }
    
    ~H"""
    <select
      class="border-gray-300 rounded-md text-sm"
      phx-change="update_condition_value"
      phx-value-group={@group_index}
      phx-value-condition={@cond_index}
      phx-value-value-type="value"
    >
      <option value="true" selected={@condition.value == "true"}>True</option>
      <option value="false" selected={@condition.value == "false"}>False</option>
    </select>
    """
  end
  
  def render_value_input(condition, group_index, cond_index) do
    assigns = %{
      condition: condition,
      group_index: group_index,
      cond_index: cond_index
    }
    
    ~H"""
    <input
      type={input_type_for(@condition.field_type)}
      class="flex-1 border-gray-300 rounded-md text-sm"
      value={@condition.value}
      placeholder="Enter value..."
      phx-change="update_condition_value"
      phx-value-group={@group_index}
      phx-value-condition={@cond_index}
      phx-value-value-type="value"
      disabled={!@condition.field}
    />
    """
  end
  
  @doc """
  Build SQL preview from expressions.
  """
  def build_sql_preview([]), do: ""
  def build_sql_preview(expressions) do
    expressions
    |> Enum.map(&build_group_sql/1)
    |> Enum.join(" ")
  end
  
  defp build_group_sql(%{conditions: conditions, conjunction: conjunction}) do
    condition_sql = 
      conditions
      |> Enum.map(&build_condition_sql/1)
      |> Enum.join(" ")
    
    "#{conjunction} (#{condition_sql})"
  end
  
  defp build_condition_sql(%{field: field, operator: op, value: value} = condition) do
    sql = case {op, value} do
      {"LIKE", value} when is_binary(value) ->
        cond do
          String.starts_with?(value, "%") -> "#{field} LIKE '#{value}'"
          String.ends_with?(value, "%") -> "#{field} LIKE '#{value}'"
          true -> "#{field} LIKE '%#{value}%'"
        end
      {"BETWEEN", _} -> "#{field} BETWEEN '#{condition.value1}' AND '#{condition.value2}'"
      {op, _} when op in ["IS NULL", "IS NOT NULL"] -> "#{field} #{op}"
      _ -> "#{field} #{op} '#{value}'"
    end
    
    if condition[:conjunction], do: "#{condition.conjunction} #{sql}", else: sql
  end
  
  @doc """
  Convert expressions to Selecto filter format.
  """
  def to_selecto_filters(expressions) do
    expressions
    |> Enum.flat_map(fn group ->
      group.conditions
      |> Enum.map(&condition_to_filter/1)
      |> Enum.filter(& &1)
    end)
  end
  
  defp condition_to_filter(%{field: field, operator: "=", value: value}) do
    ["#{field} = ?", value]
  end
  
  defp condition_to_filter(%{field: field, operator: ">", value: value}) do
    ["#{field} > ?", value]
  end
  
  defp condition_to_filter(%{field: field, operator: "BETWEEN", value1: v1, value2: v2}) do
    ["#{field} >= ? AND #{field} <= ?", v1, v2]
  end
  
  defp condition_to_filter(_), do: nil
  
  # Helper functions
  
  defp get_operators_for_type(:text), do: @operators.text
  defp get_operators_for_type(:numeric), do: @operators.numeric
  defp get_operators_for_type(:date), do: @operators.date
  defp get_operators_for_type(:boolean), do: @operators.boolean
  defp get_operators_for_type(_), do: @operators.text
  
  defp input_type_for(:numeric), do: "number"
  defp input_type_for(:date), do: "date"
  defp input_type_for(:datetime), do: "datetime-local"
  defp input_type_for(_), do: "text"
end