defmodule SelectoComponents.Form.ColumnCatalog do
  @moduledoc false

  def picker_selecto(%Selecto{} = selecto) do
    selecto
    |> base_selecto()
    |> then(fn base_selecto ->
      Enum.reduce(available_cte_names(selecto), base_selecto, fn name, acc ->
        Selecto.with_cte(acc, name)
      end)
    end)
  rescue
    _ -> selecto
  end

  def picker_selecto(selecto), do: selecto

  def picker_columns(%Selecto{} = selecto) do
    cte_names = available_cte_names(selecto)

    selecto
    |> picker_selecto()
    |> Selecto.columns()
    |> Enum.map(fn {colid, column} ->
      column = Map.put_new(column, :colid, colid)

      {column.colid, column.name,
       %{
         type: Selecto.Temporal.date_like_type(column) || Map.get(column, :type),
         format: Map.get(column, :format),
         icon: picker_icon(column, cte_names),
         icon_family: picker_icon(column, cte_names),
         cte_name: cte_name_for_field_id(column.colid, cte_names)
       }}
    end)
    |> Enum.sort(fn {_, left_name, _}, {_, right_name, _} -> left_name <= right_name end)
  end

  def picker_columns(_), do: []

  def available_cte_names(%Selecto{} = selecto) do
    selecto
    |> Selecto.domain()
    |> Map.get(:query_members, %{})
    |> Map.get(:ctes, %{})
    |> Map.keys()
    |> Enum.map(&to_string/1)
  end

  def available_cte_names(_), do: []

  def required_cte_names_for_fields(%Selecto{} = selecto, field_ids) when is_list(field_ids) do
    cte_names = available_cte_names(selecto)

    Enum.reduce(field_ids, [], fn field_id, acc ->
      case cte_name_for_field_id(field_id, cte_names) do
        nil ->
          acc

        cte_name ->
          if cte_name in acc, do: acc, else: acc ++ [cte_name]
      end
    end)
  end

  def required_cte_names_for_fields(_selecto, _field_ids), do: []

  def cte_name_for_field_id(field_id, cte_names) when is_list(cte_names) do
    with field_id when is_binary(field_id) <- normalize_field_id(field_id),
         true <- String.contains?(field_id, "."),
         [cte_name, _rest] <- String.split(field_id, ".", parts: 2),
         true <- cte_name in cte_names do
      cte_name
    else
      _ -> nil
    end
  end

  def cte_name_for_field_id(_field_id, _cte_names), do: nil

  defp base_selecto(%Selecto{} = selecto) do
    Selecto.configure(
      selecto.domain,
      selecto.postgrex_opts,
      adapter: selecto.adapter,
      validate: false
    )
  end

  defp picker_icon(column, cte_names) do
    case cte_name_for_field_id(Map.get(column, :colid), cte_names) do
      nil -> Map.get(column, :icon) || Map.get(column, :icon_family)
      _cte_name -> :cte
    end
  end

  defp normalize_field_id(field_id) when is_binary(field_id), do: field_id
  defp normalize_field_id(field_id) when is_atom(field_id), do: Atom.to_string(field_id)
  defp normalize_field_id({_func, {field_id, _format}}), do: normalize_field_id(field_id)
  defp normalize_field_id({_func, field_id}), do: normalize_field_id(field_id)
  defp normalize_field_id(_field_id), do: nil
end
