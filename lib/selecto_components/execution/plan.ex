defmodule SelectoComponents.Execution.Plan do
  @moduledoc """
  Non-I/O execution planning for SelectoComponents.

  This module turns runtime params plus socket state into an execution-ready
  plan that can be inspected and tested independently from query execution.
  """

  import SelectoComponents.Helpers.Filters, only: [filter_recurse: 3]

  alias SelectoComponents.Form
  alias SelectoComponents.Form.ColumnCatalog
  alias SelectoComponents.Form.ParamsState
  alias SelectoComponents.Presentation
  alias SelectoComponents.SafeAtom
  alias SelectoComponents.SubselectBuilder
  alias SelectoComponents.EnhancedTable.Sorting
  alias SelectoComponents.Views.Runtime, as: ViewRuntime

  defstruct [
    :params,
    :presentation_context,
    :selecto,
    :columns_list,
    :columns_map,
    :filtered,
    :selected_view,
    :view_tuple,
    :view_set,
    :view_meta
  ]

  @type t :: %__MODULE__{}

  @spec build(map(), Phoenix.LiveView.Socket.t()) :: t()
  def build(params, socket) when is_map(params) do
    presentation_context =
      socket.assigns
      |> Map.get(:presentation_context, %{})
      |> Presentation.resolve_context()

    params =
      params
      |> ParamsState.canonicalize_form_params(socket.assigns[:selecto], presentation_context)
      |> put_runtime_presentation_context(presentation_context)

    selecto =
      socket.assigns.selecto
      |> rebuild_selecto()
      |> ParamsState.apply_ctes_for_params(params)

    raw_columns = Selecto.columns(selecto)
    columns_list = ColumnCatalog.picker_columns(selecto)
    columns_map = build_columns_map(raw_columns)
    filters_by_section = build_filters_by_section(params)
    filtered = filter_recurse(selecto, filters_by_section, "filters")
    selected_view = SafeAtom.to_view_mode(get_map_value(params, :view_mode))
    params = maybe_put_detail_page(params, selected_view, socket)
    view_tuple = Enum.find(socket.assigns.views, fn {id, _, _, _} -> id == selected_view end)

    {view_set, view_meta} =
      case view_tuple do
        {_id, _module, _name, _opt} = tuple ->
          ViewRuntime.view(tuple, params, columns_map, filtered, selecto)

        nil ->
          raise "View mode '#{selected_view}' not found in configured views"
      end

    selecto =
      selecto
      |> Map.put(:set, Map.merge(Map.get(selecto, :set, %{}), view_set))
      |> maybe_apply_retarget(params)
      |> maybe_apply_denorm_groups()
      |> maybe_apply_sort(socket.assigns[:sort_by])

    %__MODULE__{
      params: params,
      presentation_context: presentation_context,
      selecto: selecto,
      columns_list: columns_list,
      columns_map: columns_map,
      filtered: filtered,
      selected_view: selected_view,
      view_tuple: view_tuple,
      view_set: view_set,
      view_meta: view_meta
    }
  end

  defp rebuild_selecto(old_selecto) do
    Selecto.configure(
      old_selecto.domain,
      old_selecto.postgrex_opts,
      adapter: old_selecto.adapter,
      validate: false
    )
  end

  defp put_runtime_presentation_context(params, presentation_context) when is_map(params) do
    Map.put(params, "_presentation_context", presentation_context || %{})
  end

  defp put_runtime_presentation_context(params, _presentation_context), do: params

  defp build_columns_map(raw_columns) do
    raw_columns
    |> Enum.into(%{}, fn {key, col} ->
      col_with_metadata =
        col
        |> Map.put(:field, col.name)
        |> Map.put(:colid, key)

      {key, col_with_metadata}
    end)
    |> then(fn cols ->
      Enum.reduce(cols, cols, fn {_colid, col}, acc ->
        Map.put(acc, col.name, col)
      end)
    end)
  end

  defp build_filters_by_section(params) do
    params
    |> Map.get("filters", %{})
    |> Map.values()
    |> Enum.filter(fn f ->
      is_map(f) and Map.has_key?(f, "section") and
        (Map.has_key?(f, "filter") or Map.get(f, "is_section") in ["Y", true, "true"])
    end)
    |> Enum.reduce(%{}, fn f, acc ->
      Map.put(acc, Map.get(f, "section"), Map.get(acc, Map.get(f, "section"), []) ++ [f])
    end)
  end

  defp maybe_put_detail_page(params, :detail, socket) do
    if Map.has_key?(socket.assigns, :current_detail_page) do
      Map.put(params, "detail_page", to_string(socket.assigns.current_detail_page))
    else
      params
    end
  end

  defp maybe_put_detail_page(params, _selected_view, _socket), do: params

  defp maybe_apply_retarget(selecto, params) do
    Selecto.AutoRetarget.maybe_apply(selecto,
      view_mode: Map.get(params, "view_mode", "detail"),
      selected: Form.get_selected_columns_from_params(params)
    )
  end

  defp maybe_apply_denorm_groups(selecto) do
    if Map.has_key?(selecto.set, :denorm_groups) and is_map(selecto.set.denorm_groups) and
         map_size(selecto.set.denorm_groups) > 0 do
      denorm_groups = selecto.set.denorm_groups

      try do
        Enum.reduce(denorm_groups, selecto, fn {relationship_path, columns}, acc ->
          SubselectBuilder.add_subselect_for_group(acc, relationship_path, columns)
        end)
      rescue
        _e -> selecto
      end
    else
      selecto
    end
  end

  defp maybe_apply_sort(selecto, nil), do: selecto
  defp maybe_apply_sort(selecto, sort_by), do: Sorting.apply_sort_to_query(selecto, sort_by)

  defp get_map_value(map, key, default \\ nil)

  defp get_map_value(map, key, default) when is_map(map) do
    Map.get(map, key, Map.get(map, to_string(key), default))
  end

  defp get_map_value(_map, _key, default), do: default
end
