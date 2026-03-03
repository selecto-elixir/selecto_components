defmodule SelectoComponents.Form.ParamsStateTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.Form.ParamsState

  test "view_config_to_params includes detail max_rows and per_page" do
    view_config = %{
      view_mode: "detail",
      filters: [],
      views: %{
        detail: %{
          selected: [],
          order_by: [],
          per_page: "60",
          max_rows: "10000",
          prevent_denormalization: true
        }
      }
    }

    params = ParamsState.view_config_to_params(view_config)

    assert params["view_mode"] == "detail"
    assert params["per_page"] == "60"
    assert params["max_rows"] == "10000"
    assert params["prevent_denormalization"] == "true"
  end

  test "view_config_to_params includes aggregate per-page config" do
    view_config = %{
      view_mode: "aggregate",
      filters: [],
      views: %{
        aggregate: %{
          group_by: [],
          aggregate: [],
          per_page: "300"
        }
      }
    }

    params = ParamsState.view_config_to_params(view_config)

    assert params["view_mode"] == "aggregate"
    assert params["aggregate_per_page"] == "300"
    refute Map.has_key?(params, "max_rows")
  end

  test "view_config_to_params includes map scalar config" do
    view_config = %{
      view_mode: "map",
      filters: [],
      views: %{
        map: %{
          geometry_field: "location",
          popup_field: "name",
          color_field: "status",
          tile_url: "https://tiles.example.test/{z}/{x}/{y}.png",
          attribution: "Example attribution",
          default_zoom: 7,
          center_lat: 41.2,
          center_lng: -87.6,
          fit_bounds: false,
          max_points: 250,
          cluster: true
        }
      }
    }

    params = ParamsState.view_config_to_params(view_config)

    assert params["view_mode"] == "map"
    assert params["geometry_field"] == "location"
    assert params["popup_field"] == "name"
    assert params["color_field"] == "status"
    assert params["tile_url"] == "https://tiles.example.test/{z}/{x}/{y}.png"
    assert params["attribution"] == "Example attribution"
    assert params["default_zoom"] == "7"
    assert params["center_lat"] == "41.2"
    assert params["center_lng"] == "-87.6"
    assert params["fit_bounds"] == "false"
    assert params["max_points"] == "250"
    assert params["cluster"] == "true"
  end

  test "view_config_to_params includes map layer config" do
    view_config = %{
      view_mode: "map",
      filters: [],
      views: %{
        map: %{
          map_layers: [
            %{
              label: "Pickup",
              geometry_field: "location",
              popup_field: "pickup_code",
              color_field: "dwell_minutes",
              point_radius: 8,
              fill_opacity: 0.35,
              visible: true
            },
            %{
              label: "Route",
              geometry_field: "route_path",
              popup_field: "pickup_code",
              color_field: "status",
              line_weight: 3,
              line_dash_array: "6,4",
              visible: false
            }
          ]
        }
      }
    }

    params = ParamsState.view_config_to_params(view_config)

    assert params["view_mode"] == "map"
    assert params["map_layers"]["0"]["geometry_field"] == "location"
    assert params["map_layers"]["0"]["point_radius"] == "8"
    assert params["map_layers"]["0"]["fill_opacity"] == "0.35"
    assert params["map_layers"]["0"]["visible"] == "true"
    assert params["map_layers"]["1"]["geometry_field"] == "route_path"
    assert params["map_layers"]["1"]["line_weight"] == "3"
    assert params["map_layers"]["1"]["line_dash_array"] == "6,4"
    assert params["map_layers"]["1"]["visible"] == "false"
  end

  test "convert_saved_config_to_full_params restores map settings" do
    saved = %{
      "map" => %{
        "geometry_field" => "location",
        "popup_field" => "name",
        "color_field" => "status",
        "default_zoom" => 8,
        "center" => [10.5, -122.75],
        "max_points" => 321,
        "fit_bounds" => false,
        "cluster" => true,
        "tile_url" => "https://tiles.example.test/{z}/{x}/{y}.png",
        "attribution" => "Saved attribution"
      }
    }

    params = ParamsState.convert_saved_config_to_full_params(saved, "map")

    assert params["view_mode"] == "map"
    assert params["geometry_field"] == "location"
    assert params["popup_field"] == "name"
    assert params["color_field"] == "status"
    assert params["default_zoom"] == "8"
    assert params["center_lat"] == "10.5"
    assert params["center_lng"] == "-122.75"
    assert params["max_points"] == "321"
    assert params["fit_bounds"] == "false"
    assert params["cluster"] == "true"
    assert params["tile_url"] == "https://tiles.example.test/{z}/{x}/{y}.png"
    assert params["attribution"] == "Saved attribution"
  end

  test "convert_saved_config_to_full_params restores map layer settings" do
    saved = %{
      "map" => %{
        "map_layers" => [
          %{
            "label" => "Pickup",
            "geometry_field" => "location",
            "popup_field" => "pickup_code",
            "color_field" => "dwell_minutes",
            "point_radius" => 8,
            "fill_opacity" => 0.35,
            "visible" => true
          },
          %{
            "label" => "Route",
            "geometry_field" => "route_path",
            "popup_field" => "pickup_code",
            "color_field" => "status",
            "line_weight" => 3,
            "line_dash_array" => "6,4",
            "visible" => false
          }
        ]
      }
    }

    params = ParamsState.convert_saved_config_to_full_params(saved, "map")

    assert params["view_mode"] == "map"
    assert params["map_layers"]["0"]["geometry_field"] == "location"
    assert params["map_layers"]["0"]["point_radius"] == "8"
    assert params["map_layers"]["1"]["geometry_field"] == "route_path"
    assert params["map_layers"]["1"]["line_dash_array"] == "6,4"
    assert params["map_layers"]["1"]["visible"] == "false"
  end
end
