defmodule SelectoComponents.Views.Map.FormTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias SelectoComponents.Theme
  alias SelectoComponents.Views.Map.Form

  test "renders themed map layer and viewport controls" do
    html = render_component(Form, base_assigns())

    assert html =~ "Map Layers"
    assert html =~ "Geometry Field"
    assert html =~ "Background Mode"
    assert html =~ "Fit map to query bounds"
    assert html =~ "sc-panel"
    assert html =~ "sc-input"
    assert html =~ "sc-select"
    assert html =~ "accent-color: var(--sc-accent);"
  end

  test "renders lat lon controls and hides map layers in lat_lon mode" do
    html = render_component(Form, lat_lon_assigns())

    assert html =~ "Source Mode"
    assert html =~ "Latitude / Longitude (numeric)"
    assert html =~ "Lat / Lon Fields"
    assert html =~ "Latitude Field"
    assert html =~ "Longitude Field"
    refute html =~ "Map Layers"
    refute html =~ "Geometry Field"
  end

  defp base_assigns do
    domain = %{
      source: %{
        source_table: "type_coverage_records",
        primary_key: :id,
        fields: [:name, :status, :location],
        redact_fields: [],
        columns: %{
          name: %{type: :string, name: "Name", colid: :name},
          status: %{type: :string, name: "Status", colid: :status},
          location: %{type: :geometry, name: "Location", colid: :location}
        },
        associations: %{}
      },
      schemas: %{},
      joins: %{},
      pivot: %{},
      extensions: [Selecto.Extensions.PostGIS]
    }

    %{
      id: "map-form-test",
      theme: Theme.default_theme(:light),
      selecto: Selecto.configure(domain, nil, validate: false),
      view_config: %{
        views: %{
          map: %{
            map_layers: [
              %{
                geometry_field: "location",
                geometry_kind: "point",
                popup_field: "name",
                color_field: "status",
                visible: true
              }
            ],
            default_zoom: 4,
            fit_bounds: true,
            background_mode: "tiles",
            coordinate_mode: "latlng"
          }
        }
      }
    }
  end

  defp lat_lon_assigns do
    domain = %{
      source: %{
        source_table: "type_coverage_records",
        primary_key: :id,
        fields: [:id, :co_name, :latitude, :longitude],
        redact_fields: [],
        columns: %{
          id: %{type: :integer, name: "ID", colid: :id},
          co_name: %{type: :string, name: "Company", colid: :co_name},
          latitude: %{type: :decimal, name: "Latitude", colid: :latitude},
          longitude: %{type: :decimal, name: "Longitude", colid: :longitude}
        },
        associations: %{}
      },
      schemas: %{},
      joins: %{},
      pivot: %{},
      default_map_source_mode: :lat_lon,
      default_map_latitude_field: "latitude",
      default_map_longitude_field: "longitude",
      default_map_popup_field: "co_name"
    }

    %{
      id: "map-form-lat-lon-test",
      theme: Theme.default_theme(:light),
      selecto: Selecto.configure(domain, nil, validate: false),
      view_config: %{
        views: %{
          map: %{
            source_mode: :lat_lon,
            latitude_field: "latitude",
            longitude_field: "longitude",
            popup_field: "co_name",
            default_zoom: 4,
            fit_bounds: true,
            background_mode: "tiles",
            coordinate_mode: "latlng"
          }
        }
      }
    }
  end
end
