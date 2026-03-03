defmodule SelectoComponents.Views.Map.Process do
  @moduledoc false

  @default_tile_url "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
  @default_attribution "&copy; OpenStreetMap contributors"
  @default_zoom 3
  @default_max_points 2000
  @default_center {0.0, 0.0}
  @default_fit_bounds true
  @default_cluster false
  @min_zoom 1
  @max_zoom 20

  @config_keys [
    :geometry_field,
    :popup_field,
    :color_field,
    :tile_url,
    :attribution,
    :default_zoom,
    :center_lat,
    :center_lng,
    :fit_bounds,
    :max_points,
    :cluster
  ]

  @default_config %{
    tile_url: @default_tile_url,
    attribution: @default_attribution,
    default_zoom: @default_zoom,
    center_lat: elem(@default_center, 0),
    center_lng: elem(@default_center, 1),
    fit_bounds: @default_fit_bounds,
    max_points: @default_max_points,
    cluster: @default_cluster
  }

  def config_keys, do: @config_keys

  def normalize_config(config) when is_map(config) do
    center = config |> get_map_value(:center) |> normalize_center_value()

    %{
      geometry_field:
        config
        |> get_map_value(:geometry_field)
        |> normalize_field(),
      popup_field:
        config
        |> get_map_value(:popup_field)
        |> normalize_field(),
      color_field:
        config
        |> get_map_value(:color_field)
        |> normalize_field(),
      tile_url:
        config
        |> get_map_value(:tile_url)
        |> normalize_text(),
      attribution:
        config
        |> get_map_value(:attribution)
        |> normalize_text(),
      default_zoom:
        config
        |> get_map_value(:default_zoom)
        |> parse_integer(nil)
        |> normalize_zoom(),
      center_lat:
        first_non_nil([
          config
          |> get_map_value(:center_lat)
          |> parse_float(nil)
          |> normalize_lat(),
          maybe_elem(center, 0)
        ]),
      center_lng:
        first_non_nil([
          config
          |> get_map_value(:center_lng)
          |> parse_float(nil)
          |> normalize_lng(),
          maybe_elem(center, 1)
        ]),
      fit_bounds:
        config
        |> get_map_value(:fit_bounds)
        |> parse_bool(nil),
      max_points:
        config
        |> get_map_value(:max_points)
        |> parse_integer(nil)
        |> normalize_max_points(),
      cluster:
        config
        |> get_map_value(:cluster)
        |> parse_bool(nil)
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  def normalize_config(_), do: %{}

  def param_to_state(params, _view) do
    normalize_config(params)
  end

  def initial_state(selecto, view_options) do
    domain = Selecto.domain(selecto)

    merged_config =
      merge_non_nil_configs([
        @default_config,
        domain_defaults_config(domain),
        normalize_config(map_view_config(domain)),
        normalize_config(extract_option_config(view_options))
      ])

    merged_config
    |> Map.put(
      :geometry_field,
      first_non_nil([Map.get(merged_config, :geometry_field), first_spatial_field(selecto)])
    )
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  def view(opt, params, columns, filtered, selecto) do
    initial = initial_state(selecto, opt)
    incoming = param_to_state(params, opt)
    config = merge_non_nil_configs([initial, incoming])

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

    base_set = Map.get(selecto, :set, %{})

    view_set =
      base_set
      |> Map.merge(%{
        selected: selected,
        filtered: filtered,
        group_by: [],
        order_by: Map.get(base_set, :order_by, []),
        aggregates: [],
        limit: Map.get(config, :max_points, @default_max_points),
        map_geometry_field: geometry_field,
        map_popup_field: popup_field,
        map_color_field: color_field,
        map_tile_url: Map.get(config, :tile_url, @default_tile_url),
        map_attribution: Map.get(config, :attribution, @default_attribution),
        map_zoom: Map.get(config, :default_zoom, @default_zoom),
        map_center: center,
        map_fit_bounds: Map.get(config, :fit_bounds, true),
        map_max_points: Map.get(config, :max_points, @default_max_points),
        map_cluster: Map.get(config, :cluster, @default_cluster)
      })

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
    merge_non_nil_configs([
      get_map_value(domain, :map_view, %{}),
      domain
      |> Map.get(:postgis, %{})
      |> get_map_value(:map_view, %{})
    ])
  end

  defp domain_defaults_config(domain) do
    normalize_config(%{
      geometry_field: get_map_value(domain, :default_map_geometry_field),
      popup_field: get_map_value(domain, :default_map_popup_field),
      color_field: get_map_value(domain, :default_map_color_field),
      tile_url: get_map_value(domain, :default_map_tile_url),
      attribution: get_map_value(domain, :default_map_attribution),
      default_zoom: get_map_value(domain, :default_map_zoom),
      center: get_map_value(domain, :default_map_center),
      fit_bounds: get_map_value(domain, :default_map_fit_bounds),
      max_points: get_map_value(domain, :default_map_limit),
      cluster: get_map_value(domain, :default_map_cluster)
    })
  end

  defp extract_option_config(options) when is_map(options) do
    map_view_opts = get_map_value(options, :map_view)
    map_opts = get_map_value(options, :map)

    cond do
      is_map(map_view_opts) -> merge_non_nil_configs([options, map_view_opts])
      is_map(map_opts) -> merge_non_nil_configs([options, map_opts])
      true -> options
    end
  end

  defp extract_option_config(_), do: %{}

  defp normalize_center_value({lat, lng}), do: normalize_center({lat, lng})

  defp normalize_center_value([lat, lng]) do
    normalize_center({lat, lng})
  end

  defp normalize_center_value(%{} = center) do
    normalize_center({get_map_value(center, :lat), get_map_value(center, :lng)})
  end

  defp normalize_center_value(center) when is_binary(center) do
    case String.split(center, ",", parts: 2) do
      [lat, lng] -> normalize_center({lat, lng})
      _ -> nil
    end
  end

  defp normalize_center_value(_), do: nil

  defp normalize_center({lat, lng}) do
    lat = lat |> parse_float(nil) |> normalize_lat()
    lng = lng |> parse_float(nil) |> normalize_lng()

    if is_number(lat) and is_number(lng), do: {lat, lng}, else: nil
  end

  defp normalize_zoom(nil), do: nil

  defp normalize_zoom(value) when is_integer(value) do
    value
    |> clamp(@min_zoom, @max_zoom)
  end

  defp normalize_zoom(_), do: nil

  defp normalize_max_points(nil), do: nil

  defp normalize_max_points(value) when is_integer(value) and value > 0, do: value
  defp normalize_max_points(value) when is_integer(value), do: 1
  defp normalize_max_points(_), do: nil

  defp normalize_lat(nil), do: nil

  defp normalize_lat(value) when is_number(value) do
    value
    |> Kernel.*(1.0)
    |> clamp(-90.0, 90.0)
  end

  defp normalize_lat(_), do: nil

  defp normalize_lng(nil), do: nil

  defp normalize_lng(value) when is_number(value) do
    value
    |> Kernel.*(1.0)
    |> clamp(-180.0, 180.0)
  end

  defp normalize_lng(_), do: nil

  defp normalize_field(nil), do: nil

  defp normalize_field(value) when is_atom(value), do: Atom.to_string(value)

  defp normalize_field(value) do
    value
    |> normalize_text()
  end

  defp normalize_text(nil), do: nil

  defp normalize_text(value) when is_atom(value),
    do: value |> Atom.to_string() |> normalize_text()

  defp normalize_text(value) do
    value
    |> blank_to_nil()
  end

  defp maybe_elem({lat, _lng}, 0), do: lat
  defp maybe_elem({_lat, lng}, 1), do: lng
  defp maybe_elem(_, _), do: nil

  defp merge_non_nil_configs(configs) when is_list(configs) do
    Enum.reduce(configs, %{}, fn
      config, acc when is_map(config) ->
        Enum.reduce(config, acc, fn
          {_key, nil}, cfg_acc -> cfg_acc
          {key, value}, cfg_acc -> Map.put(cfg_acc, key, value)
        end)

      _config, acc ->
        acc
    end)
  end

  defp clamp(value, min, _max) when value < min, do: min
  defp clamp(value, _min, max) when value > max, do: max
  defp clamp(value, _min, _max), do: value

  defp get_map_value(map, key, default \\ nil)

  defp get_map_value(map, key, default) when is_map(map) and is_atom(key) do
    Map.get(map, key, Map.get(map, Atom.to_string(key), default))
  end

  defp get_map_value(map, key, default) when is_map(map) and is_binary(key) do
    Map.get(map, key, default)
  end

  defp get_map_value(_map, _key, default), do: default

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
  defp parse_bool(value, _default) when value in [true, 1], do: true
  defp parse_bool(value, _default) when value in [false, 0], do: false

  defp parse_bool(value, default) when is_binary(value) do
    case value |> String.trim() |> String.downcase() do
      value when value in ["true", "on", "1"] -> true
      value when value in ["false", "off", "0"] -> false
      _ -> default
    end
  end

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
