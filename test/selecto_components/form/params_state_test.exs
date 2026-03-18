defmodule SelectoComponents.Form.ParamsStateTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.Form.ParamsState

  test "view_config_to_params includes detail max_rows and per_page" do
    view_config = %{
      view_mode: "detail",
      filters: [],
      views: %{
        detail: %{
          selected: [],
          order_by: [],
          per_page: "60",
          max_rows: "10000",
          row_click_action: "customer_profile",
          prevent_denormalization: true
        }
      }
    }

    params = ParamsState.view_config_to_params(view_config)

    assert params["view_mode"] == "detail"
    assert params["per_page"] == "60"
    assert params["max_rows"] == "10000"
    assert params["row_click_action"] == "customer_profile"
    assert params["prevent_denormalization"] == "true"
  end

  test "view_config_to_params includes aggregate per-page config" do
    view_config = %{
      view_mode: "aggregate",
      filters: [],
      views: %{
        aggregate: %{
          group_by: [],
          aggregate: [],
          per_page: "300"
        }
      }
    }

    params = ParamsState.view_config_to_params(view_config)

    assert params["view_mode"] == "aggregate"
    assert params["aggregate_per_page"] == "300"
    refute Map.has_key?(params, "max_rows")
  end

  test "view_config_to_params uses compact keys for view lists while preserving uuid" do
    view_config = %{
      view_mode: "aggregate",
      filters: [],
      views: %{
        aggregate: %{
          group_by: [
            {"12b1e264-6359-4f7d-881a-f3c659fd8606", "shipper.co_name",
             %{"alias" => "", "format" => "default"}}
          ],
          aggregate: [
            {"51a3f4f6-fcce-4530-8b24-d7927bd120d6", "id", %{"alias" => "", "format" => "count"}}
          ],
          per_page: "100"
        }
      }
    }

    params = ParamsState.view_config_to_params(view_config)

    assert Map.has_key?(params["group_by"], "k0")
    assert params["group_by"]["k0"]["uuid"] == "12b1e264-6359-4f7d-881a-f3c659fd8606"
    assert params["group_by"]["k0"]["field"] == "shipper.co_name"

    assert Map.has_key?(params["aggregate"], "k0")
    assert params["aggregate"]["k0"]["uuid"] == "51a3f4f6-fcce-4530-8b24-d7927bd120d6"
  end

  test "view_config_to_params includes aggregate grid toggle" do
    view_config = %{
      view_mode: "aggregate",
      filters: [],
      views: %{
        aggregate: %{
          group_by: [],
          aggregate: [],
          per_page: "100",
          grid: true
        }
      }
    }

    params = ParamsState.view_config_to_params(view_config)

    assert params["view_mode"] == "aggregate"
    assert params["aggregate_grid"] == "true"
  end

  test "view_config_to_params includes aggregate grid color settings" do
    view_config = %{
      view_mode: "aggregate",
      filters: [],
      views: %{
        aggregate: %{
          group_by: [],
          aggregate: [],
          per_page: "100",
          grid: true,
          grid_colorize: true,
          grid_color_scale: "log"
        }
      }
    }

    params = ParamsState.view_config_to_params(view_config)

    assert params["aggregate_grid"] == "true"
    assert params["aggregate_grid_colorize"] == "true"
    assert params["aggregate_grid_color_scale"] == "log"
  end

  test "view_config_to_params includes non-active view state for URL round-trips" do
    view_config = %{
      view_mode: "aggregate",
      filters: [],
      views: %{
        detail: %{
          selected: [{"d1", "id", %{"alias" => "ID"}}],
          order_by: [{"o1", "id", %{"dir" => "desc"}}],
          per_page: "60",
          max_rows: "1000",
          count_mode: "bounded",
          row_click_action: "work_item_quick_view",
          prevent_denormalization: true
        },
        aggregate: %{
          group_by: [{"g1", "status", %{"format" => "default"}}],
          aggregate: [{"a1", "id", %{"format" => "count"}}],
          per_page: "300",
          grid: true,
          grid_colorize: true,
          grid_color_scale: "log"
        }
      }
    }

    params = ParamsState.view_config_to_params(view_config)

    assert params["view_mode"] == "aggregate"
    assert params["selected"]["k0"]["field"] == "id"
    assert params["order_by"]["k0"]["field"] == "id"
    assert params["per_page"] == "60"
    assert params["row_click_action"] == "work_item_quick_view"
    assert params["group_by"]["k0"]["field"] == "status"
    assert params["aggregate"]["k0"]["field"] == "id"
    assert params["aggregate_per_page"] == "300"
  end

  test "convert_saved_config_to_full_params restores aggregate grid color settings" do
    saved = %{
      "aggregate" => %{
        "group_by" => [],
        "aggregate" => [],
        "per_page" => "100",
        "grid" => true,
        "grid_colorize" => true,
        "grid_color_scale" => "log"
      }
    }

    params = ParamsState.convert_saved_config_to_full_params(saved, "aggregate")

    assert params["view_mode"] == "aggregate"
    assert params["aggregate_grid"] == "true"
    assert params["aggregate_grid_colorize"] == "true"
    assert params["aggregate_grid_color_scale"] == "log"
  end

  test "params_to_state normalizes shortcut filters after comparator change" do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        views: [
          {:detail, SelectoComponents.Views.Detail, "Detail", []},
          {:aggregate, SelectoComponents.Views.Aggregate, "Aggregate", []},
          {:graph, SelectoComponents.Views.Graph, "Graph", []}
        ],
        view_config: %{view_mode: "detail", filters: [], views: %{}}
      }
    }

    params = %{
      "view_mode" => "detail",
      "filters" => %{
        "f1" => %{
          "filter" => "created_at",
          "comp" => "SHORTCUT",
          "value" => "3",
          "index" => "0",
          "section" => "filters",
          "uuid" => "f1"
        }
      }
    }

    updated = ParamsState.params_to_state(params, socket)
    [{"f1", "filters", filter}] = updated.assigns.view_config.filters

    assert filter["comp"] == "SHORTCUT"
    assert filter["value"] == "today"
  end

  test "params_to_state preserves valid shortcut filter values" do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        views: [
          {:detail, SelectoComponents.Views.Detail, "Detail", []},
          {:aggregate, SelectoComponents.Views.Aggregate, "Aggregate", []},
          {:graph, SelectoComponents.Views.Graph, "Graph", []}
        ],
        view_config: %{view_mode: "detail", filters: [], views: %{}}
      }
    }

    params = %{
      "view_mode" => "detail",
      "filters" => %{
        "f1" => %{
          "filter" => "created_at",
          "comp" => "SHORTCUT",
          "value" => "last_week",
          "index" => "0",
          "section" => "filters",
          "uuid" => "f1"
        }
      }
    }

    updated = ParamsState.params_to_state(params, socket)
    [{"f1", "filters", filter}] = updated.assigns.view_config.filters

    assert filter["value"] == "last_week"
  end

  test "params_to_state preserves detail row click action when params omit it" do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        views: [
          {:detail, SelectoComponents.Views.Detail, "Detail", []},
          {:aggregate, SelectoComponents.Views.Aggregate, "Aggregate", []},
          {:graph, SelectoComponents.Views.Graph, "Graph", []}
        ],
        view_config: %{
          view_mode: "detail",
          filters: [],
          views: %{
            detail: %{
              selected: [],
              order_by: [],
              per_page: "30",
              max_rows: "1000",
              count_mode: "bounded",
              row_click_action: "workspace_spotlight",
              prevent_denormalization: true
            }
          }
        }
      }
    }

    params = %{
      "view_mode" => "detail",
      "selected" => %{},
      "order_by" => %{},
      "per_page" => "30",
      "max_rows" => "1000",
      "count_mode" => "bounded",
      "prevent_denormalization" => "true"
    }

    updated = ParamsState.params_to_state(params, socket)

    assert updated.assigns.view_config.views.detail.row_click_action == "workspace_spotlight"
  end

  test "params_to_state prefers row_click_action_ui over stale hidden value" do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        views: [
          {:detail, SelectoComponents.Views.Detail, "Detail", []},
          {:aggregate, SelectoComponents.Views.Aggregate, "Aggregate", []},
          {:graph, SelectoComponents.Views.Graph, "Graph", []}
        ],
        view_config: %{view_mode: "detail", filters: [], views: %{}}
      }
    }

    params = %{
      "view_mode" => "detail",
      "row_click_action" => "work_item_api_json",
      "row_click_action_ui" => "work_item_api_preview",
      "selected" => %{},
      "order_by" => %{},
      "per_page" => "30",
      "max_rows" => "1000",
      "count_mode" => "bounded",
      "prevent_denormalization" => "true"
    }

    updated = ParamsState.params_to_state(params, socket)

    assert updated.assigns.view_config.views.detail.row_click_action == "work_item_api_preview"
  end

  test "params_to_state preserves non-selected aggregate and graph configs during detail updates" do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        selecto: %{domain: %{}},
        views: [
          {:detail, SelectoComponents.Views.Detail, "Detail", []},
          {:aggregate, SelectoComponents.Views.Aggregate, "Aggregate", []},
          {:graph, SelectoComponents.Views.Graph, "Graph", []}
        ],
        view_config: %{
          view_mode: "detail",
          filters: [],
          views: %{
            detail: %{
              selected: [],
              order_by: [],
              per_page: "30",
              max_rows: "1000",
              count_mode: "bounded",
              row_click_action: "workspace_spotlight",
              prevent_denormalization: true
            },
            aggregate: %{
              group_by: [{"g1", "category", %{}}],
              aggregate: [{"a1", "amount", %{"format" => "sum"}}],
              per_page: "300",
              grid: true,
              grid_colorize: true,
              grid_color_scale: "log"
            },
            graph: %{
              x_axis: [{"x1", "category", %{}}],
              y_axis: [{"y1", "amount", %{"function" => "sum"}}],
              series: [{"s1", "region", %{}}],
              chart_type: "line",
              options: %{"title" => "Revenue"}
            }
          }
        }
      }
    }

    params = %{
      "view_mode" => "detail",
      "selected" => %{},
      "order_by" => %{},
      "per_page" => "60",
      "max_rows" => "1000",
      "count_mode" => "bounded",
      "prevent_denormalization" => "true"
    }

    updated = ParamsState.params_to_state(params, socket)

    assert updated.assigns.view_config.views.detail.per_page == "60"

    assert updated.assigns.view_config.views.aggregate ==
             socket.assigns.view_config.views.aggregate

    assert updated.assigns.view_config.views.graph == socket.assigns.view_config.views.graph
  end

  test "params_to_state preserves detail config during aggregate updates" do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
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
              selected: [{"d1", "id", %{}}],
              order_by: [{"o1", "id", %{"dir" => "desc"}}],
              per_page: "60",
              max_rows: "10000",
              count_mode: "exact",
              row_click_action: "work_item_api_preview",
              prevent_denormalization: false
            },
            aggregate: %{
              group_by: [],
              aggregate: [],
              per_page: "100",
              grid: false,
              grid_colorize: false,
              grid_color_scale: "linear"
            }
          }
        }
      }
    }

    params = %{
      "view_mode" => "aggregate",
      "group_by" => %{
        "k0" => %{"field" => "status", "index" => "0", "uuid" => "k0", "format" => "default"}
      },
      "aggregate" => %{
        "k0" => %{"field" => "id", "index" => "0", "uuid" => "k0", "format" => "count"}
      },
      "aggregate_per_page" => "300",
      "aggregate_grid" => "true",
      "aggregate_grid_colorize" => "true",
      "aggregate_grid_color_scale" => "log"
    }

    updated = ParamsState.params_to_state(params, socket)

    assert updated.assigns.view_config.views.aggregate.per_page == "300"
    assert updated.assigns.view_config.views.aggregate.grid == true
    assert updated.assigns.view_config.views.detail == socket.assigns.view_config.views.detail
  end

  test "form_params_to_state rebuilds detail and aggregate configs from the same submitted form" do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
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

    params = %{
      "view_mode" => "aggregate",
      "selected" => %{
        "k0" => %{"field" => "id", "index" => "0", "uuid" => "detail-col-1", "alias" => "ID"}
      },
      "order_by" => %{
        "k0" => %{"field" => "id", "index" => "0", "uuid" => "detail-order-1", "dir" => "desc"}
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
        "k0" => %{"field" => "id", "index" => "0", "uuid" => "agg-metric-1", "format" => "count"}
      },
      "aggregate_per_page" => "300",
      "aggregate_grid" => "true",
      "aggregate_grid_colorize" => "true",
      "aggregate_grid_color_scale" => "log",
      "chart_type" => "line",
      "options" => %{"title" => "Revenue"}
    }

    updated = ParamsState.form_params_to_state(params, socket)

    assert updated.assigns.view_config.view_mode == "aggregate"

    assert updated.assigns.view_config.views.detail == %{
             selected: [
               {"detail-col-1", "id",
                %{"alias" => "ID", "field" => "id", "index" => "0", "uuid" => "detail-col-1"}}
             ],
             order_by: [
               {"detail-order-1", "id",
                %{"dir" => "desc", "field" => "id", "index" => "0", "uuid" => "detail-order-1"}}
             ],
             per_page: "60",
             max_rows: "10000",
             count_mode: "exact",
             row_click_action: "work_item_api_preview",
             prevent_denormalization: false
           }

    assert updated.assigns.view_config.views.aggregate == %{
             group_by: [
               {"agg-group-1", "status",
                %{
                  "field" => "status",
                  "format" => "default",
                  "index" => "0",
                  "uuid" => "agg-group-1"
                }}
             ],
             aggregate: [
               {"agg-metric-1", "id",
                %{"field" => "id", "format" => "count", "index" => "0", "uuid" => "agg-metric-1"}}
             ],
             per_page: "300",
             grid: true,
             grid_colorize: true,
             grid_color_scale: "log"
           }

    assert updated.assigns.view_config.views.graph.chart_type == "line"
    assert updated.assigns.view_config.views.graph.options == %{"title" => "Revenue"}
  end

  test "form_params_to_state preserves missing non-active views for partial URL params" do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        selecto: %{domain: %{}},
        views: [
          {:detail, SelectoComponents.Views.Detail, "Detail", []},
          {:aggregate, SelectoComponents.Views.Aggregate, "Aggregate", []},
          {:graph, SelectoComponents.Views.Graph, "Graph", []}
        ],
        view_config: %{
          view_mode: "detail",
          filters: [],
          views: %{
            detail: %{
              selected: [{"d1", "id", %{"alias" => "ID"}}],
              order_by: [],
              per_page: "60",
              max_rows: "1000",
              count_mode: "bounded",
              row_click_action: "work_item_quick_view",
              prevent_denormalization: true
            },
            aggregate: %{
              group_by: [{"g1", "status", %{"format" => "default"}}],
              aggregate: [{"a1", "id", %{"format" => "count"}}],
              per_page: "300",
              grid: true,
              grid_colorize: true,
              grid_color_scale: "log"
            },
            graph: %{
              x_axis: [],
              y_axis: [],
              series: [],
              chart_type: "line",
              options: %{"title" => "Revenue"}
            }
          }
        }
      }
    }

    params = %{
      "view_mode" => "detail",
      "filters" => %{
        "k0" => %{
          "filter" => "status",
          "comp" => "=",
          "value" => "open",
          "uuid" => "f1",
          "index" => "0",
          "section" => "filters"
        }
      },
      "selected" => %{
        "k0" => %{"field" => "id", "index" => "0", "uuid" => "d1", "alias" => "ID"}
      },
      "per_page" => "30"
    }

    updated = ParamsState.form_params_to_state(params, socket)

    assert updated.assigns.view_config.views.detail.per_page == "30"

    assert updated.assigns.view_config.views.aggregate ==
             socket.assigns.view_config.views.aggregate

    assert updated.assigns.view_config.views.graph == socket.assigns.view_config.views.graph
  end

  test "submitted_form_params drops LiveView noise and preserves submitted row_click_action" do
    params = %{
      "_target" => ["row_click_action"],
      "_unused_per_page" => "",
      "row_click_action" => "work_item_api_preview",
      "prevent_denormalization" => "on",
      "selected" => %{
        "k0" => %{
          "_unused_alias" => "",
          "field" => "id",
          "index" => "0",
          "uuid" => "123"
        }
      }
    }

    assert ParamsState.submitted_form_params(params) == %{
             "row_click_action" => "work_item_api_preview",
             "prevent_denormalization" => "true",
             "selected" => %{
               "k0" => %{
                 "field" => "id",
                 "index" => "0",
                 "uuid" => "123"
               }
             }
           }
  end

  test "view_config_to_saved_params includes all view configurations" do
    view_config = %{
      view_mode: "detail",
      filters: [
        {"f1", "filters", %{"filter" => "status", "comp" => "=", "value" => "open"}}
      ],
      views: %{
        detail: %{
          selected: [{"d1", "id", %{"alias" => "ID"}}],
          order_by: [{"o1", "id", %{"dir" => "desc"}}],
          per_page: "60",
          max_rows: "1000",
          count_mode: "bounded",
          row_click_action: "workspace_spotlight",
          prevent_denormalization: true
        },
        aggregate: %{
          group_by: [{"g1", "status", %{"format" => "default"}}],
          aggregate: [{"a1", "id", %{"format" => "count"}}],
          per_page: "300",
          grid: true,
          grid_colorize: true,
          grid_color_scale: "log"
        },
        graph: %{
          x_axis: [{"x1", "status", %{}}],
          y_axis: [{"y1", "id", %{"function" => "count"}}],
          series: [{"s1", "priority", %{}}],
          chart_type: "line",
          options: %{"title" => "Open Items"}
        }
      }
    }

    saved = ParamsState.view_config_to_saved_params(view_config)

    assert saved["view_mode"] == "detail"

    assert saved["filters"] == [
             ["f1", "filters", %{"comp" => "=", "filter" => "status", "value" => "open"}]
           ]

    assert saved["views"]["detail"]["row_click_action"] == "workspace_spotlight"
    assert saved["views"]["aggregate"]["grid"] == true
    assert saved["views"]["graph"]["chart_type"] == "line"
  end

  test "saved_params_to_state restores all view configurations" do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        views: [
          {:detail, SelectoComponents.Views.Detail, "Detail", []},
          {:aggregate, SelectoComponents.Views.Aggregate, "Aggregate", []},
          {:graph, SelectoComponents.Views.Graph, "Graph", []}
        ],
        view_config: %{view_mode: "aggregate", filters: [], views: %{}}
      }
    }

    saved_params = %{
      "view_mode" => "detail",
      "filters" => [["f1", "filters", %{"filter" => "status", "comp" => "=", "value" => "open"}]],
      "views" => %{
        "detail" => %{
          "selected" => [["d1", "id", %{"alias" => "ID"}]],
          "order_by" => [["o1", "id", %{"dir" => "desc"}]],
          "per_page" => "60",
          "max_rows" => "1000",
          "count_mode" => "bounded",
          "row_click_action" => "workspace_spotlight",
          "prevent_denormalization" => true
        },
        "aggregate" => %{
          "group_by" => [["g1", "status", %{"format" => "default"}]],
          "aggregate" => [["a1", "id", %{"format" => "count"}]],
          "per_page" => "300",
          "grid" => true,
          "grid_colorize" => true,
          "grid_color_scale" => "log"
        },
        "graph" => %{
          "x_axis" => [["x1", "status", %{}]],
          "y_axis" => [["y1", "id", %{"function" => "count"}]],
          "series" => [["s1", "priority", %{}]],
          "chart_type" => "line",
          "options" => %{"title" => "Open Items"}
        }
      }
    }

    updated = ParamsState.saved_params_to_state(saved_params, socket)

    assert updated.assigns.view_config.view_mode == "detail"

    assert updated.assigns.view_config.filters == [
             {"f1", "filters", %{"filter" => "status", "comp" => "=", "value" => "open"}}
           ]

    assert updated.assigns.view_config.views.detail["row_click_action"] == "workspace_spotlight"
    assert updated.assigns.view_config.views.aggregate["grid"] == true
    assert updated.assigns.view_config.views.graph["chart_type"] == "line"

    detail_params = ParamsState.view_config_to_params(updated.assigns.view_config)
    assert detail_params["row_click_action"] == "workspace_spotlight"
    assert detail_params["filters"]["k0"]["filter"] == "status"
  end

  test "filters_to_params uses compact keys while preserving uuid" do
    params =
      ParamsState.filters_to_params([
        {"48b7fb89-2970-41cf-850d-90da95985408", "filters",
         %{"filter" => "shipper.co_name", "comp" => "=", "value" => "DEMO TRANSPORT"}}
      ])

    assert Map.has_key?(params, "k0")
    assert params["k0"]["uuid"] == "48b7fb89-2970-41cf-850d-90da95985408"
    assert params["k0"]["filter"] == "shipper.co_name"
    refute Map.has_key?(params, "48b7fb89-2970-41cf-850d-90da95985408")
  end

  test "compact_url_params rewrites raw form UUID keys to compact keys" do
    params = %{
      "filters" => %{
        "48b7fb89-2970-41cf-850d-90da95985408" => %{
          "filter" => "shipper.co_name",
          "comp" => "=",
          "value" => "DEMO TRANSPORT",
          "index" => "0"
        }
      },
      "group_by" => %{
        "12b1e264-6359-4f7d-881a-f3c659fd8606" => %{
          "field" => "shipper.co_name",
          "format" => "default",
          "index" => "0"
        }
      }
    }

    compacted = ParamsState.compact_url_params(params)

    assert Map.has_key?(compacted["filters"], "k0")
    assert compacted["filters"]["k0"]["uuid"] == "48b7fb89-2970-41cf-850d-90da95985408"
    refute Map.has_key?(compacted["filters"], "48b7fb89-2970-41cf-850d-90da95985408")

    assert Map.has_key?(compacted["group_by"], "k0")
    assert compacted["group_by"]["k0"]["uuid"] == "12b1e264-6359-4f7d-881a-f3c659fd8606"
  end

  test "view_config_to_params includes map scalar config" do
    view_config = %{
      view_mode: "map",
      filters: [],
      views: %{
        map: %{
          geometry_field: "location",
          popup_field: "name",
          color_field: "status",
          tile_url: "https://tiles.example.test/{z}/{x}/{y}.png",
          attribution: "Example attribution",
          background_mode: "image_overlay",
          coordinate_mode: "local_xy",
          image_overlay_url: "https://assets.example.test/yard.png",
          image_overlay_bounds: [[33.7, -123.5], [49.5, -117.0]],
          image_overlay_opacity: 0.7,
          image_overlay_rotation: 19,
          default_zoom: 7,
          center_lat: 41.2,
          center_lng: -87.6,
          fit_bounds: false,
          max_points: 250,
          cluster: true
        }
      }
    }

    params = ParamsState.view_config_to_params(view_config)

    assert params["view_mode"] == "map"
    assert params["geometry_field"] == "location"
    assert params["popup_field"] == "name"
    assert params["color_field"] == "status"
    assert params["tile_url"] == "https://tiles.example.test/{z}/{x}/{y}.png"
    assert params["attribution"] == "Example attribution"
    assert params["background_mode"] == "image_overlay"
    assert params["coordinate_mode"] == "local_xy"
    assert params["image_overlay_url"] == "https://assets.example.test/yard.png"
    assert params["image_overlay_bounds"] == "33.7,-123.5,49.5,-117.0"
    assert params["image_overlay_opacity"] == "0.7"
    assert params["image_overlay_rotation"] == "19"
    assert params["default_zoom"] == "7"
    assert params["center_lat"] == "41.2"
    assert params["center_lng"] == "-87.6"
    assert params["fit_bounds"] == "false"
    assert params["max_points"] == "250"
    assert params["cluster"] == "true"
  end

  test "view_config_to_params includes map layer config" do
    view_config = %{
      view_mode: "map",
      filters: [],
      views: %{
        map: %{
          map_layers: [
            %{
              label: "Pickup",
              geometry_field: "location",
              geometry_kind: "point",
              popup_field: "pickup_code",
              color_field: "dwell_minutes",
              scale_type: "numeric_steps",
              scale_steps: "20,45,90",
              track_by: "pickup_code",
              track_order_field: "pickup_code",
              point_radius: 8,
              fill_opacity: 0.35,
              visible: true
            },
            %{
              label: "Route",
              geometry_field: "route_path",
              geometry_kind: "line",
              popup_field: "pickup_code",
              color_field: "status",
              scale_type: "categorical",
              scale_palette: "#2563eb,#ef4444",
              scale_categories: "queued:#22c55e,loading:#f59e0b",
              line_weight: 3,
              line_dash_array: "6,4",
              visible: false
            }
          ]
        }
      }
    }

    params = ParamsState.view_config_to_params(view_config)

    assert params["view_mode"] == "map"
    assert params["map_layers"]["0"]["geometry_field"] == "location"
    assert params["map_layers"]["0"]["geometry_kind"] == "point"
    assert params["map_layers"]["0"]["scale_type"] == "numeric_steps"
    assert params["map_layers"]["0"]["scale_steps"] == "20,45,90"
    assert params["map_layers"]["0"]["track_by"] == "pickup_code"
    assert params["map_layers"]["0"]["track_order_field"] == "pickup_code"
    assert params["map_layers"]["0"]["point_radius"] == "8"
    assert params["map_layers"]["0"]["fill_opacity"] == "0.35"
    assert params["map_layers"]["0"]["visible"] == "true"
    assert params["map_layers"]["1"]["geometry_field"] == "route_path"
    assert params["map_layers"]["1"]["geometry_kind"] == "line"
    assert params["map_layers"]["1"]["scale_type"] == "categorical"
    assert params["map_layers"]["1"]["scale_palette"] == "#2563eb,#ef4444"
    assert params["map_layers"]["1"]["scale_categories"] == "queued:#22c55e,loading:#f59e0b"
    assert params["map_layers"]["1"]["line_weight"] == "3"
    assert params["map_layers"]["1"]["line_dash_array"] == "6,4"
    assert params["map_layers"]["1"]["visible"] == "false"
  end

  test "convert_saved_config_to_full_params restores map settings" do
    saved = %{
      "map" => %{
        "geometry_field" => "location",
        "popup_field" => "name",
        "color_field" => "status",
        "default_zoom" => 8,
        "center" => [10.5, -122.75],
        "max_points" => 321,
        "fit_bounds" => false,
        "cluster" => true,
        "tile_url" => "https://tiles.example.test/{z}/{x}/{y}.png",
        "attribution" => "Saved attribution",
        "background_mode" => "image_overlay",
        "coordinate_mode" => "local_xy",
        "image_overlay_url" => "https://assets.example.test/yard-saved.png",
        "image_overlay_bounds" => [33.7, -123.5, 49.5, -117.0],
        "image_overlay_opacity" => 0.6,
        "image_overlay_rotation" => -12
      }
    }

    params = ParamsState.convert_saved_config_to_full_params(saved, "map")

    assert params["view_mode"] == "map"
    assert params["geometry_field"] == "location"
    assert params["popup_field"] == "name"
    assert params["color_field"] == "status"
    assert params["default_zoom"] == "8"
    assert params["center_lat"] == "10.5"
    assert params["center_lng"] == "-122.75"
    assert params["max_points"] == "321"
    assert params["fit_bounds"] == "false"
    assert params["cluster"] == "true"
    assert params["tile_url"] == "https://tiles.example.test/{z}/{x}/{y}.png"
    assert params["attribution"] == "Saved attribution"
    assert params["background_mode"] == "image_overlay"
    assert params["coordinate_mode"] == "local_xy"
    assert params["image_overlay_url"] == "https://assets.example.test/yard-saved.png"
    assert params["image_overlay_bounds"] == "33.7,-123.5,49.5,-117.0"
    assert params["image_overlay_opacity"] == "0.6"
    assert params["image_overlay_rotation"] == "-12"
  end

  test "convert_saved_config_to_full_params restores detail row click action" do
    saved = %{
      "detail" => %{
        "selected" => [],
        "order_by" => [],
        "per_page" => "30",
        "max_rows" => "1000",
        "count_mode" => "bounded",
        "row_click_action" => "customer_profile",
        "prevent_denormalization" => true
      }
    }

    params = ParamsState.convert_saved_config_to_full_params(saved, "detail")

    assert params["view_mode"] == "detail"
    assert params["row_click_action"] == "customer_profile"
  end

  test "convert_saved_config_to_full_params restores map layer settings" do
    saved = %{
      "map" => %{
        "map_layers" => [
          %{
            "label" => "Pickup",
            "geometry_field" => "location",
            "geometry_kind" => "point",
            "popup_field" => "pickup_code",
            "color_field" => "dwell_minutes",
            "scale_type" => "numeric_steps",
            "scale_steps" => "20,45,90",
            "track_by" => "pickup_code",
            "track_order_field" => "pickup_code",
            "point_radius" => 8,
            "fill_opacity" => 0.35,
            "visible" => true
          },
          %{
            "label" => "Route",
            "geometry_field" => "route_path",
            "geometry_kind" => "line",
            "popup_field" => "pickup_code",
            "color_field" => "status",
            "scale_type" => "categorical",
            "scale_palette" => "#2563eb,#ef4444",
            "scale_categories" => "queued:#22c55e,loading:#f59e0b",
            "line_weight" => 3,
            "line_dash_array" => "6,4",
            "visible" => false
          }
        ]
      }
    }

    params = ParamsState.convert_saved_config_to_full_params(saved, "map")

    assert params["view_mode"] == "map"
    assert params["map_layers"]["0"]["geometry_field"] == "location"
    assert params["map_layers"]["0"]["geometry_kind"] == "point"
    assert params["map_layers"]["0"]["scale_type"] == "numeric_steps"
    assert params["map_layers"]["0"]["track_by"] == "pickup_code"
    assert params["map_layers"]["0"]["point_radius"] == "8"
    assert params["map_layers"]["1"]["geometry_field"] == "route_path"
    assert params["map_layers"]["1"]["geometry_kind"] == "line"
    assert params["map_layers"]["1"]["scale_type"] == "categorical"
    assert params["map_layers"]["1"]["scale_categories"] == "queued:#22c55e,loading:#f59e0b"
    assert params["map_layers"]["1"]["line_dash_array"] == "6,4"
    assert params["map_layers"]["1"]["visible"] == "false"
  end
end
