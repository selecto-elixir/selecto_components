defmodule SelectoComponents.Form.ListOperationsTest do
  use ExUnit.Case, async: true

  defmodule TestLive do
    use Phoenix.LiveView
    use SelectoComponents.Form.EventHandlers.ListOperations
  end

  defp base_socket do
    %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        columns: [],
        selecto: %{domain: %{}},
        views: [
          {:detail, SelectoComponents.Views.Detail, "Detail", []},
          {:aggregate, SelectoComponents.Views.Aggregate, "Aggregate", []},
          {:graph, SelectoComponents.Views.Graph, "Graph", []}
        ],
        view_config: %{
          view_mode: "aggregate",
          filters: [],
          views: %{
            detail: %{
              selected: [],
              order_by: [],
              per_page: "30",
              max_rows: "1000",
              count_mode: "bounded",
              row_click_action: "",
              prevent_denormalization: true
            },
            aggregate: %{
              group_by: [],
              aggregate: [],
              per_page: "100",
              grid: false,
              grid_colorize: false,
              grid_color_scale: "linear"
            },
            graph: %{
              x_axis: [],
              y_axis: [],
              series: [],
              chart_type: "bar",
              options: %{}
            }
          }
        }
      }
    }
  end

  defp form_state_query do
    Plug.Conn.Query.encode(%{
      "view_mode" => "aggregate",
      "selected" => %{
        "k0" => %{
          "field" => "id",
          "index" => "0",
          "uuid" => "detail-col-1",
          "alias" => "ID"
        }
      },
      "order_by" => %{
        "k0" => %{
          "field" => "id",
          "index" => "0",
          "uuid" => "detail-order-1",
          "dir" => "desc"
        }
      },
      "per_page" => "60",
      "max_rows" => "10000",
      "count_mode" => "exact",
      "row_click_action" => "work_item_api_preview",
      "prevent_denormalization" => "false",
      "group_by" => %{
        "k0" => %{
          "field" => "status",
          "index" => "0",
          "uuid" => "agg-group-1",
          "format" => "default"
        }
      },
      "aggregate" => %{
        "k0" => %{
          "field" => "id",
          "index" => "0",
          "uuid" => "agg-metric-1",
          "format" => "count"
        },
        "k1" => %{
          "field" => "amount",
          "index" => "1",
          "uuid" => "agg-metric-2",
          "format" => "sum"
        }
      },
      "aggregate_per_page" => "300",
      "aggregate_grid" => "true",
      "aggregate_grid_colorize" => "true",
      "aggregate_grid_color_scale" => "log"
    })
  end

  defp assert_preserved_cross_tab_state(updated) do
    assert updated.assigns.view_config.views.detail.per_page == "60"
    assert updated.assigns.view_config.views.detail.max_rows == "10000"
    assert updated.assigns.view_config.views.detail.row_click_action == "work_item_api_preview"
    assert updated.assigns.view_config.views.detail.prevent_denormalization == false

    assert updated.assigns.view_config.views.aggregate.per_page == "300"
    assert updated.assigns.view_config.views.aggregate.grid == true
    assert updated.assigns.view_config.views.aggregate.grid_colorize == true
    assert updated.assigns.view_config.views.aggregate.grid_color_scale == "log"
  end

  defp detail_form_state_query do
    Plug.Conn.Query.encode(%{
      "view_mode" => "detail",
      "selected" => %{
        "k0" => %{
          "field" => "id",
          "index" => "0",
          "uuid" => "detail-col-1",
          "alias" => "ID"
        },
        "k1" => %{
          "field" => "status",
          "index" => "1",
          "uuid" => "detail-col-2",
          "alias" => "Status"
        }
      },
      "order_by" => %{
        "k0" => %{
          "field" => "id",
          "index" => "0",
          "uuid" => "detail-order-1",
          "dir" => "desc"
        }
      },
      "per_page" => "60",
      "max_rows" => "10000",
      "count_mode" => "exact",
      "row_click_action" => "work_item_api_preview",
      "prevent_denormalization" => "false",
      "group_by" => %{
        "k0" => %{
          "field" => "status",
          "index" => "0",
          "uuid" => "agg-group-1",
          "format" => "default"
        }
      },
      "aggregate" => %{
        "k0" => %{
          "field" => "id",
          "index" => "0",
          "uuid" => "agg-metric-1",
          "format" => "count"
        }
      },
      "aggregate_per_page" => "300",
      "aggregate_grid" => "true",
      "aggregate_grid_colorize" => "true",
      "aggregate_grid_color_scale" => "log"
    })
  end

  test "list picker add hydrates current form state before mutating aggregate config" do
    {:noreply, updated} =
      TestLive.handle_info(
        {:list_picker_add, form_state_query(), "aggregate", "aggregate", "priority"},
        base_socket()
      )

    assert_preserved_cross_tab_state(updated)

    assert [
             {"agg-metric-1", "id", _existing_cfg},
             {"agg-metric-2", "amount", _amount_cfg},
             {new_uuid, "priority", %{}}
           ] =
             updated.assigns.view_config.views.aggregate.aggregate

    assert is_binary(new_uuid)
    assert new_uuid != ""
  end

  test "list picker remove hydrates current form state before mutating aggregate config" do
    {:noreply, updated} =
      TestLive.handle_info(
        {:list_picker_remove, form_state_query(), "aggregate", "aggregate", "agg-metric-1"},
        base_socket()
      )

    assert_preserved_cross_tab_state(updated)

    assert [
             {"agg-metric-2", "amount",
              %{"field" => "amount", "format" => "sum", "index" => "1", "uuid" => "agg-metric-2"}}
           ] =
             updated.assigns.view_config.views.aggregate.aggregate
  end

  test "list picker reorder hydrates current form state before mutating aggregate config" do
    {:noreply, updated} =
      TestLive.handle_info(
        {:list_picker_reorder, form_state_query(), "aggregate", "aggregate", "agg-metric-2",
         "agg-metric-1"},
        base_socket()
      )

    assert_preserved_cross_tab_state(updated)

    assert [
             {"agg-metric-2", "amount",
              %{"field" => "amount", "format" => "sum", "index" => "1", "uuid" => "agg-metric-2"}},
             {"agg-metric-1", "id",
              %{"field" => "id", "format" => "count", "index" => "0", "uuid" => "agg-metric-1"}}
           ] = updated.assigns.view_config.views.aggregate.aggregate
  end

  test "detail list picker add preserves aggregate state" do
    {:noreply, updated} =
      TestLive.handle_info(
        {:list_picker_add, detail_form_state_query(), "detail", "selected", "priority"},
        base_socket()
      )

    assert_preserved_cross_tab_state(updated)
    assert updated.assigns.view_config.view_mode == "detail"

    assert [
             {"detail-col-1", "id", _id_cfg},
             {"detail-col-2", "status", _status_cfg},
             {new_uuid, "priority", %{}}
           ] = updated.assigns.view_config.views.detail.selected

    assert is_binary(new_uuid)
    assert new_uuid != ""
  end

  test "detail list picker remove preserves aggregate state" do
    {:noreply, updated} =
      TestLive.handle_info(
        {:list_picker_remove, detail_form_state_query(), "detail", "selected", "detail-col-1"},
        base_socket()
      )

    assert_preserved_cross_tab_state(updated)
    assert updated.assigns.view_config.view_mode == "detail"

    assert [
             {"detail-col-2", "status",
              %{
                "alias" => "Status",
                "field" => "status",
                "index" => "1",
                "uuid" => "detail-col-2"
              }}
           ] =
             updated.assigns.view_config.views.detail.selected
  end

  test "detail list picker reorder preserves aggregate state" do
    {:noreply, updated} =
      TestLive.handle_info(
        {:list_picker_reorder, detail_form_state_query(), "detail", "selected", "detail-col-2",
         "detail-col-1"},
        base_socket()
      )

    assert_preserved_cross_tab_state(updated)
    assert updated.assigns.view_config.view_mode == "detail"

    assert [
             {"detail-col-2", "status",
              %{
                "alias" => "Status",
                "field" => "status",
                "index" => "1",
                "uuid" => "detail-col-2"
              }},
             {"detail-col-1", "id",
              %{"alias" => "ID", "field" => "id", "index" => "0", "uuid" => "detail-col-1"}}
           ] = updated.assigns.view_config.views.detail.selected
  end
end
