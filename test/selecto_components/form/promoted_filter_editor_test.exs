defmodule SelectoComponents.Form.PromotedFilterEditorTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias SelectoComponents.Form.PromotedFilterEditor
  alias SelectoComponents.Theme

  test "renders a standard between editor" do
    html =
      render_component(&PromotedFilterEditor.editor/1, %{
        theme: Theme.default_theme(:light),
        filter: %{
          uuid: "f1",
          comp: "BETWEEN",
          render_kind: :standard,
          value_start: "3",
          value_end: "8"
        }
      })

    assert html =~ "Between"
    assert html =~ ~s(name="promoted_filters[f1][value_start]")
    assert html =~ ~s(name="promoted_filters[f1][value_end]")
  end

  test "renders a text search editor with mode options" do
    html =
      render_component(&PromotedFilterEditor.editor/1, %{
        theme: Theme.default_theme(:light),
        filter: %{
          uuid: "f2",
          comp: "TEXT_SEARCH",
          render_kind: :text_search,
          value: "launch pad",
          mode: "phrase",
          text_search_mode_options: [{"plain", "Plain"}, {"phrase", "Phrase"}]
        }
      })

    assert html =~ "Text Search"
    assert html =~ ~s(name="promoted_filters[f2][value]")
    assert html =~ ~s(name="promoted_filters[f2][mode]")
    assert html =~ ~s(<option value="phrase" selected>)
  end

  test "renders date shortcut preview for datetime shortcut filters" do
    html =
      render_component(&PromotedFilterEditor.editor/1, %{
        theme: Theme.default_theme(:light),
        filter: %{
          uuid: "f3",
          comp: "SHORTCUT",
          render_kind: :datetime,
          field_type: :date,
          field_conf: %{type: :date},
          value: "this_month"
        }
      })

    assert html =~ "Quick Select"
    assert html =~ ~s(name="promoted_filters[f3][value]")
    assert html =~ "Preview:"
  end
end
