defmodule SelectoComponents.Helpers do
  def date_formats() do
    %{
      "MM-DD-YYYY HH:MM" => "MM-DD-YYYY HH:MM",
      "YYYY-MM-DD HH:MM" => "YYYY-MM-DD HH:MM"
    }
  end

  def process_group_by(group_by, columns) do
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

  def process_aggregates(aggregates, _columns) do
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

  def process_order_by(order_by, columns) do
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

  def process_selected(detail_selected, columns) do
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
