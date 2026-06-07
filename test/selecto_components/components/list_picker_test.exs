defmodule SelectoComponents.Components.ListPickerTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias SelectoComponents.Components.ListPicker

  defp base_assigns(overrides) do
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

  test "renders a two-pane layout where available stays narrow and selected expands" do
    html =
      render_component(
        ListPicker,
        base_assigns(%{
          available: [
            {"alpha", "Alpha Item", :string},
            {"beta", "Beta Item", :utc_datetime}
          ],
          selected_items: [
            {"selected-1", "alpha", %{}}
          ]
        })
      )

    assert html =~ "grid-template-columns: minmax(12rem, 16rem) minmax(0, 1fr);"
    assert html =~ "items-stretch"
    assert html =~ "flex-1 space-y-2 overflow-y-auto"
    refute html =~ "data-selected-tray-toggle"
    refute html =~ "data-selected-tray-backdrop"
    refute html =~ "data-selected-tray"
    refute html =~ "data-available-group"
    assert html =~ ~s(data-list-picker-fieldname="selected")
    assert html =~ "Selected"
    assert html =~ "text-[0.68rem] font-semibold uppercase"
    assert html =~ ~s(data-type-icon="Text")
    assert html =~ ~s(data-type-icon="Date")
  end

  test "renders empty selected state in the always-visible selected pane" do
    html = render_component(ListPicker, base_assigns(%{selected_items: []}))

    assert html =~ "Pick items from the available list to add them here."
  end

  test "uses the full selected item as the draggable element" do
    html = render_component(ListPicker, base_assigns(%{}))

    assert html =~ ~s(data-picker-item-id="selected-1")
    assert html =~ ~s(draggable="true")
    assert html =~ ~s(title="Drag to reorder")
  end

  test "renders selected items as keyboard-focusable controls" do
    html = render_component(ListPicker, base_assigns(%{}))

    assert html =~ ~s(data-selected-item)
    assert html =~ ~s(tabindex="0")
    assert html =~ ~s(aria-label="Selected item Chosen Item")
  end

  test "renders available items as keyboard-focusable add actions" do
    html = render_component(ListPicker, base_assigns(%{}))

    assert html =~ ~s(data-filter-input)
    assert html =~ ~s(type="button" data-picker-action="add")
    assert html =~ ~s(data-available-item)
    assert html =~ ~s(data-item-id="alpha")
  end

  test "groups prefixed available items and strips repeated prefixes from item labels" do
    html =
      render_component(
        ListPicker,
        base_assigns(%{
          available: [
            {"film.title", "Film: Title", :string},
            {"film.rating", "Film: Rating", :string},
            {"actor.first_name", "Actor: First name", :string},
            {"full_name", "Full Name", :string}
          ],
          selected_items: []
        })
      )

    assert html =~ ~s(data-available-group)
    assert html =~ ~s(data-available-group-key="actor")
    assert html =~ ~s(data-available-group-key="film")
    assert html =~ ~s(data-available-group-key="other")
    assert html =~ ~s(data-search-text="Film: Title")
    assert html =~ ">Title</span>"
    assert html =~ ">Rating</span>"
    assert html =~ ">First name</span>"
    assert html =~ ">Full Name</span>"
    refute html =~ ">Film: Title</span>"
  end

  test "renders a dedicated badge for cte-backed columns" do
    html =
      render_component(
        ListPicker,
        base_assigns(%{
          available: [
            {"active_delivery_projects.priority", "Active Project Priority",
             %{type: :integer, icon: :cte, icon_family: :cte}}
          ]
        })
      )

    assert html =~ ~s(data-type-icon="CTE")
  end

  test "renders choice source indicators for choice-backed available and selected fields" do
    html =
      render_component(
        ListPicker,
        base_assigns(%{
          available: [
            {"customer_id", "Customer",
             %{
               type: :integer,
               choice_source: "customer_choices",
               choice_source_metadata: %{"id" => "customer_choices"}
             }}
          ],
          selected_items: [
            {"selected-1", "customer_id", %{}}
          ]
        })
      )

    assert html =~ ~s(data-type-key="number")
    assert html =~ ~s(data-choice-source-indicator)
    assert html =~ ~s(data-choice-source-id="customer_choices")
    assert html =~ ~s(aria-label="Choice source customer_choices")
    assert length(Regex.scan(~r/data-choice-source-indicator/, html)) == 2
  end

  test "renders selected items with tuple field identifiers" do
    html =
      render_component(
        ListPicker,
        base_assigns(%{
          available: [
            {"created_at", "Created At", :utc_datetime}
          ],
          selected_items: [
            {"selected-1", {:to_char, {"created_at", "YYYY-MM"}}, %{}}
          ],
          item_summary: []
        })
      )

    assert html =~ ~s|aria-label="Selected item to_char(created_at, YYYY-MM)"|
    assert html =~ ~s(data-type-icon="Date")
  end
end
