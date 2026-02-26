defmodule SelectoComponents.Views.Map.Component do
  use Phoenix.LiveComponent

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

    map_id = "map-#{assigns[:id] || :rand.uniform(10000)}"

    center =
      case get_in(assigns, [:selecto, :set, :map_center]) do
        {lat, lng} when is_number(lat) and is_number(lng) -> %{lat: lat, lng: lng}
        _ -> %{lat: 0.0, lng: 0.0}
      end

    assigns =
      assign(assigns,
        map_id: map_id,
        features: features,
        map_tile_url:
          get_in(assigns, [:selecto, :set, :map_tile_url]) ||
            "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
        map_attribution:
          get_in(assigns, [:selecto, :set, :map_attribution]) ||
            "&copy; OpenStreetMap contributors",
        map_zoom: get_in(assigns, [:selecto, :set, :map_zoom]) || 3,
        map_center: center,
        fit_bounds: get_in(assigns, [:selecto, :set, :map_fit_bounds]) != false
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
          class="w-full rounded-lg border border-gray-200"
          style="height: 460px;"
        >
        </div>

        <script :type={Phoenix.LiveView.ColocatedHook} name=".MapComponent">
          const LEAFLET_JS = "https://unpkg.com/leaflet@1.9.4/dist/leaflet.js";
          const LEAFLET_CSS = "https://unpkg.com/leaflet@1.9.4/dist/leaflet.css";

          function loadCssOnce(url) {
            if (document.querySelector(`link[data-leaflet-css="${url}"]`)) return;
            const link = document.createElement("link");
            link.rel = "stylesheet";
            link.href = url;
            link.dataset.leafletCss = url;
            document.head.appendChild(link);
          }

          function loadScriptOnce(url) {
            return new Promise((resolve, reject) => {
              if (window.L) {
                resolve();
                return;
              }

              const existing = document.querySelector(`script[data-leaflet-js="${url}"]`);
              if (existing) {
                existing.addEventListener("load", () => resolve(), { once: true });
                existing.addEventListener("error", () => reject(new Error("Leaflet failed to load")), { once: true });
                return;
              }

              const script = document.createElement("script");
              script.src = url;
              script.dataset.leafletJs = url;
              script.async = true;
              script.onload = () => resolve();
              script.onerror = () => reject(new Error("Leaflet failed to load"));
              document.head.appendChild(script);
            });
          }

          export default {
            map: null,
            markers: null,
            tileLayer: null,

            mounted() {
              this.initializeMap();
            },

            updated() {
              this.renderFeatures();
            },

            destroyed() {
              if (this.map) {
                this.map.remove();
                this.map = null;
              }
            },

            async initializeMap() {
              loadCssOnce(LEAFLET_CSS);
              try {
                await loadScriptOnce(LEAFLET_JS);
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

            renderFeatures() {
              if (!this.map || !this.markers || !window.L) return;

              let features = [];
              try {
                features = JSON.parse(this.el.dataset.features || "[]");
              } catch (_error) {
                features = [];
              }

              this.markers.clearLayers();

              for (const feature of features) {
                const color = feature?.properties?.color || "#2563eb";

                const layer = window.L.geoJSON(feature, {
                  pointToLayer: (_feature, latlng) =>
                    window.L.circleMarker(latlng, {
                      radius: 6,
                      color,
                      fillColor: color,
                      fillOpacity: 0.85,
                      weight: 1
                    }),
                  style: () => ({ color, weight: 2, opacity: 0.9, fillOpacity: 0.25 })
                });

                const popup = feature?.properties?.popup;
                if (popup !== null && popup !== undefined && popup !== "") {
                  layer.bindPopup(String(popup));
                }

                layer.addTo(this.markers);
              }

              const fitBounds = this.el.dataset.fitBounds === "true";
              if (fitBounds && this.markers.getLayers().length > 0) {
                this.map.fitBounds(this.markers.getBounds(), { padding: [24, 24], maxZoom: 14 });
              }
            }
          }
        </script>
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
    geometry_ix = index_for_alias(aliases, "__map_geometry", 0)
    popup_ix = index_for_alias(aliases, "__map_popup", nil)
    color_ix = index_for_alias(aliases, "__map_color", nil)

    rows
    |> Enum.map(&row_to_list/1)
    |> Enum.map(fn row ->
      geometry = row |> Enum.at(geometry_ix) |> parse_geometry()

      if geometry do
        %{
          "type" => "Feature",
          "geometry" => geometry,
          "properties" => %{
            "popup" => optional_value(row, popup_ix),
            "color" => optional_value(row, color_ix)
          }
        }
      else
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  def prepare_features(_rows, _aliases), do: []

  defp row_to_list(row) when is_tuple(row), do: Tuple.to_list(row)
  defp row_to_list(row) when is_list(row), do: row
  defp row_to_list(_), do: []

  defp optional_value(_row, nil), do: nil
  defp optional_value(row, index), do: Enum.at(row, index)

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
end
