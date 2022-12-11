defmodule SelectoComponents.Views.Detail.Process do

  def param_to_state(params) do
    %{
      selected: SelectoComponents.Helpers.view_param_process(params, "selected", "field"),
      order_by: SelectoComponents.Helpers.view_param_process(params, "order_by", "field")

    }
  end

  ### Process incoming params to build Selecto.set for view
  def view(params, columns, filtered, selecto) do
    detail_columns =
      Map.get(params, "selected", %{})
      |> Map.values()
      |> Enum.sort(fn a, b ->
        String.to_integer(a["index"]) <= String.to_integer(b["index"])
      end)

    ### Selecto Set for Detail View
    detail_set = %{
      columns: detail_columns,
      selected: detail_columns |> selected(columns),
      order_by:
        Map.get(params, "order_by", %{})
        |> order_by(columns),
      filtered: filtered,
      group_by: [],
      groups: []
    }

  end

  def order_by(order_by, _columns) do
    order_by
    |> Map.values()
    |> Enum.sort(fn a, b -> String.to_integer(a["index"]) <= String.to_integer(b["index"]) end)
    |> Enum.map(fn e ->
      case e["dir"] do
        "desc" -> {:desc, e["field"]}
        _ -> e["field"]
      end
    end)
  end

  def selected(detail_selected, columns) do
    date_formats = SelectoComponents.Helpers.date_formats()

    detail_selected
    |> Enum.map(fn e ->
      col = columns[e["field"]]
      uuid = e["uuid"]
      # move to a validation lib
      case col.type do
        x when x in [:naive_datetime, :utc_datetime] ->
          {:field, {:to_char, {col.colid, date_formats[e["format"]]}}, uuid}

        :custom_column ->
          case Map.get(col, :requires_select) do
            x when is_list(x) -> {:row, col.requires_select, uuid}
            x when is_function(x) -> {:row, col.requires_select.(e), uuid}
            nil -> {:field, col.colid, uuid}
          end

        _ ->
          {:field, col.colid, uuid}
      end
    end)
    |> List.flatten()
  end

end
