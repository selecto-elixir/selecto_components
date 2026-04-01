defmodule SelectoComponents.Views.Aggregate.FormTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias SelectoComponents.Views.Aggregate.Form
  alias SelectoComponents.Views.Aggregate.GroupByConfig

  test "shows the implied aggregate format in the selected item summary" do
    domain = %{
      name: "AggregateFormTest",
      source: %{
        source_table: "items",
        primary_key: :id,
        fields: [:id],
        redact_fields: [],
        columns: %{
          id: %{type: :integer, name: "ID", colid: :id}
        },
        associations: %{}
      },
      schemas: %{},
      joins: %{}
    }

    html =
      render_component(Form, %{
        id: "aggregate-form-test",
        columns: [{:id, "ID", :integer}],
        view: {:aggregate, SelectoComponents.Views.Aggregate, "Aggregate", %{}},
        selecto: Selecto.configure(domain, nil),
        view_config: %{
          views: %{
            aggregate: %{
              group_by: [],
              aggregate: [{"agg-1", "id", %{}}],
              per_page: "30"
            }
          }
        }
      })

    assert html =~ "Count"
    refute html =~ ~s(text-base-content/60">Default</span>)
  end

  test "shows count distinct in aggregate summaries" do
    domain = %{
      name: "AggregateFormTest",
      source: %{
        source_table: "items",
        primary_key: :id,
        fields: [:id],
        redact_fields: [],
        columns: %{
          id: %{type: :integer, name: "ID", colid: :id}
        },
        associations: %{}
      },
      schemas: %{},
      joins: %{}
    }

    html =
      render_component(Form, %{
        id: "aggregate-form-distinct-test",
        columns: [{:id, "ID", :integer}],
        view: {:aggregate, SelectoComponents.Views.Aggregate, "Aggregate", %{}},
        selecto: Selecto.configure(domain, nil),
        view_config: %{
          views: %{
            aggregate: %{
              group_by: [],
              aggregate: [{"agg-1", "id", %{"format" => "count_distinct"}}],
              per_page: "30"
            }
          }
        }
      })

    assert html =~ "Count Distinct"
  end

  test "shows count distinct as an aggregate option label" do
    domain = %{
      name: "AggregateFormTest",
      source: %{
        source_table: "items",
        primary_key: :id,
        fields: [:id],
        redact_fields: [],
        columns: %{
          id: %{type: :integer, name: "ID", colid: :id}
        },
        associations: %{}
      },
      schemas: %{},
      joins: %{}
    }

    html =
      render_component(Form, %{
        id: "aggregate-form-option-test",
        columns: [{:id, "ID", :integer}],
        view: {:aggregate, SelectoComponents.Views.Aggregate, "Aggregate", %{}},
        selecto: Selecto.configure(domain, nil),
        view_config: %{
          views: %{
            aggregate: %{
              group_by: [],
              aggregate: [{"agg-1", "id", %{}}],
              per_page: "30"
            }
          }
        }
      })

    assert html =~ "Count Distinct"
  end

  test "omits default group by format from the selected item summary" do
    domain = %{
      name: "AggregateFormTest",
      source: %{
        source_table: "items",
        primary_key: :id,
        fields: [:status],
        redact_fields: [],
        columns: %{
          status: %{type: :string, name: "Status", colid: :status}
        },
        associations: %{}
      },
      schemas: %{},
      joins: %{}
    }

    html =
      render_component(Form, %{
        id: "aggregate-form-group-default-test",
        columns: [{:status, "Status", :string}],
        view: {:aggregate, SelectoComponents.Views.Aggregate, "Aggregate", %{}},
        selecto: Selecto.configure(domain, nil),
        view_config: %{
          views: %{
            aggregate: %{
              group_by: [{"group-1", "status", %{"format" => "default"}}],
              aggregate: [],
              per_page: "30"
            }
          }
        }
      })

    refute html =~ ~s(text-base-content/60">Default</span>)
    refute html =~ ~s(text-base-content/60">default</span>)
  end

  test "datetime group by config shows year bucket options without aggregate-only formats" do
    html =
      render_component(GroupByConfig, %{
        id: "group-by-datetime-options",
        col: %{type: :utc_datetime, name: "Created At", colid: :created_at},
        uuid: "group-by-datetime-options",
        item: "created_at",
        columns: [{:created_at, "Created At", :utc_datetime}],
        fieldname: "group_by",
        prefix: "group_by[g0]",
        config: %{"format" => "year_buckets"}
      })

    assert html =~ "Year Buckets"
    assert html =~ "Bucket Ranges"
    assert html =~ "*/5 or 2020-2024"
    refute html =~ "True Count"
    refute html =~ "False Count"
    refute html =~ "Count Distinct"
  end
end
