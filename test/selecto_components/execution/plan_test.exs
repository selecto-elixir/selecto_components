defmodule SelectoComponents.Execution.PlanTest do
  use ExUnit.Case, async: true

  alias Phoenix.Component
  alias SelectoComponents.Execution.Plan

  test "build returns execution-ready plan with runtime presentation context" do
    socket =
      base_socket()
      |> Component.assign(:presentation_context, %{timezone: "America/New_York"})

    plan = Plan.build(%{"view_mode" => "detail", "selected" => %{}}, socket)

    assert plan.selected_view == :detail
    assert plan.params["_presentation_context"]["timezone"] == nil
    assert plan.params["_presentation_context"].timezone == "America/New_York"
    assert is_map(plan.columns_map)
    assert is_list(plan.columns_list)
    assert plan.view_tuple |> elem(0) == :detail
  end

  test "build applies requested sort to the planned selecto" do
    socket =
      base_socket()
      |> Component.assign(:sort_by, [{"id", :desc}])

    plan =
      Plan.build(
        %{
          "view_mode" => "detail",
          "selected" => %{"k0" => %{"field" => "id", "index" => "0", "uuid" => "d1"}}
        },
        socket
      )

    assert Map.get(plan.selecto.set, :order_by, []) == [{:desc, "id"}]
  end

  test "build normalizes unknown view mode to safe default" do
    plan = Plan.build(%{"view_mode" => "missing_view"}, base_socket())

    assert plan.selected_view == :detail
    assert elem(plan.view_tuple, 0) == :detail
  end

  defp base_socket do
    %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        selecto: selecto(),
        views: [
          {:detail, SelectoComponents.Views.Detail, "Detail", []},
          {:aggregate, SelectoComponents.Views.Aggregate, "Aggregate", []},
          {:graph, SelectoComponents.Views.Graph, "Graph", []}
        ],
        view_config: %{view_mode: "detail", filters: [], views: %{}},
        current_detail_page: 0,
        sort_by: nil,
        presentation_context: %{}
      }
    }
  end

  defp selecto do
    domain = %{
      name: "ExecutionPlanTest",
      source: %{
        source_table: "films",
        primary_key: :id,
        fields: [:id, :language],
        redact_fields: [],
        columns: %{
          id: %{type: :integer, name: "ID", colid: :id},
          language: %{type: :string, name: "Language", colid: :language}
        },
        associations: %{}
      },
      schemas: %{},
      joins: %{}
    }

    Selecto.configure(domain, nil)
  end
end
