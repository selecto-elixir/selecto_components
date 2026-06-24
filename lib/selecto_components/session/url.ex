defmodule SelectoComponents.Session.URL do
  @moduledoc """
  URL transport helpers for SelectoComponents session/view state.
  """

  alias SelectoComponents.SafeAtom
  alias SelectoComponents.Views.Aggregate.Options, as: AggregateOptions
  alias SelectoComponents.Views.Detail.Options, as: DetailOptions

  @map_param_keys ~w(
    geometry_field popup_field color_field tile_url attribution background_mode
    coordinate_mode image_overlay_url image_overlay_bounds image_overlay_opacity
    image_overlay_rotation default_zoom center_lat center_lng fit_bounds max_points cluster
  )
  @map_boolean_param_keys ~w(fit_bounds cluster)

  def view_config_to_params(view_config) do
    view_mode = get_map_value(view_config, :view_mode, "aggregate")
    ctes = get_map_value(view_config, :ctes, [])
    filters = get_map_value(view_config, :filters, [])
    views = get_map_value(view_config, :views, %{})

    params = %{
      "view_mode" => view_mode,
      "ctes" => ctes_to_params(ctes),
      "filters" => filters_to_params(filters)
    }

    view_params =
      views
      |> Enum.reduce(%{}, fn {view_key, view_data}, acc ->
        view = SafeAtom.to_view_mode(view_key)
        Map.merge(acc, view_data_to_params(view, view_data))
      end)

    Map.merge(params, view_params)
  end

  def state_to_url(params, socket, opts \\ []) do
    params = params |> compact_url_params() |> merge_passthrough_url_params(socket)
    params_encoded = Plug.Conn.Query.encode(params)
    full_path = "#{socket.assigns.my_path}?#{params_encoded}"
    Phoenix.LiveView.push_patch(socket, Keyword.merge([to: full_path], opts))
  end

  def compact_url_params(params) when is_map(params) do
    Enum.reduce(url_compactable_keys(), params, fn key, acc ->
      case Map.get(acc, key) do
        section when is_map(section) -> Map.put(acc, key, compact_param_section(section))
        _ -> acc
      end
    end)
  end

  def compact_url_params(params), do: params

  defp view_data_to_params(_view, nil), do: %{}

  defp view_data_to_params(view, view_data) when is_map(view_data) do
    Enum.reduce(view_data, %{}, fn {list_name, items}, acc ->
      cond do
        view == :map and list_name in [:map_layers, "map_layers"] ->
          merge_scalar_view_param(acc, view, list_name, items)

        view == :map ->
          merge_scalar_view_param(acc, view, list_name, items)

        is_list(items) ->
          Map.put(acc, to_string(list_name), view_items_to_params(items))

        true ->
          merge_scalar_view_param(acc, view, list_name, items)
      end
    end)
  end

  defp view_data_to_params(_view, _view_data), do: %{}

  defp view_items_to_params(items) do
    items
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn
      {{id, field, config}, index}, acc ->
        Map.put(
          acc,
          compact_param_key(index),
          Map.merge(config, %{"uuid" => id, "field" => field, "index" => to_string(index)})
        )

      {[id, field, config], index}, acc ->
        Map.put(
          acc,
          compact_param_key(index),
          Map.merge(config, %{"uuid" => id, "field" => field, "index" => to_string(index)})
        )

      {_unknown_item, _index}, acc ->
        acc
    end)
  end

  defp ctes_to_params(ctes) when is_list(ctes) do
    ctes
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn
      {{uuid, name, config}, index}, acc ->
        Map.put(
          acc,
          compact_param_key(index),
          Map.merge(stringify_map_keys(config), %{
            "uuid" => uuid,
            "name" => name,
            "index" => to_string(index)
          })
        )

      {[uuid, name, config], index}, acc ->
        Map.put(
          acc,
          compact_param_key(index),
          Map.merge(stringify_map_keys(config), %{
            "uuid" => uuid,
            "name" => name,
            "index" => to_string(index)
          })
        )

      {_unknown_item, _index}, acc ->
        acc
    end)
  end

  defp ctes_to_params(_ctes), do: %{}

  defp filters_to_params(filters) do
    filters
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn
      {{uuid, section, filter_data}, index}, acc ->
        Map.put(
          acc,
          compact_param_key(index),
          build_filter_params(uuid, section, filter_data, index)
        )

      {[uuid, section, filter_data], index}, acc ->
        Map.put(
          acc,
          compact_param_key(index),
          build_filter_params(uuid, section, filter_data, index)
        )
    end)
  end

  defp build_filter_params(uuid, section, filter_data, index) do
    case filter_data do
      conj when is_binary(conj) ->
        %{
          "uuid" => uuid,
          "conjunction" => conj,
          "is_section" => "Y",
          "section" => section,
          "index" => to_string(index)
        }

      filter_map when is_map(filter_map) ->
        Map.merge(normalize_filter_storage_state(filter_map), %{
          "uuid" => uuid,
          "section" => section,
          "index" => to_string(index)
        })
    end
  end

  defp normalize_filter_storage_state(filter_map) when is_map(filter_map),
    do: Map.new(filter_map, fn {key, value} -> {to_string(key), value} end)

  defp merge_scalar_view_param(acc, :aggregate, key, value) when key in [:per_page, "per_page"],
    do: Map.put(acc, "aggregate_per_page", AggregateOptions.normalize_per_page_param(value))

  defp merge_scalar_view_param(acc, :aggregate, key, value) when key in [:grid, "grid"],
    do: Map.put(acc, "aggregate_grid", to_string(value))

  defp merge_scalar_view_param(acc, :aggregate, key, value)
       when key in [:grid_colorize, "grid_colorize"],
       do: Map.put(acc, "aggregate_grid_colorize", to_string(value))

  defp merge_scalar_view_param(acc, :aggregate, key, value)
       when key in [:grid_color_scale, "grid_color_scale"],
       do:
         Map.put(
           acc,
           "aggregate_grid_color_scale",
           AggregateOptions.normalize_grid_color_scale_mode(value)
         )

  defp merge_scalar_view_param(acc, :detail, key, value) when key in [:max_rows, "max_rows"],
    do: Map.put(acc, "max_rows", DetailOptions.normalize_max_rows_param(value))

  defp merge_scalar_view_param(acc, :detail, key, value) when key in [:count_mode, "count_mode"],
    do: Map.put(acc, "count_mode", DetailOptions.normalize_count_mode_param(value))

  defp merge_scalar_view_param(acc, :detail, key, value)
       when key in [:row_click_action, "row_click_action"],
       do: maybe_put_param(acc, "row_click_action", normalize_optional_scalar(value))

  defp merge_scalar_view_param(acc, :map, key, value) when key in [:center, "center"],
    do: maybe_put_center_params(acc, value)

  defp merge_scalar_view_param(acc, :map, key, value) when key in [:map_layers, "map_layers"],
    do: maybe_put_param(acc, "map_layers", normalize_map_layers_param(value))

  defp merge_scalar_view_param(acc, :map, key, value) do
    case map_param_key(key) do
      nil -> acc
      param_key -> maybe_put_param(acc, param_key, normalize_map_param_value(param_key, value))
    end
  end

  defp merge_scalar_view_param(acc, _selected_view, key, value)
       when key in [:per_page, "per_page"],
       do: Map.put(acc, "per_page", normalize_per_page_param(value, "30"))

  defp merge_scalar_view_param(acc, _selected_view, key, value)
       when key in [:prevent_denormalization, "prevent_denormalization"],
       do: Map.put(acc, "prevent_denormalization", to_string(value))

  defp merge_scalar_view_param(acc, _selected_view, _key, _value), do: acc

  defp compact_param_section(section) when is_map(section) do
    section
    |> Enum.sort_by(fn {_k, v} -> sort_index_for_compaction(v) end)
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {{original_key, value}, index}, acc ->
      compacted_value =
        if is_map(value), do: Map.put_new(value, "uuid", original_key), else: value

      Map.put(acc, compact_param_key(index), compacted_value)
    end)
  end

  defp merge_passthrough_url_params(params, socket) do
    existing_params = Map.get(socket.assigns, :params, %{})

    passthrough_keys =
      ["selecto_theme", "selecto_debug", "debug", "debug_token"] ++
        normalize_passthrough_keys(Map.get(socket.assigns, :url_passthrough_params, []))

    passthrough_params =
      passthrough_keys
      |> Enum.uniq()
      |> Enum.reduce(%{}, fn key, acc ->
        case get_map_value(existing_params, key) do
          nil -> acc
          "" -> acc
          value -> Map.put(acc, to_string(key), value)
        end
      end)

    Map.merge(passthrough_params, params)
  end

  defp normalize_passthrough_keys(keys) when is_list(keys), do: Enum.map(keys, &to_string/1)
  defp normalize_passthrough_keys(_keys), do: []

  defp url_compactable_keys,
    do: [
      "ctes",
      "filters",
      "selected",
      "order_by",
      "group_by",
      "aggregate",
      "x_axis",
      "y_axis",
      "series"
    ]

  defp compact_param_key(index) when is_integer(index), do: "k" <> Integer.to_string(index, 36)

  defp maybe_put_center_params(params, center_value) do
    case parse_center_value(center_value) do
      {lat, lng} ->
        params
        |> maybe_put_param("center_lat", normalize_map_param_value("center_lat", lat), false)
        |> maybe_put_param("center_lng", normalize_map_param_value("center_lng", lng), false)

      _ ->
        params
    end
  end

  defp parse_center_value({lat, lng}), do: {lat, lng}
  defp parse_center_value([lat, lng]), do: {lat, lng}

  defp parse_center_value(center_value) when is_map(center_value),
    do: {get_map_value(center_value, :lat), get_map_value(center_value, :lng)}

  defp parse_center_value(center_value) when is_binary(center_value) do
    case String.split(center_value, ",", parts: 2) do
      [lat, lng] -> {lat, lng}
      _ -> nil
    end
  end

  defp parse_center_value(_), do: nil
  defp maybe_put_param(params, _key, nil, _replace?), do: params
  defp maybe_put_param(params, key, value, true), do: Map.put(params, key, value)

  defp maybe_put_param(params, key, value, false),
    do: if(Map.has_key?(params, key), do: params, else: Map.put(params, key, value))

  defp maybe_put_param(params, key, value), do: maybe_put_param(params, key, value, true)
  defp map_param_key(key) when is_atom(key), do: map_param_key(Atom.to_string(key))
  defp map_param_key(key) when is_binary(key), do: if(key in @map_param_keys, do: key, else: nil)
  defp map_param_key(_), do: nil

  defp normalize_map_param_value(key, value) when key in @map_boolean_param_keys,
    do: normalize_map_boolean(value)

  defp normalize_map_param_value("image_overlay_bounds", value), do: normalize_map_bounds(value)
  defp normalize_map_param_value(_key, value), do: normalize_map_scalar(value)

  defp normalize_map_layers_param(layers) when is_list(layers),
    do:
      layers
      |> Enum.with_index()
      |> Enum.into(%{}, fn {layer, index} ->
        {Integer.to_string(index), normalize_map_layer_param(layer)}
      end)

  defp normalize_map_layers_param(_), do: %{}

  defp normalize_map_layer_param(layer) when is_map(layer) do
    %{}
    |> maybe_put_param("label", normalize_map_scalar(get_map_value(layer, :label)))
    |> maybe_put_param(
      "geometry_field",
      normalize_map_scalar(get_map_value(layer, :geometry_field))
    )
    |> maybe_put_param(
      "geometry_kind",
      normalize_map_scalar(get_map_value(layer, :geometry_kind))
    )
    |> maybe_put_param("popup_field", normalize_map_scalar(get_map_value(layer, :popup_field)))
    |> maybe_put_param("color_field", normalize_map_scalar(get_map_value(layer, :color_field)))
    |> maybe_put_param("scale_type", normalize_map_scalar(get_map_value(layer, :scale_type)))
    |> maybe_put_param(
      "scale_palette",
      normalize_map_scalar(get_map_value(layer, :scale_palette))
    )
    |> maybe_put_param("scale_steps", normalize_map_scalar(get_map_value(layer, :scale_steps)))
    |> maybe_put_param(
      "scale_categories",
      normalize_map_scalar(get_map_value(layer, :scale_categories))
    )
    |> maybe_put_param("track_by", normalize_map_scalar(get_map_value(layer, :track_by)))
    |> maybe_put_param(
      "track_order_field",
      normalize_map_scalar(get_map_value(layer, :track_order_field))
    )
    |> maybe_put_param("point_radius", normalize_map_scalar(get_map_value(layer, :point_radius)))
    |> maybe_put_param("line_weight", normalize_map_scalar(get_map_value(layer, :line_weight)))
    |> maybe_put_param(
      "line_dash_array",
      normalize_map_scalar(get_map_value(layer, :line_dash_array))
    )
    |> maybe_put_param("fill_opacity", normalize_map_scalar(get_map_value(layer, :fill_opacity)))
    |> maybe_put_param(
      "stroke_opacity",
      normalize_map_scalar(get_map_value(layer, :stroke_opacity))
    )
    |> maybe_put_param("visible", normalize_map_boolean(get_map_value(layer, :visible)))
  end

  defp normalize_map_layer_param(_), do: %{}
  defp normalize_per_page_param(nil, default), do: default

  defp normalize_per_page_param(value, default) when is_binary(value),
    do: if(byte_size(String.trim(value)) > 0, do: String.trim(value), else: default)

  defp normalize_per_page_param(value, _default) when is_integer(value), do: to_string(value)
  defp normalize_per_page_param(value, _default) when is_atom(value), do: Atom.to_string(value)
  defp normalize_per_page_param(_value, default), do: default
  defp normalize_optional_scalar(nil), do: nil

  defp normalize_optional_scalar(value) when is_binary(value),
    do: if(String.trim(value) == "", do: nil, else: String.trim(value))

  defp normalize_optional_scalar(value) when is_atom(value),
    do: value |> Atom.to_string() |> normalize_optional_scalar()

  defp normalize_optional_scalar(value) when is_integer(value), do: Integer.to_string(value)
  defp normalize_optional_scalar(value) when is_float(value), do: to_string(value)
  defp normalize_optional_scalar(_value), do: nil
  defp normalize_map_bounds(nil), do: nil

  defp normalize_map_bounds([[south, west], [north, east]]),
    do:
      [south, west, north, east]
      |> Enum.map(&normalize_map_scalar/1)
      |> then(fn values ->
        if Enum.any?(values, &is_nil/1), do: nil, else: Enum.join(values, ",")
      end)

  defp normalize_map_bounds([south, west, north, east]),
    do:
      [south, west, north, east]
      |> Enum.map(&normalize_map_scalar/1)
      |> then(fn values ->
        if Enum.any?(values, &is_nil/1), do: nil, else: Enum.join(values, ",")
      end)

  defp normalize_map_bounds(value) when is_binary(value), do: normalize_map_scalar(value)
  defp normalize_map_bounds(_value), do: nil
  defp normalize_map_boolean(value) when value in [true, "true", "on", "1", 1], do: "true"
  defp normalize_map_boolean(value) when value in [false, "false", "off", "0", 0], do: "false"
  defp normalize_map_boolean(_value), do: nil
  defp normalize_map_scalar(nil), do: nil

  defp normalize_map_scalar(value) when is_binary(value),
    do: if(String.trim(value) == "", do: nil, else: String.trim(value))

  defp normalize_map_scalar(value) when is_boolean(value), do: to_string(value)

  defp normalize_map_scalar(value) when is_atom(value),
    do: value |> Atom.to_string() |> normalize_map_scalar()

  defp normalize_map_scalar(value) when is_integer(value), do: Integer.to_string(value)

  defp normalize_map_scalar(value) when is_float(value),
    do: value |> Float.round(6) |> to_string()

  defp normalize_map_scalar(_value), do: nil

  defp sort_index_for_compaction(%{"index" => index}) when is_binary(index) do
    case Integer.parse(index) do
      {parsed, ""} -> parsed
      _ -> 0
    end
  end

  defp sort_index_for_compaction(%{index: index}) when is_binary(index),
    do: sort_index_for_compaction(%{"index" => index})

  defp sort_index_for_compaction(_value), do: 0

  defp stringify_map_keys(map) when is_map(map),
    do: Map.new(map, fn {k, v} -> {to_string(k), v} end)

  defp stringify_map_keys(other), do: other
  defp get_map_value(map, key, default \\ nil)

  defp get_map_value(map, key, default) when is_map(map),
    do: Map.get(map, key, Map.get(map, to_string(key), default))

  defp get_map_value(_map, _key, default), do: default
end
