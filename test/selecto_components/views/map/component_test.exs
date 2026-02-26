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

  test "render includes map hook when results are present" do
    html =
      render_component(Component,
        id: "map-test",
        executed: true,
        query_results:
          {[[~s({"type":"Point","coordinates":[-87.6,41.8]}), "Chicago"]], [],
           ["__map_geometry", "__map_popup"]},
        selecto: %{set: %{map_zoom: 6, map_center: {41.8, -87.6}}}
      )

    assert html =~ ~r/phx-hook="[^"]*MapComponent"/
    assert html =~ "data-features="
    assert html =~ "Map View"
  end
end
