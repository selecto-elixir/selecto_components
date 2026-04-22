defmodule SelectoComponents.Execution.ResultState do
  @moduledoc """
  Bridges normalized execution results into socket assigns and notifications.
  """

  alias Phoenix.Component
  alias SelectoComponents.Execution.Result

  @spec assign_result(Phoenix.LiveView.Socket.t(), Result.t()) :: Phoenix.LiveView.Socket.t()
  def assign_result(socket, %Result{} = result) do
    Component.assign(socket, Result.to_assigns(result))
  end

  @spec maybe_notify_query_executed(Result.t()) :: :ok
  def maybe_notify_query_executed(%Result{executed: true} = result) do
    send(
      self(),
      {:query_executed,
       %{
         selecto: result.selecto,
         query_results: result.query_results,
         last_query_info: result.last_query_info,
         view_meta: result.view_meta,
         applied_view: result.applied_view,
         detail_page_cache: result.detail_page_cache,
         aggregate_page_cache: result.aggregate_page_cache
       }}
    )

    :ok
  end

  def maybe_notify_query_executed(%Result{}), do: :ok

  @spec success_row_count(Result.t()) :: non_neg_integer()
  def success_row_count(%Result{query_results: {rows, _columns, _aliases}}) when is_list(rows),
    do: length(rows)

  def success_row_count(%Result{}), do: 0

  @spec build_processing_failure(Phoenix.LiveView.Socket.t(), map(), map()) ::
          Phoenix.LiveView.Socket.t()
  def build_processing_failure(socket, params, execution_error) do
    socket
    |> Component.assign(
      query_results: nil,
      used_params: drop_runtime_only_params(params),
      applied_view: view_mode_value(params, socket.assigns[:applied_view]),
      executed: false,
      execution_error: execution_error,
      view_meta: %{},
      detail_page_cache: nil,
      aggregate_page_cache: nil,
      last_query_info: %{}
    )
  end

  @spec build_exit_failure(Phoenix.LiveView.Socket.t(), map(), map()) ::
          Phoenix.LiveView.Socket.t()
  def build_exit_failure(socket, params, execution_error) do
    socket
    |> Component.assign(
      query_results: nil,
      used_params: drop_runtime_only_params(params),
      applied_view: view_mode_value(params, socket.assigns[:applied_view]),
      executed: false,
      execution_error: execution_error,
      view_meta: %{},
      detail_page_cache: nil,
      aggregate_page_cache: nil,
      last_query_info: %{}
    )
  end

  defp drop_runtime_only_params(params) when is_map(params),
    do: Map.delete(params, "_presentation_context")

  defp drop_runtime_only_params(params), do: params

  defp view_mode_value(params, fallback) when is_map(params) do
    Map.get(params, :view_mode, Map.get(params, "view_mode", fallback))
  end

  defp view_mode_value(_params, fallback), do: fallback
end
