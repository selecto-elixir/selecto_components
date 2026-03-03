defmodule SelectoComponents.Views.Map.ComponentTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias SelectoComponents.Views.Map.Component

  test "prepare_features/2 builds geojson features from aliased rows" do
    rows = [
      [~s({"type":"Point","coordinates":[-87.6,41.8]}), "Chicago", "#ef4444"]
    ]

    aliases = ["__map_geometry", "__map_popup", "__map_color"]

    [feature] = Component.prepare_features(rows, aliases)

    assert feature["type"] == "Feature"
    assert feature["geometry"]["type"] == "Point"
    assert feature["properties"]["popup"] == "Chicago"
    assert feature["properties"]["color"] == "#ef4444"
  end

  test "prepare_features/2 maps numeric dwell minutes to marker colors" do
    rows = [
      [~s({"type":"Point","coordinates":[-118.2437,34.0522]}), "LAX-001", 18],
      [~s({"type":"Point","coordinates":[-118.1937,33.7701]}), "LGB-014", "57"],
      [~s({"type":"Point","coordinates":[-123.1207,49.2827]}), "YVR-019", 128]
    ]

    aliases = ["__map_geometry", "__map_popup", "__map_color"]

    features = Component.prepare_features(rows, aliases)

    assert Enum.at(features, 0)["properties"]["color"] == "#16a34a"
    assert Enum.at(features, 1)["properties"]["color"] == "#f97316"
    assert Enum.at(features, 2)["properties"]["color"] == "#dc2626"
  end

  test "prepare_features/2 builds features for multiple geometry aliases" do
    rows = [
      [
        ~s({"type":"Point","coordinates":[-118.2437,34.0522]}),
        "LAX-001",
        18,
        ~s({"type":"LineString","coordinates":[[-118.2437,34.0522],[-118.1637,34.1022]]}),
        "Route LAX-001",
        "#2563eb"
      ]
    ]

    aliases = [
      "__map_geometry",
      "__map_popup",
      "__map_color",
      "__map_geometry_2",
      "__map_popup_2",
      "__map_color_2"
    ]

    [feature_one, feature_two] = Component.prepare_features(rows, aliases)

    assert feature_one["geometry"]["type"] == "Point"
    assert feature_one["properties"]["layer"] == "1"
    assert feature_two["geometry"]["type"] == "LineString"
    assert feature_two["properties"]["layer"] == "2"
  end

  test "render includes map hook when results are present" do
    html =
      render_component(Component,
        id: "map-test",
        executed: true,
        query_results:
          {[[~s({"type":"Point","coordinates":[-87.6,41.8]}), "Chicago"]], [],
           ["__map_geometry", "__map_popup"]},
        selecto: %{
          set: %{map_zoom: 6, map_center: {41.8, -87.6}, map_color_field: "dwell_minutes"}
        }
      )

    assert html =~ ~r/phx-hook="[^"]*MapComponent"/
    assert html =~ "data-features="
    assert html =~ "data-map-layers="
    assert html =~ "Map View"
    assert html =~ "Dwell Time Legend"
  end

  test "render shows layer legend when multiple layers are visible" do
    html =
      render_component(Component,
        id: "map-test-layers",
        executed: true,
        query_results:
          {[
             [
               ~s({"type":"Point","coordinates":[-87.6,41.8]}),
               "Chicago",
               "#ef4444",
               ~s({"type":"LineString","coordinates":[[-87.6,41.8],[-87.4,41.9]]}),
               "Route A",
               "#2563eb"
             ]
           ], [],
           [
             "__map_geometry",
             "__map_popup",
             "__map_color",
             "__map_geometry_2",
             "__map_popup_2",
             "__map_color_2"
           ]},
        selecto: %{
          set: %{
            map_zoom: 6,
            map_center: {41.8, -87.6},
            map_layers: [
              %{
                label: "Pickups",
                geometry_field: "location",
                geometry_kind: "point",
                visible: true
              },
              %{
                label: "Routes",
                geometry_field: "route_path",
                geometry_kind: "line",
                visible: true
              }
            ]
          }
        }
      )

    assert html =~ "Layer Legend"
    assert html =~ "Pickups"
    assert html =~ "Routes"
  end
end
