defmodule SelectoComponents.Form.SavePanelTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias SelectoComponents.Form.SavePanel
  alias SelectoComponents.Theme

  test "renders the save view form controls" do
    html = render_component(&SavePanel.panel/1, %{theme: Theme.default_theme(:light)})

    assert html =~ "Save your current view configuration for later use."
    assert html =~ ~s(for="save_as")
    assert html =~ ~s(name="save_as")
    assert html =~ "Enter view name..."
  end
end
