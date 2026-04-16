defmodule SelectoComponents.Views.Graph.DrillDownTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.Views.Graph.DrillDown

  test "returns user-friendly error for invalid array chart labels" do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        view_config: %{
          view_mode: "graph",
          views: %{graph: %{x_axis: [{"x1", "tags", %{}}]}},
          filters: []
        },
        selecto: %{set: %{}},
        columns: [{"tags", "Tags", {:array, :string}}],
        views: [{:graph, nil, "Graph", %{drill_down: :detail}}],
        used_params: %{}
      }
    }

    assert {:error, message} = DrillDown.apply(socket, %{"label" => nil})
    assert message =~ "Could not drill down"
  end

  test "uses current timeseries x-axis config for drilldown filters" do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        view_config: %{
          view_mode: "timeseries",
          views: %{timeseries: %{x_axis: [{"x1", "recorded_at", %{}}]}},
          filters: []
        },
        selecto: %{set: %{}},
        columns: [{"recorded_at", "Recorded At", :utc_datetime}],
        views: [{:timeseries, nil, "Time Series", %{drill_down: :detail}}],
        used_params: %{}
      }
    }

    assert {:ok, updated_socket, _view_params} =
             DrillDown.apply(socket, %{"label" => "2026-03-04"})

    {_id, _section, filter_map} = List.last(updated_socket.assigns.view_config.filters)
    assert filter_map["filter"] == "recorded_at"
  end

  test "applies indexed grouped graph drill-down as multiple filters" do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        view_config: %{
          view_mode: "graph",
          views: %{
            graph: %{
              x_axis: [
                {"x1", "state",
                 %{"field" => "state", "index" => "0", "linked_to_next" => "true"}},
                {"x2", "title", %{"field" => "title", "index" => "1", "format" => "text_prefix"}}
              ],
              series: [
                {"s1", "rank", %{"field" => "rank", "index" => "0", "bucket_ranges" => "*/5"}}
              ]
            }
          },
          filters: []
        },
        selecto: %{
          domain: %{
            custom_columns: %{
              "state" => %{colid: "state", field: "state", type: :string},
              "title" => %{colid: "title", field: "title", type: :string},
              "rank" => %{colid: "rank", field: "rank", type: :integer}
            }
          },
          config: %{columns: %{}, domain_data: %{}},
          set: %{}
        },
        columns: [
          {"state", "State", :string},
          {"title", "Title", :string},
          {"rank", "Rank", :integer}
        ],
        views: [{:graph, nil, "Graph", %{drill_down: :detail}}],
        used_params: %{
          "x_axis" => %{
            "x1" => %{"field" => "state", "index" => "0", "linked_to_next" => "true"},
            "x2" => %{"field" => "title", "index" => "1", "format" => "text_prefix"}
          },
          "series" => %{
            "s1" => %{"field" => "rank", "index" => "0", "bucket_ranges" => "*/5"}
          }
        }
      }
    }

    params = %{
      "field0" => "state",
      "value0" => "done",
      "gidx0" => "0",
      "field1" => "title",
      "value1" => "ES",
      "gidx1" => "1",
      "field2" => "rank",
      "value2" => "0-4",
      "gidx2" => "2"
    }

    assert {:ok, updated_socket, _view_params} = DrillDown.apply(socket, params)

    filters = updated_socket.assigns.view_config.filters
    assert length(filters) == 3

    assert Enum.any?(filters, fn {_id, _section, filter} ->
             filter["filter"] == "state" and filter["comp"] == "=" and filter["value"] == "done"
           end)

    assert Enum.any?(filters, fn {_id, _section, filter} ->
             filter["filter"] == "title" and filter["comp"] == "STARTS" and
               filter["value"] == "es"
           end)

    assert Enum.any?(filters, fn {_id, _section, filter} ->
             filter["filter"] == "rank" and filter["comp"] == "BETWEEN" and
               filter["value_start"] == "0" and filter["value_end"] == "4"
           end)
  end
end
