defmodule SelectoComponents.Execution.ResultStateTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.Execution.Result
  alias SelectoComponents.Execution.ResultState

  test "assign_result assigns normalized result fields" do
    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}

    result = %Result{
      selecto: %{},
      columns: ["id"],
      field_filters: [],
      presentation_context: %{},
      query_results: {[%{id: 1}], ["id"], ["ID"]},
      used_params: %{"view_mode" => "detail"},
      applied_view: "detail",
      view_meta: %{},
      detail_page_cache: nil,
      aggregate_page_cache: nil,
      executed: true,
      execution_error: nil,
      last_query_info: %{sql: "select 1", params: [], timing: 1}
    }

    updated_socket = ResultState.assign_result(socket, result)

    assert updated_socket.assigns.applied_view == "detail"
    assert updated_socket.assigns.executed == true
    assert updated_socket.assigns.last_query_info.sql == "select 1"
  end

  test "maybe_notify_query_executed sends message for successful result" do
    result = %Result{
      selecto: %{},
      query_results: {[%{id: 1}], ["id"], ["ID"]},
      last_query_info: %{},
      view_meta: %{},
      applied_view: "detail",
      detail_page_cache: nil,
      aggregate_page_cache: nil,
      executed: true
    }

    assert :ok = ResultState.maybe_notify_query_executed(result)
    assert_received {:query_executed, %{applied_view: "detail"}}
  end

  test "build_processing_failure returns failure-shaped socket assigns" do
    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
    error = %{summary: "Failed"}

    updated_socket =
      ResultState.build_processing_failure(
        socket,
        %{"view_mode" => "graph", "_presentation_context" => %{}},
        error
      )

    assert updated_socket.assigns.executed == false
    assert updated_socket.assigns.execution_error == error
    assert updated_socket.assigns.applied_view == "graph"
    refute Map.has_key?(updated_socket.assigns.used_params, "_presentation_context")
  end
end
