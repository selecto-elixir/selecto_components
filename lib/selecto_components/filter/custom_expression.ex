defmodule SelectoComponents.Filter.CustomExpression do
  @moduledoc """
  Custom expression builder for advanced filtering with visual query building interface.
  """
  
  use Phoenix.Component
  alias Phoenix.LiveView.JS
  
  @doc """
  Custom expression builder component.
  """
  def expression_builder(assigns) do
    assigns = 
      assigns
      |> assign_new(:id, fn -> "expr-builder-#{System.unique_integer([:positive])}" end)
      |> assign_new(:expression, fn -> %{type: :simple, field: nil, operator: nil, value: nil} end)
      |> assign_new(:fields, fn -> [] end)
      |> assign_new(:operators, fn -> default_operators() end)
    
    ~H"""
    <div 
      id={@id}
      class="expression-builder"
      phx-hook="ExpressionBuilder"
    >
      <div class="space-y-3">
        <%!-- Expression type selector --%>
        <div class="flex space-x-2">
          <button
            type="button"
            class={[
              "px-3 py-1 text-sm rounded",
              @expression.type == :simple && "bg-blue-500 text-white",
              @expression.type != :simple && "bg-gray-100 text-gray-700 hover:bg-gray-200"
            ]}
            phx-click="set_expression_type"
            phx-value-type="simple"
            phx-target={@target}
          >
            Simple
          </button>
          <button
            type="button"
            class={[
              "px-3 py-1 text-sm rounded",
              @expression.type == :compound && "bg-blue-500 text-white",
              @expression.type != :compound && "bg-gray-100 text-gray-700 hover:bg-gray-200"
            ]}
            phx-click="set_expression_type"
            phx-value-type="compound"
            phx-target={@target}
          >
            Compound
          </button>
          <button
            type="button"
            class={[
              "px-3 py-1 text-sm rounded",
              @expression.type == :custom && "bg-blue-500 text-white",
              @expression.type != :custom && "bg-gray-100 text-gray-700 hover:bg-gray-200"
            ]}
            phx-click="set_expression_type"
            phx-value-type="custom"
            phx-target={@target}
          >
            Custom SQL
          </button>
        </div>
        
        <%!-- Expression builder based on type --%>
        <%= case @expression.type do %>
          <% :simple -> %>
            <.simple_expression 
              expression={@expression} 
              fields={@fields}
              operators={@operators}
              target={@target}
            />
          <% :compound -> %>
            <.compound_expression 
              expression={@expression}
              fields={@fields}
              operators={@operators}
              target={@target}
            />
          <% :custom -> %>
            <.custom_sql_expression
              expression={@expression}
              fields={@fields}
              target={@target}
            />
        <% end %>
        
        <%!-- Expression preview --%>
        <div class="p-3 bg-gray-50 rounded border border-gray-200">
          <div class="text-xs text-gray-500 mb-1">Preview:</div>
          <code class="text-sm text-gray-700">
            <%= format_expression(@expression) %>
          </code>
        </div>
        
        <%!-- Actions --%>
        <div class="flex justify-end space-x-2">
          <button
            type="button"
            class="px-3 py-1 text-sm bg-gray-200 text-gray-700 hover:bg-gray-300 rounded"
            phx-click="clear_expression"
            phx-target={@target}
          >
            Clear
          </button>
          <button
            type="button"
            class="px-3 py-1 text-sm bg-blue-500 text-white hover:bg-blue-600 rounded"
            phx-click="apply_expression"
            phx-target={@target}
          >
            Apply Filter
          </button>
        </div>
      </div>
    </div>
    """
  end
  
  @doc """
  Simple expression builder.
  """
  def simple_expression(assigns) do
    ~H"""
    <div class="flex space-x-2">
      <select
        class="flex-1 px-2 py-1 text-sm border border-gray-300 rounded focus:ring-blue-500 focus:border-blue-500"
        phx-change="update_expression_field"
        phx-target={@target}
      >
        <option value="">Select field...</option>
        <%= for field <- @fields do %>
          <option value={field.name} selected={@expression.field == field.name}>
            <%= field.label %>
          </option>
        <% end %>
      </select>
      
      <select
        class="px-2 py-1 text-sm border border-gray-300 rounded focus:ring-blue-500 focus:border-blue-500"
        phx-change="update_expression_operator"
        phx-target={@target}
        disabled={!@expression.field}
      >
        <option value="">Operator...</option>
        <%= for op <- get_operators_for_field(@expression.field, @fields, @operators) do %>
          <option value={op.value} selected={@expression.operator == op.value}>
            <%= op.label %>
          </option>
        <% end %>
      </select>
      
      <%= if @expression.operator && !operator_is_unary?(@expression.operator) do %>
        <input
          type="text"
          class="flex-1 px-2 py-1 text-sm border border-gray-300 rounded focus:ring-blue-500 focus:border-blue-500"
          placeholder="Value..."
          value={@expression.value}
          phx-blur="update_expression_value"
          phx-target={@target}
        />
      <% end %>
    </div>
    """
  end
  
  @doc """
  Compound expression builder with AND/OR logic.
  """
  def compound_expression(assigns) do
    assigns = assign_new(assigns, :conditions, fn -> [] end)
    
    ~H"""
    <div class="space-y-2">
      <div class="flex items-center space-x-2 mb-2">
        <span class="text-sm text-gray-600">Match</span>
        <select
          class="px-2 py-1 text-sm border border-gray-300 rounded"
          phx-change="update_logic_operator"
          phx-target={@target}
        >
          <option value="AND">All (AND)</option>
          <option value="OR">Any (OR)</option>
        </select>
        <span class="text-sm text-gray-600">of the following:</span>
      </div>
      
      <%= for {condition, index} <- Enum.with_index(@conditions) do %>
        <div class="flex items-center space-x-2 pl-4">
          <.simple_expression
            expression={condition}
            fields={@fields}
            operators={@operators}
            target={@target}
          />
          <button
            type="button"
            class="p-1 text-red-500 hover:text-red-700"
            phx-click="remove_condition"
            phx-value-index={index}
            phx-target={@target}
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>
      <% end %>
      
      <button
        type="button"
        class="px-3 py-1 text-sm bg-gray-100 text-gray-700 hover:bg-gray-200 rounded"
        phx-click="add_condition"
        phx-target={@target}
      >
        + Add Condition
      </button>
    </div>
    """
  end
  
  @doc """
  Custom SQL expression editor.
  """
  def custom_sql_expression(assigns) do
    ~H"""
    <div class="space-y-2">
      <div class="text-sm text-gray-600">
        Write a custom SQL WHERE clause expression:
      </div>
      
      <textarea
        class="w-full px-3 py-2 text-sm font-mono border border-gray-300 rounded focus:ring-blue-500 focus:border-blue-500"
        rows="3"
        placeholder="e.g., (price > 100 AND category = 'Electronics') OR featured = true"
        phx-blur="update_custom_sql"
        phx-target={@target}
      ><%= @expression[:sql] %></textarea>
      
      <div class="flex flex-wrap gap-1">
        <span class="text-xs text-gray-500">Available fields:</span>
        <%= for field <- @fields do %>
          <button
            type="button"
            class="px-2 py-0.5 text-xs bg-gray-100 hover:bg-gray-200 rounded"
            phx-click={JS.dispatch("insert_field", detail: %{field: field.name})}
          >
            <%= field.name %>
          </button>
        <% end %>
      </div>
      
      <%!-- Validation messages --%>
      <%= if @expression[:validation_error] do %>
        <div class="text-sm text-red-600">
          <%= @expression.validation_error %>
        </div>
      <% end %>
    </div>
    """
  end
  
  @doc """
  Filter chip display for active expressions.
  """
  def expression_chip(assigns) do
    ~H"""
    <div class="inline-flex items-center px-3 py-1 bg-blue-100 text-blue-800 rounded-full text-sm">
      <span class="font-medium"><%= @expression.field %></span>
      <span class="mx-1"><%= operator_label(@expression.operator) %></span>
      <%= if @expression.value do %>
        <span class="font-medium"><%= @expression.value %></span>
      <% end %>
      <button
        type="button"
        class="ml-2 text-blue-600 hover:text-blue-800"
        phx-click="remove_expression"
        phx-value-id={@expression.id}
        phx-target={@target}
      >
        <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
        </svg>
      </button>
    </div>
    """
  end
  
  # Helper functions
  
  defp default_operators do
    [
      %{value: "=", label: "equals", types: [:string, :number, :date, :boolean]},
      %{value: "!=", label: "not equals", types: [:string, :number, :date, :boolean]},
      %{value: ">", label: "greater than", types: [:number, :date]},
      %{value: ">=", label: "greater than or equal", types: [:number, :date]},
      %{value: "<", label: "less than", types: [:number, :date]},
      %{value: "<=", label: "less than or equal", types: [:number, :date]},
      %{value: "LIKE", label: "contains", types: [:string]},
      %{value: "NOT LIKE", label: "does not contain", types: [:string]},
      %{value: "IN", label: "in list", types: [:string, :number]},
      %{value: "NOT IN", label: "not in list", types: [:string, :number]},
      %{value: "IS NULL", label: "is empty", types: [:string, :number, :date], unary: true},
      %{value: "IS NOT NULL", label: "is not empty", types: [:string, :number, :date], unary: true},
      %{value: "BETWEEN", label: "between", types: [:number, :date]},
      %{value: "REGEX", label: "matches pattern", types: [:string]}
    ]
  end
  
  defp get_operators_for_field(nil, _fields, _operators), do: []
  defp get_operators_for_field(field_name, fields, operators) do
    field = Enum.find(fields, & &1.name == field_name)
    if field do
      Enum.filter(operators, fn op ->
        field.type in op.types
      end)
    else
      operators
    end
  end
  
  defp operator_is_unary?(operator) do
    operator in ["IS NULL", "IS NOT NULL"]
  end
  
  defp operator_label(operator) do
    case operator do
      "=" -> "is"
      "!=" -> "is not"
      ">" -> ">"
      ">=" -> "≥"
      "<" -> "<"
      "<=" -> "≤"
      "LIKE" -> "contains"
      "NOT LIKE" -> "doesn't contain"
      "IN" -> "in"
      "NOT IN" -> "not in"
      "IS NULL" -> "is empty"
      "IS NOT NULL" -> "is not empty"
      "BETWEEN" -> "between"
      "REGEX" -> "matches"
      _ -> operator
    end
  end
  
  defp format_expression(%{type: :simple} = expr) do
    if expr.field && expr.operator do
      value_part = if expr.value && !operator_is_unary?(expr.operator) do
        " '#{expr.value}'"
      else
        ""
      end
      "#{expr.field} #{expr.operator}#{value_part}"
    else
      "..."
    end
  end
  defp format_expression(%{type: :compound} = expr) do
    logic = expr[:logic] || "AND"
    conditions = expr[:conditions] || []
    
    if Enum.empty?(conditions) do
      "..."
    else
      conditions
      |> Enum.map(&format_expression/1)
      |> Enum.join(" #{logic} ")
      |> then(& "(#{&1})")
    end
  end
  defp format_expression(%{type: :custom} = expr) do
    expr[:sql] || "..."
  end
  defp format_expression(_), do: "..."
  
  @doc """
  JavaScript hooks for expression builder.
  """
  def __hooks__() do
    %{
      "ExpressionBuilder" => %{
        mounted: """
        // Handle field insertion for custom SQL
        this.handleInsertField = (e) => {
          const field = e.detail.field;
          const textarea = this.el.querySelector('textarea');
          if (textarea) {
            const start = textarea.selectionStart;
            const end = textarea.selectionEnd;
            const text = textarea.value;
            const before = text.substring(0, start);
            const after = text.substring(end);
            
            textarea.value = before + field + after;
            textarea.selectionStart = textarea.selectionEnd = start + field.length;
            textarea.focus();
            
            // Trigger change event
            textarea.dispatchEvent(new Event('blur'));
          }
        };
        
        this.el.addEventListener('insert_field', this.handleInsertField);
        
        // Syntax highlighting for custom SQL
        this.highlightSQL = () => {
          const textarea = this.el.querySelector('textarea');
          if (!textarea) return;
          
          // Add syntax highlighting overlay if needed
          // This would require a more complex implementation
        };
        
        // Auto-complete for fields
        this.setupAutoComplete = () => {
          // Implement field auto-complete
        };
        """,
        
        destroyed: """
        this.el.removeEventListener('insert_field', this.handleInsertField);
        """
      }
    }
  end
end