defmodule SelectoComponents.Views.Detail.Component do
  @doc """
    Display results of a detail view

  """
  import SelectoComponents.Components.SqlDebug
  alias SelectoComponents.EnhancedTable.Sorting
  use Phoenix.LiveComponent

  def mount(socket) do
    # Initialize column configuration
    # Will be populated in update/2
    columns = []

    socket =
      socket
      |> assign(:columns_config, init_columns_config(columns))

    {:ok, socket}
  end

  def update(assigns, socket) do
    # Extract columns from selecto if available
    columns =
      if Map.has_key?(assigns, :selecto) do
        Map.get(assigns.selecto.set, :columns, [])
        |> Enum.map(fn col ->
          %{
            id: col["field"],
            name: col["alias"] || col["field"],
            width: 150,
            min_width: 50,
            max_width: 500
          }
        end)
      else
        []
      end

    socket =
      socket
      |> assign(assigns)
      |> assign(:columns_config, init_columns_config(columns))

    {:ok, socket}
  end

  def render(assigns) do
    # Check for execution error first
    if Map.get(assigns, :execution_error) do
      # Display the actual error message
      ~H"""
      <div>
        <%= if @execution_error do %>
          <div
            class="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded relative mb-4"
            role="alert"
          >
            <strong class="font-bold">Query Error:</strong>
            <span class="block sm:inline">
              <%= case @execution_error do %>
                <% %{message: msg} -> %>
                  {msg}
                <% error when is_binary(error) -> %>
                  {error}
                <% error -> %>
                  {inspect(error)}
              <% end %>
            </span>
            <%= if Mix.env() == :dev && is_map(@execution_error) && Map.has_key?(@execution_error, :details) do %>
              <details class="mt-2">
                <summary class="cursor-pointer text-sm">Debug Details</summary>
                <pre class="text-xs mt-2 bg-red-100 p-2 rounded overflow-x-auto"><%= inspect(@execution_error.details, pretty: true) %></pre>
              </details>
            <% end %>
          </div>
        <% end %>
        <div class="text-gray-500 italic p-4">
          View cannot be displayed due to the query error shown above.
        </div>
      </div>
      """
    else
      # Check if we have valid query results and execution state
      case {assigns[:executed], assigns.query_results} do
        {false, _} ->
          # Query is being executed or hasn't been executed yet
          ~H"""
          <div>
            <div class="text-blue-500 italic p-4">Loading view...</div>
          </div>
          """

        {true, nil} ->
          # Executed but no results - this is an error state
          ~H"""
          <div>
            <div class="text-red-500 p-4">
              <div class="font-semibold">No Results</div>
              <div class="text-sm mt-1">Query executed but returned no results.</div>
            </div>
          </div>
          """

        {true, {results, _fields, aliases}} ->
          # Valid results - proceed with normal rendering
          render_detail_view(assign(assigns, :processed_results, {results, aliases}))
      end
    end
  end

  defp render_detail_view(assigns) do
    {results, aliases} = assigns.processed_results

    # Ensure results are normalized to maps if they're lists
    normalized_results =
      if length(results) > 0 and is_list(hd(results)) do
        {_results, columns, _aliases} = assigns.query_results

        Enum.map(results, fn row ->
          Enum.zip(columns, row) |> Map.new()
        end)
      else
        results
      end

    page = max(Map.get(assigns.view_meta, :page, 0), 0)
    per_page = max(Map.get(assigns.view_meta, :per_page, 30), 1)
    total_rows = Map.get(assigns.view_meta, :total_rows, Enum.count(normalized_results))

    max_page =
      if total_rows > 0 do
        div(total_rows - 1, per_page)
      else
        0
      end

    current_page = min(page, max_page)
    row_offset = current_page * per_page

    page_start =
      if total_rows > 0 do
        row_offset + 1
      else
        0
      end

    page_end =
      if total_rows > 0 do
        min(row_offset + Enum.count(normalized_results), total_rows)
      else
        0
      end

    total_pages = if total_rows > 0, do: max_page + 1, else: 0

    ### Use Selecto columns rather than aliases because a column can lead to more than one selection...

    assigns =
      assign(assigns,
        aliases: aliases,
        results: normalized_results,
        total_rows: total_rows,
        row_offset: row_offset,
        current_page: current_page,
        page_start: page_start,
        page_end: page_end,
        total_pages: total_pages,
        columns: Map.get(assigns.selecto.set, :columns, []),
        column_uuids:
          Map.get(assigns.selecto.set, :columns, []) |> Enum.map(fn c -> c["uuid"] end),
        max_page: max_page
      )

    ~H"""
    <div>
      <.sql_debug
        :if={Map.get(assigns, :sql)}
        sql={Map.get(assigns, :sql)}
        params={Map.get(assigns, :sql_params, [])}
        execution_time={Map.get(assigns, :execution_time)}
      />

      <div class="mb-3 flex flex-wrap items-center justify-between gap-3 rounded-lg border border-gray-200 bg-gradient-to-r from-gray-50 to-white px-3 py-2">
        <div class="inline-flex items-center gap-1 rounded-md border border-gray-200 bg-white p-1 shadow-sm">
          <button
            type="button"
            phx-click="set_page"
            phx-value-page={0}
            phx-target={@myself}
            class="inline-flex h-8 w-8 items-center justify-center rounded border border-gray-200 text-gray-600 transition hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-40 disabled:hover:bg-white"
            title="First page"
            aria-label="First page"
            disabled={@current_page <= 0}
          >
            <svg
              class="h-4 w-4"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="2"
              stroke="currentColor"
              aria-hidden="true"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M18 18L12 12l6-6M10 18 4 12l6-6M4 6v12"
              />
            </svg>
          </button>

          <button
            type="button"
            phx-click="set_page"
            phx-value-page={@current_page - 1}
            phx-target={@myself}
            class="inline-flex h-8 items-center gap-1 rounded border border-gray-200 px-2 text-sm font-medium text-gray-700 transition hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-40 disabled:hover:bg-white"
            title="Previous page"
            aria-label="Previous page"
            disabled={@current_page <= 0}
          >
            <svg
              class="h-4 w-4"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="2"
              stroke="currentColor"
              aria-hidden="true"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="m15 18-6-6 6-6" />
            </svg>
            Prev
          </button>

          <button
            type="button"
            phx-click="set_page"
            phx-value-page={@current_page + 1}
            phx-target={@myself}
            class="inline-flex h-8 items-center gap-1 rounded border border-gray-200 px-2 text-sm font-medium text-gray-700 transition hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-40 disabled:hover:bg-white"
            title="Next page"
            aria-label="Next page"
            disabled={@current_page >= @max_page}
          >
            Next
            <svg
              class="h-4 w-4"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="2"
              stroke="currentColor"
              aria-hidden="true"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="m9 6 6 6-6 6" />
            </svg>
          </button>

          <button
            type="button"
            phx-click="set_page"
            phx-value-page={@max_page}
            phx-target={@myself}
            class="inline-flex h-8 w-8 items-center justify-center rounded border border-gray-200 text-gray-600 transition hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-40 disabled:hover:bg-white"
            title="Last page"
            aria-label="Last page"
            disabled={@current_page >= @max_page}
          >
            <svg
              class="h-4 w-4"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="2"
              stroke="currentColor"
              aria-hidden="true"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M6 18l6-6-6-6m8 12 6-6-6-6m6 0v12"
              />
            </svg>
          </button>
        </div>

        <div class="text-sm font-medium text-gray-700">
          <span class="font-semibold tabular-nums">{@page_start}-{@page_end}</span>
          of <span class="font-semibold tabular-nums">{@total_rows}</span>
          rows
        </div>

        <div class="text-xs text-gray-500 tabular-nums">
          Page
          <span class="font-semibold">{if @total_pages > 0, do: @current_page + 1, else: 0}</span>
          of <span class="font-semibold">{@total_pages}</span>
        </div>
      </div>

      <div
        class="responsive-table-wrapper overflow-x-auto"
        id={"detail-table-wrapper-#{@myself}"}
        phx-hook=".RowClickable"
      >
        <table class="min-w-full overflow-hidden divide-y ring-1 ring-gray-200  divide-gray-200 rounded-sm table-auto   sm:rounded">
          <thead>
            <tr>
              <th class="px-2 py-3 text-xs font-medium tracking-wider text-center text-gray-700 uppercase bg-gray-50 w-12 max-w-12 min-w-12">
                #
              </th>
              <%= for {alias, idx} <- Enum.with_index(@aliases) do %>
                <% column_field = Enum.at(@columns, idx)["field"] %>
                <Sorting.sortable_header
                  column={column_field}
                  label={alias}
                  sort_by={assigns[:sort_by] || []}
                  multi={false}
                  target={@myself}
                  resizable={true}
                  column_config={assigns[:column_config] || %{}}
                />
              <% end %>
              <%!-- Add headers for subselect columns --%>
              <%= if Map.get(@view_meta, :subselect_configs, []) != [] do %>
                <%= for config <- Map.get(@view_meta, :subselect_configs, []) do %>
                  <th class="px-6 py-3 text-xs font-medium tracking-wider text-left text-gray-700 uppercase bg-gray-50">
                    {Map.get(config, :title, config.key)}
                  </th>
                <% end %>
              <% end %>
            </tr>
          </thead>
          <tbody>
            <%!--  --%>
            <%= for {resrow, display_idx} <- Enum.with_index(@results) do %>
              <% # Process row data once at the beginning of the iteration %>
              <% resrow_list =
                cond do
                  is_tuple(resrow) ->
                    Tuple.to_list(resrow)

                  is_list(resrow) ->
                    resrow

                  is_map(resrow) ->
                    # If it's already a map, extract values in column order
                    {_results, columns_from_query, _aliases} = @query_results
                    Enum.map(columns_from_query, fn col -> Map.get(resrow, col) end)

                  true ->
                    [resrow]
                end %>
              <% row_data_by_uuid = Enum.zip(@column_uuids, resrow_list) |> Enum.into(%{}) %>
              <% # Also create a map by column name for subselects %>
              <% {_results, columns_from_query, _aliases} = @query_results %>
              <% row_data_by_column = Enum.zip(columns_from_query, resrow_list) |> Map.new() %>
              <% absolute_idx = @row_offset + display_idx %>

              <tr
                class="border-b  bg-white even:bg-gray-100   last:border-none text-sm text-gray-500  align-top hover:bg-blue-50 cursor-pointer"
                phx-click="show_row_details"
                phx-value-row-index={display_idx}
                phx-target={@myself}
              >
                <td class="px-2 py-1 text-center w-12 max-w-12 min-w-12">
                  {absolute_idx + 1}
                </td>
                <%!-- Display regular columns --%>
                <td
                  :for={{_, col_conf} <- Enum.zip(@column_uuids, @columns)}
                  class="px-1 py-1 align-top"
                >
                  <% def = Selecto.columns(@selecto)[col_conf["field"]] %>
                  <%= case def do %>
                    <% %{format: :component} = def -> %>
                      {safe_render_component(def.component, %{
                        row: row_data_by_uuid[col_conf["uuid"]],
                        config: col_conf
                      })}
                    <% %{format: :link} = def -> %>
                      {safe_render_link(def.link_parts, row_data_by_uuid[col_conf["uuid"]])}
                    <% _ -> %>
                      {row_data_by_uuid[col_conf["uuid"]]}
                  <% end %>
                </td>

                <%!-- Add subselect columns inline --%>
                <%= if Map.get(@view_meta, :subselect_configs, []) != [] do %>
                  <%= for config <- Map.get(@view_meta, :subselect_configs, []) do %>
                    <% data = Map.get(row_data_by_column, config.key, []) %>
                    <% unique_id = "row#{absolute_idx}_#{config.key}" %>
                    <td class="px-1 py-1 align-top" id={"cell_#{unique_id}"}>
                      <% # Parse the data here to ensure it's fresh %>
                      <% parsed_data =
                        SelectoComponents.Components.NestedTable.parse_subselect_data(data, config) %>
                      <div id={"nested_#{unique_id}"}>
                        <%= if length(parsed_data) > 0 do %>
                          <table class="min-w-full border border-gray-300 rounded">
                            <thead>
                              <tr class="bg-gray-100">
                                <%= for key <- SelectoComponents.Components.NestedTable.get_data_keys(parsed_data) do %>
                                  <th class="px-2 py-1 text-xs font-medium text-gray-700 border-b border-gray-200">
                                    {SelectoComponents.Components.NestedTable.humanize_key(key)}
                                  </th>
                                <% end %>
                              </tr>
                            </thead>
                            <tbody>
                              <%= for {item, _idx} <- Enum.with_index(parsed_data) do %>
                                <tr class="border-b border-gray-200 last:border-b-0 hover:bg-gray-50">
                                  <%= for key <- SelectoComponents.Components.NestedTable.get_data_keys(parsed_data) do %>
                                    <td class="px-2 py-1 text-xs text-gray-700">
                                      {SelectoComponents.Components.NestedTable.format_value(
                                        Map.get(item, key, "")
                                      )}
                                    </td>
                                  <% end %>
                                </tr>
                              <% end %>
                            </tbody>
                          </table>
                        <% else %>
                          <div class="text-xs text-gray-500 italic">No data</div>
                        <% end %>
                      </div>
                    </td>
                  <% end %>
                <% end %>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".RowClickable">
        export default {
          mounted() {
            this.handleRowClick = (e) => {
              const row = e.target.closest('tr[data-row-id]');
              if (row && !e.target.closest('a, button, input, select, textarea')) {
                const rowId = row.dataset.rowId;
                const action = row.dataset.clickAction || 'row_clicked';

                this.pushEvent(action, { row_id: rowId });
              }
            };

            this.el.addEventListener('click', this.handleRowClick);
          },

          destroyed() {
            if (this.handleRowClick) {
              this.el.removeEventListener('click', this.handleRowClick);
            }
          }
        }
      </script>
    </div>
    """
  end

  def handle_event("sort_column", %{"column" => column} = params, socket) do
    multi = Map.get(params, "multi", "false") == "true"
    socket = Sorting.handle_sort_click(column, socket, multi)

    # Trigger re-execution with new sort
    send(self(), {:rerun_query_with_sort, socket.assigns.sort_by})

    {:noreply, socket}
  end

  def handle_event("set_page", params, socket) do
    new_page =
      params
      |> Map.get("page", "0")
      |> parse_page_param()
      |> clamp_page(socket.assigns[:view_meta])

    # Notify parent to update the page in the form params (parent is authoritative)
    send(self(), {:update_detail_page, new_page})

    {:noreply, socket}
  end

  def handle_event("resize_column", %{"column_id" => _column_id, "width" => _width}, socket) do
    # Column resize handled by client-side JS
    {:noreply, socket}
  end

  def handle_event("reorder_columns", %{"columns" => _column_order}, socket) do
    # Column reorder handled by client-side JS
    {:noreply, socket}
  end

  def handle_event("reset_columns", _params, socket) do
    # Column reset handled by client-side JS
    {:noreply, socket}
  end

  def handle_event("viewport_change", _params, socket) do
    # Viewport change handled by client-side JS
    {:noreply, socket}
  end

  def handle_event("scroll_position", %{"top" => top, "left" => left}, socket) do
    socket = assign(socket, scroll_position: %{top: top, left: left})
    {:noreply, socket}
  end

  def handle_event("virtual_scroll", _params, socket) do
    # Scroll handled by client-side JS
    {:noreply, socket}
  end

  def handle_event("row_height_changed", %{"index" => _index, "height" => _height}, socket) do
    # Row height update handled by client-side JS
    {:noreply, socket}
  end

  def handle_event("viewport_measured", %{"width" => _width, "height" => height}, socket) do
    virtual = Map.get(socket.assigns, :virtual_scroll, %{})
    socket = assign(socket, virtual_scroll: Map.put(virtual, :viewport_height, height))
    {:noreply, socket}
  end

  def handle_event("show_row_details", %{"row-index" => row_index}, socket) do
    index = String.to_integer(row_index)

    # Get results from processed_results if available, otherwise extract from query_results
    {results, aliases} =
      if Map.has_key?(socket.assigns, :processed_results) do
        socket.assigns.processed_results
      else
        case socket.assigns.query_results do
          {results, _columns, aliases} -> {results, aliases}
          _ -> {[], []}
        end
      end

    # Normalize results to maps if needed
    normalized_results =
      if length(results) > 0 and is_list(hd(results)) do
        {_results, columns, _aliases} = socket.assigns.query_results

        Enum.map(results, fn row ->
          Enum.zip(columns, row) |> Map.new()
        end)
      else
        results
      end

    record = Enum.at(normalized_results, index)

    # Send event to parent to show modal
    send(
      self(),
      {:show_detail_modal,
       %{
         record: record,
         current_index: index,
         total_records: length(normalized_results),
         records: normalized_results,
         fields: aliases,
         related_data: build_related_data(record, socket)
       }}
    )

    {:noreply, socket}
  end

  def handle_info({:load_more_data, _end_index}, socket) do
    # This would be implemented by the parent component to load more data
    send(self(), :load_more_virtual_data)
    {:noreply, socket}
  end

  # Helper function to initialize column configuration
  defp init_columns_config(columns) do
    Enum.map(columns, fn col ->
      %{
        id: col,
        visible: true,
        width: "auto",
        locked: false
      }
    end)
  end

  defp parse_page_param(page_value) when is_binary(page_value) do
    case Integer.parse(page_value) do
      {page, ""} -> page
      _ -> 0
    end
  end

  defp parse_page_param(page_value) when is_integer(page_value), do: page_value
  defp parse_page_param(_page_value), do: 0

  defp clamp_page(page, view_meta) do
    requested_page = max(page, 0)
    per_page = max(Map.get(view_meta || %{}, :per_page, 30), 1)
    total_rows = max(Map.get(view_meta || %{}, :total_rows, 0), 0)

    max_page =
      if total_rows > 0 do
        div(total_rows - 1, per_page)
      else
        0
      end

    min(requested_page, max_page)
  end

  # Helper function to build related data configuration
  defp build_related_data(_record, _socket) do
    # This would be configured based on the domain/schema relationships
    # For now, return empty map - parent component can override
    %{}
  end

  @doc """
  JavaScript hooks for row click handling.
  """
  def __hooks__() do
    %{
      "RowClickable" => %{
        mounted: """
        // Add click handlers to all table rows
        this.el.querySelectorAll('tr[phx-click="show_row_details"]').forEach(row => {
          row.style.cursor = 'pointer';
          
          row.addEventListener('mouseenter', () => {
            if (!row.classList.contains('bg-blue-50')) {
              row.dataset.originalBg = row.className;
              row.classList.add('bg-blue-50');
            }
          });
          
          row.addEventListener('mouseleave', () => {
            row.classList.remove('bg-blue-50');
            if (row.dataset.originalBg) {
              row.className = row.dataset.originalBg;
            }
          });
        });
        """,
        updated: """
        // Re-apply handlers after LiveView updates
        this.mounted();
        """
      }
    }
  end

  defp safe_render_component(component_fn, params) do
    try do
      component_fn.(params)
    rescue
      e ->
        error_html = """
        <div class="text-red-600 text-xs p-1 bg-red-50 rounded">
          <div class="font-bold">Component Error:</div>
          <div class="text-xs">#{inspect(e.__struct__)}: #{Exception.message(e)}</div>
          #{if Mix.env() == :dev do
          "<details class='mt-1'>
              <summary class='cursor-pointer text-xs'>Debug Info</summary>
              <div class='text-xs'>Row data: #{inspect(params.row)}</div>
            </details>"
        else
          ""
        end}
        </div>
        """

        Phoenix.HTML.raw(error_html)
    end
  end

  defp safe_render_link(link_parts_fn, row_data) do
    try do
      case link_parts_fn.(row_data) do
        {href, txt} ->
          escaped_txt = txt |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()

          Phoenix.HTML.raw("""
          <a href="#{href}" class="underline font-bold text-blue-500">
            #{escaped_txt}
          </a>
          """)

        _ ->
          row_data
      end
    rescue
      e ->
        error_html = """
        <div class="text-red-600 text-xs p-1 bg-red-50 rounded">
          <div class="font-bold">Link Error:</div>
          <div class="text-xs">#{inspect(e.__struct__)}: #{Exception.message(e)}</div>
        </div>
        """

        Phoenix.HTML.raw(error_html)
    end
  end
end
