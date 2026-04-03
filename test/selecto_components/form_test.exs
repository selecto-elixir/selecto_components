defmodule SelectoComponents.FormTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias SelectoComponents.Form

  test "renders an always-visible controller summary when collapsed" do
    html = render_component(Form, base_assigns(%{show_view_configurator: false}))

    assert html =~ ~s(data-selecto-controller-summary)
    assert html =~ ~s(data-selecto-controller-body)
    assert html =~ "View Controller"
    assert html =~ "Detail View"
    assert html =~ "Toggle View Controller"
    assert html =~ "1 applied filter"
    assert html =~ "Status = open"
    assert html =~ ~s(aria-hidden="true")
  end

  test "compacts multi-value filter summaries in the controller header" do
    html =
      render_component(
        Form,
        base_assigns(%{
          show_view_configurator: false,
          view_config: %{
            view_mode: "detail",
            filters: [
              {"f1", "filters",
               %{"filter" => "status", "comp" => "IN", "value" => "open,closed,paused"}}
            ],
            views: %{
              detail: %{selected: [], order_by: [], per_page: "30", max_rows: "1000"},
              aggregate: %{group_by: [], aggregate: [], per_page: "30"}
            }
          }
        })
      )

    assert html =~ "Status in open, closed, ..."
  end

  test "renders controller body when expanded" do
    html = render_component(Form, base_assigns(%{show_view_configurator: true}))

    assert html =~ ~s(data-selecto-controller-body)
    assert html =~ "Submit"
    assert html =~ "View"
    assert html =~ "Filters"
  end

  test "pending IN textarea text does not change remount ids while typing" do
    html_with_partial =
      render_component(
        Form,
        base_assigns(%{
          show_view_configurator: true,
          active_tab: "filter",
          view_config: %{
            view_mode: "detail",
            filters: [
              {"f1", "filters",
               %{
                 "filter" => "title",
                 "comp" => "IN",
                 "value" => "",
                 "pending_values" => "a"
               }}
            ],
            views: %{
              detail: %{selected: [], order_by: [], per_page: "30", max_rows: "1000"},
              aggregate: %{group_by: [], aggregate: [], per_page: "30"}
            }
          }
        })
      )

    html_with_full =
      render_component(
        Form,
        base_assigns(%{
          show_view_configurator: true,
          active_tab: "filter",
          view_config: %{
            view_mode: "detail",
            filters: [
              {"f1", "filters",
               %{
                 "filter" => "title",
                 "comp" => "IN",
                 "value" => "",
                 "pending_values" => "alpha"
               }}
            ],
            views: %{
              detail: %{selected: [], order_by: [], per_page: "30", max_rows: "1000"},
              aggregate: %{group_by: [], aggregate: [], per_page: "30"}
            }
          }
        })
      )

    [partial_filter_form_id] =
      Regex.run(~r/id="(filter-form-f1-\d+)"/, html_with_partial, capture: :all_but_first)

    [full_filter_form_id] =
      Regex.run(~r/id="(filter-form-f1-\d+)"/, html_with_full, capture: :all_but_first)

    [partial_in_values_id] =
      Regex.run(~r/id="(filter-in-values-f1-\d+)"/, html_with_partial, capture: :all_but_first)

    [full_in_values_id] =
      Regex.run(~r/id="(filter-in-values-f1-\d+)"/, html_with_full, capture: :all_but_first)

    assert partial_filter_form_id == full_filter_form_id
    assert partial_in_values_id == full_in_values_id
  end

  defp base_assigns(overrides) do
    domain = %{
      name: "FormSummaryTest",
      source: %{
        source_table: "work_items",
        primary_key: :id,
        fields: [:id, :status, :title],
        redact_fields: [],
        columns: %{
          id: %{type: :integer, name: "ID", colid: :id},
          status: %{type: :string, name: "Status", colid: :status},
          title: %{type: :string, name: "Title", colid: :title}
        },
        associations: %{}
      },
      schemas: %{},
      joins: %{}
    }

    Map.merge(
      %{
        id: "form-summary-test",
        selecto: Selecto.configure(domain, nil),
        active_tab: "view",
        views: [
          {:detail, SelectoComponents.Views.Detail, "Detail View", %{}},
          {:aggregate, SelectoComponents.Views.Aggregate, "Aggregate View", %{}}
        ],
        view_config: %{
          view_mode: "detail",
          filters: [
            {"f1", "filters", %{"filter" => "status", "comp" => "=", "value" => "open"}}
          ],
          views: %{
            detail: %{selected: [], order_by: [], per_page: "30", max_rows: "1000"},
            aggregate: %{group_by: [], aggregate: [], per_page: "30"}
          }
        },
        executed: false,
        applied_view: nil
      },
      overrides
    )
  end
end
