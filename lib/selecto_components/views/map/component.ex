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
    features = prepare_features(rows, aliases)
    map_set = selecto_set(assigns)

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
        map_layers: Map.get(map_set, :map_layers, []),
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

        <%= if show_dwell_legend?(@map_color_field) do %>
          <div class="mt-3 rounded-md border border-slate-200 bg-slate-50 p-3">
            <div class="text-xs font-semibold uppercase tracking-wide text-slate-700">
              Dwell Time Legend
            </div>
            <div class="mt-2 flex flex-wrap items-center gap-3 text-xs text-slate-700">
              <span class="inline-flex items-center gap-1.5">
                <span class="h-2.5 w-2.5 rounded-full bg-[#16a34a]"></span>0-20 min
              </span>
              <span class="inline-flex items-center gap-1.5">
                <span class="h-2.5 w-2.5 rounded-full bg-[#f59e0b]"></span>21-45 min
              </span>
              <span class="inline-flex items-center gap-1.5">
                <span class="h-2.5 w-2.5 rounded-full bg-[#f97316]"></span>46-90 min
              </span>
              <span class="inline-flex items-center gap-1.5">
                <span class="h-2.5 w-2.5 rounded-full bg-[#dc2626]"></span>91+ min
              </span>
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
    layers = map_layer_indexes(aliases)

    rows
    |> Enum.map(&row_to_list/1)
    |> Enum.flat_map(fn row ->
      Enum.map(layers, fn layer ->
        geometry = row |> Enum.at(layer.geometry_ix) |> parse_geometry()

        if geometry do
          %{
            "type" => "Feature",
            "geometry" => geometry,
            "properties" => %{
              "popup" => optional_value(row, layer.popup_ix),
              "color" => row |> optional_value(layer.color_ix) |> normalize_marker_color(),
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

  def prepare_features(_rows, _aliases), do: []

  defp row_to_list(row) when is_tuple(row), do: Tuple.to_list(row)
  defp row_to_list(row) when is_list(row), do: row
  defp row_to_list(_), do: []

  defp optional_value(_row, nil), do: nil
  defp optional_value(row, index), do: Enum.at(row, index)

  defp map_layer_indexes(aliases) do
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

    if layers == [] do
      [
        %{
          geometry_ix: 0,
          popup_ix: index_for_alias(aliases, "__map_popup", nil),
          color_ix: index_for_alias(aliases, "__map_color", nil),
          layer_id: "1"
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

  defp normalize_marker_color(nil), do: @default_marker_color

  defp normalize_marker_color(value) when is_integer(value) do
    dwell_color(value)
  end

  defp normalize_marker_color(value) when is_float(value) do
    value
    |> round()
    |> dwell_color()
  end

  defp normalize_marker_color(value) when is_binary(value) do
    trimmed = String.trim(value)

    cond do
      trimmed == "" ->
        @default_marker_color

      css_color?(trimmed) ->
        trimmed

      true ->
        case Integer.parse(trimmed) do
          {minutes, ""} -> dwell_color(minutes)
          _ -> @default_marker_color
        end
    end
  end

  defp normalize_marker_color(_), do: @default_marker_color

  defp dwell_color(minutes) when minutes <= 20, do: "#16a34a"
  defp dwell_color(minutes) when minutes <= 45, do: "#f59e0b"
  defp dwell_color(minutes) when minutes <= 90, do: "#f97316"
  defp dwell_color(_minutes), do: "#dc2626"

  defp css_color?(value) do
    String.match?(value, ~r/^#[0-9A-Fa-f]{3,8}$/) or
      String.match?(value, ~r/^rgba?\(.+\)$/i) or
      String.match?(value, ~r/^hsla?\(.+\)$/i) or
      String.match?(value, ~r/^[A-Za-z]+$/)
  end

  defp show_dwell_legend?(nil), do: false

  defp show_dwell_legend?(field) when is_atom(field) do
    show_dwell_legend?(Atom.to_string(field))
  end

  defp show_dwell_legend?(field) when is_binary(field) do
    String.contains?(String.downcase(field), "dwell")
  end

  defp show_dwell_legend?(_), do: false

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
