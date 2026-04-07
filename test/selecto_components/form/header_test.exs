defmodule SelectoComponents.Form.HeaderTest do
  use ExUnit.Case, async: true

  import Phoenix.Component, only: [sigil_H: 2]
  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias SelectoComponents.Form.Header
  alias SelectoComponents.Theme

  test "renders the collapsed controller summary" do
    html = render_component(&Header.summary/1, base_assigns(%{show_view_configurator: false}))

    assert html =~ ~s(data-selecto-controller-summary)
    assert html =~ "View Controller"
    assert html =~ "Detail View"
    assert html =~ "Expand View Controller"
    assert html =~ "1 applied filter"
    assert html =~ "Status = open"
  end

  test "renders compact summary overflow text" do
    html =
      render_component(
        &Header.summary/1,
        base_assigns(%{
          applied_filters: [1, 2, 3, 4, 5],
          summary_filters: ["A", "B", "C", "D", "E"]
        })
      )

    assert html =~ "A"
    assert html =~ "D"
    assert html =~ "+1 more"
  end

  test "renders promoted filter content through the slot" do
    html =
      render_component(
        fn assigns ->
          ~H"""
          <Header.summary
            id={@id}
            theme={@theme}
            controller_title={@controller_title}
            current_view_label={@current_view_label}
            applied_filters={@applied_filters}
            promoted_filters={@promoted_filters}
            summary_filters={@summary_filters}
            show_view_configurator={@show_view_configurator}
          >
            <:promoted_filter :let={filter}>
              <span data-promoted-filter={filter.uuid}>{filter.label}</span>
            </:promoted_filter>
          </Header.summary>
          """
        end,
        base_assigns(%{
          promoted_filters: [%{uuid: "f1", label: "Status", editable: true}],
          summary_filters: []
        })
      )

    assert html =~ ~s(data-promoted-filter="f1")
    assert html =~ "Status"
  end

  defp base_assigns(overrides) do
    Map.merge(
      %{
        id: "header-test",
        theme: Theme.default_theme(:light),
        controller_title: "View Controller",
        current_view_label: "Detail View",
        applied_filters: ["status"],
        promoted_filters: [],
        summary_filters: ["Status = open"],
        show_view_configurator: true
      },
      overrides
    )
  end
end
