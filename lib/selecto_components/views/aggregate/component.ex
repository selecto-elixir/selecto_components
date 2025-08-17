defmodule SelectoComponents.Views.Aggregate.Component do
  @doc """
    display results of aggregate view
  """
  use Phoenix.LiveComponent
  
  def update(assigns, socket) do
    require Logger
    Logger.info("=== AGGREGATE COMPONENT UPDATE ===\nComponent ID: #{inspect(assigns[:id])}\nExecuted?: #{inspect(assigns[:executed])}\nQuery results present?: #{inspect(assigns[:query_results] != nil)}")
    {:ok, assign(socket, assigns)}
  end

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
    # Debug the data structure issue
    require Logger
    
    # subs should be a list containing the aggregate values for this row
    # If it's a single row of data, it should be a list like [film_count, language_count]
    # If it's multiple rows, each item would be such a list
    
    # Handle both single row and multiple row cases
    actual_subs = cond do
      # If subs is a list of lists (multiple rows), take the first row for now
      is_list(subs) and length(subs) > 0 and is_list(List.first(subs)) ->
        Logger.info("Multiple rows detected, taking first row: #{inspect(List.first(subs))}")
        List.first(subs)
      
      # If subs is a single list of values (single row) 
      is_list(subs) ->
        Logger.info("Single row detected: #{inspect(subs)}")
        subs
        
      # Fallback - convert to list
      true ->
        Logger.warn("Unexpected subs format, converting: #{inspect(subs)}")
        [subs]
    end
    
    Logger.info("tree_table Debug:\nActual subs (data): #{inspect(actual_subs)}\nAggregates config: #{inspect(assigns.aggregate)}\nSubs length: #{length(actual_subs)}\nAggregates length: #{length(assigns.aggregate)}")
    
    # Ensure we have the same number of data values as aggregate configurations
    aggs = cond do
      length(actual_subs) == length(assigns.aggregate) ->
        Enum.zip(actual_subs, assigns.aggregate)
      
      length(actual_subs) > length(assigns.aggregate) ->
        # More data than expected - take only what we need
        truncated_subs = Enum.take(actual_subs, length(assigns.aggregate))
        Logger.warn("Truncating subs data: had #{length(actual_subs)}, need #{length(assigns.aggregate)}")
        Enum.zip(truncated_subs, assigns.aggregate)
        
      true ->
        # Less data than expected - pad with nils
        padded_subs = actual_subs ++ List.duplicate(nil, length(assigns.aggregate) - length(actual_subs))
        Logger.warn("Padding subs data: had #{length(actual_subs)}, need #{length(assigns.aggregate)}")
        Enum.zip(padded_subs, assigns.aggregate)
    end
    
    Logger.info("Final zipped aggs: #{inspect(aggs)}")
    
    # Log each agg structure for template debugging
    Enum.each(aggs, fn {col, {alias, {:agg, sel, coldef}}} ->
      Logger.info("Agg for template: col=#{inspect(col)}, alias=#{inspect(alias)}, sel=#{inspect(sel)}, coldef=#{inspect(coldef)}")
    end)

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
        <td :for={ {col, {_alias, {:agg, _sel, coldef}}} <- @aggs }>
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
    # Force fresh data extraction on every render - no caching
    {results, _fields, aliases} = assigns.query_results
    
    require Logger
    Logger.info("=== SIMPLE AGGREGATE RENDER ===\nAliases: #{inspect(aliases)}\nFirst 3 results: #{inspect(Enum.take(results, 3))}")
    
    # Simple approach: Just use the first row to determine how many columns are aggregates
    first_row = List.first(results) || []
    
    # The first N-1 columns are group_by, the last columns are aggregates
    # Based on aliases length vs first row length
    total_cols = length(aliases)
    group_by_count = total_cols - length(assigns.selecto.set.aggregates)
    
    # Split aliases into group_by and aggregate sections
    {group_by_aliases, agg_aliases} = Enum.split(aliases, group_by_count)
    
    Logger.info("Group by aliases: #{inspect(group_by_aliases)}\nAggregate aliases: #{inspect(agg_aliases)}")
    
    # Build simple table structure
    ~H"""
    <div>
      <table class="min-w-full overflow-hidden divide-y ring-1 ring-gray-200 divide-gray-200 rounded-sm table-auto sm:rounded">
        <tr>
          <th :for={alias <- group_by_aliases} class="font-bold px-6 py-3 text-xs font-medium tracking-wider text-left text-gray-700 uppercase bg-gray-50">
            <%= alias %>
          </th>
          <th :for={alias <- agg_aliases} class="px-6 py-3 text-xs font-medium tracking-wider text-left text-gray-700 uppercase bg-gray-50">
            <%= alias %>
          </th>
        </tr>
        <tr :for={row <- results}>
          <td :for={value <- row} class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
            <%= value %>
          </td>
        </tr>
      </table>
    </div>
    """
  end
  
  defp render_aggregate_view(assigns, results, aliases, group_by, aggregates) do
    # Double-check synchronization at render time
    expected_field_count = Enum.count(group_by) + Enum.count(aggregates)
    aliases_count = Enum.count(aliases)
    
    # If still mismatched at render time, return loading state
    if aliases_count != expected_field_count do
      assigns = assign(assigns,
        results: [],
        results_tree: [],
        aliases: [],
        group_by: [],
        aggregate: []
      )
      
      ~H"""
      <div>
        <div class="text-gray-500 italic p-4">Synchronizing view state...</div>
      </div>
      """
    else
      render_synchronized_view(assigns, results, aliases, group_by, aggregates)
    end
  end
  
  defp render_synchronized_view(assigns, results, aliases, group_by, aggregates) do
    # Add logging to track field mapping
    require Logger
    Logger.info("Starting render_synchronized_view with:\nGroup By: #{inspect(group_by)}\nAggregates: #{inspect(aggregates)}\nAliases: #{inspect(aliases)}")
    
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

    # Now we know aliases and structure match exactly
    current_fields = group_by ++ aggregates
    fmap = Enum.zip(aliases, current_fields)
    
    Logger.info("Field mapping: #{inspect(fmap)}")
    
    group_by = Enum.take(fmap, Enum.count(group_by))
    aggregates = Enum.take(fmap, Enum.count(aggregates) * -1)
    
    Logger.info("Final mapping - Group By: #{inspect(group_by)}\nAggregates: #{inspect(aggregates)}")

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
