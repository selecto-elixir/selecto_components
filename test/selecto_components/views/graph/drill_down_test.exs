defmodule SelectoComponents.Views.Graph.DrillDownTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.Views.Graph.DrillDown

  test "returns user-friendly error for invalid array chart labels" do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{
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
end
