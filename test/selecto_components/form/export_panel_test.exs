defmodule SelectoComponents.Form.ExportPanelTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias SelectoComponents.Form.ExportPanel
  alias SelectoComponents.Theme

  test "renders email export controls when delivery is enabled" do
    html = render_component(&ExportPanel.panel/1, base_assigns(%{use_export_delivery: true}))

    assert html =~ "Download CSV"
    assert html =~ "Send Current Results by Email"
    assert html =~ ~s(data-export-email-button="true")
    assert html =~ ~s(id="export-email-recipients-export-panel-test")
  end

  test "renders host integration hint when delivery is disabled" do
    html = render_component(&ExportPanel.panel/1, base_assigns(%{use_export_delivery: false}))

    assert html =~ "Assign `export_delivery_module` in the host LiveView"
    refute html =~ "Send Current Results by Email"
  end

  defp base_assigns(overrides) do
    Map.merge(
      %{
        theme: Theme.default_theme(:light),
        id: "export-panel-test",
        use_export_delivery: false,
        use_scheduled_exports: false,
        use_exported_views: false,
        scheduled_export_module: nil,
        scheduled_export_context: nil,
        exported_view_module: nil,
        exported_view_context: nil,
        exported_view_endpoint: nil,
        exported_view_base_url: nil,
        current_user_id: 123,
        selecto: %{},
        views: [],
        view_config: %{view_mode: "detail", filters: [], views: %{}},
        path: "/reports/work-items",
        tenant_context: nil
      },
      overrides
    )
  end
end
