defmodule SelectoComponents.ResultsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias SelectoComponents.Results

  test "renders stage-aware execution error banner" do
    html =
      render_component(Results, %{
        id: "results-test",
        views: [],
        applied_view: nil,
        executed: false,
        execution_error: %{
          stage: :configuration,
          category: :configuration,
          code: :invalid_view_config,
          summary: "Configuration error while preparing the view",
          user_message: "The current view configuration is not valid.",
          suggestion: "Review the current view configuration and try again.",
          suggestions: ["Review the current view configuration and try again."],
          detail: "Aggregate grid requires exactly 2 group-by fields and 1 aggregate metric.",
          severity: :warning,
          recoverable: true,
          retryable: false,
          source: :selecto,
          debug: %{view_mode: "aggregate"},
          error: %{message: "invalid config"}
        },
        component_errors: []
      })

    assert html =~ "Configuration error while preparing the view"
    assert html =~ "The current view configuration is not valid."
    assert html =~ "Aggregate grid requires exactly 2 group-by fields and 1 aggregate metric."
    assert html =~ "Review the current view configuration and try again."
  end
end
