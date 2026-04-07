defmodule SelectoComponents.ThemeTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias SelectoComponents.Components.Common
  alias SelectoComponents.Theme
  alias SelectoComponents.Theme.ThemeSpec

  defmodule Resolver do
    @behaviour SelectoComponents.Theme.Resolver

    @impl true
    def resolve_theme(_context) do
      %ThemeSpec{
        id: "tenant-ocean",
        mode: :dark,
        tokens: %{
          surface_bg: "#0b1220",
          surface_border: "#1d4ed8",
          text_primary: "#e2e8f0",
          accent: "#14b8a6",
          accent_hover: "#0f766e",
          accent_soft: "rgba(20, 184, 166, 0.14)",
          accent_contrast: "#04111d"
        },
        slots: %{}
      }
    end
  end

  test "resolves default and custom themes" do
    default = Theme.resolve_theme(%{})
    assert default.id == "light"
    assert default.tokens.surface_bg
    assert Theme.slot(default, :panel) == "sc-panel"

    themed = Theme.resolve_theme(%{theme_resolver: Resolver, tenant_context: %{tenant_id: 7}})
    assert themed.id == "tenant-ocean"
    assert themed.tokens.accent == "#14b8a6"
    assert Theme.style_attr(themed) =~ "--sc-accent: #14b8a6"
  end

  test "shared controls emit semantic theme classes" do
    button_html =
      render_component(&Common.sc_button/1, %{
        inner_block: [%{inner_block: fn _, _ -> "Save" end}]
      })

    input_html = render_component(&Common.sc_input/1, %{name: "title"})

    select_html =
      render_component(&Common.sc_select/1, %{
        name: "status",
        options: [{"open", "Open"}],
        value: "open"
      })

    assert button_html =~ "sc-btn sc-btn-secondary"
    assert input_html =~ "sc-input"
    assert select_html =~ "sc-select"
  end

  test "shared controls honor runtime slot overrides when a theme is passed" do
    theme = %ThemeSpec{
      id: "custom-slots",
      mode: :light,
      tokens: %{},
      slots: %{
        button_primary: "tenant-btn-primary",
        button_secondary: "tenant-btn-secondary",
        input: "tenant-input",
        select: "tenant-select",
        button_danger: "tenant-danger"
      }
    }

    button_html =
      render_component(&Common.sc_button/1, %{
        theme: theme,
        variant: :primary,
        inner_block: [%{inner_block: fn _, _ -> "Save" end}]
      })

    input_html = render_component(&Common.sc_input/1, %{theme: theme, name: "title"})

    select_html =
      render_component(&Common.sc_select/1, %{
        theme: theme,
        name: "status",
        options: [{"open", "Open"}],
        value: "open"
      })

    danger_html = render_component(&Common.sc_x_button/1, %{theme: theme})

    assert button_html =~ "tenant-btn-primary"
    assert input_html =~ "tenant-input"
    assert select_html =~ "tenant-select"
    assert danger_html =~ "tenant-danger"
  end

  test "resolved theme exposes scoped css vars and semantic slots for form roots" do
    theme = Theme.resolve_theme(%{theme_resolver: Resolver, tenant_context: %{tenant_id: 7}})

    assert theme.id == "tenant-ocean"
    assert Theme.style_attr(theme) =~ "--sc-surface-bg: #0b1220"
    assert Theme.style_attr(theme) =~ "--sc-accent: #14b8a6"
    assert Theme.slot(theme, :root) == "sc-theme-root"
    assert Theme.slot(theme, :panel) == "sc-panel"
    assert Theme.slot(theme, :tab_active) == "sc-tab sc-tab-active"
  end
end
