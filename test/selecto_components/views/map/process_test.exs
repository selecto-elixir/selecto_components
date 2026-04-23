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
        fields: [:id, :name, :status, :latitude, :longitude],
        redact_fields: [],
        columns: %{
          id: %{type: :integer, name: "ID", colid: :id},
          name: %{type: :string, name: "Name", colid: :name},
          status: %{type: :string, name: "Status", colid: :status},
          latitude: %{type: :float, name: "Latitude", colid: :latitude},
          longitude: %{type: :float, name: "Longitude", colid: :longitude}
        },
        associations: %{}
      },
      schemas: %{},
      joins: %{}
    }

    Selecto.configure(domain, nil, validate: false)
  end
end
