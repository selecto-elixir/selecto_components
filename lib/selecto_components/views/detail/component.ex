defmodule SelectoComponents.Views.Detail.Component do
  @doc """
    Display results of a detail view

  """
  import SelectoComponents.Components.Common
  import SelectoComponents.Components.NestedTable
  import SelectoComponents.Components.SqlDebug
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

    page = assigns.view_meta.page
    per_page = assigns.view_meta.per_page
    show_start = page * per_page
    page_count = Float.ceil(Enum.count(results) / per_page)

    ### Use Selecto columns rather than aliases because a column can lead to more than one selection...

    assigns =
      assign(assigns,
        aliases: aliases,
        show_start: show_start,
        results: results,
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
          <th :for={ r <- @aliases} class="px-6 py-3 text-xs font-medium tracking-wider text-left text-gray-700 uppercase bg-gray-50  ">
            <%= r %>
          </th>
        </tr>

        <%!--  --%>
        <%= for {resrow, i} <- Enum.slice(Enum.with_index(@results), @show_start, @view_meta.per_page) do %>
          <tr class="border-b  bg-white even:bg-gray-100   last:border-none text-sm text-gray-500  align-top">
            <% resrow_list = if is_tuple(resrow), do: Tuple.to_list(resrow), else: List.wrap(resrow) %>
            <%= with row_data <- Enum.zip( @column_uuids, resrow_list ) |> Enum.into(%{}) do %>
              <td class="px-1 py-1">
                <%= i + 1 %>
              </td>
              <%!--  --%>
              <td :for={ {_, col_conf}<- Enum.zip( @column_uuids, @columns )}
                class="px-1 py-1">
                <%= with def <- Selecto.columns(@selecto)[col_conf["field"]] do %>
                  <%= case def do %>

                    <% %{format: :component} = def -> %>
                      <%= def.component.(%{row: row_data[col_conf["uuid"]], config: col_conf}) %>

                    <% %{format: :link} = def -> %>
                      <%= with {href, txt} <- def.link_parts.(row_data[col_conf["uuid"]])  do %>
                        <.link href={href} class="underline font-bold text-blue-500">
                          <%= txt %>
                        </.link>
                      <% end %>

                    <% _ -> %>
                      <%= row_data[col_conf["uuid"]] %>

                  <% end %>
                <% end %>
              </td>
            <% end %>
          </tr>
          <%= if Map.get(@view_meta, :subselect_configs, []) != [] do %>
            <tr class="border-b bg-gray-50">
              <td colspan={length(@aliases) + 1} class="p-2">
                <% # We need to find which position in resrow_list contains the subselect data %>
                <% # The subselect data should be in the position corresponding to the "film" column %>
                <% {_results, columns_from_query, _aliases} = @query_results %>
                <% row_map = Enum.zip(columns_from_query, resrow_list) |> Map.new() %>
                
                <%= for config <- Map.get(@view_meta, :subselect_configs, []) do %>
                  <% # The data should be under the key that matches the subselect alias %>
                  <% data = Map.get(row_map, config.key, []) %>
                  
                  <.nested_table
                    data={data}
                    config={config}
                    row_id={"row_#{i}_#{config.key}"}
                    expanded={false}
                  />
                <% end %>
              </td>
            </tr>
          <% end %>
        <% end %>
      </table>
    </div>
    """
  end

  def handle_event("set_page", params, socket) do
    # send(self(), {:set_detail_page, params["page"]})
    socket =
      assign(socket,
        view_meta: %{socket.assigns.view_meta | page: String.to_integer(params["page"])}
      )

    {:noreply, socket}
  end
end
