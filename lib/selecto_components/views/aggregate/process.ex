defmodule SelectoComponents.Views.Aggregate.Process do

  def param_to_state(params, _v) do
    %{
      group_by: SelectoComponents.Helpers.view_param_process(params, "group_by", "field"),
      aggregate: SelectoComponents.Helpers.view_param_process(params, "aggregate", "field")
    }
  end

  def initial_state(selecto, _v) do
    %{
      aggregate: Map.get(selecto.domain, :default_aggregate, []) |> SelectoComponents.Helpers.build_initial_state(),
      group_by: Map.get(selecto.domain, :default_group_by, []) |> SelectoComponents.Helpers.build_initial_state()
    }
  end

  def view(opt, params, columns, filtered, selecto) do
    group_by_params = Map.get(params, "group_by", %{})

    aggregate =
      Map.get(params, "aggregate", %{})
      |> SelectoComponents.Views.Aggregate.Process.aggregates(columns)

    group_by =
      group_by_params |> SelectoComponents.Views.Aggregate.Process.group_by(columns)

    {%{
      groups: group_by,
      gb_params: group_by_params,
      aggregates: aggregate,
      selected: Enum.map(group_by, fn {_c, sel} -> sel end) ++ aggregate,
      filtered: filtered,
      group_by: [
        {:rollup, Enum.map(1..Enum.count(group_by), fn g -> {:literal, g} end)}
      ],
      ### when using rollup, we need to workaround postgres bug. Currently implemented in Selecto builder
      order_by: Enum.map(1..Enum.count(group_by), fn g -> {:literal, g} end)
    }, %{}}
  end

  def group_by(group_by, columns) do
    group_by
    |> Map.values()
    |> Enum.sort(fn a, b -> String.to_integer(a["index"]) <= String.to_integer(b["index"]) end)
    |> Enum.map(fn e ->
      col = columns[e["field"]]
      uuid = e["uuid"]

      ### Group by filter, _select, format...
      sel =
        if Map.get(col, :group_by_filter_select) do
          case col.group_by_filter_select do
            x when is_list(x) -> {:row, col.group_by_filter_select, uuid}
            x when is_function(x) -> {:row, col.group_by_filter_select.(e), uuid}
          end
        else
          case col.type do
            x when x in [:naive_datetime, :utc_datetime] ->
              {:extract, col.colid, e["format"]}

            :custom_column ->
              case Map.get(col, :requires_select) do
                x when is_list(x) -> {:row, col.requires_select, uuid}
                x when is_function(x) -> {:row, col.requires_select.(e), uuid}
                nil -> col.colid
              end

            _ ->
              col.colid
          end
        end

      {col, sel}
    end)
  end


  def aggregates(aggregates, _columns) do
    aggregates
    |> Map.values()
    |> Enum.sort(fn a, b -> String.to_integer(a["index"]) <= String.to_integer(b["index"]) end)
    |> Enum.map(fn e ->
      {String.to_atom(
         case e["format"] do
           nil -> "count"
           _ -> e["format"]
         end
       ), e["field"]}
    end)
  end

end
