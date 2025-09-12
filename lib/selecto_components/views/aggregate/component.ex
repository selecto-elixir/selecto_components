defmodule SelectoComponents.Views.Aggregate.Component do
  @doc """
    display results of aggregate view
  """
  use Phoenix.LiveComponent
  alias SelectoComponents.EnhancedTable.Sorting

  def update(assigns, socket) do
    # Force a complete re-assignment to ensure LiveView recognizes data changes
    socket = assign(socket, assigns)

    # Add a timestamp to force re-rendering if data changed
    socket = assign(socket, :last_update, System.system_time(:microsecond))

    {:ok, socket}
  end
  
  # Sorting disabled in aggregate view to prevent SQL errors with ROLLUP queries
  # def handle_event("sort_column", %{"column" => column} = params, socket) do
  #   multi = Map.get(params, "multi", "false") == "true"
  #   socket = Sorting.handle_sort_click(column, socket, multi)
  #   
  #   # Trigger re-execution with new sort
  #   send(self(), {:rerun_query_with_sort, socket.assigns.sort_by})
  #   
  #   {:noreply, socket}
  # end

  # # Helper function to determine styling level based on group values
  # defp determine_level(group_values) do
  #   # Count non-nil values to determine hierarchy level
  #   non_nil_count = Enum.count(group_values, fn val -> val != nil end)

  #   case non_nil_count do
  #     0 -> 0  # Total row (all group values are nil)
  #     1 -> 1  # First level grouping
  #     2 -> 2  # Second level grouping
  #     3 -> 3  # Third level grouping
  #     _ -> 4  # Deeper levels
  #   end
  # end

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
    # subs should be a list containing the aggregate values for this row
    # If it's a single row of data, it should be a list like [film_count, language_count]
    # If it's multiple rows, each item would be such a list

    # Handle both single row and multiple row cases
    actual_subs = cond do
      # If subs is a list of lists (multiple rows), take the first row for now
      is_list(subs) and length(subs) > 0 and is_list(List.first(subs)) ->
        List.first(subs)

      # If subs is a single list of values (single row)
      is_list(subs) ->
        subs

      # Fallback - convert to list
      true ->
        [subs]
    end

    # Ensure we have the same number of data values as aggregate configurations
    aggs = cond do
      length(actual_subs) == length(assigns.aggregate) ->
        Enum.zip(actual_subs, assigns.aggregate)

      length(actual_subs) > length(assigns.aggregate) ->
        # More data than expected - take only what we need
        truncated_subs = Enum.take(actual_subs, length(assigns.aggregate))
        Enum.zip(truncated_subs, assigns.aggregate)

      true ->
        # Less data than expected - pad with nils
        padded_subs = actual_subs ++ List.duplicate(nil, length(assigns.aggregate) - length(actual_subs))
        Enum.zip(padded_subs, assigns.aggregate)
    end

    level =
      Enum.count(assigns.payload) -
        (Enum.filter(assigns.payload, fn
           {_, _g, nil, _in} -> true
           _ -> false
         end)
         |> Enum.count())

    groups =
      assigns.payload
      |> Enum.reduce(
        [],
        fn {i, {_, {:group_by, _, coldef}}, v, _}, acc ->
          ### make this use a with!
          ### Filters from previous payload
          prefil =
            [List.last(acc)]
            |> Enum.map(fn
              nil -> %{}
              {_i, _c, _v, fil} -> fil
            end)
            |> List.first()
          # Handle rollup rows where coldef is :rollup atom instead of a map
          newfil =
            case {coldef, v} do
              {:rollup, _} ->
                # For rollup rows, don't create filters
                %{}

              {coldef, {_, filt}} when is_map(coldef) ->
                filter_key = Map.get(coldef, :group_by_filter, Map.get(coldef, :colid, Map.get(coldef, :name)))
                if filter_key != nil do
                  %{"phx-value-#{filter_key}" => filt}
                else
                  %{}
                end

              {coldef, _} when is_map(coldef) ->
                filter_key = Map.get(coldef, :group_by_filter, Map.get(coldef, :colid, Map.get(coldef, :name)))
                if filter_key != nil do
                  %{"phx-value-#{filter_key}" => v}
                else
                  %{}
                end

              _ ->
                # Fallback for unexpected cases
                %{}
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
              <% :rollup -> %>
                <%= case v do
                  {display_value, _id} -> display_value
                  tuple when is_tuple(tuple) -> elem(tuple, 0)
                  _ -> v
                end %>
              <% %{group_by_format: comp} -> %>
                <%= comp.(v, coldef) %>
              <% _ -> %>
                <%= case v do
                  {display_value, _id} -> display_value
                  tuple when is_tuple(tuple) -> elem(tuple, 0)
                  _ -> v
                end %>
            <% end %>
          </div>
        </th>
        <td :for={ {col, {_alias, {:agg, _sel, coldef}}} <- @aggs }>
          <%= case coldef do %>
            <% %{format: fmt_fun} when is_function(fmt_fun) -> %>
              <%= fmt_fun.(col) %>
            <% _ -> %>
              <%= case col do
                {display_value, _id} -> display_value
                tuple when is_tuple(tuple) -> elem(tuple, 0)
                _ -> col
              end %>
          <% end %>
        </td>
      </tr>

    """
  end

  def render(assigns) do
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
        # Valid execution with results - proceed with normal rendering

        # Extract the actual selected fields from the selecto configuration
        # Note: assigns.selecto.set.group_by contains ROLLUP config, not actual fields
        # The actual fields are in assigns.selecto.set.selected
        selected_fields = assigns.selecto.set.selected || []

        # Also get the original group_by and aggregates for processing
        rollup_group_by = assigns.selecto.set.group_by || []
        aggregates = assigns.selecto.set.aggregates || []

        # Use the rollup rendering logic instead of simple flat rendering
        render_aggregate_view(assigns, results, aliases, selected_fields, rollup_group_by, aggregates)

      _ ->
        # Fallback for unexpected states
        ~H"""
        <div>
          <div class="text-yellow-500 p-4">
            <div class="font-semibold">Unknown State</div>
            <div class="text-sm mt-1">
              Executed: <%= inspect(assigns[:executed]) %><br/>
              Query Results: <%= inspect(assigns.query_results != nil) %>
            </div>
          </div>
        </div>
        """
      end
    end
  end

  defp render_aggregate_view(assigns, results, aliases, selected_fields, rollup_group_by, aggregates) do
    # Use the actual selected fields for counting instead of group_by + aggregates
    # because ROLLUP can add extra fields to the query result
    expected_field_count = Enum.count(selected_fields)
    aliases_count = Enum.count(aliases)

    # If still mismatched at render time, check if we should show loading or error state
    if aliases_count != expected_field_count do
      # If we have no query results or they're stale, show loading
      # If executed is false, we're waiting for a new query
      cond do
        not assigns[:executed] ->
          ~H"""
          <div>
            <div class="text-blue-500 italic p-4">Loading view...</div>
          </div>
          """

        assigns.query_results == nil ->
          ~H"""
          <div>
            <div class="text-blue-500 italic p-4">Loading view...</div>
          </div>
          """

        true ->
          # We have results but they don't match - this suggests a configuration issue
          assigns = assign(assigns,
            expected_field_count: expected_field_count,
            aliases_count: aliases_count,
            selected_fields_count: Enum.count(selected_fields),
            aggregates_count: Enum.count(aggregates),
            aliases_debug: inspect(aliases)
          )

          ~H"""
          <div>
            <div class="text-red-500 p-4">
              <div class="font-semibold">View Configuration Error</div>
              <div class="text-sm mt-1">
                Expected <%= @expected_field_count %> fields but got <%= @aliases_count %> from query.
                This usually indicates a mismatch between the view configuration and query results.
              </div>
              <details class="mt-2 text-xs">
                <summary class="cursor-pointer">Debug Info</summary>
                <div>Selected Fields: <%= @selected_fields_count %></div>
                <div>Aggregate Fields: <%= @aggregates_count %></div>
                <div>Query Aliases: <%= @aliases_debug %></div>
              </details>
            </div>
          </div>
          """
      end
    else
      render_synchronized_view(assigns, results, aliases, selected_fields, rollup_group_by, aggregates)
    end
  end

  defp render_synchronized_view(assigns, results, aliases, selected_fields, rollup_group_by, aggregates) do

    # Process the selected fields to match the aliases
    # The selected fields should match 1:1 with the aliases from the query
    field_mappings = Enum.zip(aliases, selected_fields)

    # Split the mappings back into group_by and aggregate sections
    # We need to determine which selected fields are group by vs aggregates
    # Look at the rollup_group_by to determine how many group by fields we have

    # Count the actual group by fields (not the ROLLUP wrapper)
    num_group_by = case rollup_group_by do
      [{:rollup, positions}] when is_list(positions) -> Enum.count(positions)
      _ -> 0
    end

    #num_aggregates = Enum.count(selected_fields) - num_group_by

    group_by_mappings = Enum.take(field_mappings, num_group_by)
    aggregate_mappings = Enum.drop(field_mappings, num_group_by)

    # Convert to the format expected by the template
    group_by =
      group_by_mappings
      |> Enum.map(fn {alias, field} ->
        # Get the proper column definition from selecto based on the field
        coldef = case field do
          {:field, field_id, _alias} when is_atom(field_id) ->
            Selecto.field(assigns.selecto, field_id)
          {:field, {_extract_type, field_id, _format}, _alias} when is_atom(field_id) ->
            Selecto.field(assigns.selecto, field_id)
          {:row, _selector, _alias} ->
            # For row selectors, use a basic column definition
            %{name: alias, format: nil}
          _ ->
            # Fallback to basic definition
            %{name: alias, format: nil}
        end
        {alias, {:group_by, field, coldef}}
      end)

    aggregates_processed =
      Enum.zip(aggregate_mappings, aggregates)
      |> Enum.map(fn {{alias, _field}, agg} ->
        # Get the proper column definition from selecto
        coldef = case agg do
          {:field, {_func, field_id}, _alias} when is_atom(field_id) ->
            Selecto.field(assigns.selecto, field_id)
          {:field, field_id, _alias} when is_atom(field_id) ->
            Selecto.field(assigns.selecto, field_id)
          _ ->
            # Fallback to empty map for unknown aggregate types
            %{}
        end
        {alias, {:agg, agg, coldef}}
      end)

    # The result_tree function expects just the group by field definitions, not the full tuple
    # Extract just the field definitions from the group_by tuples
    group_by_fields = Enum.map(group_by, fn {_alias, {:group_by, field, _coldef}} -> field end)

    result_tree = result_tree(results, group_by_fields)

    assigns =
      assign(assigns,
        results: results,
        results_tree: result_tree,
        aliases: aliases,
        group_by: group_by,
        aggregate: aggregates_processed
      )

    ~H"""
    <div>
      <table class="min-w-full overflow-hidden divide-y ring-1 ring-gray-200  divide-gray-200 rounded-sm table-auto   sm:rounded">

        <tr>
          <%!-- Non-sortable headers for group by columns (sorting disabled in aggregate view) --%>
          <%= for {alias, {:group_by, _field, _coldef}} <- @group_by do %>
            <th class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
              <%= alias %>
            </th>
          <% end %>

          <%!-- Non-sortable headers for aggregate columns (sorting disabled in aggregate view) --%>
          <%= for {alias, {:agg, _agg, _coldef}} <- @aggregate do %>
            <th class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
              <%= alias %>
            </th>
          <% end %>

        </tr>
        <.tree_table :for={res <- Enum.with_index(@results_tree)} subs={res} groups={@group_by} aggregate={@aggregate}/>
      </table>
    </div>
    """
  end
end
