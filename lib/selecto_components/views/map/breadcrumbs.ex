defmodule SelectoComponents.Views.Map.Breadcrumbs do
  @moduledoc """
  Shared contract helpers for breadcrumb playback experiences built on the map view.

  This module intentionally keeps the contract small and transport-friendly:

  - playback/filter params normalization (`normalize_playback_params/2`)
  - default breadcrumb map layer metadata (`default_layer/1`)
  """

  @default_params %{
    vehicle_id: nil,
    route_id: nil,
    grouping_mode: "vehicle",
    playhead: 100,
    playback_speed: 2,
    max_points: 2000,
    sample_every: 1,
    max_tracks: 40,
    show_track_arrows: true,
    show_track_endpoints: true
  }

  @spec default_params() :: map()
  def default_params, do: @default_params

  @spec normalize_playback_params(map(), map()) :: map()
  def normalize_playback_params(params, defaults \\ %{})
      when is_map(params) and is_map(defaults) do
    defaults = Map.merge(@default_params, defaults)

    %{
      vehicle_id: blank_to_nil(get_value(params, :vehicle_id, defaults.vehicle_id)),
      route_id: blank_to_nil(get_value(params, :route_id, defaults.route_id)),
      grouping_mode:
        normalize_grouping_mode(get_value(params, :grouping_mode, defaults.grouping_mode)),
      playhead:
        params
        |> get_value(:playhead, defaults.playhead)
        |> to_int(defaults.playhead)
        |> clamp(0, 100),
      playback_speed:
        params
        |> get_value(:playback_speed, defaults.playback_speed)
        |> to_int(defaults.playback_speed)
        |> clamp(1, 10),
      max_points:
        params
        |> get_value(:max_points, defaults.max_points)
        |> to_int(defaults.max_points)
        |> clamp(50, 20_000),
      sample_every:
        params
        |> get_value(:sample_every, defaults.sample_every)
        |> to_int(defaults.sample_every)
        |> clamp(1, 30),
      max_tracks:
        params
        |> get_value(:max_tracks, defaults.max_tracks)
        |> to_int(defaults.max_tracks)
        |> clamp(1, 200),
      show_track_arrows:
        params
        |> get_value(:show_track_arrows, defaults.show_track_arrows)
        |> to_bool(defaults.show_track_arrows),
      show_track_endpoints:
        params
        |> get_value(:show_track_endpoints, defaults.show_track_endpoints)
        |> to_bool(defaults.show_track_endpoints)
    }
  end

  @spec default_layer(map()) :: map()
  def default_layer(overrides \\ %{}) when is_map(overrides) do
    %{
      label: "Vehicle Breadcrumbs",
      geometry_field: "location",
      geometry_kind: "point",
      color_field: "age_minutes",
      scale_type: "numeric_steps",
      scale_steps: "10,30,90",
      scale_palette: "#22c55e,#84cc16,#f59e0b,#64748b",
      track_by: "vehicle",
      track_order_field: "occurred_at",
      show_track_arrows: true,
      show_track_endpoints: true,
      point_radius: 5,
      line_weight: 3,
      line_dash_array: "",
      fill_opacity: 0.85,
      stroke_opacity: 0.9,
      visible: true
    }
    |> Map.merge(overrides)
  end

  defp get_value(map, key, default) do
    Map.get(map, key, Map.get(map, to_string(key), default))
  end

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(value), do: value

  defp to_int(value, _default) when is_integer(value), do: value

  defp to_int(value, default) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {parsed, ""} -> parsed
      _ -> default
    end
  end

  defp to_int(_value, default), do: default

  defp to_bool(value, _default) when is_boolean(value), do: value

  defp to_bool(value, default) when is_binary(value) do
    case String.downcase(String.trim(value)) do
      value when value in ["true", "1", "yes", "on"] -> true
      value when value in ["false", "0", "no", "off"] -> false
      _ -> default
    end
  end

  defp to_bool(_value, default), do: default

  defp normalize_grouping_mode(mode) when mode in ["vehicle", :vehicle], do: "vehicle"
  defp normalize_grouping_mode(mode) when mode in ["route", :route], do: "route"
  defp normalize_grouping_mode(_), do: "vehicle"

  defp clamp(value, min_value, max_value) do
    value
    |> max(min_value)
    |> min(max_value)
  end
end
