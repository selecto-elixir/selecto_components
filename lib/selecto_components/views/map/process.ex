defmodule SelectoComponents.Views.Map.Process do
  @moduledoc false

  @default_tile_url "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
  @default_attribution "&copy; OpenStreetMap contributors"
  @default_zoom 3
  @default_max_points 2000
  @default_center {0.0, 0.0}
  @default_fit_bounds true
  @default_cluster false
  @default_background_mode "tiles"
  @default_image_overlay_opacity 0.85
  @default_coordinate_mode "latlng"
  @default_image_overlay_rotation 0.0
  @min_zoom 1
  @max_zoom 20

  @config_keys [
    :geometry_field,
    :popup_field,
    :color_field,
    :tile_url,
    :attribution,
    :background_mode,
    :coordinate_mode,
    :image_overlay_url,
    :image_overlay_bounds,
    :image_overlay_opacity,
    :image_overlay_rotation,
    :default_zoom,
    :center_lat,
    :center_lng,
    :fit_bounds,
    :max_points,
    :cluster,
    :map_layers
  ]

  @default_config %{
    tile_url: @default_tile_url,
    attribution: @default_attribution,
    background_mode: @default_background_mode,
    coordinate_mode: @default_coordinate_mode,
    image_overlay_opacity: @default_image_overlay_opacity,
    image_overlay_rotation: @default_image_overlay_rotation,
    default_zoom: @default_zoom,
    center_lat: elem(@default_center, 0),
    center_lng: elem(@default_center, 1),
    fit_bounds: @default_fit_bounds,
    max_points: @default_max_points,
    cluster: @default_cluster,
    map_layers: []
  }

  def config_keys, do: @config_keys

  def normalize_config(config) when is_map(config) do
    coordinate_mode =
      config
      |> get_map_value(:coordinate_mode)
      |> normalize_coordinate_mode()

    mode = coordinate_mode || @default_coordinate_mode

    center = config |> get_map_value(:center) |> normalize_center_value(mode)

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
      background_mode:
        config
        |> get_map_value(:background_mode)
        |> normalize_background_mode(),
      coordinate_mode: coordinate_mode,
      image_overlay_url:
        config
        |> get_map_value(:image_overlay_url)
        |> normalize_text(),
      image_overlay_bounds:
        config
        |> get_map_value(:image_overlay_bounds)
        |> normalize_image_overlay_bounds(mode),
      image_overlay_opacity:
        config
        |> get_map_value(:image_overlay_opacity)
        |> parse_float(nil)
        |> normalize_image_overlay_opacity(),
      image_overlay_rotation:
        config
        |> get_map_value(:image_overlay_rotation)
        |> parse_float(nil)
        |> normalize_image_overlay_rotation(),
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
          |> normalize_axis(:lat, mode),
          maybe_elem(center, 0)
        ]),
      center_lng:
        first_non_nil([
          config
          |> get_map_value(:center_lng)
          |> parse_float(nil)
          |> normalize_axis(:lng, mode),
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
        |> parse_bool(nil),
      map_layers: maybe_normalize_layers(config)
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

    layers =
      resolve_layers(
        config[:map_layers],
        geometry_field,
        popup_field,
        color_field,
        columns,
        selecto
      )

    primary_layer = hd(layers)

    selected =
      layers
      |> Enum.with_index(1)
      |> Enum.flat_map(fn {layer, index} ->
        alias_suffix = if index == 1, do: "", else: "_#{index}"

        [
          {:field, {:st_asgeojson, layer.geometry_field}, "__map_geometry#{alias_suffix}"}
        ] ++
          optional_select_field(layer.popup_field, "__map_popup#{alias_suffix}") ++
          optional_select_field(layer.color_field, "__map_color#{alias_suffix}") ++
          optional_select_field(layer.track_by, "__map_track_by#{alias_suffix}") ++
          optional_select_field(layer.track_order_field, "__map_track_order#{alias_suffix}")
      end)

    center =
      normalize_center(
        {Map.get(config, :center_lat), Map.get(config, :center_lng)},
        Map.get(config, :coordinate_mode, @default_coordinate_mode)
      )

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
        map_geometry_field: primary_layer.geometry_field,
        map_popup_field: primary_layer.popup_field,
        map_color_field: primary_layer.color_field,
        map_layers: layers,
        map_tile_url: Map.get(config, :tile_url, @default_tile_url),
        map_attribution: Map.get(config, :attribution, @default_attribution),
        map_background_mode: Map.get(config, :background_mode, @default_background_mode),
        map_coordinate_mode: Map.get(config, :coordinate_mode, @default_coordinate_mode),
        map_image_overlay_url: Map.get(config, :image_overlay_url),
        map_image_overlay_bounds: Map.get(config, :image_overlay_bounds),
        map_image_overlay_opacity:
          Map.get(config, :image_overlay_opacity, @default_image_overlay_opacity),
        map_image_overlay_rotation:
          Map.get(config, :image_overlay_rotation, @default_image_overlay_rotation),
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
      background_mode: get_map_value(domain, :default_map_background_mode),
      coordinate_mode: get_map_value(domain, :default_map_coordinate_mode),
      image_overlay_url: get_map_value(domain, :default_map_image_overlay_url),
      image_overlay_bounds: get_map_value(domain, :default_map_image_overlay_bounds),
      image_overlay_opacity: get_map_value(domain, :default_map_image_overlay_opacity),
      image_overlay_rotation: get_map_value(domain, :default_map_image_overlay_rotation),
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

  defp normalize_center_value({lat, lng}, mode), do: normalize_center({lat, lng}, mode)

  defp normalize_center_value([lat, lng], mode) do
    normalize_center({lat, lng}, mode)
  end

  defp normalize_center_value(%{} = center, mode) do
    normalize_center({get_map_value(center, :lat), get_map_value(center, :lng)}, mode)
  end

  defp normalize_center_value(center, mode) when is_binary(center) do
    case String.split(center, ",", parts: 2) do
      [lat, lng] -> normalize_center({lat, lng}, mode)
      _ -> nil
    end
  end

  defp normalize_center_value(_, _mode), do: nil

  defp normalize_center({lat, lng}, mode) do
    lat = lat |> parse_float(nil) |> normalize_axis(:lat, mode)
    lng = lng |> parse_float(nil) |> normalize_axis(:lng, mode)

    if is_number(lat) and is_number(lng), do: {lat, lng}, else: nil
  end

  defp normalize_background_mode(nil), do: nil

  defp normalize_background_mode(value) when is_atom(value) do
    value
    |> Atom.to_string()
    |> normalize_background_mode()
  end

  defp normalize_background_mode(value) when is_binary(value) do
    case value |> String.trim() |> String.downcase() do
      "tiles" -> "tiles"
      "image_overlay" -> "image_overlay"
      _ -> nil
    end
  end

  defp normalize_background_mode(_), do: nil

  defp normalize_coordinate_mode(nil), do: nil

  defp normalize_coordinate_mode(value) when is_atom(value) do
    value
    |> Atom.to_string()
    |> normalize_coordinate_mode()
  end

  defp normalize_coordinate_mode(value) when is_binary(value) do
    case value |> String.trim() |> String.downcase() do
      "latlng" -> "latlng"
      "local_xy" -> "local_xy"
      _ -> nil
    end
  end

  defp normalize_coordinate_mode(_), do: nil

  defp normalize_image_overlay_bounds([[south, west], [north, east]], mode) do
    normalize_bounds_coords(south, west, north, east, mode)
  end

  defp normalize_image_overlay_bounds([south, west, north, east], mode) do
    normalize_bounds_coords(south, west, north, east, mode)
  end

  defp normalize_image_overlay_bounds(%{} = bounds, mode) do
    normalize_bounds_coords(
      get_map_value(bounds, :south) || get_map_value(bounds, :min_lat),
      get_map_value(bounds, :west) || get_map_value(bounds, :min_lng),
      get_map_value(bounds, :north) || get_map_value(bounds, :max_lat),
      get_map_value(bounds, :east) || get_map_value(bounds, :max_lng),
      mode
    )
  end

  defp normalize_image_overlay_bounds(bounds, mode) when is_binary(bounds) do
    values =
      bounds
      |> String.split(",", trim: true)
      |> Enum.map(&(&1 |> String.trim() |> parse_float(nil)))

    case values do
      [south, west, north, east] -> normalize_bounds_coords(south, west, north, east, mode)
      _ -> nil
    end
  end

  defp normalize_image_overlay_bounds(_, _mode), do: nil

  defp normalize_bounds_coords(south, west, north, east, mode) do
    south = south |> parse_float(nil) |> normalize_axis(:lat, mode)
    west = west |> parse_float(nil) |> normalize_axis(:lng, mode)
    north = north |> parse_float(nil) |> normalize_axis(:lat, mode)
    east = east |> parse_float(nil) |> normalize_axis(:lng, mode)

    if Enum.any?([south, west, north, east], &is_nil/1) do
      nil
    else
      [[min(south, north), min(west, east)], [max(south, north), max(west, east)]]
    end
  end

  defp normalize_image_overlay_opacity(nil), do: nil

  defp normalize_image_overlay_opacity(value) when is_number(value) do
    value
    |> Kernel.*(1.0)
    |> clamp(0.0, 1.0)
  end

  defp normalize_image_overlay_opacity(_), do: nil

  defp normalize_image_overlay_rotation(nil), do: nil

  defp normalize_image_overlay_rotation(value) when is_number(value) do
    value
    |> Kernel.*(1.0)
    |> clamp(-360.0, 360.0)
  end

  defp normalize_image_overlay_rotation(_), do: nil

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

  defp normalize_axis(nil, _axis, _mode), do: nil

  defp normalize_axis(value, _axis, "local_xy") when is_number(value) do
    value * 1.0
  end

  defp normalize_axis(value, :lat, _mode), do: normalize_lat(value)
  defp normalize_axis(value, :lng, _mode), do: normalize_lng(value)

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

  defp normalize_layers(nil), do: []

  defp normalize_layers(layers) when is_map(layers) do
    layers
    |> Enum.sort_by(fn {key, _value} -> parse_integer(to_string(key), 0) end)
    |> Enum.map(fn {_key, value} -> value end)
    |> normalize_layers()
  end

  defp normalize_layers(layers) when is_list(layers) do
    Enum.map(layers, fn layer ->
      %{
        label:
          layer
          |> get_map_value(:label)
          |> normalize_text(),
        geometry_field:
          layer
          |> get_map_value(:geometry_field)
          |> normalize_field(),
        geometry_kind:
          layer
          |> get_map_value(:geometry_kind)
          |> normalize_geometry_kind(),
        popup_field:
          layer
          |> get_map_value(:popup_field)
          |> normalize_field(),
        color_field:
          layer
          |> get_map_value(:color_field)
          |> normalize_field(),
        scale_type:
          layer
          |> get_map_value(:scale_type)
          |> normalize_scale_type(),
        scale_palette:
          layer
          |> get_map_value(:scale_palette)
          |> normalize_text(),
        scale_steps:
          layer
          |> get_map_value(:scale_steps)
          |> normalize_text(),
        scale_categories:
          layer
          |> get_map_value(:scale_categories)
          |> normalize_text(),
        track_by:
          layer
          |> get_map_value(:track_by)
          |> normalize_field(),
        track_order_field:
          layer
          |> get_map_value(:track_order_field)
          |> normalize_field(),
        point_radius:
          layer
          |> get_map_value(:point_radius)
          |> parse_integer(nil)
          |> normalize_point_radius(),
        line_weight:
          layer
          |> get_map_value(:line_weight)
          |> parse_integer(nil)
          |> normalize_line_weight(),
        line_dash_array:
          layer
          |> get_map_value(:line_dash_array)
          |> normalize_text(),
        fill_opacity:
          layer
          |> get_map_value(:fill_opacity)
          |> parse_float(nil)
          |> normalize_fill_opacity(),
        stroke_opacity:
          layer
          |> get_map_value(:stroke_opacity)
          |> parse_float(nil)
          |> normalize_stroke_opacity(),
        visible:
          layer
          |> get_map_value(:visible)
          |> parse_bool(true)
      }
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Map.new()
    end)
    |> Enum.filter(fn layer -> Map.get(layer, :geometry_field) not in [nil, ""] end)
  end

  defp normalize_layers(_), do: []

  defp maybe_normalize_layers(config) when is_map(config) do
    if has_map_key?(config, :map_layers) do
      config
      |> get_map_value(:map_layers)
      |> normalize_layers()
    else
      nil
    end
  end

  defp maybe_normalize_layers(_), do: nil

  defp has_map_key?(map, key) when is_map(map) and is_atom(key) do
    Map.has_key?(map, key) or Map.has_key?(map, Atom.to_string(key))
  end

  defp resolve_layers(raw_layers, geometry_field, popup_field, color_field, columns, selecto) do
    fallback_layer = [build_layer(geometry_field, popup_field, color_field, columns, selecto)]

    case normalize_layers(raw_layers) do
      [] ->
        fallback_layer

      layers ->
        layers
        |> Enum.filter(fn layer -> Map.get(layer, :visible, true) != false end)
        |> Enum.map(fn layer ->
          build_layer(
            Map.get(layer, :geometry_field),
            Map.get(layer, :popup_field),
            Map.get(layer, :color_field),
            columns,
            selecto,
            Map.get(layer, :label),
            layer
          )
        end)
        |> Enum.filter(fn layer -> layer.geometry_field not in [nil, ""] end)
        |> case do
          [] -> fallback_layer
          resolved -> resolved
        end
    end
  end

  defp build_layer(
         geometry_field,
         popup_field,
         color_field,
         columns,
         selecto,
         label \\ nil,
         layer_opts \\ %{}
       ) do
    %{
      label: label,
      geometry_field: resolve_geometry_field(geometry_field, columns, selecto),
      geometry_kind:
        layer_opts
        |> get_map_value(:geometry_kind)
        |> normalize_geometry_kind(),
      popup_field: resolve_optional_field(popup_field, columns),
      color_field: resolve_optional_field(color_field, columns),
      scale_type:
        layer_opts
        |> get_map_value(:scale_type)
        |> normalize_scale_type(),
      scale_palette:
        layer_opts
        |> get_map_value(:scale_palette)
        |> normalize_text(),
      scale_steps:
        layer_opts
        |> get_map_value(:scale_steps)
        |> normalize_text(),
      scale_categories:
        layer_opts
        |> get_map_value(:scale_categories)
        |> normalize_text(),
      track_by:
        layer_opts
        |> get_map_value(:track_by)
        |> normalize_field()
        |> resolve_optional_field(columns),
      track_order_field:
        layer_opts
        |> get_map_value(:track_order_field)
        |> normalize_field()
        |> resolve_optional_field(columns),
      point_radius:
        layer_opts
        |> get_map_value(:point_radius)
        |> parse_integer(point_radius_default(layer_opts))
        |> normalize_point_radius(),
      line_weight:
        layer_opts
        |> get_map_value(:line_weight)
        |> parse_integer(line_weight_default(layer_opts))
        |> normalize_line_weight(),
      line_dash_array:
        layer_opts
        |> get_map_value(:line_dash_array)
        |> normalize_text(),
      fill_opacity:
        layer_opts
        |> get_map_value(:fill_opacity)
        |> parse_float(fill_opacity_default(layer_opts))
        |> normalize_fill_opacity(),
      stroke_opacity:
        layer_opts
        |> get_map_value(:stroke_opacity)
        |> parse_float(stroke_opacity_default(layer_opts))
        |> normalize_stroke_opacity()
    }
  end

  defp point_radius_default(layer_opts) do
    case get_map_value(layer_opts, :geometry_kind) |> normalize_geometry_kind() do
      "line" -> 4
      "area" -> 4
      _ -> 6
    end
  end

  defp line_weight_default(layer_opts) do
    case get_map_value(layer_opts, :geometry_kind) |> normalize_geometry_kind() do
      "line" -> 3
      "area" -> 2
      _ -> 2
    end
  end

  defp fill_opacity_default(layer_opts) do
    case get_map_value(layer_opts, :geometry_kind) |> normalize_geometry_kind() do
      "line" -> 0.05
      "area" -> 0.25
      _ -> 0.85
    end
  end

  defp stroke_opacity_default(layer_opts) do
    case get_map_value(layer_opts, :geometry_kind) |> normalize_geometry_kind() do
      "area" -> 0.8
      _ -> 0.9
    end
  end

  defp normalize_point_radius(nil), do: nil
  defp normalize_point_radius(value) when value < 1, do: 1
  defp normalize_point_radius(value) when value > 30, do: 30
  defp normalize_point_radius(value), do: value

  defp normalize_line_weight(nil), do: nil
  defp normalize_line_weight(value) when value < 1, do: 1
  defp normalize_line_weight(value) when value > 12, do: 12
  defp normalize_line_weight(value), do: value

  defp normalize_fill_opacity(nil), do: nil
  defp normalize_fill_opacity(value) when value < 0.0, do: 0.0
  defp normalize_fill_opacity(value) when value > 1.0, do: 1.0
  defp normalize_fill_opacity(value), do: value

  defp normalize_stroke_opacity(nil), do: nil
  defp normalize_stroke_opacity(value) when value < 0.0, do: 0.0
  defp normalize_stroke_opacity(value) when value > 1.0, do: 1.0
  defp normalize_stroke_opacity(value), do: value

  defp normalize_scale_type(nil), do: "auto"

  defp normalize_scale_type(value) when is_atom(value) do
    value
    |> Atom.to_string()
    |> normalize_scale_type()
  end

  defp normalize_scale_type(value) when is_binary(value) do
    case value |> String.trim() |> String.downcase() do
      scale when scale in ["auto", "categorical", "numeric_steps", "linear"] -> scale
      _ -> "auto"
    end
  end

  defp normalize_scale_type(_), do: "auto"

  defp normalize_geometry_kind(nil), do: "auto"

  defp normalize_geometry_kind(kind) when is_atom(kind) do
    kind
    |> Atom.to_string()
    |> normalize_geometry_kind()
  end

  defp normalize_geometry_kind(kind) when is_binary(kind) do
    case kind |> String.trim() |> String.downcase() do
      value when value in ["point", "line", "area", "auto"] -> value
      _ -> "auto"
    end
  end

  defp normalize_geometry_kind(_), do: "auto"

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
