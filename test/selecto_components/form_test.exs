defmodule SelectoComponents.FormTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias SelectoComponents.Form
  alias SelectoComponents.Form.FilterRendering

  test "renders an always-visible controller summary when collapsed" do
    html = render_component(Form, base_assigns(%{show_view_configurator: false}))

    assert html =~ ~s(data-selecto-controller-summary)
    assert html =~ ~s(data-selecto-controller-body)
    assert html =~ "View Controller"
    assert html =~ "Detail View"
    assert html =~ "Expand View Controller"
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

  test "renders default keyboard shortcut wiring" do
    html = render_component(Form, base_assigns(%{show_view_configurator: true}))

    assert html =~ ~s(data-selecto-shortcuts-enabled="true")
    assert html =~ ~s(data-selecto-shortcuts-show-hints="true")
    assert html =~ ~s(data-selecto-active-view="detail")
    assert html =~ ~s(data-selecto-available-views="detail,aggregate")
    assert html =~ "Keyboard Shortcuts"
    assert html =~ "Switch to Detail view"
    assert html =~ "Cmd/Ctrl + Enter"
    assert html =~ "Focus filters"
    assert html =~ "Next configuration tab"
    assert html =~ "Download XLSX"
  end

  test "allows host apps to disable keyboard shortcuts" do
    html =
      render_component(
        Form,
        base_assigns(%{show_view_configurator: true, keyboard_shortcuts: false})
      )

    assert html =~ ~s(data-selecto-shortcuts-enabled="false")
    refute html =~ "Keyboard Shortcuts"
  end

  test "renders the submit button in its dirty state when the view config has pending edits" do
    html =
      render_component(
        Form,
        base_assigns(%{
          show_view_configurator: true,
          form_state_revision: 6,
          applied_form_state_revision: 4,
          view_config_dirty?: true
        })
      )

    assert html =~ ~s(id="selecto-view-form-form-summary-test")
    assert html =~ ~s(data-selecto-submit-button="true")
    assert html =~ ~s(data-dirty="true")
    assert html =~ "Unsaved"
  end

  test "renders promoted equals filters as controller inputs while leaving other filters summarized" do
    html =
      render_component(
        Form,
        base_assigns(%{
          show_view_configurator: false,
          view_config: %{
            view_mode: "detail",
            filters: [
              {"f1", "filters",
               %{"filter" => "status", "comp" => "=", "value" => "open", "promote" => "true"}},
              {"f2", "filters", %{"filter" => "title", "comp" => "=", "value" => "launch"}}
            ],
            views: %{
              detail: %{selected: [], order_by: [], per_page: "30", max_rows: "1000"},
              aggregate: %{group_by: [], aggregate: [], per_page: "30"}
            }
          }
        })
      )

    assert html =~ ~s(name="promoted_filters[f1][value]")
    assert html =~ ~s(value="open")
    assert html =~ "Equals"
    assert html =~ "FormSummaryTest: Status"
    assert html =~ "Title = launch"
  end

  test "renders promoted non-equals filters with operator-specific controller editors" do
    html =
      render_component(
        Form,
        base_assigns(%{
          show_view_configurator: false,
          view_config: %{
            view_mode: "detail",
            filters: [
              {"f1", "filters",
               %{
                 "filter" => "estimate",
                 "comp" => "BETWEEN",
                 "value_start" => "3",
                 "value_end" => "8",
                 "promote" => "true"
               }},
              {"f2", "filters",
               %{
                 "filter" => "status",
                 "comp" => "IN",
                 "value" => "open,closed",
                 "promote" => "true"
               }},
              {"f3", "filters",
               %{
                 "filter" => "search",
                 "comp" => "TEXT_SEARCH",
                 "value" => "launch pad",
                 "mode" => "phrase",
                 "promote" => "true"
               }},
              {"f4", "filters",
               %{
                 "filter" => "due_on",
                 "comp" => "SHORTCUT",
                 "value" => "this_month",
                 "promote" => "true"
               }}
            ],
            views: %{
              detail: %{selected: [], order_by: [], per_page: "30", max_rows: "1000"},
              aggregate: %{group_by: [], aggregate: [], per_page: "30"}
            }
          }
        })
      )

    assert html =~ ~s(name="promoted_filters[f1][value_start]")
    assert html =~ ~s(name="promoted_filters[f1][value_end]")
    assert html =~ "Between"
    assert html =~ ~s(name="promoted_filters[f2][value]")
    assert html =~ "open\nclosed"
    assert html =~ "Is One Of"
    assert html =~ ~s(name="promoted_filters[f3][value]")
    assert html =~ ~s(name="promoted_filters[f3][mode]")
    assert html =~ "Text Search"
    assert html =~ ~s(name="promoted_filters[f4][value]")
    assert html =~ ~s(<optgroup label="Days">)
    assert html =~ ~s(<option value="this_month" selected>)
    assert html =~ "Preview:"
    assert html =~ FilterRendering.date_shortcut_preview("this_month")
    refute html =~ ~s(type="text" name="promoted_filters[f4][value]")
  end

  test "renders promoted numeric filters using display-local values when present" do
    html =
      render_component(
        Form,
        base_assigns(%{
          show_view_configurator: false,
          presentation_context: %{locale: "de-DE"},
          view_config: %{
            view_mode: "detail",
            filters: [
              {"f1", "filters",
               %{
                 "filter" => "estimate",
                 "comp" => ">=",
                 "value" => "145.5",
                 "display_value" => "145,5",
                 "promote" => "true"
               }},
              {"f2", "filters",
               %{
                 "filter" => "estimate",
                 "comp" => "BETWEEN",
                 "value_start" => "1234.5",
                 "value_end" => "2345.5",
                 "display_value_start" => "1.234,5",
                 "display_value_end" => "2.345,5",
                 "promote" => "true"
               }}
            ],
            views: %{
              detail: %{selected: [], order_by: [], per_page: "30", max_rows: "1000"},
              aggregate: %{group_by: [], aggregate: [], per_page: "30"}
            }
          }
        })
      )

    assert html =~ ~s(name="promoted_filters[f1][value]")
    assert html =~ ~s(value="145,5")
    assert html =~ ~s(name="promoted_filters[f2][value_start]")
    assert html =~ ~s(value="1.234,5")
    assert html =~ ~s(name="promoted_filters[f2][value_end]")
    assert html =~ ~s(value="2.345,5")
  end

  test "renders promoted locale-aware IN filters as newline-delimited display values" do
    html =
      render_component(
        Form,
        base_assigns(%{
          show_view_configurator: false,
          presentation_context: %{locale: "de-DE"},
          view_config: %{
            view_mode: "detail",
            filters: [
              {"f1", "filters",
               %{
                 "filter" => "amount",
                 "comp" => "IN",
                 "value" => "145.5,146.5",
                 "display_value" => "145,5\n146,5",
                 "promote" => "true"
               }}
            ],
            views: %{
              detail: %{selected: [], order_by: [], per_page: "30", max_rows: "1000"},
              aggregate: %{group_by: [], aggregate: [], per_page: "30"}
            }
          }
        })
      )

    assert html =~ ~s(name="promoted_filters[f1][value]")
    assert html =~ "145,5\n146,5"
    assert html =~ ~s(placeholder="Enter one value per line")
    refute html =~ "Enter one value per line or use commas"
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

  test "string IS NULL filters keep the standard operator list instead of switching to datetime controls" do
    html =
      render_component(
        Form,
        base_assigns(%{
          show_view_configurator: true,
          active_tab: "filter",
          view_config: %{
            view_mode: "detail",
            filters: [
              {"f1", "filters", %{"filter" => "status", "comp" => "IS NULL"}}
            ],
            views: %{
              detail: %{selected: [], order_by: [], per_page: "30", max_rows: "1000"},
              aggregate: %{group_by: [], aggregate: [], per_page: "30"}
            }
          }
        })
      )

    assert html =~ "Equals"
    assert html =~ "Is One Of"
    assert html =~ "Is Empty"
    refute html =~ "Date Equals"
    refute html =~ "Quick Select"
  end

  defp base_assigns(overrides) do
    domain = %{
      name: "FormSummaryTest",
      source: %{
        source_table: "work_items",
        primary_key: :id,
        fields: [:id, :status, :title, :estimate, :amount, :due_on, :search],
        redact_fields: [],
        columns: %{
          id: %{type: :integer, name: "ID", colid: :id},
          status: %{type: :string, name: "Status", colid: :status},
          title: %{type: :string, name: "Title", colid: :title},
          estimate: %{type: :integer, name: "Estimate", colid: :estimate},
          amount: %{type: :decimal, name: "Amount", colid: :amount},
          due_on: %{type: :date, name: "Due On", colid: :due_on},
          search: %{type: :tsvector, name: "Search", colid: :search}
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
