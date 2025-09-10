defmodule SelectoComponents.Views.Detail.Component do
  @doc """
    Display results of a detail view

  """
  import SelectoComponents.Components.Common
  import SelectoComponents.Components.NestedTable
  import SelectoComponents.Components.SqlDebug
  alias SelectoComponents.EnhancedTable.Sorting
  use Phoenix.LiveComponent

  def render(assigns) do
    ### Todo Deal with page changes without executing again.......
    # |> IO.inspect()
    
    # Check for execution error first
    if Map.get(assigns, :execution_error) do
      # Error is already displayed by the form component wrapper
      # Just show a message that view cannot be rendered
      ~H"""
      <div>
        <div class="text-gray-500 italic p-4">
          View cannot be displayed due to query error. Please check the error message above.
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
    # IO.puts("RENDER!")
    # IO.inspect(assigns.view_meta, label: "VIEW META")
    
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

      <table class="min-w-full overflow-hidden divide-y ring-1 ring-gray-200  divide-gray-200 rounded-sm table-auto   sm:rounded">

        <tr>
          <th class="px-6 py-3 text-xs font-medium tracking-wider text-left text-gray-700 uppercase bg-gray-50  ">#</th>
          <%= for {alias, idx} <- Enum.with_index(@aliases) do %>
            <% column_field = Enum.at(@columns, idx)["field"] %>
            <Sorting.sortable_header 
              column={column_field}
              label={alias}
              sort_by={assigns[:sort_by] || []}
              multi={false}
              target={@myself}
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
          
          <tr class="border-b  bg-white even:bg-gray-100   last:border-none text-sm text-gray-500  align-top">
            <td class="px-1 py-1">
              <%= actual_idx + 1 %>
            </td>
            <%!-- Display regular columns --%>
            <td :for={ {_, col_conf}<- Enum.zip( @column_uuids, @columns )}
              class="px-1 py-1 align-top">
              <%= with def <- Selecto.columns(@selecto)[col_conf["field"]] do %>
                <%= case def do %>

                  <% %{format: :component} = def -> %>
                    <%= def.component.(%{row: row_data_by_uuid[col_conf["uuid"]], config: col_conf}) %>

                  <% %{format: :link} = def -> %>
                    <%= with {href, txt} <- def.link_parts.(row_data_by_uuid[col_conf["uuid"]])  do %>
                      <.link href={href} class="underline font-bold text-blue-500">
                        <%= txt %>
                      </.link>
                    <% end %>

                  <% _ -> %>
                    <%= row_data_by_uuid[col_conf["uuid"]] %>

                <% end %>
              <% end %>
            </td>
            
            <%!-- Add subselect columns inline --%>
            <%= if Map.get(@view_meta, :subselect_configs, []) != [] do %>
              <% IO.puts("[NESTED TABLE DEBUG] Subselect configs found: #{inspect(Map.get(@view_meta, :subselect_configs, []))}") %>
              <%= for config <- Map.get(@view_meta, :subselect_configs, []) do %>
                <% IO.puts("[NESTED TABLE DEBUG] Processing config for key: #{config.key}") %>
                <% IO.puts("[NESTED TABLE DEBUG] Available columns in row: #{inspect(Map.keys(row_data_by_column))}") %>
                <% data = Map.get(row_data_by_column, config.key, []) %>
                <% IO.puts("[NESTED TABLE DEBUG] Raw data for #{config.key}: #{inspect(data)}") %>
                <% # Use actual_idx to ensure unique IDs %>
                <% unique_id = "page#{@view_meta.page}_idx#{actual_idx}_#{config.key}" %>
                <td class="px-1 py-1 align-top" id={"cell_#{unique_id}"}>
                  <% # Parse the data here to ensure it's fresh %>
                  <% parsed_data = SelectoComponents.Components.NestedTable.parse_subselect_data(data) %>
                  <% IO.puts("[NESTED TABLE DEBUG] Parsed data for #{config.key}: #{inspect(parsed_data)}") %>
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
      </table>
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
end
