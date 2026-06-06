defmodule SelectoComponents.Views.Detail.FormTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias SelectoComponents.Theme
  alias SelectoComponents.Views.Detail.ColumnConfig
  alias SelectoComponents.Views.Detail.Form

  test "renders row click action select with current action selected" do
    domain = %{
      name: "DetailFormTest",
      source: %{
        source_table: "work_items",
        primary_key: :id,
        fields: [:id, :title],
        redact_fields: [],
        columns: %{
          id: %{type: :integer, name: "ID", colid: :id},
          title: %{type: :string, name: "Title", colid: :title}
        },
        associations: %{}
      },
      schemas: %{},
      joins: %{},
      detail_actions: %{
        work_item_api_json: %{
          name: "Open Work Item API JSON",
          type: :external_link,
          required_fields: [:id],
          payload: %{url_template: "/api/v1/updato/work-items/{{id}}"}
        }
      }
    }

    html =
      render_component(Form, %{
        id: "detail-form-test",
        columns: [{:id, "ID", :integer}, {:title, "Title", :string}],
        view: {:detail, SelectoComponents.Views.Detail, "Detail", %{}},
        selecto: Selecto.configure(domain, nil),
        view_config: %{
          views: %{
            detail: %{
              selected: [],
              order_by: [],
              per_page: "30",
              max_rows: "1000",
              count_mode: "bounded",
              row_click_action: "work_item_api_json",
              prevent_denormalization: true
            }
          }
        }
      })

    assert html =~ ~s(id="detail-row-click-action-work_item_api_json")
    assert html =~ ~s(name="row_click_action")
    assert html =~ ~s(phx-change="set_row_click_action")
    assert html =~ ~s(<option value="work_item_api_json" selected>)
  end

  test "renders generated row action form choices from domain actions" do
    domain = %{
      name: "DetailFormGeneratedActionsTest",
      source: %{
        source_table: "work_items",
        primary_key: :id,
        fields: [:id, :title],
        redact_fields: [],
        columns: %{
          id: %{type: :integer, name: "ID", colid: :id},
          title: %{type: :string, name: "Title", colid: :title}
        },
        associations: %{}
      },
      schemas: %{},
      joins: %{},
      detail_actions: %{},
      actions: %{
        archive: %{
          id: :archive,
          label: "Archive",
          scope: :row,
          capability: "work_items.archive",
          execution: %{operation: :update},
          links: %{
            preview: "/work-items/actions/archive/preview",
            apply: "/work-items/actions/archive/apply"
          }
        }
      }
    }

    html =
      render_component(Form, %{
        id: "detail-form-generated-actions-test",
        columns: [{:id, "ID", :integer}, {:title, "Title", :string}],
        view: {:detail, SelectoComponents.Views.Detail, "Detail", %{}},
        selecto: Selecto.configure(domain, nil),
        view_config: %{
          views: %{
            detail: %{
              selected: [],
              order_by: [],
              row_click_action: "domain_action_form_archive"
            }
          }
        }
      })

    assert html =~ ~s(id="detail-row-click-action-domain_action_form_archive")
    assert html =~ ~s(<option value="domain_action_form_archive" selected>)
    assert html =~ "Archive"
    assert html =~ "Generated from domain action"
    assert html =~ "work_items.archive"
    assert html =~ "preview: /work-items/actions/archive/preview"
    assert html =~ "apply: /work-items/actions/archive/apply"
  end

  test "filters generated row action form choices through capability resolver" do
    domain = %{
      name: "DetailFormPolicyActionsTest",
      source: %{
        source_table: "work_items",
        primary_key: :id,
        fields: [:id, :title],
        redact_fields: [],
        columns: %{
          id: %{type: :integer, name: "ID", colid: :id},
          title: %{type: :string, name: "Title", colid: :title}
        },
        associations: %{}
      },
      schemas: %{},
      joins: %{},
      detail_actions: %{},
      actions: %{
        archive: %{
          id: :archive,
          label: "Archive",
          scope: :row,
          capability: "work_items.archive",
          execution: %{operation: :update}
        },
        set_estimate: %{
          id: :set_estimate,
          label: "Set estimate",
          scope: :row,
          capability: "work_items.estimation",
          execution: %{operation: :update}
        }
      }
    }

    html =
      render_component(Form, %{
        id: "detail-form-policy-actions-test",
        columns: [{:id, "ID", :integer}, {:title, "Title", :string}],
        view: {:detail, SelectoComponents.Views.Detail, "Detail", %{}},
        selecto: Selecto.configure(domain, nil),
        row_action_availability_opts: [
          capability_resolver: fn
            %{capability: "work_items.archive"} ->
              Selecto.Capabilities.hidden(:not_visible)

            _request ->
              Selecto.Capabilities.allow(:allowed)
          end
        ],
        view_config: %{
          views: %{
            detail: %{
              selected: [],
              order_by: [],
              row_click_action: ""
            }
          }
        }
      })

    refute html =~ ~s(value="domain_action_form_archive")
    assert html =~ ~s(value="domain_action_form_set_estimate")
    assert html =~ "Set estimate"
  end

  test "uses detail config as the only row click action source while editing" do
    domain = %{
      name: "DetailFormParamsTest",
      source: %{
        source_table: "work_items",
        primary_key: :id,
        fields: [:id, :title],
        redact_fields: [],
        columns: %{
          id: %{type: :integer, name: "ID", colid: :id},
          title: %{type: :string, name: "Title", colid: :title}
        },
        associations: %{}
      },
      schemas: %{},
      joins: %{},
      detail_actions: %{
        work_item_quick_view: %{name: "Quick", type: :modal, payload: %{}},
        work_item_api_preview: %{
          name: "Preview",
          type: :iframe_modal,
          payload: %{url_template: "/x"}
        }
      }
    }

    html =
      render_component(Form, %{
        id: "detail-form-params-test",
        columns: [{:id, "ID", :integer}, {:title, "Title", :string}],
        view: {:detail, SelectoComponents.Views.Detail, "Detail", %{}},
        selecto: Selecto.configure(domain, nil),
        view_config: %{
          views: %{
            detail: %{
              selected: [],
              order_by: []
            }
          }
        }
      })

    assert html =~ ~s(id="detail-row-click-action-none")
    refute html =~ ~s(<option value="work_item_api_preview" selected>)
  end

  test "renders prevent_denormalization unchecked when restored as string false" do
    domain = %{
      name: "DetailFormCheckboxTest",
      source: %{
        source_table: "work_items",
        primary_key: :id,
        fields: [:id, :title],
        redact_fields: [],
        columns: %{
          id: %{type: :integer, name: "ID", colid: :id},
          title: %{type: :string, name: "Title", colid: :title}
        },
        associations: %{}
      },
      schemas: %{},
      joins: %{},
      detail_actions: %{}
    }

    html =
      render_component(Form, %{
        id: "detail-form-checkbox-test",
        columns: [{:id, "ID", :integer}, {:title, "Title", :string}],
        view: {:detail, SelectoComponents.Views.Detail, "Detail", %{}},
        selecto: Selecto.configure(domain, nil),
        view_config: %{
          views: %{
            detail: %{
              selected: [],
              order_by: [],
              prevent_denormalization: "false"
            }
          }
        }
      })

    refute html =~ ~s(name="prevent_denormalization" value="true" checked)
  end

  test "set_row_click_action updates detail view config" do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        view_config: %{
          views: %{
            detail: %{
              row_click_action: "work_item_quick_view"
            }
          }
        }
      }
    }

    assert {:noreply, updated_socket} =
             Form.handle_event(
               "set_row_click_action",
               %{"row_click_action" => "work_item_api_json"},
               socket
             )

    assert updated_socket.assigns.view_config.views.detail.row_click_action ==
             "work_item_api_json"

    assert_receive {:update_view_config, updated_config}
    assert updated_config.views.detail.row_click_action == "work_item_api_json"
  end

  test "set_row_click_action accepts the direct select value payload" do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        view_config: %{
          views: %{
            detail: %{
              row_click_action: "work_item_quick_view"
            }
          }
        }
      }
    }

    assert {:noreply, updated_socket} =
             Form.handle_event(
               "set_row_click_action",
               %{"value" => "work_item_api_json"},
               socket
             )

    assert updated_socket.assigns.view_config.views.detail.row_click_action ==
             "work_item_api_json"
  end

  test "detail column config uses themed labels and controls" do
    html =
      render_component(ColumnConfig, %{
        id: "detail-column-config",
        theme: Theme.default_theme(:light),
        item: "created_at",
        col: %{type: :utc_datetime, name: "Created At", colid: :created_at},
        columns: [{:created_at, "Created At", :utc_datetime}],
        prefix: "selected[c0]",
        config: %{"format" => "year_buckets"}
      })

    assert html =~ "Name:"
    assert html =~ "Alias:"
    assert html =~ "Options:"
    assert html =~ "Bucket Ranges"
    assert html =~ "sc-input"
    assert html =~ "sc-select"
  end

  test "detail column config supports postgres datetime atom formatting" do
    html =
      render_component(ColumnConfig, %{
        id: "detail-column-config-datetime-atom",
        theme: Theme.default_theme(:light),
        item: "atnd_created",
        col: %{type: :datetime, name: "Attendance Created", colid: :atnd_created},
        columns: [{:atnd_created, "Attendance Created", :datetime}],
        prefix: "selected[c0]",
        config: %{"format" => "year_buckets"}
      })

    assert html =~ "Options:"
    assert html =~ "Year Buckets"
    assert html =~ "Bucket Ranges"
  end

  test "detail column config keeps temporal format on default when none is configured" do
    html =
      render_component(ColumnConfig, %{
        id: "detail-column-config-default-format",
        theme: Theme.default_theme(:light),
        item: "published_at_usec",
        col: %{type: :utc_datetime, name: "Published At", colid: :published_at_usec},
        columns: [{:published_at_usec, "Published At", :utc_datetime}],
        prefix: "selected[c0]",
        config: %{}
      })

    assert html =~ ~s(name="selected[c0][format]")
    assert html =~ ~s(<option value="">Default</option>)
    refute html =~ ~s(<option value="YYYY-MM-DD" selected>)
  end
end
