defmodule SelectoComponents.Components.AggregateTable do
  @doc """
    display results of aggregate view
  """
  use Phoenix.LiveComponent


  def result_tree(results, group_by) do
    groups = Enum.to_list( 1 .. Enum.count(group_by) )

    descend(results, groups) |> IO.inspect

  end


  defp descend(results, [g | t]) do
    Enum.chunk_by(results,   #### what do do when a group-by is null? coalease and let the rollup row have the nulll..
      fn r -> List.first(r) end
    )
    |> Enum.map(
        fn z ->
            {  # we have to strip out the first item of each subarray. Is there a better way?
              List.first( List.first( z )),
              descend(Enum.map(z, fn [lh | lt] -> lt end ), t) }
        end )
  end
  defp descend(results, _) do
    results
  end



  def render(assigns) do
    ### TODO
    ### Group-by can be a row() to return ID + NAME for filter links

    {results, fields, aliases} = Selecto.execute(assigns.selecto, results_type: :tuples)
    ### Will always be first X items
    group_by = assigns.selecto.set.groups
    aggregates = assigns.selecto.set.selected -- group_by

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

        nil ->
          {:agg, nil, nil}
      end)

    fmap = Enum.zip(aliases, group_by ++ aggregates)
    group_by = Enum.take(fmap, Enum.count(group_by))
    aggregates = Enum.take(fmap, Enum.count(aggregates) * -1)

    result_tree = result_tree(results, group_by)

    assigns =
      assign(assigns,
        results: results,
        aliases: aliases,
        group_by: group_by,
        aggregate: aggregates
      )

    ~H"""
    <div>
      <table class="min-w-full overflow-hidden divide-y ring-1 ring-gray-200 dark:ring-0 divide-gray-200 rounded-sm table-auto dark:divide-y-0 dark:divide-gray-800 sm:rounded">

        <tr>
          <th :for={{alias, {:group_by, g, def}} <- @group_by} class="font-bold px-6 py-3 text-xs font-medium tracking-wider text-left text-gray-700 uppercase bg-gray-50 dark:bg-gray-600 dark:text-gray-300">
            <%= case g do %>
            <%= {:extract, f, fmt} -> %>
              <%= fmt %>: <%= def.name %>
            <% {a, f} -> %>
              <%= a %>: <%= f %>
            <% f -> %>
              <%= inspect(f) %>
            <% end %>
          </th>

          <th :for={{alias, r} <- @aggregate} class="px-6 py-3 text-xs font-medium tracking-wider text-left text-gray-700 uppercase bg-gray-50 dark:bg-gray-600 dark:text-gray-300">
            <%= case r do %>
            <% {:agg, {a, f}, def} -> %>
              <%= a %>: <%= f %>
            <% f -> %>
              <%= inspect(f) %>
            <% end %>
          </th>
        </tr>

        <tr :for={resrow <- @results} class="border-b dark:border-gray-700 bg-white even:bg-white dark:bg-gray-700 dark:even:bg-gray-800 last:border-none">
          <%= with r <- Enum.zip( @aliases, resrow ) |> Enum.into(%{}) do %>

            <td :for={{alias, {:group_by, c, coldef}} <- @group_by} class="px-6 py-4 text-sm text-gray-500 dark:text-gray-400">
              <div>
                <%= case coldef do %>
                  <% %{group_by_format: comp} -> %>
                    <%= comp.(r[alias], coldef) %>

                  <% _ -> %>
                    <%= r[alias] %>
                <% end %>
              </div>
            </td>

            <td :for={{alias, {:agg, {a, c}, coldef}} = agg <- @aggregate} class="px-6 py-4 text-sm text-gray-500 dark:text-gray-400">
              <%= case coldef do %>
                <% %{format: fmt_fun} when is_function(fmt_fun) -> %>
                  <%= fmt_fun.(r[c]) %>
                <% _ -> %>
                  <%= r[alias] %>
              <% end %>
            </td>

          <% end %>

        </tr>
      </table>
    </div>
    """
  end
end
