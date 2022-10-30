defmodule SelectoComponents.Components.AggregateTable do
  @doc """
    display results of aggregate view
  """
  use Phoenix.LiveComponent

  def render(assigns) do
    {results, aliases} = Selecto.execute(assigns.selecto)

    group_by = assigns.selecto.set.group_by
    aggregates = assigns.selecto.set.selected -- group_by

    IO.inspect(group_by, label: "Group By")
    group_by =
      Enum.map(
        group_by,
        fn
          {:extract, f, fmt} = g ->
            {:group_by, g, assigns.selecto.config.columns[f]}

          {a, f} = g ->
            {:group_by, g, assigns.selecto.config.columns[f]}
          g ->
            {:group_by, g, assigns.selecto.config.columns[g]}
        end
      )

    aggregates =
      Enum.map(aggregates, fn
        {:extract, f, fmt} = agg ->
          {:agg, agg, assigns.selecto.config.columns[f]}

        {a, f} = agg ->
          {:agg, agg, assigns.selecto.config.columns[f]}
      end)

    fmap = Enum.zip(aliases, group_by ++ aggregates) |> Enum.into(%{})

    assigns =
      assign(assigns,
        results: results,
        aliases: aliases,
        group_by: group_by,
        aggregate: aggregates,
        fmap: fmap
      )

    ~H"""
    <div>
      <table class="min-w-full overflow-hidden divide-y ring-1 ring-gray-200 dark:ring-0 divide-gray-200 rounded-sm table-auto dark:divide-y-0 dark:divide-gray-800 sm:rounded">
        <tr>

          <th :for={{:group_by, g, def} <- @group_by} class="font-bold px-6 py-3 text-xs font-medium tracking-wider text-left text-gray-700 uppercase bg-gray-50 dark:bg-gray-600 dark:text-gray-300">
            <%= case g do %>
            <%= {:extract, f, fmt} -> %>
              <%= fmt %>: <%= def.name %>
            <% {a, f} -> %>
              <%= a %>: <%= f %>
            <% f -> %>
              <%= inspect(f) %>
            <% end %>
          </th>

          <th :for={r <- @aggregate} class="px-6 py-3 text-xs font-medium tracking-wider text-left text-gray-700 uppercase bg-gray-50 dark:bg-gray-600 dark:text-gray-300">
            <%= case r do %>
            <% {:agg, {a, f}, def} -> %>
              <%= a %>: <%= f %>
            <% f -> %>
              <%= inspect(f) %>
            <% end %>
          </th>
        </tr>

        <tr :for={r <- @results} class="border-b dark:border-gray-700 bg-white even:bg-white dark:bg-gray-700 dark:even:bg-gray-800 last:border-none">
          <td :for={c <- @aliases} class="px-6 py-4 text-sm text-gray-500 dark:text-gray-400">
            <%= with def <- @fmap[c] do %>
              <%= case def do %>
                <% {:group_by, g, def} -> %>
                  GROUP <%= r[c] %>

                <% {:agg, {func, _field}, %{format: fmt_fun} = def} when is_function(fmt_fun) -> %>
                  FMT AGG <%= fmt_fun.(r[c]) %>
                <% _ -> %>
                  AGG <%= r[c] %>
              <% end %>
            <% end %>
          </td>
        </tr>
      </table>
    </div>
    """
  end
end
