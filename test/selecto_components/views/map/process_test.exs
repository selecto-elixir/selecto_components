defmodule SelectoComponents.Views.Map.ProcessTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.Views.Map.Process

  test "view builds lat/lon point selections when source_mode is lat_lon" do
    selecto = selecto()

    {view_set, _view_meta} =
      Process.view(
        %{
          map_view: %{
            source_mode: :lat_lon,
            latitude_field: "latitude",
            longitude_field: "longitude",
            popup_field: "name",
            color_field: "status"
          }
        },
        %{
          "source_mode" => "lat_lon",
          "latitude_field" => "latitude",
          "longitude_field" => "longitude",
          "popup_field" => "name",
          "color_field" => "status"
        },
        columns_map(selecto),
        [],
        selecto
      )

    assert view_set.selected == [
             {:field, "latitude", "__map_lat"},
             {:field, "longitude", "__map_lng"},
             {:field, "name", "__map_popup"},
             {:field, "status", "__map_color"}
           ]

    assert view_set.map_source_mode == :lat_lon
    assert view_set.map_latitude_field == "latitude"
    assert view_set.map_longitude_field == "longitude"
  end

  test "view includes track path field for lat lon source mode" do
    selecto = selecto()

    {view_set, _view_meta} =
      Process.view(
        %{
          map_view: %{
            source_mode: :lat_lon,
            latitude_field: "latitude",
            longitude_field: "longitude",
            track_path_field: "recent_locations",
            popup_field: "name"
          }
        },
        %{
          "source_mode" => "lat_lon",
          "latitude_field" => "latitude",
          "longitude_field" => "longitude",
          "track_path_field" => "recent_locations",
          "popup_field" => "name"
        },
        columns_map(selecto),
        [],
        selecto
      )

    assert {:field, "recent_locations", "__map_track_path"} in view_set.selected
  end

  test "view includes track path field for geometry source mode" do
    selecto = geometry_selecto()

    {view_set, _view_meta} =
      Process.view(
        %{
          map_view: %{
            source_mode: :geometry,
            geometry_field: "location",
            track_path_field: "recent_locations"
          }
        },
        %{
          "source_mode" => "geometry",
          "geometry_field" => "location",
          "track_path_field" => "recent_locations"
        },
        columns_map(selecto),
        [],
        selecto
      )

    assert {:field, "recent_locations", "__map_track_path"} in view_set.selected
  end

  defp columns_map(selecto) do
    selecto
    |> Selecto.columns()
    |> Enum.into(%{}, fn {key, col} -> {key, Map.put(col, :name, to_string(key))} end)
    |> then(fn cols ->
      Enum.reduce(cols, cols, fn {_key, col}, acc -> Map.put(acc, col.name, col) end)
    end)
  end

  defp selecto do
    domain = %{
      name: "MapLatLonProcessTest",
      source: %{
        source_table: "sites",
        primary_key: :id,
        fields: [:id, :name, :status, :latitude, :longitude, :recent_locations],
        redact_fields: [],
        columns: %{
          id: %{type: :integer, name: "ID", colid: :id},
          name: %{type: :string, name: "Name", colid: :name},
          status: %{type: :string, name: "Status", colid: :status},
          latitude: %{type: :float, name: "Latitude", colid: :latitude},
          longitude: %{type: :float, name: "Longitude", colid: :longitude},
          recent_locations: %{type: :jsonb, name: "Recent Locations", colid: :recent_locations}
        },
        associations: %{}
      },
      schemas: %{},
      joins: %{}
    }

    Selecto.configure(domain, nil, validate: false)
  end

  defp geometry_selecto do
    domain = %{
      name: "MapGeometryProcessTest",
      source: %{
        source_table: "sites",
        primary_key: :id,
        fields: [:id, :location, :recent_locations],
        redact_fields: [],
        columns: %{
          id: %{type: :integer, name: "ID", colid: :id},
          location: %{type: :geometry, name: "Location", colid: :location},
          recent_locations: %{type: :jsonb, name: "Recent Locations", colid: :recent_locations}
        },
        associations: %{}
      },
      schemas: %{},
      joins: %{}
    }

    Selecto.configure(domain, nil, validate: false)
  end
end
