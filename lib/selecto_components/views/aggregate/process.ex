defmodule SelectoComponents.Views.Aggregate.Process do
  def param_to_state(params, _v) do
    %{
      group_by: SelectoComponents.Views.view_param_process(params, "group_by", "field"),
      aggregate: SelectoComponents.Views.view_param_process(params, "aggregate", "field")
    }
  end

  def initial_state(selecto, _v) do
    %{
      aggregate:
        Map.get(Selecto.domain(selecto), :default_aggregate, [])
        |> SelectoComponents.Helpers.build_initial_state(),
      group_by:
        Map.get(Selecto.domain(selecto), :default_group_by, [])
        |> SelectoComponents.Helpers.build_initial_state()
    }
  end

  def view(_opt, params, columns, filtered, _selecto) do
    group_by_params = Map.get(params, "group_by", %{})

    aggregate =
      Map.get(params, "aggregate", %{})
      |> aggregates(columns)

    group_by = group_by_params |> group_by(columns)

    {%{
       groups: group_by,
       gb_params: group_by_params,
       aggregates: aggregate,
       selected: Enum.map(group_by, fn {_c, sel} -> sel end) ++ aggregate,
       filtered: filtered,
       group_by: [
         {:rollup, Enum.map(1..Enum.count(group_by), fn g -> {:literal_position, g} end)}
       ],
       ### when using rollup, we need to workaround postgres bug. Currently implemented in Selecto builder
       order_by: Enum.map(1..Enum.count(group_by), fn g -> {:literal_position, g} end)
     }, %{}}
  end

  def group_by(group_by, columns) do
    group_by
    |> Map.values()
    |> Enum.sort(fn a, b -> String.to_integer(a["index"]) <= String.to_integer(b["index"]) end)
    |> Enum.map(fn e ->
      col = columns[e["field"]]
      # ????
      alias =
        case e["alias"] do
          "" -> e["field"]
          nil -> e["field"]
          _ -> e["alias"]
        end

      ### Group by filter, _select, format...
      sel =
        if Map.get(col, :group_by_filter_select) do
          case col.group_by_filter_select do
            x when is_list(x) -> {:row, col.group_by_filter_select, alias}
            x when is_function(x) -> {:row, col.group_by_filter_select.(e), alias}
          end
        else
          case col.type do
            x when x in [:naive_datetime, :utc_datetime] ->
              {:field, datetime_gb_proc(col, e), alias}

            :custom_column ->
              case Map.get(col, :requires_select) do
                x when is_list(x) -> {:row, col.requires_select, alias}
                x when is_function(x) -> {:row, col.requires_select.(e), alias}
                nil -> {col.colid, alias}
              end

            _ ->
              # col.colid
              {:field, col.colid, alias}
          end
        end

      {col, sel}
    end)
  end

  defp datetime_gb_proc(col, config) do
    # "Year", "Month", "Day", "Hour", "YYYY-MM-DD", "YYYY-MM"
    case config["format"] do
      # x when x in ~w(Year Month Day) -> {:extract, col.colid, x}
      x when x in ~w(YYYY-MM-DD YYYY-MM YYYY) -> {:to_char, {col.colid, x}}
    end
  end

  def aggregates(aggregates, _columns) do
    aggregates
    |> Map.values()
    |> Enum.sort(fn a, b -> String.to_integer(a["index"]) <= String.to_integer(b["index"]) end)
    |> Enum.map(fn e ->
      # ????
      alias =
        case e["alias"] do
          "" -> e["field"]
          nil -> e["field"]
          _ -> e["alias"]
        end

      {:field,
       {
         String.to_atom(
           case e["format"] do
             nil -> "count"
             _ -> e["format"]
           end
         ),
         e["field"]
       }, alias}
    end)
  end
end
