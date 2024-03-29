defmodule SelectoComponents.Views.Aggregate.Component do
  @doc """
    display results of aggregate view
  """
  use Phoenix.LiveComponent

  ### TODO when a level has 1 and it's child has 1, combine them

  def result_tree(results, group_by) do
    descend(results, group_by)
  end

  defp descend(results, [_ | t]) do
    #### what do do when a group-by is null? coalease and let the rollup row have the nulll?
    Enum.chunk_by(
      results,
      ### OR-- change nulls to {:nil, uuid} so they don't chunk... then keep a list of them so
      ### we can determine which nul is from the rollup vs from the data
      fn r -> List.first(r) end
    )
    |> Enum.map(fn z ->
      # we have to strip out the first item of each subarray. Is there a better way?
      {
        List.first(List.first(z)),
        descend(Enum.map(z, fn [_ | lt] -> lt end), t)
      }
    end)
  end

  defp descend(results, _) do
    results
  end

  defp tree_table(%{subs: {{gb, subs}, i}, groups: [first_group | groups]} = assigns) do
    ## Carry the data to construct this group by forward until we get to the place we will actually draw the row
    payload =
      Map.get(assigns, :payload, []) ++
        [{i, first_group, gb, Enum.count(Map.get(assigns, :payload, []))}]

    assigns =
      Map.put(assigns, :payload, payload)
      |> Map.put(:subs, subs)
      |> Map.put(:groups, groups)

    ~H"""
      <.tree_table :for={res <- Enum.with_index(@subs)} payload={@payload} subs={res} groups={@groups} aggregate={@aggregate} />
    """
  end

  defp tree_table(%{subs: {subs, _}} = assigns) do
    aggs = Enum.zip(subs, assigns.aggregate)

    level =
      Enum.count(assigns.payload) -
        (Enum.filter(assigns.payload, fn
           {_, _g, nil, _in} -> true
           _ -> false
         end)
         |> Enum.count())

    # IO.inspect(subs)
    ## <th :for={{{i, {_id, {:group_by, _col, coldef}}, v, ind}, c} <- Enum.with_index(@payload) }  >

    groups =
      assigns.payload
      |> Enum.reduce(
        [],
        fn {i, {_, {:group_by, _, coldef}}, v, _}, acc ->
          # IO.inspect(v)
          ### make this use a with!
          ### Filters from previous payload
          prefil =
            [List.last(acc)]
            |> Enum.map(fn
              nil -> %{}
              {_i, _c, _v, fil} -> fil
            end)
            |> List.first()

          newfil =
            case v do
              {_, filt} ->
                %{
                  "phx-value-#{Map.get(coldef, :group_by_filter, Map.get(coldef, :colid))}" =>
                    filt
                }

              _ ->
                %{"phx-value-#{Map.get(coldef, :group_by_filter, Map.get(coldef, :colid))}" => v}
            end

          acc ++
            [{i, coldef, v, Map.merge(newfil, prefil)}]
        end
      )

    assigns = Map.put(assigns, :aggs, aggs) |> Map.put(:level, level) |> Map.put(:subs, subs) |> Map.put(:ttgroups, groups)


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
        <th :for={{{_i, coldef, v, filters}, c} <- Enum.with_index(@ttgroups) }  >


          <div :if={ @level - 1 == c } phx-click="agg_add_filters" { filters } >
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
    {results, _fields, aliases} = assigns.query_results

    ### Will always be first X items
    group_by = assigns.selecto.set.groups
    aggregates = assigns.selecto.set.aggregates

    group_by =
      Enum.map(
        group_by,
        fn
          {col, {:extract, _f, _fmt}} = g ->
            {:group_by, g, col}

          {col, {_a, _f}} = g ->
            {:group_by, g, col}

          {col, g} ->
            {:group_by, g, col}
        end
      )

    aggregates =
      Enum.map(aggregates, fn
        {:field, {:extract, f, _fmt} = agg, _} ->
          {:agg, agg, Selecto.field(assigns.selecto, f)}

        {:field, {_a, f} = agg, _} ->
          {:agg, agg, Selecto.field(assigns.selecto, f)}

        {:field, f, _} ->
          {:agg, f, Selecto.field(assigns.selecto, f)}

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
      <table class="min-w-full overflow-hidden divide-y ring-1 ring-gray-200  divide-gray-200 rounded-sm table-auto   sm:rounded">

        <tr>
          <th :for={{alias, _} <- @group_by} class="font-bold px-6 py-3 text-xs font-medium tracking-wider text-left text-gray-700 uppercase bg-gray-50  ">
            <%= alias %>
          </th>

          <th :for={{alias, _} <- @aggregate} class="px-6 py-3 text-xs font-medium tracking-wider text-left text-gray-700 uppercase bg-gray-50  ">
            <%= alias %>
          </th>

        </tr>
        <.tree_table :for={res <- Enum.with_index(@results_tree)} subs={res} groups={@group_by} aggregate={@aggregate}/>
      </table>
    </div>
    """
  end
end
