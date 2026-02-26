defmodule SelectoComponents.Views.Map.ProcessTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.Views.Map.Process

  describe "initial_state/2" do
    test "uses map defaults from configured domain metadata" do
      selecto = build_selecto()

      state = Process.initial_state(selecto, :map)

      assert state.geometry_field == "location"
      assert state.tile_url =~ "openstreetmap"
      assert is_integer(state.default_zoom)
      assert state.default_zoom > 0
      assert state.fit_bounds == true
    end
  end

  describe "view/5" do
    test "builds map select set with spatial projection" do
      selecto = build_selecto()

      columns = %{
        "location" => %{name: "location", type: :geometry, colid: :location},
        "name" => %{name: "name", type: :string, colid: :name}
      }

      params = %{
        "geometry_field" => "location",
        "popup_field" => "name",
        "default_zoom" => "5",
        "max_points" => "250"
      }

      {view_set, _meta} = Process.view(%{}, params, columns, [], selecto)

      assert view_set.limit == 250
      assert view_set.map_geometry_field == "location"
      assert view_set.map_popup_field == "name"
      assert view_set.map_zoom == 5

      assert {:field, {:st_asgeojson, "location"}, "__map_geometry"} in view_set.selected
      assert {:field, "name", "__map_popup"} in view_set.selected
    end
  end

  defp build_selecto do
    domain = %{
      name: "Spatial",
      source: %{
        source_table: "places",
        primary_key: :id,
        fields: [:id, :name, :location],
        redact_fields: [],
        columns: %{
          id: %{type: :integer},
          name: %{type: :string},
          location: %{type: :geometry}
        },
        associations: %{}
      },
      schemas: %{},
      joins: %{},
      postgis: %{
        map_view: %{
          geometry_field: "location",
          popup_field: "name",
          tile_url: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
          attribution: "&copy; OpenStreetMap contributors",
          default_zoom: 3,
          fit_bounds: true,
          max_points: 2_000
        }
      }
    }

    Selecto.configure(domain, nil)
  end
end
