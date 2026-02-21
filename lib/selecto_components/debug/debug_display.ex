defmodule SelectoComponents.Debug.DebugDisplay do
  @moduledoc """
  LiveComponent for displaying debug information based on domain configuration.
  """

  use Phoenix.LiveComponent
  alias SelectoComponents.Debug.ConfigReader

  def render(assigns) do
    ~H"""
    <div
      class="selecto-debug-panel"
      id={"debug-panel-#{@id}"}
      phx-hook="SelectoComponents.Debug.DebugDisplay.DebugClipboard"
    >
      <div :if={@show_debug} class="bg-gray-100 border border-gray-300 rounded-md p-3 mt-2 text-xs">
        <div class="flex items-center justify-between mb-2">
          <div class="flex items-center gap-2">
            <h4 class="font-semibold text-gray-700">Debug Information</h4>
            <button
              type="button"
              phx-click="toggle_debug_details"
              phx-target={@myself}
              class="inline-flex items-center px-2 py-1 bg-blue-500 hover:bg-blue-600 text-white rounded text-xs font-medium transition-colors"
            >
              <%= if @expanded do %>
                <svg class="h-3 w-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M19 9l-7 7-7-7"
                  />
                </svg>
                Hide Details
              <% else %>
                <svg class="h-3 w-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M9 5l7 7-7 7"
                  />
                </svg>
                Show Details
              <% end %>
            </button>
          </div>
          <div class="text-gray-600">
            {summary_text(@debug_info)}
          </div>
        </div>

        <div :if={@expanded} class="space-y-2">
          <div :if={@debug_info[:query]} class="border-t border-gray-200 pt-2">
            <div class="flex items-center justify-between mb-2">
              <h5 class="font-medium text-gray-600">SQL Query</h5>
              <div class="flex items-center gap-2">
                <!-- Copy button fixed - COMPTASK-0099 -->
                <button
                  type="button"
                  phx-click="copy_sql"
                  phx-target={@myself}
                  class="inline-flex items-center px-2 py-1 bg-blue-500 hover:bg-blue-600 text-white rounded text-xs font-medium transition-colors"
                  title="Copy SQL to clipboard"
                >
                  <svg class="h-3 w-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"
                    />
                  </svg>
                  Copy
                </button>
                <button
                  :if={@debug_info[:params] && length(@debug_info.params) > 0}
                  type="button"
                  phx-click="toggle_sql_mode"
                  phx-target={@myself}
                  class="inline-flex items-center px-2 py-1 bg-gray-500 hover:bg-gray-600 text-white rounded text-xs font-medium transition-colors"
                >
                  <%= if @show_interpolated do %>
                    Show Parameterized
                  <% else %>
                    Show Interpolated
                  <% end %>
                </button>
              </div>
            </div>
            <%= if @show_interpolated && @debug_info[:params] do %>
              <div class="bg-gray-900 p-3 rounded border border-gray-700 overflow-x-auto">
                {Phoenix.HTML.raw(
                  format_sql_with_makeup(interpolate_params(@debug_info.query, @debug_info.params))
                )}
              </div>
              <div class="mt-2 text-xs text-gray-600">
                <span class="font-semibold">Note:</span>
                This interpolated query can be copied and pasted directly into psql or other SQL tools.
              </div>
            <% else %>
              <div class="bg-gray-900 p-3 rounded border border-gray-700 overflow-x-auto">
                {Phoenix.HTML.raw(format_sql_with_makeup(@debug_info.query))}
              </div>
            <% end %>
          </div>

          <.debug_section
            :if={@debug_info[:params] && !@show_interpolated}
            title="Parameters"
            content={@debug_info.params}
            type="list"
          />

          <.debug_section
            :if={@debug_info[:timing]}
            title="Execution Time"
            content={format_timing(@debug_info.timing)}
            type="text"
          />

          <.debug_section
            :if={@debug_info[:row_count]}
            title="Row Count"
            content={@debug_info.row_count}
            type="text"
          />

          <.debug_section
            :if={@debug_info[:execution_plan]}
            title="Execution Plan"
            content={@debug_info.execution_plan}
            type="code"
          />

          <.debug_metadata metadata={@metadata} />
        </div>
      </div>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".DebugClipboard">
        export default {
          mounted() {
            this.handleCopyEvent = (e) => {
              const button = e.target.closest('button[phx-click="copy_sql"]');
              if (button) {
                const sqlQuery = this.el.querySelector('[data-sql-query]')?.textContent ||
                                this.el.querySelector('pre')?.textContent || '';

                if (sqlQuery) {
                  navigator.clipboard.writeText(sqlQuery).then(() => {
                    const originalText = button.innerHTML;
                    button.innerHTML = '✓ Copied!';
                    button.classList.add('bg-green-500');
                    button.classList.remove('bg-blue-500');

                    setTimeout(() => {
                      button.innerHTML = originalText;
                      button.classList.remove('bg-green-500');
                      button.classList.add('bg-blue-500');
                    }, 2000);
                  });
                }
              }
            };

            this.el.addEventListener('click', this.handleCopyEvent);
          },

          destroyed() {
            if (this.handleCopyEvent) {
              this.el.removeEventListener('click', this.handleCopyEvent);
            }
          }
        }
      </script>
    </div>
    """
  end

  def debug_section(assigns) do
    ~H"""
    <div class="border-t border-gray-200 pt-2">
      <h5 class="font-medium text-gray-600 mb-1">{@title}</h5>
      <%= case @type do %>
        <% "code" -> %>
          <%= if @title == "SQL Query" do %>
            <div class="bg-gray-900 p-3 rounded border border-gray-700 overflow-x-auto">
              {Phoenix.HTML.raw(format_sql_with_makeup(@content))}
            </div>
          <% else %>
            <pre class="bg-gray-50 p-3 rounded border border-gray-200 overflow-x-auto">
              <code class="text-xs font-mono text-gray-800"><%= @content %></code>
            </pre>
          <% end %>
        <% "list" -> %>
          <%= if @title == "Parameters" do %>
            <ul class="bg-white p-2 rounded border border-gray-200">
              <%= for {item, index} <- Enum.with_index(@content, 1) do %>
                <li class="text-xs font-mono">
                  <span class="text-blue-600 font-semibold">${index}</span>
                  <span class="text-gray-500 mx-1">=</span>
                  <span class="text-gray-800">{format_param_value(item)}</span>
                </li>
              <% end %>
            </ul>
          <% else %>
            <ul class="bg-white p-2 rounded border border-gray-200">
              <%= for {item, index} <- Enum.with_index(@content) do %>
                <li class="text-xs">
                  <span class="text-gray-500">[{index}]</span>
                  {inspect(item, pretty: true, limit: 50)}
                </li>
              <% end %>
            </ul>
          <% end %>
        <% _ -> %>
          <div class="bg-white p-2 rounded border border-gray-200 text-xs">
            {@content}
          </div>
      <% end %>
    </div>
    """
  end

  def debug_metadata(assigns) do
    ~H"""
    <div :if={@metadata && map_size(@metadata) > 0} class="border-t border-gray-200 pt-2">
      <h5 class="font-medium text-gray-600 mb-1">Metadata</h5>
      <dl class="grid grid-cols-2 gap-x-4 gap-y-1 text-xs">
        <%= for {key, value} <- @metadata do %>
          <dt class="text-gray-500">{humanize_key(key)}:</dt>
          <dd class="text-gray-700">{format_metadata_value(value)}</dd>
        <% end %>
      </dl>
    </div>
    """
  end

  def mount(socket) do
    {:ok,
     assign(socket,
       expanded: true,
       show_debug: false,
       show_interpolated: false,
       debug_info: %{},
       metadata: %{}
     )}
  end

  def update(assigns, socket) do
    domain_module = Map.get(assigns, :domain_module)
    view_type = Map.get(assigns, :view_type)

    config = ConfigReader.get_view_config(domain_module, view_type)
    show_debug = ConfigReader.debug_enabled?(domain_module, view_type)

    debug_info =
      if show_debug && assigns[:debug_data] do
        ConfigReader.build_debug_info(assigns.debug_data, config)
      else
        %{}
      end

    metadata = extract_metadata(assigns)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(
       show_debug: show_debug,
       debug_info: debug_info,
       metadata: metadata,
       config: config
     )}
  end

  def handle_event("toggle_debug_details", _, socket) do
    {:noreply, assign(socket, expanded: !socket.assigns.expanded)}
  end

  def handle_event("toggle_sql_mode", _, socket) do
    {:noreply, assign(socket, show_interpolated: !socket.assigns.show_interpolated)}
  end

  def handle_event("copy_sql", _params, socket) do
    sql_to_copy =
      if socket.assigns.show_interpolated do
        # Get interpolated SQL
        case socket.assigns.debug_info do
          %{query: query, params: params} when is_binary(query) and is_list(params) ->
            interpolate_params(query, params)

          %{query: query} when is_binary(query) ->
            query

          _ ->
            ""
        end
      else
        # Get raw SQL
        socket.assigns.debug_info[:query] || ""
      end

    # Push event to JavaScript hook to handle clipboard
    {:noreply, push_event(socket, "copy-to-clipboard", %{text: sql_to_copy})}
  end

  # Helper functions

  defp format_timing(timing) when is_number(timing) do
    cond do
      timing < 1 -> "< 1ms"
      timing < 1000 -> "#{round(timing)}ms"
      true -> "#{Float.round(timing / 1000, 2)}s"
    end
  end

  defp format_timing(timing), do: inspect(timing)

  defp summary_text(debug_info) do
    parts = []

    parts =
      if debug_info[:timing] do
        ["Executed in #{format_timing(debug_info.timing)}" | parts]
      else
        parts
      end

    parts =
      if debug_info[:row_count] do
        ["#{debug_info.row_count} rows" | parts]
      else
        parts
      end

    if Enum.empty?(parts) do
      "Click to expand debug information"
    else
      Enum.join(parts, " • ")
    end
  end

  defp extract_metadata(assigns) do
    %{}
    |> maybe_add_metadata(:domain, assigns[:domain_module])
    |> maybe_add_metadata(:view_type, assigns[:view_type])
    |> maybe_add_metadata(:filters_count, count_filters(assigns[:filters]))
    |> maybe_add_metadata(:aggregates_count, count_items(assigns[:aggregates]))
    |> maybe_add_metadata(:columns_count, count_items(assigns[:columns]))
  end

  defp maybe_add_metadata(metadata, _key, nil), do: metadata
  defp maybe_add_metadata(metadata, _key, ""), do: metadata
  defp maybe_add_metadata(metadata, key, value), do: Map.put(metadata, key, value)

  defp count_filters(nil), do: nil
  defp count_filters(filters) when is_list(filters), do: length(filters)
  defp count_filters(filters) when is_map(filters), do: map_size(filters)
  defp count_filters(_), do: nil

  defp count_items(nil), do: nil
  defp count_items(items) when is_list(items), do: length(items)
  defp count_items(items) when is_map(items), do: map_size(items)
  defp count_items(_), do: nil

  defp humanize_key(key) when is_atom(key) do
    key
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp humanize_key(key), do: to_string(key)

  defp format_metadata_value(value) when is_atom(value) do
    value
    |> Atom.to_string()
    |> String.replace("_", " ")
  end

  defp format_metadata_value(value) when is_number(value), do: to_string(value)
  defp format_metadata_value(value), do: inspect(value, limit: 20)

  defp format_param_value(value) when is_binary(value) do
    if String.length(value) > 50 do
      "'#{String.slice(value, 0, 50)}...'"
    else
      "'#{value}'"
    end
  end

  defp format_param_value(value) when is_nil(value), do: "NULL"
  defp format_param_value(value) when is_boolean(value), do: if(value, do: "TRUE", else: "FALSE")
  defp format_param_value(value) when is_number(value), do: to_string(value)
  defp format_param_value(value), do: inspect(value, limit: 50)

  defp interpolate_params(sql, params) when is_binary(sql) and is_list(params) do
    # Replace $1, $2, etc. with actual parameter values
    params
    |> Enum.with_index(1)
    |> Enum.reduce(sql, fn {value, index}, acc ->
      # Escape the parameter value for SQL
      escaped_value = escape_sql_value(value)
      String.replace(acc, "$#{index}", escaped_value)
    end)
  end

  defp interpolate_params(sql, _), do: sql

  defp escape_sql_value(nil), do: "NULL"
  defp escape_sql_value(true), do: "TRUE"
  defp escape_sql_value(false), do: "FALSE"
  defp escape_sql_value(value) when is_number(value), do: to_string(value)

  defp escape_sql_value(value) when is_binary(value) do
    # Escape single quotes by doubling them
    escaped = String.replace(value, "'", "''")
    "'#{escaped}'"
  end

  defp escape_sql_value(%DateTime{} = dt), do: "'#{DateTime.to_iso8601(dt)}'"
  defp escape_sql_value(%Date{} = d), do: "'#{Date.to_iso8601(d)}'"
  defp escape_sql_value(%Time{} = t), do: "'#{Time.to_iso8601(t)}'"

  defp escape_sql_value(value) when is_list(value) do
    # Handle arrays/lists
    items = Enum.map(value, &escape_sql_value/1)
    "ARRAY[#{Enum.join(items, ", ")}]"
  end

  defp escape_sql_value(value), do: "'#{inspect(value)}'"

  defp format_sql_with_makeup(sql) when is_binary(sql) do
    # Use Makeup to format and highlight SQL
    # First, ensure MakeupSQL lexer is registered
    Makeup.Registry.fetch_lexer_by_name!("sql")

    # Format the SQL with Makeup
    sql
    |> Makeup.highlight(lexer: Makeup.Lexers.SQLLexer)
    |> add_makeup_styles()
  rescue
    _ ->
      # Fallback to simple HTML escaping if Makeup fails
      "<pre class=\"text-xs font-mono text-gray-300\">#{Phoenix.HTML.html_escape(sql) |> Phoenix.HTML.safe_to_string()}</pre>"
  end

  defp format_sql_with_makeup(_), do: ""

  # Add inline styles for Makeup tokens since we're in a component
  defp add_makeup_styles(html) do
    """
    <style>
      .highlight { font-family: monospace; font-size: 0.75rem; line-height: 1.25rem; color: #e5e7eb; }
      .highlight .k { color: #93c5fd; font-weight: 600; } /* Keywords */
      .highlight .kc { color: #86efac; font-weight: 600; } /* Keyword constants (TRUE, FALSE, NULL) */
      .highlight .kd { color: #f87171; font-weight: 600; } /* Keyword declarations (CREATE, ALTER, DROP) */
      .highlight .o { color: #9ca3af; } /* Operators */
      .highlight .s { color: #fde047; } /* Strings */
      .highlight .si { color: #fbbf24; } /* String interpolation */
      .highlight .n { color: #e5e7eb; } /* Names */
      .highlight .nf { color: #fbbf24; } /* Function names */
      .highlight .m { color: #67e8f9; } /* Numbers */
      .highlight .c { color: #6b7280; font-style: italic; } /* Comments */
      .highlight .p { color: #9ca3af; } /* Punctuation */
    </style>
    <div class="highlight">#{html}</div>
    """
  end
end
