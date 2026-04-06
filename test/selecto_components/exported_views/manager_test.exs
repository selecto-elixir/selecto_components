defmodule SelectoComponents.ExportedViews.ManagerTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias SelectoComponents.ExportedViews.Manager
  alias SelectoComponents.Theme

  test "renders themed exported view form controls" do
    html =
      render_component(Manager, %{
        id: "exported-views-manager",
        theme: Theme.default_theme(:light),
        exported_view_context: nil,
        exported_view_endpoint: nil,
        exported_view_base_url: nil,
        current_user_id: 42,
        selecto: %{},
        views: [],
        view_config: %{view_mode: "detail", filters: [], views: %{}},
        path: "/orders",
        tenant_context: nil
      })

    assert html =~ "Exported Views"
    assert html =~ "Create Exported View"
    assert html =~ "No exported views yet."
    assert html =~ "sc-panel"
    assert html =~ "sc-input"
    assert html =~ "sc-btn sc-btn-primary"
  end
end
