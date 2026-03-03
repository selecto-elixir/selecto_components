defmodule SelectoComponents.Views.Map.Component do
  use Phoenix.LiveComponent

  @default_marker_color "#2563eb"

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  def render(assigns) do
    ~H"""
    <div class="map-component-wrapper">
      <%= cond do %>
        <% assigns[:execution_error] -> %>
          {render_error_state(assigns)}
        <% assigns[:executed] == false -> %>
          {render_loading_state(assigns)}
        <% assigns[:executed] && match?({_rows, _fields, _aliases}, assigns.query_results) -> %>
          {render_map(assigns)}
        <% true -> %>
          {render_no_results_state(assigns)}
      <% end %>
    </div>
    """
  end

  defp render_map(assigns) do
    {rows, _fields, aliases} = assigns.query_results
    map_set = selecto_set(assigns)
    map_layers = Map.get(map_set, :map_layers, [])
    features = prepare_features(rows, aliases, map_layers)

    map_id = "map-#{assigns[:id] || :rand.uniform(10000)}"

    center =
      case Map.get(map_set, :map_center) do
        {lat, lng} when is_number(lat) and is_number(lng) -> %{lat: lat, lng: lng}
        _ -> %{lat: 0.0, lng: 0.0}
      end

    assigns =
      assign(assigns,
        map_id: map_id,
        features: features,
        map_layers: map_layers,
        scale_legends: scale_legends(features, map_layers),
        map_color_field: Map.get(map_set, :map_color_field),
        map_tile_url:
          Map.get(map_set, :map_tile_url) || "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
        map_attribution:
          Map.get(map_set, :map_attribution) || "&copy; OpenStreetMap contributors",
        map_zoom: Map.get(map_set, :map_zoom) || 3,
        map_center: center,
        fit_bounds: Map.get(map_set, :map_fit_bounds) != false,
        cluster: Map.get(map_set, :map_cluster) == true
      )

    ~H"""
    <div class="bg-white rounded-lg border border-gray-200 p-4">
      <div class="flex items-center justify-between mb-3">
        <h3 class="text-lg font-semibold text-gray-800">Map View</h3>
        <span class="text-xs text-gray-500">{length(@features)} features</span>
      </div>

      <%= if @features == [] do %>
        <div class="flex items-center justify-center h-64 bg-gray-50 rounded-lg border border-gray-200 text-gray-500">
          No mappable geometry returned for the current query.
        </div>
      <% else %>
        <div
          id={@map_id}
          phx-hook=".MapComponent"
          phx-update="ignore"
          data-features={Jason.encode!(@features)}
          data-tile-url={@map_tile_url}
          data-attribution={@map_attribution}
          data-zoom={@map_zoom}
          data-center={Jason.encode!(@map_center)}
          data-fit-bounds={to_string(@fit_bounds)}
          data-cluster={to_string(@cluster)}
          data-map-layers={Jason.encode!(@map_layers)}
          class="w-full rounded-lg border border-gray-200"
          style="height: 460px;"
        >
        </div>

        <script :type={Phoenix.LiveView.ColocatedHook} name=".MapComponent">
          const LEAFLET_JS = "https://unpkg.com/leaflet@1.9.4/dist/leaflet.js";
          const LEAFLET_CSS = "https://unpkg.com/leaflet@1.9.4/dist/leaflet.css";
          const MARKER_CLUSTER_JS = "https://unpkg.com/leaflet.markercluster@1.5.3/dist/leaflet.markercluster.js";
          const MARKER_CLUSTER_CSS = "https://unpkg.com/leaflet.markercluster@1.5.3/dist/MarkerCluster.css";
          const MARKER_CLUSTER_DEFAULT_CSS = "https://unpkg.com/leaflet.markercluster@1.5.3/dist/MarkerCluster.Default.css";

          function loadCssOnce(url, attrName) {
            if (document.querySelector(`link[${attrName}="${url}"]`)) return;

            const link = document.createElement("link");
            link.rel = "stylesheet";
            link.href = url;
            link.setAttribute(attrName, url);
            document.head.appendChild(link);
          }

          function loadScriptOnce(url, attrName, readyCheck, errorMessage) {
            return new Promise((resolve, reject) => {
              if (readyCheck()) {
                resolve();
                return;
              }

              const existing = document.querySelector(`script[${attrName}="${url}"]`);
              if (existing) {
                existing.addEventListener(
                  "load",
                  () => {
                    if (readyCheck()) {
                      resolve();
                    } else {
                      reject(new Error(errorMessage));
                    }
                  },
                  { once: true }
                );

                existing.addEventListener("error", () => reject(new Error(errorMessage)), {
                  once: true
                });

                return;
              }

              const script = document.createElement("script");
              script.src = url;
              script.setAttribute(attrName, url);
              script.async = true;

              script.onload = () => {
                if (readyCheck()) {
                  resolve();
                } else {
                  reject(new Error(errorMessage));
                }
              };

              script.onerror = () => reject(new Error(errorMessage));
              document.head.appendChild(script);
            });
          }

          export default {
            map: null,
            markers: null,
            clusterMarkers: null,
            nonPointLayers: null,
            tileLayer: null,
            clusterLoadPromise: null,

            mounted() {
              this.initializeMap();
            },

            updated() {
              this.applyTileLayerConfig();
              this.renderFeatures();
            },

            destroyed() {
              this.destroyLayers();

              if (this.map) {
                this.map.remove();
                this.map = null;
              }
            },

            async initializeMap() {
              loadCssOnce(LEAFLET_CSS, "data-leaflet-css");

              try {
                await loadScriptOnce(
                  LEAFLET_JS,
                  "data-leaflet-js",
                  () => Boolean(window.L),
                  "Leaflet failed to load"
                );
              } catch (_error) {
                return;
              }

              if (!window.L || this.map) return;

              const center = this.getCenter();
              const zoom = Number(this.el.dataset.zoom || 3);

              this.map = window.L.map(this.el).setView([center.lat, center.lng], zoom);

              this.tileLayer = window.L.tileLayer(this.el.dataset.tileUrl, {
                attribution: this.el.dataset.attribution,
                maxZoom: 20
              });

              this.tileLayer.addTo(this.map);
              this.markers = window.L.featureGroup().addTo(this.map);
              this.renderFeatures();
            },

            applyTileLayerConfig() {
              if (!this.map || !this.tileLayer || !window.L) return;

              const nextTileUrl = this.el.dataset.tileUrl;
              const nextAttribution = this.el.dataset.attribution || "";

              const urlChanged = nextTileUrl && this.tileLayer._url !== nextTileUrl;
              const attributionChanged = this.tileLayer.options.attribution !== nextAttribution;

              if (!urlChanged && !attributionChanged) return;

              if (this.map.hasLayer(this.tileLayer)) {
                this.map.removeLayer(this.tileLayer);
              }

              this.tileLayer = window.L.tileLayer(nextTileUrl, {
                attribution: nextAttribution,
                maxZoom: 20
              });

              this.tileLayer.addTo(this.map);
            },

            getCenter() {
              try {
                const center = JSON.parse(this.el.dataset.center || "{}");
                return {
                  lat: Number(center.lat || 0),
                  lng: Number(center.lng || 0)
                };
              } catch (_error) {
                return { lat: 0, lng: 0 };
              }
            },

            getFeatures() {
              try {
                const features = JSON.parse(this.el.dataset.features || "[]");
                return Array.isArray(features) ? features : [];
              } catch (_error) {
                return [];
              }
            },

            getLayerStyles() {
              try {
                const layers = JSON.parse(this.el.dataset.mapLayers || "[]");

                if (!Array.isArray(layers)) return {};

                return layers.reduce((acc, layer, index) => {
                  const key = String(index + 1);

                  acc[key] = {
                    pointRadius: Number(layer?.point_radius || 6),
                    lineWeight: Number(layer?.line_weight || 2),
                    lineDashArray: layer?.line_dash_array || "",
                    fillOpacity: Number(layer?.fill_opacity ?? 0.25),
                    strokeOpacity: Number(layer?.stroke_opacity ?? 0.9)
                  };

                  return acc;
                }, {});
              } catch (_error) {
                return {};
              }
            },

            isClusterEnabled() {
              return this.el.dataset.cluster === "true";
            },

            async ensureClusterAssets() {
              if (!this.isClusterEnabled()) return false;
              if (window.L && window.L.markerClusterGroup) return true;

              if (!this.clusterLoadPromise) {
                this.clusterLoadPromise = (async () => {
                  loadCssOnce(MARKER_CLUSTER_CSS, "data-marker-cluster-css");
                  loadCssOnce(MARKER_CLUSTER_DEFAULT_CSS, "data-marker-cluster-default-css");

                  await loadScriptOnce(
                    MARKER_CLUSTER_JS,
                    "data-marker-cluster-js",
                    () => Boolean(window.L && window.L.markerClusterGroup),
                    "Leaflet marker cluster failed to load"
                  );

                  return true;
                })()
                  .catch(() => false)
                  .finally(() => {
                    this.clusterLoadPromise = null;
                  });
              }

              return this.clusterLoadPromise;
            },

            syncLayerMode(useCluster) {
              if (!this.map || !window.L) return;

              if (useCluster) {
                if (this.markers && this.map.hasLayer(this.markers)) {
                  this.map.removeLayer(this.markers);
                }

                if (!this.clusterMarkers) {
                  this.clusterMarkers = window.L.markerClusterGroup({
                    showCoverageOnHover: false,
                    disableClusteringAtZoom: 15
                  });
                }

                if (!this.nonPointLayers) {
                  this.nonPointLayers = window.L.featureGroup();
                }

                if (!this.map.hasLayer(this.clusterMarkers)) {
                  this.clusterMarkers.addTo(this.map);
                }

                if (!this.map.hasLayer(this.nonPointLayers)) {
                  this.nonPointLayers.addTo(this.map);
                }

                return;
              }

              if (this.clusterMarkers && this.map.hasLayer(this.clusterMarkers)) {
                this.map.removeLayer(this.clusterMarkers);
              }

              if (this.nonPointLayers && this.map.hasLayer(this.nonPointLayers)) {
                this.map.removeLayer(this.nonPointLayers);
              }

              if (!this.markers) {
                this.markers = window.L.featureGroup();
              }

              if (!this.map.hasLayer(this.markers)) {
                this.markers.addTo(this.map);
              }
            },

            clearLayers() {
              if (this.markers?.clearLayers) this.markers.clearLayers();
              if (this.clusterMarkers?.clearLayers) this.clusterMarkers.clearLayers();
              if (this.nonPointLayers?.clearLayers) this.nonPointLayers.clearLayers();
            },

            createPointLayer(feature, layerStyle) {
              const coords = feature?.geometry?.coordinates;
              if (!Array.isArray(coords) || coords.length < 2) return null;

              const lng = Number(coords[0]);
              const lat = Number(coords[1]);

              if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;

              const color = feature?.properties?.color || "#2563eb";

              const marker = window.L.circleMarker([lat, lng], {
                radius: Number(layerStyle?.pointRadius || 6),
                color,
                fillColor: color,
                fillOpacity: Number(layerStyle?.fillOpacity ?? 0.85),
                weight: Number(layerStyle?.lineWeight || 1),
                opacity: Number(layerStyle?.strokeOpacity ?? 0.9),
                dashArray: layerStyle?.lineDashArray || null
              });

              this.bindPopup(marker, feature?.properties?.popup);
              return marker;
            },

            createGeoLayer(feature, layerStyle) {
              const color = feature?.properties?.color || "#2563eb";

              const layer = window.L.geoJSON(feature, {
                pointToLayer: (_feature, latlng) =>
                  window.L.circleMarker(latlng, {
                    radius: Number(layerStyle?.pointRadius || 6),
                    color,
                    fillColor: color,
                    fillOpacity: Number(layerStyle?.fillOpacity ?? 0.85),
                    weight: Number(layerStyle?.lineWeight || 1),
                    opacity: Number(layerStyle?.strokeOpacity ?? 0.9),
                    dashArray: layerStyle?.lineDashArray || null
                  }),
                style: () => ({
                  color,
                  weight: Number(layerStyle?.lineWeight || 2),
                  opacity: Number(layerStyle?.strokeOpacity ?? 0.9),
                  fillOpacity: Number(layerStyle?.fillOpacity ?? 0.25),
                  dashArray: layerStyle?.lineDashArray || null
                })
              });

              this.bindPopup(layer, feature?.properties?.popup);
              return layer;
            },

            bindPopup(layer, popup) {
              if (!layer) return;
              if (popup === null || popup === undefined || popup === "") return;
              layer.bindPopup(String(popup));
            },

            createLayer(feature, useCluster) {
              if (!window.L || !feature?.geometry) return null;

              const layerId = String(feature?.properties?.layer || "1");
              const layerStyles = this.getLayerStyles();
              const layerStyle = layerStyles[layerId] || {};

              if (useCluster && feature.geometry.type === "Point") {
                const layer = this.createPointLayer(feature, layerStyle);
                return layer ? { layer, clustered: true } : null;
              }

              const layer = this.createGeoLayer(feature, layerStyle);
              return layer ? { layer, clustered: false } : null;
            },

            layerBounds(layer) {
              if (!layer || !layer.getLayers || layer.getLayers().length === 0) return null;

              const bounds = layer.getBounds ? layer.getBounds() : null;
              if (!bounds || !bounds.isValid || !bounds.isValid()) return null;

              return bounds;
            },

            mergeBounds(base, next) {
              if (!next) return base;
              if (!base) return next;
              return base.extend(next);
            },

            fitMapToData(useCluster) {
              if (!this.map) return;
              if (this.el.dataset.fitBounds !== "true") return;

              let bounds = null;

              if (useCluster) {
                bounds = this.mergeBounds(bounds, this.layerBounds(this.clusterMarkers));
                bounds = this.mergeBounds(bounds, this.layerBounds(this.nonPointLayers));
              } else {
                bounds = this.layerBounds(this.markers);
              }

              if (bounds && bounds.isValid && bounds.isValid()) {
                this.map.fitBounds(bounds, { padding: [24, 24], maxZoom: 14 });
              }
            },

            async renderFeatures() {
              if (!this.map || !window.L) return;

              const clusterReady = await this.ensureClusterAssets();
              const useCluster =
                this.isClusterEnabled() && clusterReady && Boolean(window.L.markerClusterGroup);

              this.syncLayerMode(useCluster);
              this.clearLayers();

              const features = this.getFeatures();

              for (const feature of features) {
                const built = this.createLayer(feature, useCluster);
                if (!built) continue;

                if (useCluster && built.clustered && this.clusterMarkers) {
                  this.clusterMarkers.addLayer(built.layer);
                } else if (useCluster && this.nonPointLayers) {
                  this.nonPointLayers.addLayer(built.layer);
                } else if (this.markers) {
                  this.markers.addLayer(built.layer);
                }
              }

              this.fitMapToData(useCluster);
            },

            destroyLayers() {
              this.clearLayers();

              if (this.map) {
                if (this.markers && this.map.hasLayer(this.markers)) {
                  this.map.removeLayer(this.markers);
                }

                if (this.clusterMarkers && this.map.hasLayer(this.clusterMarkers)) {
                  this.map.removeLayer(this.clusterMarkers);
                }

                if (this.nonPointLayers && this.map.hasLayer(this.nonPointLayers)) {
                  this.map.removeLayer(this.nonPointLayers);
                }

                if (this.tileLayer && this.map.hasLayer(this.tileLayer)) {
                  this.map.removeLayer(this.tileLayer);
                }
              }

              this.markers = null;
              this.clusterMarkers = null;
              this.nonPointLayers = null;
              this.tileLayer = null;
            }
          };
        </script>

        <%= if @scale_legends != [] do %>
          <div class="mt-3 rounded-md border border-slate-200 bg-slate-50 p-3">
            <div class="text-xs font-semibold uppercase tracking-wide text-slate-700">
              Scale Legend
            </div>
            <div :for={legend <- @scale_legends} class="mt-2">
              <div class="text-[11px] font-semibold text-slate-600">{legend.title}</div>
              <div class="mt-1 flex flex-wrap items-center gap-3 text-xs text-slate-700">
                <span :for={entry <- legend.entries} class="inline-flex items-center gap-1.5">
                  <span class="h-2.5 w-2.5 rounded-full" style={"background-color: #{entry.color}"}></span>{entry.label}
                </span>
              </div>
            </div>
          </div>
        <% end %>

        <%= if show_layer_legend?(@map_layers) do %>
          <div class="mt-3 rounded-md border border-slate-200 bg-slate-50 p-3">
            <div class="text-xs font-semibold uppercase tracking-wide text-slate-700">
              Layer Legend
            </div>
            <div class="mt-2 flex flex-wrap items-center gap-3 text-xs text-slate-700">
              <span
                :for={layer <- visible_layers(@map_layers)}
                class="inline-flex items-center gap-1.5"
              >
                <span class={layer_swatch_class(layer)} style={layer_swatch_style(layer)}></span>
                {layer_label(layer)}
              </span>
            </div>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp render_loading_state(assigns) do
    ~H"""
    <div class="flex items-center justify-center h-64 bg-gray-50 rounded-lg border border-gray-200">
      <div class="text-blue-500 italic">Loading map...</div>
    </div>
    """
  end

  defp render_no_results_state(assigns) do
    ~H"""
    <div class="flex items-center justify-center h-64 bg-gray-50 rounded-lg border border-gray-200 text-gray-600">
      No map data available.
    </div>
    """
  end

  defp render_error_state(assigns) do
    ~H"""
    <div class="flex items-center justify-center min-h-64 bg-red-50 rounded-lg border border-red-300 p-6">
      <div class="text-center text-red-700">
        <div class="font-semibold">Query execution error</div>
        <div class="text-sm mt-1">{inspect(assigns[:execution_error])}</div>
      </div>
    </div>
    """
  end

  @doc false
  def prepare_features(rows, aliases) when is_list(rows) and is_list(aliases) do
    prepare_features(rows, aliases, [])
  end

  def prepare_features(_rows, _aliases), do: []

  def prepare_features(rows, aliases, map_layers) when is_list(rows) and is_list(aliases) do
    layers = map_layer_indexes(aliases, map_layers)

    rows
    |> Enum.map(&row_to_list/1)
    |> Enum.flat_map(fn row ->
      Enum.map(layers, fn layer ->
        geometry = row |> Enum.at(layer.geometry_ix) |> parse_geometry()
        raw_color = row |> optional_value(layer.color_ix)

        if geometry do
          %{
            "type" => "Feature",
            "geometry" => geometry,
            "properties" => %{
              "popup" => optional_value(row, layer.popup_ix),
              "color" => normalize_marker_color(raw_color, layer.config),
              "raw_color" => raw_color,
              "layer" => layer.layer_id
            }
          }
        else
          nil
        end
      end)
    end)
    |> Enum.reject(&is_nil/1)
  end

  def prepare_features(_rows, _aliases, _map_layers), do: []

  defp row_to_list(row) when is_tuple(row), do: Tuple.to_list(row)
  defp row_to_list(row) when is_list(row), do: row
  defp row_to_list(_), do: []

  defp optional_value(_row, nil), do: nil
  defp optional_value(row, index), do: Enum.at(row, index)

  defp map_layer_indexes(aliases, map_layers) do
    layers =
      aliases
      |> Enum.with_index()
      |> Enum.filter(fn {alias_name, _ix} ->
        String.starts_with?(to_string(alias_name), "__map_geometry")
      end)
      |> Enum.map(fn {alias_name, geometry_ix} ->
        suffix = String.replace_prefix(to_string(alias_name), "__map_geometry", "")

        %{
          geometry_ix: geometry_ix,
          popup_ix: index_for_alias(aliases, "__map_popup#{suffix}", nil),
          color_ix: index_for_alias(aliases, "__map_color#{suffix}", nil),
          layer_id: layer_id_from_suffix(suffix)
        }
      end)
      |> Enum.map(fn layer ->
        config = layer_config(map_layers, layer.layer_id)
        Map.put(layer, :config, config)
      end)

    if layers == [] do
      [
        %{
          geometry_ix: 0,
          popup_ix: index_for_alias(aliases, "__map_popup", nil),
          color_ix: index_for_alias(aliases, "__map_color", nil),
          layer_id: "1",
          config: layer_config(map_layers, "1")
        }
      ]
    else
      layers
    end
  end

  defp layer_id_from_suffix(""), do: "1"

  defp layer_id_from_suffix("_" <> rest) when rest != "" do
    rest
  end

  defp layer_id_from_suffix(value), do: value

  defp layer_config(map_layers, layer_id) do
    case Integer.parse(to_string(layer_id)) do
      {index, ""} when index > 0 -> Enum.at(map_layers, index - 1, %{})
      _ -> %{}
    end
  end

  defp normalize_marker_color(value, config) do
    scale_type = normalize_scale_type(Map.get(config, :scale_type))
    palette = parse_palette(Map.get(config, :scale_palette))
    trimmed = if is_binary(value), do: String.trim(value), else: value

    cond do
      trimmed in [nil, ""] -> @default_marker_color
      is_binary(trimmed) and css_color?(trimmed) -> trimmed
      scale_type == "categorical" -> categorical_color(trimmed, palette)
      scale_type == "linear" -> linear_color(trimmed, palette)
      true -> numeric_steps_color(trimmed, Map.get(config, :scale_steps), palette)
    end
  end

  defp normalize_scale_type(value) when value in [nil, ""], do: "auto"

  defp normalize_scale_type(value) when is_atom(value),
    do: normalize_scale_type(Atom.to_string(value))

  defp normalize_scale_type(value) when is_binary(value) do
    case String.downcase(String.trim(value)) do
      "categorical" -> "categorical"
      "linear" -> "linear"
      "numeric_steps" -> "numeric_steps"
      _ -> "auto"
    end
  end

  defp normalize_scale_type(_), do: "auto"

  defp parse_palette(nil), do: []

  defp parse_palette(value) when is_binary(value) do
    value
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&css_color?/1)
  end

  defp parse_palette(_), do: []

  defp parse_steps(nil), do: [20, 45, 90]

  defp parse_steps(value) when is_binary(value) do
    parsed =
      value
      |> String.split(",", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.map(&Integer.parse/1)
      |> Enum.flat_map(fn
        {n, ""} -> [n]
        _ -> []
      end)
      |> Enum.sort()

    if parsed == [], do: [20, 45, 90], else: parsed
  end

  defp parse_steps(_), do: [20, 45, 90]

  defp numeric_steps_color(value, steps_value, palette) do
    case parse_number(value) do
      nil ->
        categorical_color(value, palette)

      number ->
        steps = parse_steps(steps_value)
        [c1, c2, c3, c4] = palette_for_steps(palette)

        cond do
          number <= Enum.at(steps, 0) -> c1
          number <= Enum.at(steps, 1) -> c2
          number <= Enum.at(steps, 2) -> c3
          true -> c4
        end
    end
  end

  defp linear_color(value, palette) do
    case parse_number(value) do
      nil ->
        categorical_color(value, palette)

      number ->
        {low, high} = linear_palette(palette)
        t = max(0.0, min(number / 100.0, 1.0))
        lerp_hex(low, high, t)
    end
  end

  defp categorical_color(value, palette) do
    colors = if palette == [], do: default_categorical_palette(), else: palette
    idx = :erlang.phash2(to_string(value), max(length(colors), 1))
    Enum.at(colors, idx, @default_marker_color)
  end

  defp parse_number(value) when is_integer(value), do: value * 1.0
  defp parse_number(value) when is_float(value), do: value

  defp parse_number(value) when is_binary(value) do
    trimmed = String.trim(value)

    case Float.parse(trimmed) do
      {number, ""} -> number
      _ -> nil
    end
  end

  defp parse_number(_), do: nil

  defp palette_for_steps([a, b, c, d | _]), do: [a, b, c, d]
  defp palette_for_steps(_), do: ["#16a34a", "#f59e0b", "#f97316", "#dc2626"]

  defp linear_palette([low, high | _]), do: {low, high}
  defp linear_palette(_), do: {"#16a34a", "#dc2626"}

  defp default_categorical_palette do
    ["#2563eb", "#0ea5e9", "#14b8a6", "#22c55e", "#f59e0b", "#f97316", "#ef4444", "#a855f7"]
  end

  defp lerp_hex(low, high, t) do
    with {:ok, {lr, lg, lb}} <- hex_to_rgb(low),
         {:ok, {hr, hg, hb}} <- hex_to_rgb(high) do
      r = round(lr + (hr - lr) * t)
      g = round(lg + (hg - lg) * t)
      b = round(lb + (hb - lb) * t)
      rgb_to_hex({r, g, b})
    else
      _ -> @default_marker_color
    end
  end

  defp hex_to_rgb("#" <> hex) when byte_size(hex) == 6 do
    case Integer.parse(hex, 16) do
      {value, ""} ->
        {:ok,
         {Bitwise.band(Bitwise.bsr(value, 16), 255), Bitwise.band(Bitwise.bsr(value, 8), 255),
          Bitwise.band(value, 255)}}

      _ ->
        :error
    end
  end

  defp hex_to_rgb(_), do: :error

  defp rgb_to_hex({r, g, b}) do
    "#" <> String.upcase(Base.encode16(<<r, g, b>>))
  end

  defp scale_legends(features, map_layers) do
    map_layers
    |> Enum.with_index(1)
    |> Enum.filter(fn {layer, _idx} -> Map.get(layer, :visible, true) != false end)
    |> Enum.map(fn {layer, idx} -> build_scale_legend(layer, idx, features) end)
    |> Enum.reject(&is_nil/1)
  end

  defp build_scale_legend(layer, idx, features) do
    scale_type = normalize_scale_type(Map.get(layer, :scale_type))
    title = layer_label(layer)
    layer_id = to_string(idx)

    entries =
      case scale_type do
        "categorical" -> categorical_legend_entries(layer, layer_id, features)
        "linear" -> linear_legend_entries(layer)
        _ -> numeric_steps_legend_entries(layer)
      end

    if entries == [], do: nil, else: %{title: title, entries: entries}
  end

  defp categorical_legend_entries(layer, layer_id, features) do
    values =
      features
      |> Enum.filter(fn feature -> get_in(feature, ["properties", "layer"]) == layer_id end)
      |> Enum.map(fn feature -> get_in(feature, ["properties", "raw_color"]) end)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Enum.take(6)

    palette = parse_palette(Map.get(layer, :scale_palette))

    Enum.map(values, fn value ->
      %{label: to_string(value), color: categorical_color(value, palette)}
    end)
  end

  defp linear_legend_entries(layer) do
    {low, high} = linear_palette(parse_palette(Map.get(layer, :scale_palette)))
    [%{label: "Low", color: low}, %{label: "High", color: high}]
  end

  defp numeric_steps_legend_entries(layer) do
    steps = parse_steps(Map.get(layer, :scale_steps))
    [c1, c2, c3, c4] = palette_for_steps(parse_palette(Map.get(layer, :scale_palette)))

    [
      %{label: "<=#{Enum.at(steps, 0)}", color: c1},
      %{label: "#{Enum.at(steps, 0) + 1}-#{Enum.at(steps, 1)}", color: c2},
      %{label: "#{Enum.at(steps, 1) + 1}-#{Enum.at(steps, 2)}", color: c3},
      %{label: ">#{Enum.at(steps, 2)}", color: c4}
    ]
  end

  defp css_color?(value) do
    String.match?(value, ~r/^#[0-9A-Fa-f]{3,8}$/) or
      String.match?(value, ~r/^rgba?\(.+\)$/i) or
      String.match?(value, ~r/^hsla?\(.+\)$/i)
  end

  defp show_layer_legend?(layers) when is_list(layers), do: length(visible_layers(layers)) > 1
  defp show_layer_legend?(_), do: false

  defp visible_layers(layers) do
    Enum.filter(layers, fn layer -> Map.get(layer, :visible, true) != false end)
  end

  defp layer_label(layer) do
    Map.get(layer, :label) || Map.get(layer, :geometry_field) || "Layer"
  end

  defp layer_swatch_class(layer) do
    case layer_kind(layer) do
      "line" -> "inline-block w-8 border-t"
      "area" -> "inline-block h-3.5 w-3.5 rounded-sm border"
      _ -> "inline-block h-3 w-3 rounded-full border"
    end
  end

  defp layer_swatch_style(layer) do
    color = default_layer_color(layer)
    stroke = Map.get(layer, :stroke_opacity, 0.9)
    fill = Map.get(layer, :fill_opacity, 0.25)
    line_weight = Map.get(layer, :line_weight, 2)
    dash = Map.get(layer, :line_dash_array)

    case layer_kind(layer) do
      "line" ->
        "border-color: #{color}; border-top-width: #{line_weight}px; border-top-style: #{if is_binary(dash) and dash != "", do: "dashed", else: "solid"}; opacity: #{stroke};"

      "area" ->
        "border-color: #{color}; border-width: #{line_weight}px; background-color: #{color}; opacity: #{max(fill, 0.2)};"

      _ ->
        "border-color: #{color}; background-color: #{color}; opacity: #{stroke};"
    end
  end

  defp default_layer_color(layer) do
    case Map.get(layer, :geometry_kind) do
      "line" -> "#2563eb"
      "area" -> "#0f766e"
      _ -> "#2563eb"
    end
  end

  defp layer_kind(layer) do
    case Map.get(layer, :geometry_kind) do
      value when value in ["point", "line", "area"] -> value
      _ -> infer_kind_from_field(Map.get(layer, :geometry_field))
    end
  end

  defp infer_kind_from_field(field) when is_binary(field) do
    down = String.downcase(field)

    cond do
      String.contains?(down, "line") or String.contains?(down, "route") or
          String.contains?(down, "path") ->
        "line"

      String.contains?(down, "zone") or String.contains?(down, "area") or
          String.contains?(down, "polygon") ->
        "area"

      true ->
        "point"
    end
  end

  defp infer_kind_from_field(_), do: "point"

  defp index_for_alias(aliases, key, default) do
    Enum.find_index(aliases, fn alias_name -> to_string(alias_name) == key end) || default
  end

  defp parse_geometry(nil), do: nil

  defp parse_geometry(%{"type" => _type} = geometry), do: geometry

  defp parse_geometry(geometry) when is_binary(geometry) do
    geometry
    |> String.trim()
    |> strip_srid_prefix()
    |> decode_geojson_or_wkt()
  end

  defp parse_geometry(_), do: nil

  defp strip_srid_prefix("SRID=" <> rest) do
    case String.split(rest, ";", parts: 2) do
      [_srid, geom] -> geom
      _ -> rest
    end
  end

  defp strip_srid_prefix(geometry), do: geometry

  defp decode_geojson_or_wkt("{" <> _ = json) do
    case Jason.decode(json) do
      {:ok, %{"type" => _type} = geometry} -> geometry
      _ -> nil
    end
  end

  defp decode_geojson_or_wkt("POINT(" <> _ = wkt), do: parse_wkt_point(wkt)
  defp decode_geojson_or_wkt("point(" <> _ = wkt), do: parse_wkt_point(wkt)
  defp decode_geojson_or_wkt(_), do: nil

  defp parse_wkt_point(wkt) do
    with "POINT(" <> rest <- String.upcase(wkt),
         coords <- String.trim_trailing(rest, ")"),
         [lng_str, lat_str] <- String.split(coords, ~r/\s+/, trim: true),
         {lng, ""} <- Float.parse(lng_str),
         {lat, ""} <- Float.parse(lat_str) do
      %{"type" => "Point", "coordinates" => [lng, lat]}
    else
      _ -> nil
    end
  end

  defp selecto_set(assigns) do
    case Map.get(assigns, :selecto) do
      %{set: set} when is_map(set) -> set
      _ -> %{}
    end
  end
end
