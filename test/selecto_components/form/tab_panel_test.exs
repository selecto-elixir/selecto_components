defmodule SelectoComponents.Form.TabPanelTest do
  use ExUnit.Case, async: true

  import Phoenix.Component, only: [sigil_H: 2]
  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias SelectoComponents.Form.TabPanel
  alias SelectoComponents.Theme

  test "renders the active panel with title and content" do
    html =
      render_component(
        fn assigns ->
          ~H"""
          <TabPanel.panel active_tab="export" tab="export" theme={@theme} title="Export Options">
            <span data-panel-content="true">content</span>
          </TabPanel.panel>
          """
        end,
        %{theme: Theme.default_theme(:light)}
      )

    assert html =~ ~s(id="main-tabpanel-export")
    assert html =~ "Export Options"
    assert html =~ ~s(data-panel-content="true")
    assert html =~ ~s(sc-panel p-3)
  end

  test "renders inactive panels as hidden" do
    html =
      render_component(
        fn assigns ->
          ~H"""
          <TabPanel.panel active_tab="view" tab="export" theme={@theme} title="Export Options">
            content
          </TabPanel.panel>
          """
        end,
        %{theme: Theme.default_theme(:light)}
      )

    assert html =~ ~s(id="main-tabpanel-export")
    assert html =~ ~s(class="hidden")
  end
end
