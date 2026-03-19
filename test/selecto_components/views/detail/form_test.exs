defmodule SelectoComponents.Views.Detail.FormTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

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
end
