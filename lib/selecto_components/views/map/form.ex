defmodule SelectoComponents.Views.Map.Form do
  use Phoenix.LiveComponent

  alias SelectoComponents.Theme
  alias SelectoComponents.Views.Map.Process

  def render(assigns) do
    config =
      get_in(assigns, [:view_config, :views, :map]) ||
        get_in(assigns, [:view_config, :views, "map"]) ||
        %{}

    assigns =
      assign(assigns,
        map_config: Process.normalize_config(config),
        spatial_columns: spatial_columns(assigns.selecto),
        popup_columns: popup_columns(assigns.selecto)
      )

    assigns =
      assigns
      |> assign(:theme, Map.get(assigns, :theme, Theme.default_theme(:light)))
      |> assign(:map_layers, map_layers_for_form(assigns.map_config, assigns))

    ~H"""
    <div class="space-y-6">
      <div class={Theme.slot(@theme, :panel) <> " p-4"} style="background: var(--sc-surface-bg);">
        <div class="mb-3">
          <h4 class="text-sm font-semibold" style="color: var(--sc-text-primary);">Map Layers</h4>
          <p class="text-xs" style="color: var(--sc-text-secondary);">
            Configure up to 3 geometry layers (points, lines, areas) rendered together.
          </p>
        </div>

        <div class="space-y-3">
          <div
            :for={{layer, index} <- Enum.with_index(@map_layers)}
            class={Theme.slot(@theme, :panel) <> " rounded-md p-3"}
            style="background: color-mix(in srgb, var(--sc-surface-bg-alt) 68%, var(--sc-surface-bg));"
          >
            <div class="mb-2 flex items-center justify-between">
              <div class="text-xs font-semibold uppercase tracking-wide" style="color: var(--sc-text-secondary);">
                Layer {index + 1}
              </div>
              <label class={Theme.slot(@theme, :checkbox_label) <> " inline-flex items-center gap-2 text-xs"}>
                <input type="hidden" name={"map_layers[#{index}][visible]"} value="false" />
                <input
                  type="checkbox"
                  name={"map_layers[#{index}][visible]"}
                  value="true"
                  checked={Map.get(layer, :visible, true)}
                  class="h-4 w-4 rounded border"
                  style={checkbox_style()}
                /> Visible
              </label>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
              <div>
                <label class={field_label_class()} style={field_label_style()}>Label</label>
                <input
                  type="text"
                  name={"map_layers[#{index}][label]"}
                  value={Map.get(layer, :label, "")}
                  class={field_input_class(@theme)}
                />
              </div>

              <div>
                <label class={field_label_class()} style={field_label_style()}>Geometry Field</label>
                <select
                  name={"map_layers[#{index}][geometry_field]"}
                  class={field_select_class(@theme)}
                >
                  <option
                    :for={{field, label} <- @spatial_columns}
                    value={field}
                    selected={Map.get(layer, :geometry_field) == field}
                  >
                    {label}
                  </option>
                </select>
              </div>

              <div>
                <label class={field_label_class()} style={field_label_style()}>Geometry Kind</label>
                <select
                  name={"map_layers[#{index}][geometry_kind]"}
                  class={field_select_class(@theme)}
                >
                  <option value="auto" selected={Map.get(layer, :geometry_kind, "auto") == "auto"}>
                    Auto
                  </option>
                  <option value="point" selected={Map.get(layer, :geometry_kind) == "point"}>
                    Point
                  </option>
                  <option value="line" selected={Map.get(layer, :geometry_kind) == "line"}>
                    Line
                  </option>
                  <option value="area" selected={Map.get(layer, :geometry_kind) == "area"}>
                    Area
                  </option>
                </select>
              </div>

              <div>
                <label class={field_label_class()} style={field_label_style()}>Popup Field</label>
                <select
                  name={"map_layers[#{index}][popup_field]"}
                  class={field_select_class(@theme)}
                >
                  <option value="" selected={Map.get(layer, :popup_field) in [nil, ""]}>None</option>
                  <option
                    :for={{field, label} <- @popup_columns}
                    value={field}
                    selected={Map.get(layer, :popup_field) == field}
                  >
                    {label}
                  </option>
                </select>
              </div>

              <div>
                <label class={field_label_class()} style={field_label_style()}>Color Field</label>
                <select
                  name={"map_layers[#{index}][color_field]"}
                  class={field_select_class(@theme)}
                >
                  <option value="" selected={Map.get(layer, :color_field) in [nil, ""]}>None</option>
                  <option
                    :for={{field, label} <- @popup_columns}
                    value={field}
                    selected={Map.get(layer, :color_field) == field}
                  >
                    {label}
                  </option>
                </select>
              </div>

              <div>
                <label class={field_label_class()} style={field_label_style()}>Scale Type</label>
                <select
                  name={"map_layers[#{index}][scale_type]"}
                  class={field_select_class(@theme)}
                >
                  <option value="auto" selected={Map.get(layer, :scale_type, "auto") == "auto"}>
                    Auto
                  </option>
                  <option value="categorical" selected={Map.get(layer, :scale_type) == "categorical"}>
                    Categorical
                  </option>
                  <option
                    value="numeric_steps"
                    selected={Map.get(layer, :scale_type) == "numeric_steps"}
                  >
                    Numeric Steps
                  </option>
                  <option value="linear" selected={Map.get(layer, :scale_type) == "linear"}>
                    Linear
                  </option>
                </select>
              </div>

              <div>
                <label class={field_label_class()} style={field_label_style()}>Palette (optional)</label>
                <input
                  type="text"
                  placeholder="#16a34a,#f59e0b,#dc2626"
                  name={"map_layers[#{index}][scale_palette]"}
                  value={Map.get(layer, :scale_palette, "")}
                  class={field_input_class(@theme)}
                />
              </div>

              <div>
                <label class={field_label_class()} style={field_label_style()}>
                  Steps (for numeric)
                </label>
                <input
                  type="text"
                  placeholder="20,45,90"
                  name={"map_layers[#{index}][scale_steps]"}
                  value={Map.get(layer, :scale_steps, "")}
                  class={field_input_class(@theme)}
                />
              </div>

              <div>
                <label class={field_label_class()} style={field_label_style()}>Category Colors</label>
                <input
                  type="text"
                  placeholder="queued:#22c55e,loading:#f59e0b"
                  name={"map_layers[#{index}][scale_categories]"}
                  value={Map.get(layer, :scale_categories, "")}
                  class={field_input_class(@theme)}
                />
              </div>

              <div>
                <label class={field_label_class()} style={field_label_style()}>
                  Track By (breadcrumbs)
                </label>
                <select
                  name={"map_layers[#{index}][track_by]"}
                  class={field_select_class(@theme)}
                >
                  <option value="" selected={Map.get(layer, :track_by) in [nil, ""]}>None</option>
                  <option
                    :for={{field, label} <- @popup_columns}
                    value={field}
                    selected={Map.get(layer, :track_by) == field}
                  >
                    {label}
                  </option>
                </select>
              </div>

              <div>
                <label class={field_label_class()} style={field_label_style()}>Track Order Field</label>
                <select
                  name={"map_layers[#{index}][track_order_field]"}
                  class={field_select_class(@theme)}
                >
                  <option value="" selected={Map.get(layer, :track_order_field) in [nil, ""]}>
                    None
                  </option>
                  <option
                    :for={{field, label} <- @popup_columns}
                    value={field}
                    selected={Map.get(layer, :track_order_field) == field}
                  >
                    {label}
                  </option>
                </select>
              </div>

              <%= if Map.get(layer, :geometry_kind, "auto") in ["auto", "point"] do %>
                <div>
                  <label class={field_label_class()} style={field_label_style()}>Point Radius</label>
                  <input
                    type="number"
                    min="1"
                    max="30"
                    name={"map_layers[#{index}][point_radius]"}
                    value={Map.get(layer, :point_radius, 6)}
                    class={field_input_class(@theme)}
                  />
                </div>
              <% end %>

              <%= if Map.get(layer, :geometry_kind, "auto") in ["auto", "line", "area"] do %>
                <div>
                  <label class={field_label_class()} style={field_label_style()}>Line Weight</label>
                  <input
                    type="number"
                    min="1"
                    max="12"
                    name={"map_layers[#{index}][line_weight]"}
                    value={Map.get(layer, :line_weight, 2)}
                    class={field_input_class(@theme)}
                  />
                </div>
              <% end %>

              <%= if Map.get(layer, :geometry_kind, "auto") in ["auto", "line"] do %>
                <div>
                  <label class={field_label_class()} style={field_label_style()}>Line Dash</label>
                  <input
                    type="text"
                    placeholder="e.g. 6,4"
                    name={"map_layers[#{index}][line_dash_array]"}
                    value={Map.get(layer, :line_dash_array, "")}
                    class={field_input_class(@theme)}
                  />
                </div>
              <% end %>

              <%= if Map.get(layer, :geometry_kind, "auto") in ["auto", "point", "area"] do %>
                <div>
                  <label class={field_label_class()} style={field_label_style()}>Fill Opacity</label>
                  <input
                    type="number"
                    step="0.05"
                    min="0"
                    max="1"
                    name={"map_layers[#{index}][fill_opacity]"}
                    value={Map.get(layer, :fill_opacity, 0.25)}
                    class={field_input_class(@theme)}
                  />
                </div>
              <% end %>

              <div>
                <label class={field_label_class()} style={field_label_style()}>Stroke Opacity</label>
                <input
                  type="number"
                  step="0.05"
                  min="0"
                  max="1"
                  name={"map_layers[#{index}][stroke_opacity]"}
                  value={Map.get(layer, :stroke_opacity, 0.9)}
                  class={field_input_class(@theme)}
                />
              </div>
            </div>
          </div>
        </div>
      </div>

      <input type="hidden" name="geometry_field" value={Map.get(hd(@map_layers), :geometry_field)} />
      <input type="hidden" name="popup_field" value={Map.get(hd(@map_layers), :popup_field, "")} />
      <input type="hidden" name="color_field" value={Map.get(hd(@map_layers), :color_field, "")} />

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <label class={panel_label_class()} style={field_label_style()}>Zoom</label>
          <input
            name="default_zoom"
            type="number"
            min="1"
            max="20"
            value={map_value(@map_config, :default_zoom, 3)}
            class={field_input_class(@theme)}
          />
        </div>

        <div>
          <label class={panel_label_class()} style={field_label_style()}>Center Latitude</label>
          <input
            name="center_lat"
            type="number"
            step="0.000001"
            value={map_value(@map_config, :center_lat, 0.0)}
            class={field_input_class(@theme)}
          />
        </div>

        <div>
          <label class={panel_label_class()} style={field_label_style()}>Center Longitude</label>
          <input
            name="center_lng"
            type="number"
            step="0.000001"
            value={map_value(@map_config, :center_lng, 0.0)}
            class={field_input_class(@theme)}
          />
        </div>

        <div>
          <label class={panel_label_class()} style={field_label_style()}>Max Points</label>
          <input
            name="max_points"
            type="number"
            min="1"
            value={map_value(@map_config, :max_points, 2000)}
            class={field_input_class(@theme)}
          />
        </div>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <label class={panel_label_class()} style={field_label_style()}>Background Mode</label>
          <select
            name="background_mode"
            class={field_select_class(@theme)}
          >
            <option
              value="tiles"
              selected={map_value(@map_config, :background_mode, "tiles") == "tiles"}
            >
              Tile Map
            </option>
            <option
              value="image_overlay"
              selected={map_value(@map_config, :background_mode) == "image_overlay"}
            >
              Image Overlay
            </option>
          </select>
        </div>

        <div>
          <label class={panel_label_class()} style={field_label_style()}>Coordinate Mode</label>
          <select
            name="coordinate_mode"
            class={field_select_class(@theme)}
          >
            <option
              value="latlng"
              selected={map_value(@map_config, :coordinate_mode, "latlng") == "latlng"}
            >
              Geographic (lat/lng)
            </option>
            <option value="local_xy" selected={map_value(@map_config, :coordinate_mode) == "local_xy"}>
              Local XY
            </option>
          </select>
        </div>

        <div>
          <label class={panel_label_class()} style={field_label_style()}>Image Overlay Opacity</label>
          <input
            name="image_overlay_opacity"
            type="number"
            step="0.05"
            min="0"
            max="1"
            value={map_value(@map_config, :image_overlay_opacity, 0.85)}
            class={field_input_class(@theme)}
          />
        </div>

        <div>
          <label class={panel_label_class()} style={field_label_style()}>Image Rotation (degrees)</label>
          <input
            name="image_overlay_rotation"
            type="number"
            step="1"
            min="-360"
            max="360"
            value={map_value(@map_config, :image_overlay_rotation, 0)}
            class={field_input_class(@theme)}
          />
        </div>

        <div class="md:col-span-2">
          <label class={panel_label_class()} style={field_label_style()}>Image Overlay URL</label>
          <input
            name="image_overlay_url"
            type="text"
            placeholder="https://example.com/yard-overlay.png"
            value={map_value(@map_config, :image_overlay_url, "")}
            class={field_input_class(@theme)}
          />
        </div>

        <div class="md:col-span-2">
          <label class={panel_label_class()} style={field_label_style()}>
            Image Bounds (south,west,north,east)
          </label>
          <input
            name="image_overlay_bounds"
            type="text"
            placeholder="33.7,-123.5,49.5,-117.0"
            value={image_overlay_bounds_value(@map_config)}
            class={field_input_class(@theme)}
          />
        </div>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <label class={panel_label_class()} style={field_label_style()}>Tile URL</label>
          <input
            name="tile_url"
            type="text"
            value={
              map_value(@map_config, :tile_url, "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png")
            }
            class={field_input_class(@theme)}
          />
        </div>

        <div>
          <label class={panel_label_class()} style={field_label_style()}>Attribution</label>
          <input
            name="attribution"
            type="text"
            value={map_value(@map_config, :attribution, "&copy; OpenStreetMap contributors")}
            class={field_input_class(@theme)}
          />
        </div>
      </div>

      <div class="flex flex-wrap items-center gap-6">
        <label class={Theme.slot(@theme, :checkbox_label) <> " inline-flex items-center gap-2 text-sm"}>
          <input type="hidden" name="fit_bounds" value="false" />
          <input
            name="fit_bounds"
            type="checkbox"
            value="true"
            checked={map_bool(@map_config, :fit_bounds, true)}
            class="h-4 w-4 rounded border"
            style={checkbox_style()}
          /> Fit map to query bounds
        </label>

        <label class={Theme.slot(@theme, :checkbox_label) <> " inline-flex items-center gap-2 text-sm"}>
          <input type="hidden" name="cluster" value="false" />
          <input
            name="cluster"
            type="checkbox"
            value="true"
            checked={map_bool(@map_config, :cluster, false)}
            class="h-4 w-4 rounded border"
            style={checkbox_style()}
          /> Enable point clustering
        </label>
      </div>
    </div>
    """
  end

  defp field_label_class, do: "mb-1 block text-xs font-medium"
  defp panel_label_class, do: "mb-2 block text-sm font-medium"
  defp field_label_style, do: "color: var(--sc-text-secondary);"
  defp field_input_class(theme), do: Theme.slot(theme, :input)
  defp field_select_class(theme), do: Theme.slot(theme, :select)

  defp checkbox_style do
    "border-color: var(--sc-surface-border); accent-color: var(--sc-accent);"
  end

  defp map_value(config, key, default \\ nil)

  defp map_value(config, key, default) when is_map(config) and is_atom(key) do
    Map.get(config, key, Map.get(config, Atom.to_string(key), default))
  end

  defp map_value(_config, _key, default), do: default

  defp map_bool(config, key, default) do
    case map_value(config, key, nil) do
      value when value in [true, "true", "on", "1", 1] -> true
      value when value in [false, "false", "off", "0", 0] -> false
      _ -> default
    end
  end

  defp image_overlay_bounds_value(config) do
    case map_value(config, :image_overlay_bounds, nil) do
      [[south, west], [north, east]] ->
        Enum.join([south, west, north, east], ",")

      value when is_binary(value) ->
        String.trim(value)

      _ ->
        ""
    end
  end

  defp map_layers_for_form(map_config, assigns) do
    existing_layers = map_value(map_config, :map_layers, [])

    layers =
      case existing_layers do
        layers when is_list(layers) and layers != [] -> layers
        _ -> [default_primary_layer(map_config)]
      end

    geometry_defaults =
      assigns.spatial_columns
      |> Enum.map(fn {field, _label} -> field end)

    layers
    |> Enum.take(3)
    |> Enum.with_index()
    |> Enum.map(fn {layer, index} ->
      geometry_kind = normalize_geometry_kind(Map.get(layer, :geometry_kind))
      defaults = style_defaults_for_kind(geometry_kind)

      %{
        label: Map.get(layer, :label) || "Layer #{index + 1}",
        geometry_field: Map.get(layer, :geometry_field) || Enum.at(geometry_defaults, index),
        geometry_kind: geometry_kind,
        popup_field: Map.get(layer, :popup_field),
        color_field: Map.get(layer, :color_field),
        scale_type: Map.get(layer, :scale_type, "auto"),
        scale_palette: Map.get(layer, :scale_palette),
        scale_steps: Map.get(layer, :scale_steps),
        scale_categories: Map.get(layer, :scale_categories),
        track_by: Map.get(layer, :track_by),
        track_order_field: Map.get(layer, :track_order_field),
        point_radius: Map.get(layer, :point_radius, defaults.point_radius),
        line_weight: Map.get(layer, :line_weight, defaults.line_weight),
        line_dash_array: Map.get(layer, :line_dash_array),
        fill_opacity: Map.get(layer, :fill_opacity, defaults.fill_opacity),
        stroke_opacity: Map.get(layer, :stroke_opacity, defaults.stroke_opacity),
        visible: Map.get(layer, :visible, true)
      }
    end)
    |> ensure_three_layers(geometry_defaults)
  end

  defp default_primary_layer(map_config) do
    defaults = style_defaults_for_kind("auto")

    %{
      label: "Layer 1",
      geometry_field: map_value(map_config, :geometry_field),
      geometry_kind: "auto",
      popup_field: map_value(map_config, :popup_field),
      color_field: map_value(map_config, :color_field),
      scale_type: "auto",
      scale_palette: nil,
      scale_steps: nil,
      scale_categories: nil,
      track_by: nil,
      track_order_field: nil,
      point_radius: defaults.point_radius,
      line_weight: defaults.line_weight,
      line_dash_array: nil,
      fill_opacity: defaults.fill_opacity,
      stroke_opacity: defaults.stroke_opacity,
      visible: true
    }
  end

  defp ensure_three_layers(layers, geometry_defaults) do
    missing = max(3 - length(layers), 0)

    padding =
      if missing == 0 do
        []
      else
        Enum.map(0..(missing - 1), fn idx ->
          absolute_index = length(layers) + idx

          %{
            label: "Layer #{absolute_index + 1}",
            geometry_field: Enum.at(geometry_defaults, absolute_index),
            geometry_kind: "auto",
            popup_field: nil,
            color_field: nil,
            scale_type: "auto",
            scale_palette: nil,
            scale_steps: nil,
            scale_categories: nil,
            track_by: nil,
            track_order_field: nil,
            point_radius: 6,
            line_weight: 2,
            line_dash_array: nil,
            fill_opacity: 0.25,
            stroke_opacity: 0.9,
            visible: false
          }
        end)
      end

    layers ++ padding
  end

  defp normalize_geometry_kind(nil), do: "auto"

  defp normalize_geometry_kind(kind) when is_atom(kind) do
    kind
    |> Atom.to_string()
    |> normalize_geometry_kind()
  end

  defp normalize_geometry_kind(kind) when is_binary(kind) do
    case String.downcase(String.trim(kind)) do
      value when value in ["auto", "point", "line", "area"] -> value
      _ -> "auto"
    end
  end

  defp normalize_geometry_kind(_), do: "auto"

  defp style_defaults_for_kind("point"),
    do: %{point_radius: 6, line_weight: 2, fill_opacity: 0.85, stroke_opacity: 0.9}

  defp style_defaults_for_kind("line"),
    do: %{point_radius: 4, line_weight: 3, fill_opacity: 0.05, stroke_opacity: 0.9}

  defp style_defaults_for_kind("area"),
    do: %{point_radius: 4, line_weight: 2, fill_opacity: 0.25, stroke_opacity: 0.8}

  defp style_defaults_for_kind(_),
    do: %{point_radius: 6, line_weight: 2, fill_opacity: 0.25, stroke_opacity: 0.9}

  defp spatial_columns(selecto) do
    selecto
    |> Selecto.columns()
    |> Enum.filter(fn {_field, col} -> spatial_type?(Map.get(col, :type)) end)
    |> Enum.map(fn {field, col} -> {to_string(field), col.name} end)
  end

  defp popup_columns(selecto) do
    selecto
    |> Selecto.columns()
    |> Enum.filter(fn {_field, col} ->
      format = Map.get(col, :format)
      format not in [:component, :link]
    end)
    |> Enum.map(fn {field, col} -> {to_string(field), col.name} end)
  end

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
end
