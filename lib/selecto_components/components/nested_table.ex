defmodule SelectoComponents.Components.NestedTable do
  @moduledoc """
  Component for rendering nested tables from subselect results.
  Provides expandable/collapsible sections for related data.
  """
  
  use Phoenix.Component
  alias Phoenix.LiveView.JS

  @doc """
  Renders a nested table for subselect results.
  
  ## Attributes
  - data: The subselect data (JSON array or list of maps)
  - config: Configuration for the nested table display
  - row_id: Unique identifier for this row (for expand/collapse)
  """
  attr :data, :any, required: true
  attr :config, :map, required: true
  attr :row_id, :string, required: true
  attr :expanded, :boolean, default: false

  def nested_table(assigns) do
    assigns = assigns
      |> Map.put(:parsed_data, parse_subselect_data(assigns.data))
      |> Map.put(:table_id, "nested_#{assigns.row_id}")
      |> Map.put(:column_headers, get_column_headers(assigns))
    
    ~H"""
    <div class="nested-table-container ml-4 mt-2">
      <div class="flex items-center">
        <button
          type="button"
          class="flex items-center text-sm font-medium text-gray-700 hover:text-gray-900"
          phx-click={toggle_nested_table(@table_id)}
        >
          <svg
            class={"h-4 w-4 mr-1 transition-transform #{if @expanded, do: "rotate-90", else: ""}"}
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
          </svg>
          <%= @config.title %> (<%= length(@parsed_data) %> items)
        </button>
      </div>
      
      <div id={@table_id} class={if @expanded, do: "block", else: "hidden"}>
        <%= if length(@parsed_data) > 0 do %>
          <div class="mt-2 overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <%= for header <- @column_headers do %>
                    <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      <%= header %>
                    </th>
                  <% end %>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                <%= for {item, idx} <- Enum.with_index(@parsed_data) do %>
                  <%= if idx < max_display_rows(@config) do %>
                    <tr class="hover:bg-gray-50">
                      <%= for key <- get_data_keys(@parsed_data) do %>
                        <td class="px-3 py-2 whitespace-nowrap text-sm text-gray-900">
                          <%= format_value(Map.get(item, key, "")) %>
                        </td>
                      <% end %>
                    </tr>
                  <% end %>
                <% end %>
              </tbody>
            </table>
            
            <%= if length(@parsed_data) > max_display_rows(@config) do %>
              <div class="px-3 py-2 text-sm text-gray-500">
                ... and <%= length(@parsed_data) - max_display_rows(@config) %> more items
              </div>
            <% end %>
          </div>
        <% else %>
          <div class="mt-2 px-3 py-2 text-sm text-gray-500 italic">
            No related <%= String.downcase(@config.title) %> found
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @doc """
  Renders multiple nested tables for a row with subselect data
  """
  attr :row, :map, required: true
  attr :subselect_configs, :list, default: []
  attr :row_id, :string, required: true

  def nested_tables(assigns) do
    ~H"""
    <div class="nested-tables">
      <%= for config <- @subselect_configs do %>
        <.nested_table
          data={Map.get(@row, config.key, [])}
          config={config}
          row_id={@row_id}
          expanded={Map.get(config, :initial_state, :collapsed) == :expanded}
        />
      <% end %>
    </div>
    """
  end

  # Private functions

  defp parse_subselect_data(nil), do: []
  defp parse_subselect_data(data) when is_list(data), do: data
  defp parse_subselect_data(data) when is_binary(data) do
    # Try to parse JSON string
    case Jason.decode(data) do
      {:ok, parsed} when is_list(parsed) -> parsed
      _ -> []
    end
  end
  defp parse_subselect_data(_), do: []

  defp get_nested_value(item, field) do
    # Extract value from nested data
    # Handle both "column" and "table[column]" formats
    case String.split(field, ["[", "]"], trim: true) do
      [_table, column] -> Map.get(item, column, "")
      [column] -> Map.get(item, column, "")
    end
  end

  defp max_display_rows(config) do
    Map.get(config, :max_rows, 10)
  end

  defp toggle_nested_table(table_id) do
    JS.toggle(to: "##{table_id}")
    |> JS.toggle_class("rotate-90", to: "[data-table='#{table_id}']")
  end

  defp get_column_headers(assigns) do
    # Try to get headers from the first data item or config
    case parse_subselect_data(assigns.data) do
      [first | _] when is_map(first) ->
        Map.keys(first)
        |> Enum.map(&humanize_key/1)
      _ ->
        # Fallback to config columns if available
        case Map.get(assigns.config, :columns, []) do
          columns when is_list(columns) and length(columns) > 0 ->
            Enum.map(columns, fn 
              {_, field, _} -> humanize_key(extract_field_name(field))
              field when is_binary(field) -> humanize_key(extract_field_name(field))
              _ -> "Column"
            end)
          _ ->
            []
        end
    end
  end

  defp get_data_keys(parsed_data) do
    case parsed_data do
      [first | _] when is_map(first) -> Map.keys(first)
      _ -> []
    end
  end

  defp humanize_key(key) when is_binary(key) do
    key
    |> String.replace("_", " ")
    |> String.capitalize()
  end
  defp humanize_key(key), do: to_string(key)

  defp extract_field_name(field) when is_binary(field) do
    case String.split(field, ".", parts: 2) do
      [_, name] -> name
      [name] -> name
    end
  end

  defp format_value(value) when is_binary(value), do: value
  defp format_value(value) when is_number(value), do: to_string(value)
  defp format_value(nil), do: ""
  defp format_value(value), do: inspect(value)

  @doc """
  Generates JavaScript hooks for nested table interactions
  """
  def hooks do
    %{
      "NestedTable" => %{
        mounted: """
        this.handleToggle = (e) => {
          const tableId = e.currentTarget.dataset.table;
          const table = document.getElementById(tableId);
          const icon = e.currentTarget.querySelector('svg');
          
          if (table.classList.contains('hidden')) {
            table.classList.remove('hidden');
            icon.classList.add('rotate-90');
          } else {
            table.classList.add('hidden');
            icon.classList.remove('rotate-90');
          }
        };
        
        this.el.querySelectorAll('[data-toggle]').forEach(btn => {
          btn.addEventListener('click', this.handleToggle);
        });
        """,
        destroyed: """
        this.el.querySelectorAll('[data-toggle]').forEach(btn => {
          btn.removeEventListener('click', this.handleToggle);
        });
        """
      }
    }
  end

  @doc """
  CSS styles for nested tables
  """
  def styles do
    """
    .nested-table-container {
      border-left: 2px solid #e5e7eb;
      padding-left: 1rem;
      margin-bottom: 0.5rem;
    }
    
    .nested-table-container table {
      font-size: 0.875rem;
    }
    
    .nested-table-container .rotate-90 {
      transform: rotate(90deg);
    }
    
    .nested-tables {
      margin-top: 0.5rem;
    }
    """
  end
end