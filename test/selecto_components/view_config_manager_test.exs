defmodule SelectoComponents.ViewConfigManagerTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias SelectoComponents.Theme
  alias SelectoComponents.ViewConfigManager

  test "renders themed load and save controls" do
    html =
      render_component(ViewConfigManager, %{
        id: "view-config-manager",
        theme: Theme.default_theme(:light),
        view_config: %{view_mode: "detail", views: %{}},
        saved_view_context: nil,
        current_user_id: 42,
        parent_id: %Phoenix.LiveComponent.CID{cid: 1}
      })

    assert html =~ "Load View"
    assert html =~ "Save View"
    assert html =~ "sc-panel"
    assert html =~ "sc-btn sc-btn-secondary"
    assert html =~ "sc-btn sc-btn-primary"
  end
end
