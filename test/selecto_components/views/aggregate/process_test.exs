defmodule SelectoComponents.Views.Aggregate.ProcessTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.Views.Aggregate.Process

  test "param_to_state reads aggregate grid toggle" do
    state = Process.param_to_state(%{"aggregate_grid" => "true"}, %{})
    assert state.grid == true

    state = Process.param_to_state(%{"aggregate_grid" => "false"}, %{})
    assert state.grid == false
  end

  test "param_to_state reads aggregate grid color settings" do
    state =
      Process.param_to_state(
        %{
          "aggregate_grid_colorize" => "true",
          "aggregate_grid_color_scale" => "log"
        },
        %{}
      )

    assert state.grid_colorize == true
    assert state.grid_color_scale == "log"
  end

  test "aggregates honors count distinct from format" do
    assert Process.aggregates(%{"a1" => %{"field" => "id", "format" => "count_distinct"}}, []) ==
             [{:field, {:count_distinct, "id"}, "id"}]
  end
end
