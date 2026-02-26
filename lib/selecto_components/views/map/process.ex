defmodule SelectoComponents.Views.Map.Process do
  @moduledoc false

  @default_tile_url "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
  @default_attribution "&copy; OpenStreetMap contributors"
  @default_zoom 3
  @default_max_points 2000

  def param_to_state(params, _view) do
    %{
      geometry_field: Map.get(params, "geometry_field"),
      popup_field: blank_to_nil(Map.get(params, "popup_field")),
      color_field: blank_to_nil(Map.get(params, "color_field")),
      tile_url: blank_to_nil(Map.get(params, "tile_url")),
      attribution: blank_to_nil(Map.get(params, "attribution")),
      default_zoom: parse_integer(Map.get(params, "default_zoom"), nil),
      center_lat: parse_float(Map.get(params, "center_lat"), nil),
      center_lng: parse_float(Map.get(params, "center_lng"), nil),
      fit_bounds: parse_bool(Map.get(params, "fit_bounds"), nil),
      max_points: parse_integer(Map.get(params, "max_points"), nil)
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  def initial_state(selecto, _view) do
    domain = Selecto.domain(selecto)
    map_view = map_view_config(domain)
    center = normalize_center(Map.get(map_view, :center, {0.0, 0.0}))

    %{
      geometry_field:
        first_non_nil([
          Map.get(map_view, :geometry_field),
          Map.get(domain, :default_map_geometry_field),
          first_spatial_field(selecto)
        ]),
      popup_field:
        first_non_nil([
          Map.get(map_view, :popup_field),
          Map.get(domain, :default_map_popup_field)
        ]),
      color_field:
        first_non_nil([
          Map.get(map_view, :color_field),
          Map.get(domain, :default_map_color_field)
        ]),
      tile_url:
        first_non_nil([
          Map.get(map_view, :tile_url),
          Map.get(domain, :default_map_tile_url),
          @default_tile_url
        ]),
      attribution:
        first_non_nil([
          Map.get(map_view, :attribution),
          Map.get(domain, :default_map_attribution),
          @default_attribution
        ]),
      default_zoom:
        first_non_nil([
          Map.get(map_view, :default_zoom),
          Map.get(domain, :default_map_zoom),
          @default_zoom
        ]),
      center_lat: elem(center, 0),
      center_lng: elem(center, 1),
      fit_bounds:
        first_non_nil([
          Map.get(map_view, :fit_bounds),
          Map.get(domain, :default_map_fit_bounds),
          true
        ]),
      max_points:
        first_non_nil([
          Map.get(map_view, :max_points),
          Map.get(domain, :default_map_limit),
          @default_max_points
        ])
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  def view(_opt, params, columns, filtered, selecto) do
    initial = initial_state(selecto, nil)
    incoming = param_to_state(params, nil)
    config = Map.merge(initial, incoming)

    geometry_field = resolve_geometry_field(config[:geometry_field], columns, selecto)
    popup_field = resolve_optional_field(config[:popup_field], columns)
    color_field = resolve_optional_field(config[:color_field], columns)

    selected =
      [
        {:field, {:st_asgeojson, geometry_field}, "__map_geometry"}
      ] ++
        optional_select_field(popup_field, "__map_popup") ++
        optional_select_field(color_field, "__map_color")

    center =
      normalize_center({Map.get(config, :center_lat), Map.get(config, :center_lng)})

    view_set = %{
      selected: selected,
      filtered: filtered,
      limit: Map.get(config, :max_points, @default_max_points),
      map_geometry_field: geometry_field,
      map_popup_field: popup_field,
      map_color_field: color_field,
      map_tile_url: Map.get(config, :tile_url, @default_tile_url),
      map_attribution: Map.get(config, :attribution, @default_attribution),
      map_zoom: Map.get(config, :default_zoom, @default_zoom),
      map_center: center,
      map_fit_bounds: Map.get(config, :fit_bounds, true),
      map_max_points: Map.get(config, :max_points, @default_max_points)
    }

    {view_set, %{}}
  end

  defp optional_select_field(nil, _alias_name), do: []
  defp optional_select_field(field, alias_name), do: [{:field, field, alias_name}]

  defp resolve_geometry_field(nil, _columns, selecto), do: first_spatial_field(selecto)

  defp resolve_geometry_field(field, columns, selecto) do
    resolve_optional_field(field, columns) || first_spatial_field(selecto)
  end

  defp resolve_optional_field(nil, _columns), do: nil
  defp resolve_optional_field("", _columns), do: nil

  defp resolve_optional_field(field, columns) do
    cond do
      Map.has_key?(columns, field) ->
        field

      Map.has_key?(columns, to_string(field)) ->
        to_string(field)

      true ->
        Enum.find_value(columns, fn {key, col} ->
          if to_string(key) == to_string(field) or col.name == to_string(field),
            do: key,
            else: nil
        end)
    end
  end

  defp first_spatial_field(selecto) do
    selecto
    |> Selecto.columns()
    |> Enum.find_value(fn {field, col} ->
      if spatial_type?(Map.get(col, :type)), do: field, else: nil
    end)
  end

  defp map_view_config(domain) do
    domain
    |> Map.get(:postgis, %{})
    |> Map.get(:map_view, %{})
  end

  defp normalize_center({lat, lng}) when is_number(lat) and is_number(lng),
    do: {lat * 1.0, lng * 1.0}

  defp normalize_center(_), do: {0.0, 0.0}

  defp parse_integer(nil, default), do: default
  defp parse_integer(value, _default) when is_integer(value), do: value

  defp parse_integer(value, default) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {parsed, ""} -> parsed
      _ -> default
    end
  end

  defp parse_integer(_, default), do: default

  defp parse_float(nil, default), do: default
  defp parse_float(value, _default) when is_float(value), do: value
  defp parse_float(value, _default) when is_integer(value), do: value * 1.0

  defp parse_float(value, default) when is_binary(value) do
    case Float.parse(String.trim(value)) do
      {parsed, ""} -> parsed
      _ -> default
    end
  end

  defp parse_float(_, default), do: default

  defp parse_bool(nil, default), do: default
  defp parse_bool(value, _default) when value in [true, "true", "on", "1", 1], do: true
  defp parse_bool(value, _default) when value in [false, "false", "off", "0", 0], do: false
  defp parse_bool(_, default), do: default

  defp blank_to_nil(value) when is_binary(value) do
    trimmed = String.trim(value)
    if trimmed == "", do: nil, else: trimmed
  end

  defp blank_to_nil(value), do: value

  defp spatial_type?(type) when is_atom(type) do
    Selecto.TypeSystem.type_category(type) == :spatial
  end

  defp spatial_type?(type) when is_binary(type) do
    type
    |> Selecto.TypeSystem.parse_sql_type()
    |> Selecto.TypeSystem.type_category()
    |> Kernel.==(:spatial)
  end

  defp spatial_type?(_), do: false

  defp first_non_nil(values) do
    Enum.find(values, fn value -> not is_nil(value) end)
  end
end
