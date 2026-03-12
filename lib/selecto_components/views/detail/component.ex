defmodule SelectoComponents.Views.Detail.Component do
  @doc """
    Display results of a detail view

  """
  import SelectoComponents.Components.SqlDebug
  alias SelectoComponents.EnhancedTable.Sorting
  alias SelectoComponents.Views.Detail.RowActions
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

    # Keep detail rows positional to avoid duplicate-name map collisions.
    normalized_results =
      if length(results) > 0 and (is_list(hd(results)) or is_tuple(hd(results))) do
        Enum.map(results, fn row ->
          if is_tuple(row), do: Tuple.to_list(row), else: row
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
        visible_aliases: visible_aliases(Map.get(assigns.selecto.set, :columns, [])),
        results: normalized_results,
        total_rows: total_rows,
        row_offset: row_offset,
        current_page: current_page,
        page_start: page_start,
        page_end: page_end,
        total_pages: total_pages,
        columns: Map.get(assigns.selecto.set, :columns, []),
        row_action_query_columns:
          Map.get(
            assigns.selecto.set,
            :row_action_query_columns,
            Map.get(assigns.selecto.set, :columns, [])
          ),
        column_uuids:
          Map.get(assigns.selecto.set, :columns, []) |> Enum.map(fn c -> c["uuid"] end),
        max_page: max_page
      )

    row_action =
      resolve_current_row_action(
        assigns.selecto,
        assigns.view_meta,
        assigns[:enable_modal_detail]
      )

    row_action_missing_fields =
      RowActions.missing_required_fields(row_action, assigns.row_action_query_columns)

    assigns =
      assign(assigns,
        row_action: row_action,
        row_action_missing_fields: row_action_missing_fields
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
              <%= for {alias, idx} <- Enum.with_index(@visible_aliases) do %>
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
                    # If it's already a map, extract values in column order.
                    # Fall back to alias at the same position to avoid collisions
                    # from duplicate DB column names.
                    {_results, columns_from_query, aliases_from_query} = @query_results

                    columns_from_query
                    |> Enum.with_index()
                    |> Enum.map(fn {col, idx} ->
                      map_get_flexible(resrow, Enum.at(aliases_from_query, idx)) ||
                        map_get_flexible(resrow, col)
                    end)

                  true ->
                    [resrow]
                end %>
              <% row_data_by_uuid = Enum.zip(@column_uuids, resrow_list) |> Enum.into(%{}) %>
              <% # Also create a map by column name for subselects %>
              <% {_results, columns_from_query, aliases_from_query} = @query_results %>
              <% row_data_by_column = Enum.zip(columns_from_query, resrow_list) |> Map.new() %>
              <% absolute_idx = @row_offset + display_idx %>
              <% row_action_context =
                build_row_action_context(
                  resrow,
                  resrow_list,
                  @row_action_query_columns,
                  columns_from_query,
                  aliases_from_query
                ) %>
              <% resolved_row_link =
                if @row_action && @row_action.type == :external_link && @row_action_missing_fields == [] do
                  @row_action
                  |> RowActions.resolve_external_link(row_action_context)
                  |> sanitize_row_link()
                else
                  nil
                end %>
              <% row_action_type =
                cond do
                  @row_action_missing_fields != [] ->
                    "none"

                  @row_action && modal_row_action?(@row_action.type) ->
                    "modal"

                  resolved_row_link ->
                    "external_link"

                  true ->
                    "none"
                end %>
              <% row_clickable = row_action_type != "none" %>

              <tr
                class={[
                  "border-b bg-white even:bg-gray-100 last:border-none text-sm text-gray-500 align-top",
                  if(row_clickable, do: "hover:bg-blue-50 cursor-pointer", else: "cursor-default")
                ]}
                data-row-action-type={row_action_type}
                data-row-link={resolved_row_link && resolved_row_link.url}
                data-row-link-target={resolved_row_link && resolved_row_link.target}
                phx-click={if row_action_type == "modal", do: "show_row_details"}
                phx-value-row-index={if row_action_type == "modal", do: display_idx}
                phx-target={if row_action_type == "modal", do: @myself}
              >
                <td class="px-2 py-1 text-center w-12 max-w-12 min-w-12">
                  {absolute_idx + 1}
                </td>
                <%!-- Display regular columns --%>
                <td
                  :for={{col_conf, column_idx} <- Enum.with_index(@columns)}
                  class="px-1 py-1 align-top"
                >
                  <% column_uuid = config_get(col_conf, "uuid") %>
                  <% column_field = config_get(col_conf, "field") %>
                  <% column_alias = config_get(col_conf, "alias") %>
                  <% row_value =
                    case column_uuid do
                      uuid when is_binary(uuid) and uuid != "" ->
                        Map.get(
                          row_data_by_uuid,
                          uuid,
                          map_get_flexible(resrow, column_field) ||
                            map_get_flexible(resrow, column_alias) ||
                            Enum.at(resrow_list, column_idx)
                        )

                      _ ->
                        map_get_flexible(resrow, column_field) ||
                          map_get_flexible(resrow, column_alias) ||
                          Enum.at(resrow_list, column_idx)
                    end %>
                  <% def = Selecto.columns(@selecto)[column_field] %>
                  <%= case def do %>
                    <% %{format: :component} = def -> %>
                      {safe_render_component(def.component, %{
                        row: row_value,
                        config: col_conf
                      })}
                    <% %{format: :link} = def -> %>
                      {safe_render_link(def.link_parts, row_value)}
                    <% _ -> %>
                      {safe_cell_value(row_value)}
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
                                <%= for key <- SelectoComponents.Components.NestedTable.get_data_keys(parsed_data, config) do %>
                                  <th class="px-2 py-1 text-xs font-medium text-gray-700 border-b border-gray-200">
                                    {SelectoComponents.Components.NestedTable.humanize_key(key)}
                                  </th>
                                <% end %>
                              </tr>
                            </thead>
                            <tbody>
                              <%= for {item, _idx} <- Enum.with_index(parsed_data) do %>
                                <tr class="border-b border-gray-200 last:border-b-0 hover:bg-gray-50">
                                  <%= for key <- SelectoComponents.Components.NestedTable.get_data_keys(parsed_data, config) do %>
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
              if (e.target.closest('a, button, input, select, textarea')) {
                return;
              }

              const row = e.target.closest('tr[data-row-action-type="external_link"]');

              if (row) {
                const url = row.dataset.rowLink;
                const target = row.dataset.rowLinkTarget || '_blank';

                if (!url) {
                  return;
                }

                if (target === '_self') {
                  window.location.assign(url);
                  return;
                }

                const opened = window.open(url, target);

                if (opened) {
                  opened.opener = null;
                }
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

  def handle_event("show_row_details", params, socket) do
    row_index = Map.get(params, "row-index", Map.get(params, "row_index", "0"))
    requested_index = row_index |> parse_page_param() |> max(0)

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

    # Keep detail rows positional for rendering, but build modal records as maps.
    normalized_results =
      if length(results) > 0 and (is_list(hd(results)) or is_tuple(hd(results))) do
        Enum.map(results, fn row ->
          if is_tuple(row), do: Tuple.to_list(row), else: row
        end)
      else
        results
      end

    total_records = length(normalized_results)

    row_action =
      resolve_current_row_action(
        socket.assigns.selecto,
        socket.assigns[:view_meta],
        socket.assigns[:enable_modal_detail]
      )

    row_action_missing_fields =
      RowActions.missing_required_fields(
        row_action,
        Map.get(
          socket.assigns.selecto.set,
          :row_action_query_columns,
          Map.get(socket.assigns.selecto.set, :columns, [])
        )
      )

    if total_records == 0 or is_nil(row_action) or not modal_row_action?(row_action.type) or
         row_action_missing_fields != [] do
      {:noreply, socket}
    else
      index = min(requested_index, total_records - 1)
      row = Enum.at(normalized_results, index)

      {_results, columns, aliases_from_query} = socket.assigns.query_results

      display_record = build_display_record(row, columns, aliases_from_query)

      row_context =
        build_row_action_context(
          row,
          normalize_row_values(row, columns, aliases_from_query),
          Map.get(
            socket.assigns.selecto.set,
            :row_action_query_columns,
            Map.get(socket.assigns.selecto.set, :columns, [])
          ),
          columns,
          aliases_from_query
        )

      modal_records =
        Enum.map(normalized_results, &build_display_record(&1, columns, aliases_from_query))

      modal_options = RowActions.resolve_modal_options(row_action, row_context)

      action_specific_data =
        case row_action.type do
          :iframe_modal -> RowActions.resolve_iframe_modal(row_action, row_context) || %{}
          :live_component -> RowActions.resolve_live_component(row_action, row_context) || %{}
          _ -> %{}
        end

      # Send event to parent to show modal
      send(
        self(),
        {:show_detail_modal,
         Map.merge(
           %{
             action_id: row_action.id,
             action_source: Map.get(row_action, :source, :configured),
             action_type: row_action.type,
             record: display_record,
             current_index: index,
             total_records: total_records,
             records: modal_records,
             fields: aliases,
             related_data: build_related_data(display_record, socket),
             title: Map.get(modal_options, :title, row_action.name || "Record Details"),
             title_template: row_action.payload |> config_get("title"),
             subtitle_field: Map.get(modal_options, :subtitle_field),
             size: Map.get(modal_options, :size, :lg),
             navigation_enabled: Map.get(modal_options, :navigation_enabled, true),
             edit_enabled: Map.get(modal_options, :edit_enabled, false)
           },
           action_specific_data
         )}
      )

      {:noreply, socket}
    end
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

  defp resolve_current_row_action(selecto, view_meta, enable_modal_detail) do
    row_click_action = Map.get(view_meta || %{}, :row_click_action)

    RowActions.current_action(selecto, row_click_action,
      legacy_modal_enabled: enable_modal_detail == true
    )
  end

  defp visible_aliases(columns) do
    Enum.map(columns, fn column ->
      config_get(column, "alias") || config_get(column, "field") || ""
    end)
  end

  defp modal_row_action?(action_type)
       when action_type in [:modal, :iframe_modal, :live_component],
       do: true

  defp modal_row_action?(_action_type), do: false

  defp build_display_record(row, columns, aliases) when is_list(row) do
    build_modal_record(row, columns, aliases)
  end

  defp build_display_record(%{} = row_map, _columns, _aliases), do: row_map

  defp build_display_record(row_tuple, columns, aliases) when is_tuple(row_tuple) do
    row_tuple
    |> Tuple.to_list()
    |> build_modal_record(columns, aliases)
  end

  defp build_display_record(_row, _columns, _aliases), do: %{}

  defp normalize_row_values(row, _columns, _aliases) when is_list(row), do: row

  defp normalize_row_values(row_tuple, columns, aliases) when is_tuple(row_tuple) do
    normalize_row_values(Tuple.to_list(row_tuple), columns, aliases)
  end

  defp normalize_row_values(%{} = row_map, columns, aliases) do
    columns
    |> Enum.with_index()
    |> Enum.map(fn {column, idx} ->
      map_get_flexible(row_map, Enum.at(aliases, idx)) || map_get_flexible(row_map, column)
    end)
  end

  defp normalize_row_values(_row, _columns, _aliases), do: []

  defp build_row_action_context(
         row,
         row_values,
         selected_columns,
         columns_from_query,
         aliases_from_query
       ) do
    %{
      display_record: build_display_record(row, columns_from_query, aliases_from_query),
      field_values:
        build_row_field_values(
          row,
          row_values,
          selected_columns,
          columns_from_query,
          aliases_from_query
        )
    }
  end

  defp build_row_field_values(
         row,
         row_values,
         selected_columns,
         columns_from_query,
         aliases_from_query
       ) do
    selected_columns
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {column_config, idx}, acc ->
      case config_get(column_config, "field") do
        field when is_binary(field) and field != "" ->
          value =
            resolve_field_value(
              row,
              row_values,
              idx,
              field,
              Enum.at(columns_from_query, idx),
              Enum.at(aliases_from_query, idx)
            )

          Map.put(acc, field, value)

        _ ->
          acc
      end
    end)
  end

  defp resolve_field_value(%{} = row_map, row_values, idx, field, column_name, alias_name) do
    map_get_flexible(row_map, field) ||
      map_get_flexible(row_map, alias_name) ||
      map_get_flexible(row_map, column_name) ||
      Enum.at(row_values, idx)
  end

  defp resolve_field_value(_row, row_values, idx, _field, _column_name, _alias_name) do
    Enum.at(row_values, idx)
  end

  defp sanitize_row_link(nil), do: nil

  defp sanitize_row_link(%{url: url, target: target}) do
    case sanitize_href(url) do
      nil -> nil
      safe_url -> %{url: safe_url, target: target}
    end
  end

  defp build_modal_record(row, columns, aliases) when is_list(row) do
    row
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {value, idx}, acc ->
      alias_key = Enum.at(aliases, idx)
      column_key = Enum.at(columns, idx)
      base_key = if is_binary(alias_key) and alias_key != "", do: alias_key, else: column_key
      key = dedupe_modal_key(base_key, acc, idx)
      Map.put(acc, key, value)
    end)
  end

  defp dedupe_modal_key(base_key, acc, _idx) when is_binary(base_key) and base_key != "" do
    if Map.has_key?(acc, base_key), do: next_dedup_key(base_key, acc, 2), else: base_key
  end

  defp dedupe_modal_key(base_key, _acc, _idx) when is_atom(base_key), do: Atom.to_string(base_key)
  defp dedupe_modal_key(_base_key, _acc, idx), do: "field_#{idx}"

  defp next_dedup_key(base_key, acc, suffix) do
    candidate = "#{base_key}_#{suffix}"

    if Map.has_key?(acc, candidate),
      do: next_dedup_key(base_key, acc, suffix + 1),
      else: candidate
  end

  defp map_get_flexible(map, key) when is_map(map) do
    if is_nil(key) do
      nil
    else
      direct_value = Map.get(map, key)

      if is_nil(direct_value) do
        fallback_value(map, key)
      else
        direct_value
      end
    end
  end

  defp map_get_flexible(_map, _key), do: nil

  defp fallback_value(map, key) when is_atom(key), do: Map.get(map, Atom.to_string(key))

  defp fallback_value(map, key) when is_binary(key) do
    atom_key =
      try do
        String.to_existing_atom(key)
      rescue
        ArgumentError -> nil
      end

    atom_value = if atom_key, do: Map.get(map, atom_key), else: nil

    if is_nil(atom_value) do
      Enum.find_value(map, fn
        {candidate_key, value} when is_atom(candidate_key) ->
          if Atom.to_string(candidate_key) == key, do: value

        {candidate_key, value} when is_binary(candidate_key) ->
          if candidate_key == key, do: value

        _ ->
          nil
      end)
    else
      atom_value
    end
  end

  defp fallback_value(_map, _key), do: nil

  defp config_get(config, key) when is_map(config) and is_binary(key) do
    Map.get(config, key) || fallback_value(config, key)
  end

  defp config_get(config, key) when is_list(config) and is_binary(key) do
    case {key, config} do
      {"uuid", [uuid | _]} ->
        to_string(uuid)

      {"field", [_uuid, field | _]} ->
        to_string(field)

      {"alias", [_uuid, _field, conf]} when is_map(conf) ->
        Map.get(conf, "alias") || Map.get(conf, :alias)

      _ ->
        nil
    end
  end

  defp config_get(_config, _key), do: nil

  defp safe_cell_value(value) do
    if Phoenix.HTML.Safe.impl_for(value) do
      value
    else
      case value do
        nil -> ""
        value when is_atom(value) -> Atom.to_string(value)
        _ -> inspect(value)
      end
    end
  end

  defp safe_render_component(component_fn, params) do
    try do
      component_fn.(params)
    rescue
      e ->
        base = "Component Error: #{inspect(e.__struct__)}: #{Exception.message(e)}"

        if Mix.env() == :dev do
          "#{base} (Row data: #{inspect(params[:row])})"
        else
          base
        end
    end
  end

  defp safe_render_link(link_parts_fn, row_data) do
    try do
      case link_parts_fn.(row_data) do
        {href, txt} ->
          text = link_text_value(txt)

          case sanitize_href(href) do
            nil ->
              text

            safe_href ->
              safe_link_html(text, safe_href)
          end

        _ ->
          safe_cell_value(row_data)
      end
    rescue
      e ->
        "Link Error: #{inspect(e.__struct__)}: #{Exception.message(e)}"
    end
  end

  defp sanitize_href(href) when is_binary(href) do
    trimmed = String.trim(href)
    lower = String.downcase(trimmed)
    uri = URI.parse(trimmed)

    cond do
      trimmed == "" ->
        nil

      String.contains?(trimmed, <<0>>) ->
        nil

      uri.scheme in ["http", "https"] ->
        trimmed

      is_nil(uri.scheme) and not String.starts_with?(trimmed, "//") and
          not String.starts_with?(lower, ["javascript:", "data:", "vbscript:"]) ->
        trimmed

      true ->
        nil
    end
  end

  defp sanitize_href(_href), do: nil

  defp safe_link_html(text, href) when is_binary(text) and is_binary(href) do
    escaped_text = text |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
    escaped_href = href |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()

    {:safe,
     [
       "<a href=\"",
       escaped_href,
       "\" class=\"underline font-bold text-blue-500\">",
       escaped_text,
       "</a>"
     ]}
  end

  defp link_text_value(nil), do: ""
  defp link_text_value(value) when is_binary(value), do: value
  defp link_text_value(value) when is_atom(value), do: Atom.to_string(value)

  defp link_text_value(value) do
    to_string(value)
  rescue
    _ -> inspect(value)
  end
end
