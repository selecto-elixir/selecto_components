defmodule SelectoComponents.Views.Detail.Component do
  @doc """
    Display results of a detail view

  """
  import SelectoComponents.Components.Common
  use Phoenix.LiveComponent
  use Phoenix.HTML

  def render(assigns) do
    ### Todo Deal with page changes without executing again.......
    {results, fields, aliases} = assigns.query_results #|> IO.inspect()
    #IO.puts("RENDER!")
    #IO.inspect(assigns.view_meta, label: "VIEW META")

    selected = Map.get(assigns.selecto.set, :columns, [])

    selected =
      Enum.map(selected, fn
        {a, f} = sel ->
          {sel, assigns.selecto.config.columns[f]}

        f ->
          {f, assigns.selecto.config.columns[f]}
      end)

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
        column_uuids: Map.get(assigns.selecto.set, :columns, []) |> Enum.map( fn c -> c["uuid"] end ),
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

      <table class="min-w-full overflow-hidden divide-y ring-1 ring-gray-200 dark:ring-0 divide-gray-200 rounded-sm table-auto dark:divide-y-0 dark:divide-gray-800 sm:rounded">

        <tr>
          <th class="px-6 py-3 text-xs font-medium tracking-wider text-left text-gray-700 uppercase bg-gray-50 dark:bg-gray-600 dark:text-gray-300">#</th>
          <th :for={ r <- @aliases} class="px-6 py-3 text-xs font-medium tracking-wider text-left text-gray-700 uppercase bg-gray-50 dark:bg-gray-600 dark:text-gray-300">
            <%= r %>
          </th>
        </tr>

        <%!--  --%>
        <tr :for={{resrow, i} <- Enum.slice(Enum.with_index(@results), @show_start, @view_meta.per_page)}
          class="border-b dark:border-gray-700 bg-white even:bg-gray-100 dark:bg-gray-700 dark:even:bg-gray-800 last:border-none text-sm text-gray-500 dark:text-gray-400 align-top">
          <%= with row_data <- Enum.zip( @column_uuids, resrow ) |> Enum.into(%{}) do %>
            <td class="px-1 py-1">
              <%= i + 1 %>
            </td>
            <%!--  --%>
            <td :for={ {alias, col_conf}<- Enum.zip( @column_uuids, @columns )}
              class="px-1 py-1">
              <%= with def <- @selecto.config.columns[col_conf["field"]] do %>
                <%= case def do %>

                  <%= %{format: :component} = def -> %>
                    <%= def.component.(%{row: row_data[col_conf["uuid"]], config: col_conf}) %>

                  <%= %{format: :link} = def -> %>
                    <%= with {href, txt} <- def.link_parts.(row_data[col_conf["uuid"]])  do %>
                      <.link href={href} class="underline font-bold text-blue-500">
                        <%= txt %>
                      </.link>
                    <% end %>

                  <% _ -> %>
                    <%= row_data[col_conf["uuid"]] %>

                <%= end %>
              <%= end %>
            </td>
          <% end %>
        </tr>
      </table>
    </div>
    """
  end

  def handle_event("set_page", params, socket) do
    #send(self(), {:set_detail_page, params["page"]})
    socket = assign(socket, view_meta: %{ socket.assigns.view_meta | page: String.to_integer(params["page"]) })

    {:noreply, socket}
  end
end
