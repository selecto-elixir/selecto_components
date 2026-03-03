defmodule SelectoComponents.Views.Map.ProcessTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.Views.Map.Process

  describe "normalize_config/1" do
    test "normalizes mixed map config keys" do
      config =
        Process.normalize_config(%{
          "geometry_field" => "  location  ",
          "popup_field" => "",
          "default_zoom" => "21",
          "center" => "95,-190",
          "fit_bounds" => "false",
          "max_points" => "0",
          "cluster" => "true"
        })

      assert config.geometry_field == "location"
      refute Map.has_key?(config, :popup_field)
      assert config.default_zoom == 20
      assert config.center_lat == 90.0
      assert config.center_lng == -180.0
      assert config.fit_bounds == false
      assert config.max_points == 1
      assert config.cluster == true
    end
  end

  describe "initial_state/2" do
    test "uses map defaults from configured domain metadata" do
      selecto = build_selecto()

      state = Process.initial_state(selecto, %{})

      assert state.geometry_field == "location"
      assert state.tile_url =~ "openstreetmap"
      assert state.default_zoom == 4
      assert state.center_lat == 41.2
      assert state.center_lng == -87.6
      assert state.fit_bounds == true
      assert state.cluster == false
    end

    test "view options override domain and postgis defaults" do
      selecto = build_selecto()

      state =
        Process.initial_state(selecto, %{
          map_view: %{
            "default_zoom" => "9",
            "center" => [10.25, -121.5],
            "fit_bounds" => "false",
            "max_points" => "333",
            "cluster" => "true",
            "tile_url" => "https://tiles.example.test/{z}/{x}/{y}.png"
          }
        })

      assert state.default_zoom == 9
      assert state.center_lat == 10.25
      assert state.center_lng == -121.5
      assert state.fit_bounds == false
      assert state.max_points == 333
      assert state.cluster == true
      assert state.tile_url == "https://tiles.example.test/{z}/{x}/{y}.png"
    end

    test "config keys include contract fields" do
      assert :geometry_field in Process.config_keys()
      assert :popup_field in Process.config_keys()
      assert :color_field in Process.config_keys()
      assert :cluster in Process.config_keys()
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
        "max_points" => "250",
        "cluster" => "true"
      }

      {view_set, _meta} = Process.view(%{}, params, columns, [], selecto)

      assert view_set.limit == 250
      assert view_set.map_geometry_field == "location"
      assert view_set.map_popup_field == "name"
      assert view_set.map_zoom == 5
      assert view_set.map_cluster == true
      assert view_set.group_by == []
      assert view_set.aggregates == []

      assert {:field, {:st_asgeojson, "location"}, "__map_geometry"} in view_set.selected
      assert {:field, "name", "__map_popup"} in view_set.selected
    end

    test "builds selected fields for configured map layers" do
      selecto = build_selecto()

      columns = %{
        "location" => %{name: "location", type: :geometry, colid: :location},
        "route_path" => %{name: "route_path", type: :geometry, colid: :route_path},
        "name" => %{name: "name", type: :string, colid: :name},
        "status" => %{name: "status", type: :string, colid: :status}
      }

      params = %{
        "map_layers" => [
          %{
            "geometry_field" => "location",
            "geometry_kind" => "point",
            "popup_field" => "name",
            "color_field" => "status",
            "point_radius" => "9",
            "fill_opacity" => "0.4"
          },
          %{
            "geometry_field" => "route_path",
            "geometry_kind" => "line",
            "popup_field" => "name",
            "color_field" => "status",
            "line_weight" => "4",
            "line_dash_array" => "6,4"
          }
        ]
      }

      {view_set, _meta} = Process.view(%{}, params, columns, [], selecto)

      assert length(view_set.map_layers) == 2
      assert {:field, {:st_asgeojson, "location"}, "__map_geometry"} in view_set.selected
      assert {:field, {:st_asgeojson, "route_path"}, "__map_geometry_2"} in view_set.selected
      assert {:field, "name", "__map_popup_2"} in view_set.selected
      assert {:field, "status", "__map_color_2"} in view_set.selected
      assert Enum.at(view_set.map_layers, 0).point_radius == 9
      assert Enum.at(view_set.map_layers, 0).fill_opacity == 0.4
      assert Enum.at(view_set.map_layers, 0).geometry_kind == "point"
      assert Enum.at(view_set.map_layers, 1).line_weight == 4
      assert Enum.at(view_set.map_layers, 1).line_dash_array == "6,4"
      assert Enum.at(view_set.map_layers, 1).geometry_kind == "line"
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
          "geometry_field" => "location",
          "popup_field" => "name",
          "tile_url" => "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
          "attribution" => "&copy; OpenStreetMap contributors",
          "default_zoom" => "4",
          "center" => [41.2, -87.6],
          "fit_bounds" => "true",
          "max_points" => "2000",
          "cluster" => "false"
        }
      }
    }

    Selecto.configure(domain, nil)
  end
end
