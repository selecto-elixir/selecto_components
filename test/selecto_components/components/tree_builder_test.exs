defmodule SelectoComponents.Components.TreeBuilderTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias SelectoComponents.Components.TreeBuilder

  defp base_assigns(overrides \\ %{}) do
    base = %{
      id: "test-tree-builder",
      available: [
        {"title", "Title", :string},
        {"state", "State", :string}
      ],
      filters: [],
      filter_form: [%{inner_block: fn _, _ -> "" end}]
    }

    Map.merge(base, overrides)
  end

  test "renders a narrow available column and taller build area" do
    html = render_component(TreeBuilder, base_assigns())

    assert html =~ "sm:grid-cols-[minmax(10rem,13rem)_minmax(0,1fr)]"
    assert html =~ "md:grid-cols-[minmax(11rem,14rem)_minmax(0,1fr)]"
    assert html =~ "h-96"
    assert html =~ "xl:h-[32rem]"
    assert html =~ "rounded-lg border px-3 py-2 text-sm"
  end

  test "binds direct double click events for available items and logical groups" do
    html = render_component(TreeBuilder, base_assigns())

    assert html =~ ~s(phx-dblclick="treedrop")
    assert html =~ ~s(data-filter-picker-input)
    assert html =~ ~s(role="option")
    assert html =~ ~s(tabindex="-1")
    assert html =~ ~s(phx-value-element="__AND__")
    assert html =~ ~s(phx-value-element="__OR__")
    assert html =~ ~s(phx-value-element="title")
    assert html =~ ~s(phx-value-element="state")
  end

  test "renders applied filters as keyboard-focusable rows" do
    html =
      render_component(
        TreeBuilder,
        base_assigns(%{
          filters: [
            {"filter-1", "filters", %{"filter" => "title", "comp" => "=", "value" => "abc"}}
          ]
        })
      )

    assert html =~ ~s(data-filter-row)
    assert html =~ ~s(data-filter-row-uuid="filter-1")
    assert html =~ ~s(data-filter-row-kind="filter")
    assert html =~ ~s(data-filter-row-field="title")
    assert html =~ ~s(tabindex="0")
    assert html =~ ~s(aria-label="Filter Title")
    assert html =~ ~s(data-filter-row-remove)
  end
end
