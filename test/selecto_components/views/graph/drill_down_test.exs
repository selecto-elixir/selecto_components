defmodule SelectoComponents.Views.Graph.DrillDownTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.Views.Graph.DrillDown

  test "returns user-friendly error for invalid array chart labels" do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        view_config: %{
          view_mode: "graph",
          views: %{graph: %{x_axis: [{"x1", "tags", %{}}]}},
          filters: []
        },
        selecto: %{set: %{}},
        columns: [{"tags", "Tags", {:array, :string}}],
        views: [{:graph, nil, "Graph", %{drill_down: :detail}}],
        used_params: %{}
      }
    }

    assert {:error, message} = DrillDown.apply(socket, %{"label" => nil})
    assert message =~ "Could not drill down"
  end

  test "uses current timeseries x-axis config for drilldown filters" do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        view_config: %{
          view_mode: "timeseries",
          views: %{timeseries: %{x_axis: [{"x1", "recorded_at", %{}}]}},
          filters: []
        },
        selecto: %{set: %{}},
        columns: [{"recorded_at", "Recorded At", :utc_datetime}],
        views: [{:timeseries, nil, "Time Series", %{drill_down: :detail}}],
        used_params: %{}
      }
    }

    assert {:ok, updated_socket, _view_params} =
             DrillDown.apply(socket, %{"label" => "2026-03-04"})

    {_id, _section, filter_map} = List.last(updated_socket.assigns.view_config.filters)
    assert filter_map["filter"] == "recorded_at"
  end
end
