defmodule SelectoComponents.Execution.CTEs do
  @moduledoc """
  CTE synchronization and application helpers for execution planning.
  """

  alias SelectoComponents.Form.ColumnCatalog

  @field_param_sections ~w(selected order_by group_by aggregate x_axis y_axis series)
  @view_state_field_keys [:selected, :order_by, :group_by, :aggregate, :x_axis, :y_axis, :series]

  def sync_view_config(view_config, %Selecto{} = selecto) when is_map(view_config) do
    derived_names = derived_cte_names_from_view_config(view_config, selecto)
    existing_ctes = get_map_value(view_config, :ctes, [])
    synced_ctes = build_cte_entries(derived_names, existing_ctes)

    Map.put(view_config, :ctes, synced_ctes)
  end

  def sync_view_config(view_config, _selecto), do: view_config

  def apply_for_params(selecto, params) when is_map(params) do
    explicit_names =
      params
      |> ctes_from_params([])
      |> Enum.map(&cte_entry_name/1)
      |> Enum.reject(&is_nil/1)

    derived_names = derived_cte_names_from_params(params, selecto)

    Enum.reduce(explicit_names ++ derived_names, selecto, fn
      name, acc when is_binary(name) and name != "" ->
        if name in ColumnCatalog.available_cte_names(acc) and not cte_already_applied?(acc, name) do
          Selecto.with_cte(acc, name)
        else
          acc
        end

      _name, acc ->
        acc
    end)
  end

  def apply_for_params(selecto, _params), do: selecto

  defp ctes_from_params(params, default) when is_map(params) do
    case Map.get(params, "ctes") do
      section when is_map(section) ->
        section
        |> Enum.sort_by(fn {_uuid, value} -> sort_index(value) end)
        |> Enum.map(fn {uuid, value} ->
          cte_uuid = get_map_value(value, :uuid, uuid)
          name = get_map_value(value, :name)

          {cte_uuid, name, Map.drop(stringify_map_keys(value), ["uuid", "name", "index"])}
        end)
        |> Enum.reject(fn {_uuid, name, _config} -> is_nil(name) or to_string(name) == "" end)

      _ ->
        default
    end
  end

  defp ctes_from_params(_params, default), do: default

  defp derived_cte_names_from_params(params, %Selecto{} = selecto) when is_map(params) do
    field_ids = field_ids_from_params(params) ++ filter_ids_from_params(params)
    ColumnCatalog.required_cte_names_for_fields(selecto, field_ids)
  end

  defp derived_cte_names_from_params(_params, _selecto), do: []

  defp derived_cte_names_from_view_config(view_config, %Selecto{} = selecto)
       when is_map(view_config) do
    field_ids =
      field_ids_from_view_config(view_config) ++ filter_ids_from_view_config(view_config)

    ColumnCatalog.required_cte_names_for_fields(selecto, field_ids)
  end

  defp derived_cte_names_from_view_config(_view_config, _selecto), do: []

  defp field_ids_from_params(params) when is_map(params) do
    @field_param_sections
    |> Enum.flat_map(fn section ->
      params
      |> Map.get(section, %{})
      |> list_field_ids_from_param_section()
    end)
  end

  defp field_ids_from_params(_params), do: []

  defp list_field_ids_from_param_section(section) when is_map(section) do
    section
    |> Map.values()
    |> Enum.map(&get_map_value(&1, :field))
    |> Enum.reject(&is_nil/1)
  end

  defp list_field_ids_from_param_section(_section), do: []

  defp filter_ids_from_params(params) when is_map(params) do
    params
    |> Map.get("filters", %{})
    |> Map.values()
    |> Enum.map(&get_map_value(&1, :filter))
    |> Enum.reject(&is_nil/1)
  end

  defp filter_ids_from_params(_params), do: []

  defp field_ids_from_view_config(view_config) when is_map(view_config) do
    view_config
    |> get_map_value(:views, %{})
    |> Map.values()
    |> Enum.flat_map(&field_ids_from_view_state/1)
  end

  defp field_ids_from_view_config(_view_config), do: []

  defp field_ids_from_view_state(view_state) when is_map(view_state) do
    @view_state_field_keys
    |> Enum.flat_map(fn key ->
      view_state
      |> get_map_value(key, [])
      |> list_field_ids_from_items()
    end)
  end

  defp field_ids_from_view_state(_view_state), do: []

  defp list_field_ids_from_items(items) when is_list(items) do
    items
    |> Enum.map(fn
      {_uuid, field, _config} -> field
      [_, field, _config] -> field
      _other -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp list_field_ids_from_items(_items), do: []

  defp filter_ids_from_view_config(view_config) when is_map(view_config) do
    view_config
    |> get_map_value(:filters, [])
    |> Enum.map(fn
      {_uuid, _section, filter_value} -> get_map_value(filter_value, :filter)
      [_, _, filter_value] -> get_map_value(filter_value, :filter)
      _other -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp filter_ids_from_view_config(_view_config), do: []

  defp build_cte_entries(names, existing_ctes) when is_list(names) do
    existing_by_name =
      Map.new(existing_ctes, fn entry ->
        case normalize_cte_entry(entry) do
          {uuid, name, config} -> {name, {uuid, name, config}}
          nil -> {nil, nil}
        end
      end)

    names
    |> Enum.uniq()
    |> Enum.map(fn name ->
      Map.get(existing_by_name, name, {"auto-cte-#{name}", name, %{}})
    end)
  end

  defp build_cte_entries(_names, _existing_ctes), do: []

  defp normalize_cte_entry({uuid, name, config}),
    do: {to_string(uuid), to_string(name), config || %{}}

  defp normalize_cte_entry([uuid, name, config]),
    do: {to_string(uuid), to_string(name), config || %{}}

  defp normalize_cte_entry(_entry), do: nil

  defp cte_entry_name({_, name, _}) when is_binary(name), do: name
  defp cte_entry_name([_, name, _]) when is_binary(name), do: name
  defp cte_entry_name(_entry), do: nil

  defp cte_already_applied?(%Selecto{} = selecto, name) do
    selecto
    |> get_in([Access.key(:set, %{}), Access.key(:ctes, [])])
    |> Enum.any?(fn spec ->
      spec_name =
        Map.get(spec, :name) ||
          Map.get(spec, :as) ||
          Map.get(spec, "name") ||
          Map.get(spec, "as")

      to_string(spec_name || "") == name
    end)
  end

  defp cte_already_applied?(_selecto, _name), do: false

  defp stringify_map_keys(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {to_string(key), value} end)
  end

  defp stringify_map_keys(_value), do: %{}

  defp sort_index(value) when is_map(value) do
    case Map.get(value, "index") do
      idx when is_binary(idx) ->
        case Integer.parse(idx) do
          {num, ""} -> num
          _ -> 0
        end

      idx when is_integer(idx) ->
        idx

      _ ->
        0
    end
  end

  defp sort_index(_value), do: 0

  defp get_map_value(map, key, default \\ nil)

  defp get_map_value(map, key, default) when is_map(map) do
    Map.get(map, key, Map.get(map, to_string(key), default))
  end

  defp get_map_value(_map, _key, default), do: default
end
