defmodule SelectoComponents.Components.AggregateTable do
  @doc """
    display results of aggregate view
  """
  use Phoenix.LiveComponent


  ### TODO when a level has 1 and it's child has 1, combine them

  def result_tree(results, group_by) do
    groups = Enum.to_list( 1 .. Enum.count(group_by) )

    descend(results, groups)

  end


  defp descend(results, [g | t]) do
    Enum.chunk_by(results,   #### what do do when a group-by is null? coalease and let the rollup row have the nulll?
    ### OR-- change nulls to {:nil, uuid} so they don't chunk... then keep a list of them so
    ### we can determine which nul is from the rollup vs from the data
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

  defp tree_table( %{subs: {{gb, subs}, i}, groups: [first_group | groups]} = assigns ) do
    payload = Map.get(assigns, :payload, []) ++ [{i, first_group, gb, Enum.count(Map.get(assigns, :payload, []))}]
    assigns = Map.put(assigns, :payload, payload) |> Map.put(:subs, subs) |> Map.put(:groups, groups)

    ~H"""
      <.tree_table :for={res <- Enum.with_index(@subs)} payload={@payload} subs={res} groups={@groups} aggregate={@aggregate} />
    """

  end

  defp tree_table(  %{subs: {subs, i} } = assigns ) do

    aggs = Enum.zip(subs, assigns.aggregate)

    level = Enum.count(assigns.payload) -
      (Enum.filter(assigns.payload, fn
        {_, _g, nil ,_in} -> true
        _ -> false
      end) |> Enum.count())

    #IO.inspect(subs)
    ## <th :for={{{i, {_id, {:group_by, _col, coldef}}, v, ind}, c} <- Enum.with_index(@payload) }  >

    groups = assigns.payload |> Enum.reduce([],
      fn {i, {_id, {:group_by, _col, coldef}}, v, ind}, acc ->
        ### make this use a with!
        prefil = [List.last(acc)] |> Enum.map( fn
            nil -> %{}
            {_i, _c, _v, fil} -> fil
          end ) |> List.first()
        acc ++ [
          {
            i, coldef, v,
            Map.merge(
              %{"phx-value-#{ coldef.field }" => v},
              prefil
            )
          }
        ]
    end  )


    assigns = Map.put(assigns, :aggs, aggs) |> Map.put(:level, level) |> Map.put(:subs, subs)

    ~H"""
      <tr class={ case @level do
        0 -> "bg-slate-500 text-left text-white"
        1 -> "bg-slate-400 text-left text-black"
        2 -> "bg-slate-300 text-left text-black"
        3 -> "bg-slate-200 text-left text-black"
        4 -> "bg-slate-100 text-left text-black"
        _ -> "bg-slate-50 text-left text-black"
        end
      } >
        <th :for={{{i, coldef, v, filters}, c} <- Enum.with_index(groups) }  >


          <div :if={ level - 1 == c } phx-click="agg_add_filters" { filters } >
            <%= case coldef do %>
              <% %{group_by_format: comp} -> %>
                <%= comp.(v, coldef) %>
              <% _ -> %>
                <%= v %>
            <% end %>
          </div>
        </th>
        <td :for={ {col, {_id, {:agg, _sel, coldef}}} <- @aggs }>
          <%= case coldef do %>
            <% %{format: fmt_fun} when is_function(fmt_fun) -> %>
              <%= fmt_fun.(col) %>
            <% _ -> %>
              <%= col %>
          <% end %>
        </td>
      </tr>

    """
  end




  def render(assigns) do
    ### TODO
    ### Group-by can be a row() to return ID + NAME for filter links

    {results, fields, aliases} = Selecto.execute(assigns.selecto, results_type: :tuples)

    results = case results do #WTF postgres does wrong rollup order sometimes!
      [[f | _ft] | _t] when not is_nil(f) -> Enum.reverse(results)
      _ -> results
    end

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
        results_tree: result_tree,
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
        <.tree_table :for={res <- Enum.with_index(@results_tree)} subs={res} groups={@group_by} aggregate={@aggregate}/>
      </table>
    </div>
    """
  end
end
