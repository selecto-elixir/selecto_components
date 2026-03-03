defmodule SelectoComponents.Views.Map.BreadcrumbsTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.Views.Map.Breadcrumbs

  test "normalize_playback_params/2 clamps and normalizes incoming params" do
    params = %{
      "vehicle_id" => "TRK-100",
      "route_id" => "",
      "grouping_mode" => "route",
      "playhead" => "145",
      "playback_speed" => "0",
      "max_points" => "50000",
      "sample_every" => "0",
      "max_tracks" => "999",
      "show_track_arrows" => "false",
      "show_track_endpoints" => "true"
    }

    normalized = Breadcrumbs.normalize_playback_params(params)

    assert normalized.vehicle_id == "TRK-100"
    assert normalized.route_id == nil
    assert normalized.grouping_mode == "route"
    assert normalized.playhead == 100
    assert normalized.playback_speed == 1
    assert normalized.max_points == 20_000
    assert normalized.sample_every == 1
    assert normalized.max_tracks == 200
    assert normalized.show_track_arrows == false
    assert normalized.show_track_endpoints == true
  end

  test "default_layer/1 returns breadcrumb-friendly map layer defaults" do
    layer = Breadcrumbs.default_layer(%{track_by: "route", show_track_arrows: false})

    assert layer.label == "Vehicle Breadcrumbs"
    assert layer.geometry_field == "location"
    assert layer.color_field == "age_minutes"
    assert layer.scale_type == "numeric_steps"
    assert layer.scale_steps == "10,30,90"
    assert layer.track_by == "route"
    assert layer.track_order_field == "occurred_at"
    assert layer.show_track_arrows == false
    assert layer.show_track_endpoints == true
  end
end
