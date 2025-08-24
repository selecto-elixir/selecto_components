defmodule SelectoComponents.Views.Detail.Component do
  @doc """
    Display results of a detail view

  """
  import SelectoComponents.Components.Common
  use Phoenix.LiveComponent

  def render(assigns) do
    ### Todo Deal with page changes without executing again.......
    # |> IO.inspect()
    
    require Logger
    Logger.debug("=== DETAIL RENDER ===\nExecuted: #{inspect(assigns[:executed])}\nQuery results present: #{inspect(assigns.query_results != nil)}")
    
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
      <div class="flex justify-center">
        <div class="inline-block w-36">
          <.sc_button :if={@view_meta.page > 0} type="button" phx-click="set_page" phx-value-page={@view_meta.page - 1} phx-target={@myself}>
            <Heroicons.backward class="w-6 h-6 inline"/>
            Prev Page
          </.sc_button>
        </div>
        <div class="inline-block px-4 py-2 align-bottom">
          <%= Enum.count(@results) %> Rows Found
        </div>
        <div class="inline-block w-36">
          <.sc_button :if={@view_meta.page < @max_pages} type="button" phx-click="set_page" phx-value-page={@view_meta.page + 1} phx-target={@myself}>
            Next Page
            <Heroicons.forward class="w-6 h-6 inline"/>
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
        <tr :for={{resrow, i} <- Enum.slice(Enum.with_index(@results), @show_start, @view_meta.per_page)}
          class="border-b  bg-white even:bg-gray-100   last:border-none text-sm text-gray-500  align-top">
          <%= with row_data <- Enum.zip( @column_uuids, resrow ) |> Enum.into(%{}) do %>
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
