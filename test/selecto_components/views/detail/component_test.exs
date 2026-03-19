defmodule SelectoComponents.Views.Detail.ComponentTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias SelectoComponents.Views.Detail.Component

  defp selecto do
    domain = %{
      name: "DetailComponentTest",
      source: %{
        source_table: "records",
        primary_key: :id,
        fields: [:id],
        redact_fields: [],
        columns: %{id: %{type: :integer}},
        associations: %{}
      },
      schemas: %{},
      joins: %{}
    }

    Selecto.configure(domain, nil)
  end

  defp base_assigns(overrides \\ %{}) do
    base = %{
      id: "detail-component-test",
      executed: true,
      execution_error: nil,
      selecto: %{
        selecto()
        | set: %{
            columns: [
              %{"field" => "id", "alias" => "id", "uuid" => "id-col"}
            ]
          }
      },
      query_results: {[[100], [101]], [:id], ["ID"]},
      view_meta: %{page: 2, per_page: 2, total_rows: 10, subselect_configs: []}
    }

    Map.merge(base, overrides)
  end

  test "renders current detail page rows and global row numbers" do
    html = render_component(Component, base_assigns())

    assert html =~ "5-6"
    assert html =~ "rows"

    assert html =~
             ~r/Page\s*<span class="font-semibold">3<\/span>\s*of\s*<span class="font-semibold">5<\/span>/

    assert html =~ ~r/>\s*5\s*</
    assert html =~ ~r/>\s*6\s*</
    assert html =~ "100"
    assert html =~ "101"
    assert html =~ "aria-label=\"First page\""
    assert html =~ "aria-label=\"Previous page\""
    assert html =~ "aria-label=\"Next page\""
    assert html =~ "aria-label=\"Last page\""
  end

  test "disables forward pagination buttons on the last page" do
    assigns =
      base_assigns(%{
        view_meta: %{page: 4, per_page: 2, total_rows: 10, subselect_configs: []}
      })

    html = render_component(Component, assigns)

    assert html =~ ~r/aria-label="Next page"[^>]*disabled/
    assert html =~ ~r/aria-label="Last page"[^>]*disabled/
    refute html =~ ~r/aria-label="First page"[^>]*disabled/
    refute html =~ ~r/aria-label="Previous page"[^>]*disabled/
  end

  test "disables backward pagination buttons on the first page" do
    assigns =
      base_assigns(%{
        view_meta: %{page: 0, per_page: 2, total_rows: 10, subselect_configs: []}
      })

    html = render_component(Component, assigns)

    assert html =~ ~r/aria-label="First page"[^>]*disabled/
    assert html =~ ~r/aria-label="Previous page"[^>]*disabled/
    refute html =~ ~r/aria-label="Next page"[^>]*disabled/
    refute html =~ ~r/aria-label="Last page"[^>]*disabled/
  end

  test "renders mapped row values when query columns are string keys" do
    assigns =
      base_assigns(%{
        query_results: {[%{id: 100}, %{id: 101}], ["id"], ["ID"]}
      })

    html = render_component(Component, assigns)

    assert html =~ "100"
    assert html =~ "101"
  end

  test "renders stage-aware execution errors" do
    assigns =
      base_assigns(%{
        execution_error: %{
          stage: :sql_compile,
          category: :query,
          code: :sql_compile_failed,
          summary: "Query error while generating SQL",
          user_message: "The current configuration could not be compiled into valid SQL.",
          suggestion: "Check calculated fields, grouping, filters, and ordering.",
          suggestions: ["Check calculated fields, grouping, filters, and ordering."],
          detail: "column foo does not exist",
          severity: :error,
          recoverable: true,
          retryable: false,
          source: :selecto,
          debug: %{sql: "select * from broken"},
          error: %{message: "broken"}
        }
      })

    html = render_component(Component, assigns)

    assert html =~ "Query error while generating SQL"
    assert html =~ "The current configuration could not be compiled into valid SQL."
    assert html =~ "Check calculated fields, grouping, filters, and ordering."
  end

  test "renders tuple values safely instead of crashing detail cells" do
    tuple_value = {{2026, 3, 17}, {8, 0, 0, 0}}

    assigns =
      base_assigns(%{
        query_results: {[[tuple_value]], ["placed_at"], ["placed_at"]},
        selecto: %{
          selecto()
          | domain: %{
              selecto().domain
              | source: %{
                  selecto().domain.source
                  | fields: [:id, :placed_at],
                    columns: %{id: %{type: :integer}, placed_at: %{type: :utc_datetime}}
                }
            },
            set: %{
              columns: [
                %{"field" => "placed_at", "alias" => "placed_at", "uuid" => "placed-at-col"}
              ]
            }
        }
      })

    html = render_component(Component, assigns)

    assert html =~ "{{2026, 3, 17}, {8, 0, 0, 0}}"
  end

  test "renders row values when column uuid does not match row-data uuid mapping" do
    assigns =
      base_assigns(%{
        selecto: %{
          selecto()
          | set: %{
              columns: [
                %{"field" => "id", "alias" => "id", "uuid" => "unknown-uuid"}
              ]
            }
        },
        query_results: {[%{"id" => 100}, %{"id" => 101}], ["id"], ["ID"]}
      })

    html = render_component(Component, assigns)

    assert html =~ "100"
    assert html =~ "101"
  end

  test "maps row values by alias when DB columns collide" do
    domain = %{
      name: "DetailAliasCollisionTest",
      source: %{
        source_table: "orders",
        primary_key: :id,
        fields: [:id],
        redact_fields: [],
        columns: %{id: %{type: :integer}},
        associations: %{}
      },
      schemas: %{},
      joins: %{}
    }

    collision_selecto =
      Selecto.configure(domain, nil)
      |> Map.put(:set, %{
        columns: [
          %{"field" => "supplier.co_name", "alias" => "supplier_name", "uuid" => "c1"},
          %{"field" => "customer.co_name", "alias" => "customer_name", "uuid" => "c2"}
        ]
      })

    assigns = %{
      id: "detail-component-alias-collision",
      executed: true,
      execution_error: nil,
      selecto: collision_selecto,
      query_results:
        {[["Supplier A", "Customer B"]], ["co_name", "co_name"],
         ["supplier_name", "customer_name"]},
      view_meta: %{page: 0, per_page: 10, total_rows: 1, subselect_configs: []}
    }

    html = render_component(Component, assigns)

    assert html =~ "Supplier A"
    assert html =~ "Customer B"
  end

  test "show_row_details dedupes duplicate modal keys" do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{
        selecto: %{
          selecto()
          | set: %{
              columns: [
                %{"field" => "supplier.co_name", "alias" => "supplier_name", "uuid" => "c1"},
                %{"field" => "customer.co_name", "alias" => "customer_name", "uuid" => "c2"}
              ]
            }
        },
        enable_modal_detail: true,
        view_meta: %{},
        processed_results: {[["Supplier A", "Customer B"]], ["co_name", "co_name"]},
        query_results:
          {[["Supplier A", "Customer B"]], ["co_name", "co_name"], ["co_name", "co_name"]}
      }
    }

    assert {:noreply, _socket} =
             Component.handle_event("show_row_details", %{"row-index" => "0"}, socket)

    assert_receive {:show_detail_modal, detail_data}
    assert detail_data.record["co_name"] == "Supplier A"
    assert detail_data.record["co_name_2"] == "Customer B"
  end

  test "show_row_details includes title template for configured modal actions" do
    domain = %{
      name: "DetailModalTitleTemplateTest",
      source: %{
        source_table: "workspaces",
        primary_key: :id,
        fields: [:id, :name],
        redact_fields: [],
        columns: %{id: %{type: :integer}, name: %{type: :string}},
        associations: %{}
      },
      schemas: %{},
      joins: %{},
      detail_actions: %{
        workspace_snapshot: %{
          name: "Workspace Snapshot",
          type: :modal,
          required_fields: [:id, :name],
          payload: %{title: ~S(Workspace #{{id}} - {{name}})}
        }
      }
    }

    socket = %Phoenix.LiveView.Socket{
      assigns: %{
        selecto:
          Selecto.configure(domain, nil)
          |> Map.put(:set, %{
            columns: [
              %{"field" => "id", "alias" => "id", "uuid" => "id-col"},
              %{"field" => "name", "alias" => "name", "uuid" => "name-col"}
            ]
          }),
        enable_modal_detail: false,
        view_meta: %{row_click_action: "workspace_snapshot"},
        processed_results: {[[117, "Austin Workspace 2-1"]], ["id", "name"]},
        query_results: {[[117, "Austin Workspace 2-1"]], ["id", "name"], ["id", "name"]}
      }
    }

    assert {:noreply, _socket} =
             Component.handle_event("show_row_details", %{"row-index" => "0"}, socket)

    assert_receive {:show_detail_modal, detail_data}
    assert detail_data.title == "Workspace #117 - Austin Workspace 2-1"
    assert detail_data.title_template == ~S(Workspace #{{id}} - {{name}})
  end

  test "show_row_details includes iframe modal payload" do
    domain = %{
      name: "DetailIframeActionTest",
      source: %{
        source_table: "workspaces",
        primary_key: :id,
        fields: [:id, :name],
        redact_fields: [],
        columns: %{id: %{type: :integer}, name: %{type: :string}},
        associations: %{}
      },
      schemas: %{},
      joins: %{},
      detail_actions: %{
        workspace_preview: %{
          name: "Workspace Preview",
          type: :iframe_modal,
          required_fields: [:id],
          payload: %{
            title: ~S(Preview #{{id}}),
            url_template: "/workspaces/{{id}}/preview",
            sandbox: "allow-scripts"
          }
        }
      }
    }

    socket = %Phoenix.LiveView.Socket{
      assigns: %{
        selecto:
          Selecto.configure(domain, nil)
          |> Map.put(:set, %{
            columns: [
              %{"field" => "id", "alias" => "id", "uuid" => "id-col"},
              %{"field" => "name", "alias" => "name", "uuid" => "name-col"}
            ]
          }),
        enable_modal_detail: false,
        view_meta: %{row_click_action: "workspace_preview"},
        processed_results: {[[117, "Austin Workspace 2-1"]], ["id", "name"]},
        query_results: {[[117, "Austin Workspace 2-1"]], ["id", "name"], ["id", "name"]}
      }
    }

    assert {:noreply, _socket} =
             Component.handle_event("show_row_details", %{"row-index" => "0"}, socket)

    assert_receive {:show_detail_modal, detail_data}
    assert detail_data.action_type == :iframe_modal
    assert detail_data.iframe_url == "/workspaces/117/preview"
    assert detail_data.url_template == "/workspaces/{{id}}/preview"
    assert detail_data.iframe_sandbox == "allow-scripts"
  end

  test "show_row_details includes live component payload" do
    domain = %{
      name: "DetailLiveComponentActionTest",
      source: %{
        source_table: "workspaces",
        primary_key: :id,
        fields: [:id, :name],
        redact_fields: [],
        columns: %{id: %{type: :integer}, name: %{type: :string}},
        associations: %{}
      },
      schemas: %{},
      joins: %{},
      detail_actions: %{
        workspace_component: %{
          name: "Workspace Component",
          type: :live_component,
          required_fields: [:id, :name],
          payload: %{
            title: ~S(Component #{{id}}),
            module: SelectoComponents.Modal.DetailModal,
            assigns: %{
              workspace_id: {:field, "id"},
              workspace_name: {:field, "name"}
            }
          }
        }
      }
    }

    socket = %Phoenix.LiveView.Socket{
      assigns: %{
        selecto:
          Selecto.configure(domain, nil)
          |> Map.put(:set, %{
            columns: [
              %{"field" => "id", "alias" => "id", "uuid" => "id-col"},
              %{"field" => "name", "alias" => "name", "uuid" => "name-col"}
            ]
          }),
        enable_modal_detail: false,
        view_meta: %{row_click_action: "workspace_component"},
        processed_results: {[[117, "Austin Workspace 2-1"]], ["id", "name"]},
        query_results: {[[117, "Austin Workspace 2-1"]], ["id", "name"], ["id", "name"]}
      }
    }

    assert {:noreply, _socket} =
             Component.handle_event("show_row_details", %{"row-index" => "0"}, socket)

    assert_receive {:show_detail_modal, detail_data}
    assert detail_data.action_type == :live_component
    assert detail_data.component_module == SelectoComponents.Modal.DetailModal
    assert detail_data.component_assigns.workspace_id == 117
    assert detail_data.component_assigns.workspace_name == "Austin Workspace 2-1"
  end

  test "renders external link row action data attributes" do
    domain = %{
      name: "DetailExternalLinkTest",
      source: %{
        source_table: "customers",
        primary_key: :id,
        fields: [:customer_id],
        redact_fields: [],
        columns: %{customer_id: %{type: :integer}},
        associations: %{}
      },
      schemas: %{},
      joins: %{},
      detail_actions: %{
        customer_profile: %{
          name: "Customer Profile",
          type: :external_link,
          required_fields: [:customer_id],
          payload: %{url_template: "https://example.test/customers/{{customer_id}}"}
        }
      }
    }

    external_link_selecto =
      Selecto.configure(domain, nil)
      |> Map.put(:set, %{
        columns: [
          %{"field" => "customer_id", "alias" => "customer_id", "uuid" => "customer-id-col"}
        ]
      })

    html =
      render_component(Component, %{
        id: "detail-component-external-link",
        executed: true,
        execution_error: nil,
        selecto: external_link_selecto,
        query_results: {[[100]], ["customer_id"], ["customer_id"]},
        view_meta: %{
          page: 0,
          per_page: 10,
          total_rows: 1,
          subselect_configs: [],
          row_click_action: "customer_profile"
        }
      })

    assert html =~ ~s(data-row-action-type="external_link")
    assert html =~ ~s(data-row-link="https://example.test/customers/100")
  end

  test "resolves external links with hidden row action fields" do
    domain = %{
      name: "DetailExternalLinkHiddenFieldTest",
      source: %{
        source_table: "workspaces",
        primary_key: :id,
        fields: [:id, :name, :purpose],
        redact_fields: [],
        columns: %{
          id: %{type: :integer},
          name: %{type: :string},
          purpose: %{type: :string}
        },
        associations: %{}
      },
      schemas: %{},
      joins: %{},
      detail_actions: %{
        workspace_link: %{
          name: "Workspace Link",
          type: :external_link,
          required_fields: [:id, :purpose],
          payload: %{url_template: "https://example.test/workspaces/{{id}}?purpose={{purpose}}"}
        }
      }
    }

    selecto_with_hidden_field =
      Selecto.configure(domain, nil)
      |> Map.put(:set, %{
        columns: [
          %{"field" => "id", "alias" => "id", "uuid" => "id-col"},
          %{"field" => "name", "alias" => "name", "uuid" => "name-col"}
        ],
        row_action_query_columns: [
          %{"field" => "id", "alias" => "id", "uuid" => "id-col"},
          %{"field" => "name", "alias" => "name", "uuid" => "name-col"},
          %{"field" => "purpose", "alias" => "purpose", "uuid" => "purpose-col", "hidden" => true}
        ]
      })

    html =
      render_component(Component, %{
        id: "detail-component-external-link-hidden-field",
        executed: true,
        execution_error: nil,
        selecto: selecto_with_hidden_field,
        query_results:
          {[[100, "HQ", "planning"]], ["id", "name", "purpose"], ["id", "name", "purpose"]},
        view_meta: %{
          page: 0,
          per_page: 10,
          total_rows: 1,
          subselect_configs: [],
          row_click_action: "workspace_link"
        }
      })

    assert html =~ ~s(data-row-action-type="external_link")
    assert html =~ ~s(data-row-link="https://example.test/workspaces/100?purpose=planning")
  end
end
