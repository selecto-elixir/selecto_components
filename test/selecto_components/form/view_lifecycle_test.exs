defmodule SelectoComponents.Form.ViewLifecycleTest do
  use ExUnit.Case, async: true

  defmodule SavedViewStub do
    @behaviour SelectoComponents.SavedViews

    @impl true
    def get_view_names(_context), do: []

    @impl true
    def get_view(_name, _context), do: nil

    @impl true
    def save_view(name, context, params) do
      send(self(), {:saved_view, name, context, params})
      %{name: name, params: params}
    end

    @impl true
    def decode_view(view), do: view.params
  end

  defmodule TestLive do
    use Phoenix.LiveView
    use SelectoComponents.Form.EventHandlers.ViewLifecycle
  end

  test "view validate is ignored while waiting for submit patch" do
    original_view_config = %{
      view_mode: "detail",
      filters: [],
      views: %{detail: %{selected: [{"d1", "id", %{}}], order_by: []}}
    }

    socket = %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        validation_locked_until_patch: true,
        view_config: original_view_config
      }
    }

    {:noreply, updated_socket} =
      TestLive.handle_event("view-validate", %{"view_mode" => "aggregate"}, socket)

    assert updated_socket.assigns.view_config == original_view_config
    assert updated_socket.assigns.validation_locked_until_patch == true
  end

  test "view validate clears skip flag but still processes pasted IN values" do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        skip_next_validation: true,
        views: [
          {:aggregate, SelectoComponents.Views.Aggregate, "Aggregate View", %{}},
          {:detail, SelectoComponents.Views.Detail, "Detail View", %{}},
          {:graph, SelectoComponents.Views.Graph, "Graph View", %{}}
        ],
        view_config: %{
          view_mode: "detail",
          filters: [],
          views: %{
            detail: %{selected: [], order_by: [], per_page: "30", max_rows: "1000"},
            aggregate: %{group_by: [], aggregate: [], per_page: "100"},
            graph: %{x_axis: [], y_axis: [], series: [], chart_type: "bar", options: %{}}
          }
        }
      }
    }

    params = %{
      "view_mode" => "detail",
      "filters" => %{
        "f1" => %{
          "filter" => "status",
          "comp" => "IN",
          "value" => "open",
          "pending_values" => "closed\npaused",
          "index" => "0",
          "section" => "filters"
        }
      }
    }

    {:noreply, updated_socket} = TestLive.handle_event("view-validate", params, socket)

    assert updated_socket.assigns.skip_next_validation == false

    assert updated_socket.assigns.view_config.filters == [
             {"f1", "filters",
              %{
                "comp" => "IN",
                "filter" => "status",
                "index" => "0",
                "section" => "filters",
                "selected_values" => ["open", "closed", "paused"],
                "value" => "open,closed,paused"
              }}
           ]
  end

  test "save tab persists all view configurations" do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        active_tab: "save",
        saved_view_module: SavedViewStub,
        saved_view_context: "/work-items",
        my_path: "/work-items",
        view_config: %{
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
              prevent_denormalization: false
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
        },
        params: %{}
      }
    }

    {:noreply, _updated_socket} =
      TestLive.handle_event("view-apply", %{"save_as" => "My Saved View"}, socket)

    assert_received {:saved_view, "My Saved View", "/work-items", saved_params}
    assert saved_params["view_mode"] == "detail"
    assert saved_params["views"]["detail"]["row_click_action"] == "workspace_spotlight"
    assert saved_params["views"]["detail"]["prevent_denormalization"] == false
    assert saved_params["views"]["aggregate"]["grid"] == true
    assert saved_params["views"]["graph"]["chart_type"] == "line"

    assert saved_params["filters"] == [
             ["f1", "filters", %{"comp" => "=", "filter" => "status", "value" => "open"}]
           ]
  end
end
