defmodule SelectoComponents.Components.ListPickerTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias SelectoComponents.Components.ListPicker

  defp base_assigns(overrides \\ %{}) do
    base = %{
      id: "test-list-picker",
      view: {"detail", nil, nil, nil},
      fieldname: "selected",
      available: [
        {"alpha", "Alpha Item", :string},
        {"beta", "Beta Item", :string}
      ],
      selected_items: [
        {"selected-1", "Chosen Item", %{}}
      ],
      item_form: [],
      item_summary: []
    }

    Map.merge(base, overrides)
  end

  test "renders a two-pane layout where available yields space first" do
    html = render_component(ListPicker, base_assigns())

    assert html =~ "grid-cols-[minmax(0,1fr)_minmax(12rem,40%)]"
    refute html =~ "data-selected-tray-toggle"
    refute html =~ "data-selected-tray-backdrop"
    refute html =~ "data-selected-tray"
    assert html =~ ">Selected<"
  end

  test "renders empty selected state in the always-visible selected pane" do
    html = render_component(ListPicker, base_assigns(%{selected_items: []}))

    assert html =~ "Pick items from the available list to add them here."
  end
end
