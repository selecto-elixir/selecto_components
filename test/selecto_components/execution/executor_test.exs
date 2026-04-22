defmodule SelectoComponents.Execution.ExecutorTest do
  use ExUnit.Case, async: true

  alias Phoenix.Component
  alias SelectoComponents.Execution.Executor
  alias SelectoComponents.Execution.Plan
  alias SelectoComponents.Execution.Result

  test "run returns normalized execution result shape" do
    socket =
      base_socket()
      |> Component.assign(:view_config, %{view_mode: "detail", filters: [], views: %{detail: %{}}})

    plan =
      Plan.build(
        %{
          "view_mode" => "detail",
          "selected" => %{"k0" => %{"field" => "id", "index" => "0", "uuid" => "d1"}}
        },
        socket
      )

    result = Executor.run(plan, socket)

    assert %Result{} = result
    assert is_boolean(result.executed)
    assert result.applied_view == "detail"
    assert is_map(result.last_query_info)
    assert Map.has_key?(Result.to_assigns(result), :execution_error)
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
        presentation_context: %{},
        last_query_info: %{}
      }
    }
  end

  defp selecto do
    domain = %{
      name: "ExecutionExecutorTest",
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
