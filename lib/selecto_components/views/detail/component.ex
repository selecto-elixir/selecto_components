defmodule SelectoComponents.Views.Detail.Component do
  @doc """
    Display results of a detail view

  """
  import SelectoComponents.Components.Common
  import SelectoComponents.Components.NestedTable
  import SelectoComponents.Components.SqlDebug
  alias SelectoComponents.EnhancedTable.Sorting
  alias SelectoComponents.EnhancedTable.ColumnManager
  alias SelectoComponents.EnhancedTable.ResponsiveWrapper
  alias SelectoComponents.EnhancedTable.Virtualization
  use Phoenix.LiveComponent

  def mount(socket) do
    # Initialize column configuration
    columns = []  # Will be populated in update/2
    socket = 
      socket
      |> assign(:columns_config, init_columns_config(columns))
    {:ok, socket}
  end

  def update(assigns, socket) do
    # Extract columns from selecto if available
    columns = if Map.has_key?(assigns, :selecto) do
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
    ### Todo Deal with page changes without executing again.......
    
    # Check for execution error first
    if Map.get(assigns, :execution_error) do
      # Display the actual error message
      ~H"""
      <div>
        <%= if @execution_error do %>
          <div class="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded relative mb-4" role="alert">
            <strong class="font-bold">Query Error:</strong>
            <span class="block sm:inline">
              <%= case @execution_error do %>
                <% %{message: msg} -> %>
                  <%= msg %>
                <% error when is_binary(error) -> %>
                  <%= error %>
                <% error -> %>
                  <%= inspect(error) %>
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
    normalized_results = if length(results) > 0 and is_list(hd(results)) do
      {_results, columns, _aliases} = assigns.query_results
      Enum.map(results, fn row ->
        Enum.zip(columns, row) |> Map.new()
      end)
    else
      results
    end

    page = assigns.view_meta.page
    per_page = assigns.view_meta.per_page
    show_start = page * per_page
    page_count = Float.ceil(Enum.count(normalized_results) / per_page)

    ### Use Selecto columns rather than aliases because a column can lead to more than one selection...

    assigns =
      assign(assigns,
        aliases: aliases,
        show_start: show_start,
        results: normalized_results,
        columns: Map.get(assigns.selecto.set, :columns, []),
        column_uuids:
          Map.get(assigns.selecto.set, :columns, []) |> Enum.map(fn c -> c["uuid"] end),
        max_pages: page_count
      )

    ~H"""
    <div>
      <.sql_debug 
        :if={Map.get(assigns, :sql)}
        sql={Map.get(assigns, :sql)}
        params={Map.get(assigns, :sql_params, [])}
        execution_time={Map.get(assigns, :execution_time)}
      />
      
      <div class="flex justify-center">
        <div class="inline-block w-36">
          <.sc_button :if={@view_meta.page > 0} type="button" phx-click="set_page" phx-value-page={@view_meta.page - 1} phx-target={@myself}>
            <svg class="w-8 h-8 inline" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" width="100%" height="100%">
              <path stroke-linecap="round" stroke-linejoin="round" d="M21 16.811c0 .864-.933 1.406-1.683.977l-7.108-4.061a1.125 1.125 0 0 1 0-1.954l7.108-4.061A1.125 1.125 0 0 1 21 8.689v8.122ZM11.25 16.811c0 .864-.933 1.406-1.683.977l-7.108-4.061a1.125 1.125 0 0 1 0-1.954l7.108-4.061a1.125 1.125 0 0 1 1.683.977v8.122Z" />
            </svg>
            Prev Page
          </.sc_button>
        </div>
        <div class="inline-block px-4 py-2 align-bottom">
          <%= Enum.count(@results) %> Rows Found
        </div>
        <div class="inline-block w-36">
          <.sc_button :if={@view_meta.page < @max_pages} type="button" phx-click="set_page" phx-value-page={@view_meta.page + 1} phx-target={@myself}>
            Next Page
            <svg class="w-8 h-8 inline" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" width="100%" height="100%">
              <path stroke-linecap="round" stroke-linejoin="round" d="M3 8.689c0-.864.933-1.406 1.683-.977l7.108 4.061a1.125 1.125 0 0 1 0 1.954l-7.108 4.061A1.125 1.125 0 0 1 3 16.811V8.69ZM12.75 8.689c0-.864.933-1.406 1.683-.977l7.108 4.061a1.125 1.125 0 0 1 0 1.954l-7.108 4.061a1.125 1.125 0 0 1-1.683-.977V8.69Z" />
            </svg>
          </.sc_button>
        </div>
      </div>

      <div class="responsive-table-wrapper overflow-x-auto" id={"detail-table-wrapper-#{@myself}"} phx-hook="RowClickable">
        <table class="min-w-full overflow-hidden divide-y ring-1 ring-gray-200  divide-gray-200 rounded-sm table-auto   sm:rounded">
        <thead>
        <tr>
          <th class="px-2 py-3 text-xs font-medium tracking-wider text-center text-gray-700 uppercase bg-gray-50 w-12 max-w-12 min-w-12">#</th>
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
                <%= Map.get(config, :title, config.key) %>
              </th>
            <% end %>
          <% end %>
        </tr>
        </thead>
        <tbody>
        <%!--  --%>
        <%= for {{resrow, actual_idx}, display_idx} <- Enum.slice(Enum.with_index(@results), @show_start, @view_meta.per_page) |> Enum.with_index() do %>
          <% # Process row data once at the beginning of the iteration %>
          <% resrow_list = cond do
            is_tuple(resrow) -> Tuple.to_list(resrow)
            is_list(resrow) -> resrow
            is_map(resrow) -> 
              # If it's already a map, extract values in column order
              {_results, columns_from_query, _aliases} = @query_results
              Enum.map(columns_from_query, fn col -> Map.get(resrow, col) end)
            true -> [resrow]
          end %>
          <% row_data_by_uuid = Enum.zip(@column_uuids, resrow_list) |> Enum.into(%{}) %>
          <% # Also create a map by column name for subselects %>
          <% {_results, columns_from_query, _aliases} = @query_results %>
          <% row_data_by_column = Enum.zip(columns_from_query, resrow_list) |> Map.new() %>
          
          <tr 
            class="border-b  bg-white even:bg-gray-100   last:border-none text-sm text-gray-500  align-top hover:bg-blue-50 cursor-pointer"
            phx-click="show_row_details"
            phx-value-row-index={actual_idx}
            phx-target={@myself}
          >
            <td class="px-2 py-1 text-center w-12 max-w-12 min-w-12">
              <%= actual_idx + 1 %>
            </td>
            <%!-- Display regular columns --%>
            <td :for={ {_, col_conf}<- Enum.zip( @column_uuids, @columns )}
              class="px-1 py-1 align-top">
              <% def = Selecto.columns(@selecto)[col_conf["field"]] %>
              <%= case def do %>

                <% %{format: :component} = def -> %>
                    <%=
                      safe_render_component(def.component, %{
                        row: row_data_by_uuid[col_conf["uuid"]],
                        config: col_conf
                      })
                    %>

                  <% %{format: :link} = def -> %>
                    <%=
                      safe_render_link(def.link_parts, row_data_by_uuid[col_conf["uuid"]])
                    %>

                  <% _ -> %>
                    <%= row_data_by_uuid[col_conf["uuid"]] %>

              <% end %>
            </td>
            
            <%!-- Add subselect columns inline --%>
            <%= if Map.get(@view_meta, :subselect_configs, []) != [] do %>
              <%= for config <- Map.get(@view_meta, :subselect_configs, []) do %>
                <% data = Map.get(row_data_by_column, config.key, []) %>
                <% # Use actual_idx to ensure unique IDs %>
                <% unique_id = "page#{@view_meta.page}_idx#{actual_idx}_#{config.key}" %>
                <td class="px-1 py-1 align-top" id={"cell_#{unique_id}"}>
                  <% # Parse the data here to ensure it's fresh %>
                  <% parsed_data = SelectoComponents.Components.NestedTable.parse_subselect_data(data) %>
                  <div id={"nested_#{unique_id}"}>
                    <%= if length(parsed_data) > 0 do %>
                      <table class="min-w-full border border-gray-300 rounded">
                        <thead>
                          <tr class="bg-gray-100">
                            <%= for key <- SelectoComponents.Components.NestedTable.get_data_keys(parsed_data) do %>
                              <th class="px-2 py-1 text-xs font-medium text-gray-700 border-b border-gray-200">
                                <%= SelectoComponents.Components.NestedTable.humanize_key(key) %>
                              </th>
                            <% end %>
                          </tr>
                        </thead>
                        <tbody>
                          <%= for {item, _idx} <- Enum.with_index(parsed_data) do %>
                            <tr class="border-b border-gray-200 last:border-b-0 hover:bg-gray-50">
                              <%= for key <- SelectoComponents.Components.NestedTable.get_data_keys(parsed_data) do %>
                                <td class="px-2 py-1 text-xs text-gray-700">
                                  <%= SelectoComponents.Components.NestedTable.format_value(Map.get(item, key, "")) %>
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
    # send(self(), {:set_detail_page, params["page"]})
    new_page = String.to_integer(params["page"])
    
    socket =
      assign(socket,
        view_meta: %{socket.assigns.view_meta | page: new_page}
      )

    {:noreply, socket}
  end

  def handle_event("resize_column", %{"column_id" => column_id, "width" => width}, socket) do
    new_width = String.to_integer(width)
    # Column resize handled by client-side JS
    {:noreply, socket}
  end

  def handle_event("reorder_columns", %{"columns" => column_order}, socket) do
    # Get current columns to reset with new order
    columns = socket.assigns[:columns] || []
    # Column reorder handled by client-side JS
    {:noreply, socket}
  end

  def handle_event("reset_columns", _params, socket) do
    # Get initial columns to reset
    columns = if Map.has_key?(socket.assigns, :selecto) do
      Map.get(socket.assigns.selecto.set, :columns, [])
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
    # Column reset
    {:noreply, socket}
  end

  def handle_event("viewport_change", params, socket) do
    # Viewport change handled by client-side JS
    {:noreply, socket}
  end

  def handle_event("scroll_position", %{"top" => top, "left" => left}, socket) do
    socket = assign(socket, scroll_position: %{top: top, left: left})
    {:noreply, socket}
  end

  def handle_event("virtual_scroll", params, socket) do
    # Scroll handled by client-side JS
    {:noreply, socket}
  end

  def handle_event("row_height_changed", %{"index" => index, "height" => height}, socket) do
    # Row height update handled by client-side JS
    {:noreply, socket}
  end

  def handle_event("viewport_measured", %{"width" => _width, "height" => height}, socket) do
    virtual = Map.get(socket.assigns, :virtual_scroll, %{})
    socket = assign(socket, virtual_scroll: Map.put(virtual, :viewport_height, height))
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
  
  def handle_event("show_row_details", %{"row-index" => row_index}, socket) do
    index = String.to_integer(row_index)

    # Get results from processed_results if available, otherwise extract from query_results
    {results, aliases} = if Map.has_key?(socket.assigns, :processed_results) do
      socket.assigns.processed_results
    else
      case socket.assigns.query_results do
        {results, _columns, aliases} -> {results, aliases}
        _ -> {[], []}
      end
    end

    # Normalize results to maps if needed
    normalized_results = if length(results) > 0 and is_list(hd(results)) do
      {_results, columns, _aliases} = socket.assigns.query_results
      Enum.map(results, fn row ->
        Enum.zip(columns, row) |> Map.new()
      end)
    else
      results
    end

    record = Enum.at(normalized_results, index)

    # Send event to parent to show modal
    send(self(), {:show_detail_modal, %{
      record: record,
      current_index: index,
      total_records: length(normalized_results),
      records: normalized_results,
      fields: aliases,
      related_data: build_related_data(record, socket)
    }})

    {:noreply, socket}
  end
  
  def handle_info({:load_more_data, _end_index}, socket) do
    # This would be implemented by the parent component to load more data
    send(self(), :load_more_virtual_data)
    {:noreply, socket}
  end
  
  # Helper function to build related data configuration
  defp build_related_data(record, socket) do
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
          Phoenix.HTML.raw("""
          <a href="#{href}" class="underline font-bold text-blue-500">
            #{Phoenix.HTML.html_escape(txt)}
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
