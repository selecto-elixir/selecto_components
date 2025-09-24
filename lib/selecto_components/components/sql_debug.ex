defmodule SelectoComponents.Components.SqlDebug do
  @moduledoc """
  Component for displaying SQL queries in development mode.
  Shows prettified SQL with syntax highlighting and copy functionality.
  """
  
  use Phoenix.Component
  alias Phoenix.LiveView.JS

  @doc """
  Renders SQL debug information if in dev mode.
  
  ## Attributes
  - sql: The SQL query string
  - params: Query parameters (optional)
  - expanded: Whether the debug section is initially expanded
  """
  attr :sql, :string, default: nil
  attr :params, :list, default: []
  attr :expanded, :boolean, default: false
  attr :execution_time, :integer, default: nil

  def sql_debug(assigns) do
    # Only show in development mode
    if Mix.env() == :dev && assigns.sql do
      assigns = assigns
        |> Map.put(:formatted_sql, format_sql(assigns.sql))
        |> Map.put(:debug_id, "sql_debug_#{:erlang.unique_integer([:positive])}")
      
      ~H"""
      <div class="sql-debug-container mt-4 mb-4 border border-gray-300 dark:border-gray-600 rounded-lg bg-gray-50 dark:bg-gray-800">
        <div class="flex items-center justify-between px-4 py-2 bg-gray-100 dark:bg-gray-700 border-b border-gray-300 dark:border-gray-600 rounded-t-lg">
          <button
            type="button"
            class="flex items-center text-sm font-medium text-gray-700 dark:text-gray-300 hover:text-gray-900 dark:hover:text-gray-100"
            phx-click={toggle_debug(@debug_id)}
          >
            <svg
              class={"h-4 w-4 mr-1 transition-transform #{if @expanded, do: "rotate-90", else: ""}"}
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
            </svg>
            SQL Debug
            <%= if @execution_time do %>
              <span class="ml-2 text-xs text-gray-500 dark:text-gray-400">(<%= @execution_time %>ms)</span>
            <% end %>
          </button>
          
          <button
            type="button"
            class="px-2 py-1 text-xs font-medium text-gray-600 dark:text-gray-300 bg-white dark:bg-gray-600 border border-gray-300 dark:border-gray-500 rounded hover:bg-gray-50 dark:hover:bg-gray-500"
            phx-click={copy_to_clipboard(@debug_id <> "_sql")}
          >
            Copy SQL
          </button>
        </div>
        
        <div id={@debug_id} class={if @expanded, do: "block", else: "hidden"}>
          <div class="p-4">
            <div class="mb-3">
              <h4 class="text-xs font-semibold text-gray-600 dark:text-gray-400 uppercase mb-1">Query</h4>
              <pre id={@debug_id <> "_sql"} class="sql-code bg-gray-900 dark:bg-gray-800 text-gray-100 dark:text-gray-200 p-3 rounded overflow-x-auto text-xs"><%= @formatted_sql %></pre>
            </div>
            
            <%= if @params && length(@params) > 0 do %>
              <div>
                <h4 class="text-xs font-semibold text-gray-600 dark:text-gray-400 uppercase mb-1">Parameters</h4>
                <div class="bg-white dark:bg-gray-700 border border-gray-200 dark:border-gray-600 rounded p-2">
                  <ul class="text-xs font-mono">
                    <%= for {param, idx} <- Enum.with_index(@params, 1) do %>
                      <li class="py-1">
                        <span class="text-gray-500 dark:text-gray-400">$<%= idx %>:</span>
                        <span class="text-gray-900 dark:text-gray-200"><%= inspect(param) %></span>
                      </li>
                    <% end %>
                  </ul>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>
      """
    else
      ~H""
    end
  end

  @doc """
  Renders a simplified inline SQL display
  """
  attr :sql, :string, required: true

  def sql_inline(assigns) do
    if Mix.env() == :dev do
      ~H"""
      <span class="sql-inline font-mono text-xs text-gray-600 dark:text-gray-300 bg-gray-100 dark:bg-gray-700 px-1 py-0.5 rounded">
        <%= truncate_sql(@sql) %>
      </span>
      """
    else
      ~H""
    end
  end

  # Private functions

  defp format_sql(sql) do
    sql
    |> add_syntax_highlighting()
    |> indent_sql()
  end

  defp add_syntax_highlighting(sql) do
    # Basic SQL syntax highlighting
    keywords = ~w(
      select from where join left right inner outer on
      group by order having limit offset distinct
      as and or not in exists between like ilike
      case when then else end null is true false
      insert into values update set delete
      create table alter drop index primary key foreign references
      begin commit rollback transaction
      with recursive union all intersect except
      json_agg array_agg row_to_json to_json jsonb_agg
    )
    
    # Replace keywords with highlighted versions
    Enum.reduce(keywords, sql, fn keyword, acc ->
      # Case-insensitive replacement
      Regex.replace(
        ~r/\b#{keyword}\b/i,
        acc,
        "<span class='sql-keyword'>#{String.upcase(keyword)}</span>"
      )
    end)
  end

  defp indent_sql(sql) do
    # Basic SQL indentation for readability
    sql
    |> String.replace("SELECT", "\nSELECT")
    |> String.replace("FROM", "\nFROM")
    |> String.replace("WHERE", "\nWHERE")
    |> String.replace("JOIN", "\n  JOIN")
    |> String.replace("LEFT JOIN", "\n  LEFT JOIN")
    |> String.replace("RIGHT JOIN", "\n  RIGHT JOIN")
    |> String.replace("GROUP BY", "\nGROUP BY")
    |> String.replace("ORDER BY", "\nORDER BY")
    |> String.replace("HAVING", "\nHAVING")
    |> String.replace("LIMIT", "\nLIMIT")
    |> String.trim()
  end

  defp truncate_sql(sql, max_length \\ 100) do
    if String.length(sql) > max_length do
      String.slice(sql, 0, max_length) <> "..."
    else
      sql
    end
  end

  defp toggle_debug(debug_id) do
    JS.toggle(to: "##{debug_id}")
    |> JS.toggle_class("rotate-90", to: "[data-debug='#{debug_id}']")
  end

  defp copy_to_clipboard(element_id) do
    JS.dispatch("phx:copy", to: "##{element_id}")
  end

  @doc """
  JavaScript hooks for SQL debug functionality
  """
  def hooks do
    %{
      "SqlDebug" => %{
        mounted: """
        // Copy to clipboard functionality
        this.el.addEventListener('phx:copy', e => {
          const text = e.target.textContent;
          navigator.clipboard.writeText(text).then(() => {
            // Show success feedback
            const button = e.target.closest('.sql-debug-container').querySelector('[phx-click*="copy"]');
            const originalText = button.textContent;
            button.textContent = 'Copied!';
            button.classList.add('bg-green-50', 'text-green-700');
            
            setTimeout(() => {
              button.textContent = originalText;
              button.classList.remove('bg-green-50', 'text-green-700');
            }, 2000);
          });
        });
        """
      }
    }
  end

  @doc """
  CSS styles for SQL debug display
  """
  def styles do
    """
    .sql-debug-container {
      font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
    }
    
    .sql-code {
      font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
      line-height: 1.5;
    }
    
    .sql-keyword {
      color: #ff79c6;
      font-weight: bold;
    }
    
    .sql-function {
      color: #50fa7b;
    }
    
    .sql-string {
      color: #f1fa8c;
    }
    
    .sql-number {
      color: #bd93f9;
    }
    
    .sql-comment {
      color: #6272a4;
      font-style: italic;
    }
    
    .sql-inline {
      max-width: 300px;
      display: inline-block;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
      vertical-align: middle;
    }
    """
  end
end