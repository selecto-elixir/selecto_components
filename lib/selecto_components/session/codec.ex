defmodule SelectoComponents.Session.Codec do
  @moduledoc """
  Session-oriented codec helpers for SelectoComponents.

  This module owns form/url decode and saved-view encode/decode behavior while
  the rest of the runtime still uses `view_config` as a compatibility shape.
  """

  alias SelectoComponents.Execution.CTEs
  alias SelectoComponents.Form.ParamsState
  alias SelectoComponents.Views.Runtime, as: ViewRuntime

  @spec filter_params_to_view_config(map(), Phoenix.LiveView.Socket.t()) :: map()
  def filter_params_to_view_config(params, socket) do
    filters = ParamsState.view_filter_process(params, "filters")

    %{
      Map.get(socket.assigns, :view_config, %{})
      | filters: filters
    }
  end

  @spec params_to_view_config(map(), Phoenix.LiveView.Socket.t()) :: map()
  def params_to_view_config(params, socket) do
    params =
      ParamsState.canonicalize_form_params(
        params,
        socket.assigns[:selecto],
        socket.assigns[:presentation_context]
      )

    filters = ParamsState.view_filter_process(params, "filters")
    existing_config = socket.assigns[:view_config] || %{}

    selected_view =
      SelectoComponents.SafeAtom.to_view_mode(
        Map.get(params, "view_mode", existing_config[:view_mode] || "aggregate")
      )

    view_configs =
      Enum.reduce(socket.assigns.views, %{}, fn {view, _module, _name, _opt} = view_tuple, acc ->
        Map.put(
          acc,
          view,
          updated_view_state(view, selected_view, view_tuple, params, existing_config, socket)
        )
      end)
      |> preserve_missing_detail_view_params(existing_config, params)

    provisional_config =
      Map.merge(existing_config, %{
        filters: filters,
        views: view_configs,
        view_mode: Map.get(params, "view_mode", existing_config[:view_mode] || "aggregate")
      })

    CTEs.sync_view_config(provisional_config, socket.assigns[:selecto])
  end

  @spec form_params_to_view_config(map(), Phoenix.LiveView.Socket.t()) :: map()
  def form_params_to_view_config(params, socket) do
    params =
      ParamsState.canonicalize_form_params(
        params,
        socket.assigns[:selecto],
        socket.assigns[:presentation_context]
      )

    existing_config = socket.assigns[:view_config] || %{}
    stale_submit? = stale_form_submit?(params, socket)
    filters = submitted_filters_state(params, existing_config, stale_submit?)

    view_configs =
      Enum.reduce(socket.assigns.views, %{}, fn {view, _module, _name, _opt} = view_tuple, acc ->
        Map.put(
          acc,
          view,
          submitted_view_state(view, view_tuple, params, existing_config, socket, stale_submit?)
        )
      end)
      |> preserve_missing_detail_view_params(existing_config, params)

    provisional_config =
      Map.merge(existing_config, %{
        filters: filters,
        views: view_configs,
        view_mode: Map.get(params, "view_mode", existing_config[:view_mode] || "aggregate")
      })

    CTEs.sync_view_config(provisional_config, socket.assigns[:selecto])
  end

  @spec view_config_to_saved_params(map()) :: map()
  def view_config_to_saved_params(view_config) when is_map(view_config) do
    %{
      "view_mode" => get_map_value(view_config, :view_mode, "aggregate"),
      "ctes" => normalize_saved_ctes_for_storage(get_map_value(view_config, :ctes, [])),
      "filters" => normalize_saved_filters_for_storage(get_map_value(view_config, :filters, [])),
      "views" => normalize_saved_views_for_storage(get_map_value(view_config, :views, %{}))
    }
  end

  def view_config_to_saved_params(view_config), do: view_config

  @spec saved_params_to_view_config(map(), Phoenix.LiveView.Socket.t()) :: map()
  def saved_params_to_view_config(saved_params, socket) when is_map(saved_params) do
    if Map.has_key?(saved_params, "views") or Map.has_key?(saved_params, :views) do
      existing_config = socket.assigns[:view_config] || %{}

      restored_config = %{
        view_mode:
          get_map_value(
            saved_params,
            :view_mode,
            get_map_value(existing_config, :view_mode, "aggregate")
          ),
        filters: normalize_saved_filters_from_storage(get_map_value(saved_params, :filters, [])),
        views: restore_saved_views(saved_params, existing_config, socket)
      }

      existing_config
      |> Map.merge(restored_config)
      |> CTEs.sync_view_config(socket.assigns[:selecto])
    else
      params_to_view_config(saved_params, socket)
    end
  end

  def saved_params_to_view_config(saved_params, socket),
    do: params_to_view_config(saved_params, socket)

  defp stale_form_submit?(params, socket) do
    case Map.get(params, "form_state_revision") do
      nil ->
        false

      submitted_revision ->
        normalize_form_state_revision(submitted_revision) != socket.assigns[:form_state_revision]
    end
  end

  defp normalize_form_state_revision(value) when is_integer(value), do: value

  defp normalize_form_state_revision(value) when is_binary(value) do
    case Integer.parse(value) do
      {parsed, ""} -> parsed
      _ -> 0
    end
  end

  defp normalize_form_state_revision(_value), do: 0

  defp submitted_view_state(view, view_tuple, params, existing_config, socket, stale_submit?) do
    existing_view = get_in(existing_config, [:views, view])

    cond do
      view_params_present?(view, params) ->
        submitted_view = ViewRuntime.param_to_state(view_tuple, params)

        if stale_submit? do
          merge_submitted_view_state(view, submitted_view, existing_view || %{}, params)
        else
          submitted_view
        end

      existing_view ->
        existing_view

      selecto = socket.assigns[:selecto] ->
        ViewRuntime.initial_state(view_tuple, selecto)

      true ->
        %{}
    end
  end

  defp view_params_present?(view, params) when is_map(params) do
    view_param_keys(view)
    |> Enum.any?(fn key -> Map.has_key?(params, key) end)
  end

  defp view_params_present?(_view, _params), do: false

  defp submitted_filters_state(params, existing_config, stale_submit?) do
    existing_filters = get_map_value(existing_config, :filters, [])

    if Map.has_key?(params, "filters") do
      submitted_filters = ParamsState.view_filter_process(params, "filters")

      if stale_submit? do
        merge_submitted_filters(submitted_filters, existing_filters)
      else
        submitted_filters
      end
    else
      existing_filters
    end
  end

  defp merge_submitted_filters([], existing_filters), do: existing_filters

  defp merge_submitted_filters(submitted_filters, existing_filters) do
    submitted_by_uuid =
      Map.new(submitted_filters, fn {uuid, section, value} ->
        {uuid, {section, value}}
      end)

    Enum.map(existing_filters, fn {uuid, section, value} = existing_filter ->
      case Map.get(submitted_by_uuid, uuid) do
        nil ->
          existing_filter

        {submitted_section, submitted_value} ->
          {uuid, submitted_section || section, merge_filter_value(value, submitted_value)}
      end
    end)
  end

  defp merge_filter_value(existing_value, submitted_value)
       when is_map(existing_value) and is_map(submitted_value) do
    Map.merge(existing_value, submitted_value)
  end

  defp merge_filter_value(_existing_value, submitted_value), do: submitted_value

  defp merge_submitted_view_state(view, submitted_view, existing_view, params) do
    state_keys =
      submitted_view_specs(view) |> Enum.map(fn {_type, _param_key, state_key} -> state_key end)

    merged_view = Map.merge(existing_view, Map.drop(submitted_view, state_keys))

    Enum.reduce(submitted_view_specs(view), merged_view, fn
      {:list, param_key, state_key}, acc ->
        if Map.has_key?(params, param_key) do
          submitted_items = Map.get(submitted_view, state_key, [])
          existing_items = Map.get(existing_view, state_key, [])
          Map.put(acc, state_key, merge_submitted_list_items(submitted_items, existing_items))
        else
          Map.put(
            acc,
            state_key,
            Map.get(existing_view, state_key, Map.get(submitted_view, state_key, []))
          )
        end

      {:scalar, param_key, state_key}, acc ->
        if Map.has_key?(params, param_key) do
          Map.put(acc, state_key, Map.get(submitted_view, state_key))
        else
          Map.put(
            acc,
            state_key,
            Map.get(existing_view, state_key, Map.get(submitted_view, state_key))
          )
        end
    end)
  end

  defp merge_submitted_list_items([], existing_items), do: existing_items

  defp merge_submitted_list_items(submitted_items, existing_items) do
    submitted_by_uuid = Map.new(submitted_items, fn item -> {list_item_uuid(item), item} end)

    Enum.map(existing_items, fn existing_item ->
      case Map.get(submitted_by_uuid, list_item_uuid(existing_item)) do
        nil -> existing_item
        submitted_item -> merge_list_item(existing_item, submitted_item)
      end
    end)
  end

  defp merge_list_item(
         {uuid, field, existing_config},
         {_submitted_uuid, _submitted_field, submitted_config}
       )
       when is_map(existing_config) and is_map(submitted_config) do
    {uuid, field, Map.merge(existing_config, submitted_config)}
  end

  defp merge_list_item([uuid, field, existing_config], [
         _submitted_uuid,
         _submitted_field,
         submitted_config
       ])
       when is_map(existing_config) and is_map(submitted_config) do
    [uuid, field, Map.merge(existing_config, submitted_config)]
  end

  defp merge_list_item(existing_item, _submitted_item), do: existing_item

  defp list_item_uuid({uuid, _field, _config}), do: uuid
  defp list_item_uuid([uuid, _field, _config]), do: uuid
  defp list_item_uuid(other), do: other

  defp submitted_view_specs(:detail) do
    [
      {:list, "selected", :selected},
      {:list, "order_by", :order_by},
      {:scalar, "per_page", :per_page},
      {:scalar, "max_rows", :max_rows},
      {:scalar, "count_mode", :count_mode},
      {:scalar, "row_click_action", :row_click_action},
      {:scalar, "prevent_denormalization", :prevent_denormalization}
    ]
  end

  defp submitted_view_specs(:aggregate) do
    [
      {:list, "group_by", :group_by},
      {:list, "aggregate", :aggregate},
      {:scalar, "aggregate_per_page", :per_page},
      {:scalar, "aggregate_grid", :grid},
      {:scalar, "aggregate_grid_colorize", :grid_colorize},
      {:scalar, "aggregate_grid_color_scale", :grid_color_scale}
    ]
  end

  defp submitted_view_specs(:graph) do
    [
      {:list, "x_axis", :x_axis},
      {:list, "y_axis", :y_axis},
      {:list, "series", :series},
      {:list, "color_by", :color_by},
      {:scalar, "chart_type", :chart_type},
      {:scalar, "options", :options}
    ]
  end

  defp submitted_view_specs(_view), do: []

  defp view_param_keys(:detail),
    do: [
      "selected",
      "order_by",
      "per_page",
      "max_rows",
      "count_mode",
      "row_click_action",
      "prevent_denormalization"
    ]

  defp view_param_keys(:aggregate),
    do: [
      "group_by",
      "aggregate",
      "aggregate_per_page",
      "aggregate_grid",
      "aggregate_grid_colorize",
      "aggregate_grid_color_scale"
    ]

  defp view_param_keys(:graph),
    do: ["x_axis", "y_axis", "series", "color_by", "chart_type", "options"]

  defp view_param_keys(:map),
    do: [
      "map_layers",
      "geometry_field",
      "popup_field",
      "color_field",
      "tile_url",
      "attribution",
      "background_mode",
      "coordinate_mode",
      "image_overlay_url",
      "image_overlay_bounds",
      "image_overlay_opacity",
      "image_overlay_rotation",
      "default_zoom",
      "center_lat",
      "center_lng",
      "fit_bounds",
      "max_points",
      "cluster"
    ]

  defp view_param_keys(_view), do: []

  defp updated_view_state(view, selected_view, view_tuple, params, existing_config, socket) do
    cond do
      view == selected_view ->
        ViewRuntime.param_to_state(view_tuple, params)

      existing_view = get_in(existing_config, [:views, view]) ->
        existing_view

      selecto = socket.assigns[:selecto] ->
        ViewRuntime.initial_state(view_tuple, selecto)

      true ->
        %{}
    end
  end

  defp normalize_saved_views_for_storage(views) when is_map(views) do
    Map.new(views, fn {key, value} -> {to_string(key), normalize_saved_term(value)} end)
  end

  defp normalize_saved_views_for_storage(_views), do: %{}
  defp normalize_saved_ctes_for_storage(ctes) when is_list(ctes), do: normalize_saved_term(ctes)
  defp normalize_saved_ctes_for_storage(_ctes), do: []

  defp normalize_saved_filters_for_storage(filters) when is_list(filters) do
    Enum.map(filters, &normalize_saved_term/1)
  end

  defp normalize_saved_filters_for_storage(_filters), do: []

  defp normalize_saved_term(term) when is_map(term) do
    Map.new(term, fn {key, value} -> {to_string(key), normalize_saved_term(value)} end)
  end

  defp normalize_saved_term(term) when is_list(term), do: Enum.map(term, &normalize_saved_term/1)

  defp normalize_saved_term(term) when is_tuple(term),
    do: term |> Tuple.to_list() |> normalize_saved_term()

  defp normalize_saved_term(term), do: term

  defp normalize_saved_filters_from_storage(filters) when is_list(filters) do
    Enum.map(filters, fn
      [uuid, section, filter_data] -> {uuid, section, filter_data}
      {uuid, section, filter_data} -> {uuid, section, filter_data}
      other -> other
    end)
  end

  defp normalize_saved_filters_from_storage(_filters), do: []

  defp restore_saved_views(saved_params, existing_config, socket) do
    Enum.reduce(socket.assigns.views, %{}, fn {view, _module, _name, _opt} = view_tuple, acc ->
      restored_view =
        case get_in(saved_params, ["views", Atom.to_string(view)]) ||
               get_in(saved_params, [:views, view]) do
          nil ->
            get_in(existing_config, [:views, view]) ||
              if(socket.assigns[:selecto],
                do: ViewRuntime.initial_state(view_tuple, socket.assigns.selecto),
                else: %{}
              )

          saved_view ->
            saved_view
            |> normalize_saved_term()
            |> normalize_restored_view(view)
        end

      Map.put(acc, view, restored_view)
    end)
  end

  defp normalize_restored_view(saved_view, :detail) when is_map(saved_view) do
    normalize_saved_boolean(saved_view, :prevent_denormalization, true)
  end

  defp normalize_restored_view(saved_view, _view), do: saved_view

  defp normalize_saved_boolean(saved_view, key, default) do
    current_value = Map.get(saved_view, key, Map.get(saved_view, to_string(key), default))
    normalized_value = normalize_saved_boolean_value(current_value, default)

    saved_view
    |> Map.put(key, normalized_value)
    |> Map.put(to_string(key), normalized_value)
  end

  defp normalize_saved_boolean_value(value, _default) when value in [true, "true", "on", 1, "1"],
    do: true

  defp normalize_saved_boolean_value(value, _default) when value in [false, "false", 0, "0"],
    do: false

  defp normalize_saved_boolean_value([value | _rest], default),
    do: normalize_saved_boolean_value(value, default)

  defp normalize_saved_boolean_value(nil, default), do: default
  defp normalize_saved_boolean_value(_value, default), do: default

  defp preserve_missing_detail_view_params(view_configs, existing_config, params) do
    existing_detail = get_in(existing_config, [:views, :detail]) || %{}
    detail_config = Map.get(view_configs, :detail, %{})

    detail_config =
      detail_config
      |> preserve_scalar_when_missing(existing_detail, params, "row_click_action")
      |> preserve_scalar_when_missing(existing_detail, params, "per_page")
      |> preserve_scalar_when_missing(existing_detail, params, "max_rows")
      |> preserve_scalar_when_missing(existing_detail, params, "count_mode")
      |> preserve_scalar_when_missing(existing_detail, params, "prevent_denormalization")

    Map.put(view_configs, :detail, detail_config)
  end

  defp preserve_scalar_when_missing(detail_config, existing_detail, params, param_key) do
    if is_map(params) and Map.has_key?(params, param_key) do
      detail_config
    else
      preserve_scalar_from_existing(detail_config, existing_detail, param_key)
    end
  end

  defp preserve_scalar_from_existing(detail_config, existing_detail, param_key) do
    param_atom = detail_param_atom(param_key)
    existing_value = Map.get(existing_detail, param_atom, Map.get(existing_detail, param_key))

    if is_nil(existing_value),
      do: detail_config,
      else: Map.put(detail_config, param_atom, existing_value)
  end

  defp detail_param_atom("row_click_action"), do: :row_click_action
  defp detail_param_atom("per_page"), do: :per_page
  defp detail_param_atom("max_rows"), do: :max_rows
  defp detail_param_atom("count_mode"), do: :count_mode
  defp detail_param_atom("prevent_denormalization"), do: :prevent_denormalization

  defp get_map_value(map, key, default) when is_map(map) do
    Map.get(map, key, Map.get(map, to_string(key), default))
  end

  defp get_map_value(_map, _key, default), do: default
end
