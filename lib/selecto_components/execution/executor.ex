defmodule SelectoComponents.Execution.Executor do
  @moduledoc """
  Query execution and result normalization for SelectoComponents.
  """

  alias SelectoComponents.Execution.Result
  alias SelectoComponents.Execution.QueryHelpers
  alias SelectoComponents.Form
  alias SelectoComponents.Performance.MetricsCollector
  alias SelectoComponents.Views.Aggregate.Options, as: AggregateOptions
  alias SelectoComponents.Views.Detail.Options, as: DetailOptions

  @spec run(SelectoComponents.Execution.Plan.t(), Phoenix.LiveView.Socket.t()) :: Result.t()
  def run(plan, socket) do
    {query_result, view_meta, page_query_cache} =
      QueryHelpers.execute_query_with_pagination(
        plan.selecto,
        plan.params,
        plan.view_meta,
        socket
      )

    case query_result do
      {:ok, {rows, columns, aliases}, metadata} ->
        build_success_result(
          plan,
          socket,
          rows,
          columns,
          aliases,
          metadata,
          view_meta,
          page_query_cache
        )

      {:error, %{__struct__: module} = error} when module == Selecto.Error ->
        build_selecto_error_result(plan, error, view_meta, page_query_cache)

      {:error, error} ->
        build_generic_error_result(plan, error, view_meta, page_query_cache)
    end
  end

  defp build_success_result(
         plan,
         socket,
         rows,
         columns,
         aliases,
         metadata,
         view_meta,
         page_query_cache
       ) do
    query_sql = Map.get(metadata, :sql)
    query_params = Map.get(metadata, :params, [])
    execution_time = Map.get(metadata, :execution_time, 0)

    if is_binary(query_sql) and query_sql != "" do
      MetricsCollector.record_query(query_sql, execution_time, %{
        rows_returned: length(rows),
        total_rows:
          Map.get(view_meta, :total_rows, Map.get(view_meta, :aggregate_total_rows, length(rows))),
        columns_count: length(columns),
        view_mode: socket.assigns.view_config.view_mode,
        has_filters: length(list_field(plan.selecto.set, :filtered)) > 0,
        has_grouping: length(list_field(plan.selecto.set, :group_by)) > 0,
        params: query_params
      })
    end

    {rows_for_display, view_meta} =
      QueryHelpers.maybe_cap_aggregate_rows(rows, view_meta, plan.params)

    normalized_rows =
      QueryHelpers.normalize_rows_for_view(
        rows_for_display,
        columns,
        socket.assigns.view_config.view_mode
      )

    view_meta = Map.merge(view_meta, %{exe_id: UUID.uuid4()})

    detail_cache_assignment =
      if DetailOptions.detail_view_mode?(plan.params), do: page_query_cache, else: nil

    aggregate_cache_assignment =
      if AggregateOptions.aggregate_view_mode?(plan.params), do: page_query_cache, else: nil

    cache_debug_info =
      QueryHelpers.build_query_cache_debug_info(
        detail_cache_assignment,
        plan.params,
        normalized_rows,
        columns,
        aliases
      )

    previous_last_query_info = socket.assigns[:last_query_info] || %{}
    executed_sql? = is_binary(query_sql) and query_sql != ""

    effective_sql = if executed_sql?, do: query_sql, else: Map.get(previous_last_query_info, :sql)

    effective_params =
      if executed_sql?,
        do: query_params,
        else: Map.get(previous_last_query_info, :params, query_params)

    effective_timing =
      if executed_sql?, do: execution_time, else: Map.get(previous_last_query_info, :timing)

    last_query_info = %{
      sql: effective_sql,
      params: effective_params,
      timing: effective_timing,
      page_cache_memory_bytes: cache_debug_info.bytes,
      page_cache_pages: cache_debug_info.pages,
      page_cache_rows: cache_debug_info.rows
    }

    %Result{
      selecto: plan.selecto,
      columns: plan.columns_list,
      field_filters: Selecto.filters(plan.selecto),
      presentation_context: plan.presentation_context,
      query_results: {normalized_rows, columns, aliases},
      used_params: drop_runtime_only_params(plan.params),
      applied_view: get_map_value(plan.params, :view_mode),
      view_meta: view_meta,
      detail_page_cache: detail_cache_assignment,
      aggregate_page_cache: aggregate_cache_assignment,
      executed: true,
      execution_error: nil,
      last_query_info: last_query_info
    }
  end

  defp build_selecto_error_result(plan, error, view_meta, page_query_cache) do
    sanitized_error =
      Form.sanitize_error_for_environment(
        error,
        execution_error_opts(error, plan.params, operation: "view-apply")
      )

    {error_sql, error_params} = safe_to_sql(plan.selecto)

    %Result{
      selecto: plan.selecto,
      columns: plan.columns_list,
      field_filters: Selecto.filters(plan.selecto),
      presentation_context: plan.presentation_context,
      query_results: nil,
      used_params: drop_runtime_only_params(plan.params),
      applied_view: get_map_value(plan.params, :view_mode),
      view_meta: view_meta,
      detail_page_cache:
        if(DetailOptions.detail_view_mode?(plan.params), do: page_query_cache, else: nil),
      aggregate_page_cache:
        if(AggregateOptions.aggregate_view_mode?(plan.params), do: page_query_cache, else: nil),
      executed: false,
      execution_error: sanitized_error,
      last_query_info: %{sql: error_sql, params: error_params, timing: nil}
    }
  end

  defp build_generic_error_result(plan, error, view_meta, page_query_cache) do
    sanitized_error =
      Form.build_selecto_error(:query_error, inspect(error), %{original_error: error})
      |> Form.sanitize_error_for_environment(
        execution_error_opts(error, plan.params, operation: "view-apply")
      )

    {error_sql, error_params} = safe_to_sql(plan.selecto)

    %Result{
      selecto: plan.selecto,
      columns: plan.columns_list,
      field_filters: Selecto.filters(plan.selecto),
      presentation_context: plan.presentation_context,
      query_results: nil,
      used_params: drop_runtime_only_params(plan.params),
      applied_view: get_map_value(plan.params, :view_mode),
      view_meta: view_meta,
      detail_page_cache:
        if(DetailOptions.detail_view_mode?(plan.params), do: page_query_cache, else: nil),
      aggregate_page_cache:
        if(AggregateOptions.aggregate_view_mode?(plan.params), do: page_query_cache, else: nil),
      executed: false,
      execution_error: sanitized_error,
      last_query_info: %{sql: error_sql, params: error_params, timing: nil}
    }
  end

  defp safe_to_sql(selecto) do
    try do
      case Selecto.to_sql(selecto) do
        {sql, params} -> {sql, params}
        _ -> {nil, []}
      end
    rescue
      _ -> {nil, []}
    end
  end

  defp list_field(map, key) when is_map(map) and is_atom(key) do
    case Map.get(map, key, []) do
      list when is_list(list) -> list
      _ -> []
    end
  end

  defp list_field(_map, _key), do: []

  defp execution_error_opts(error, params, extra_opts) do
    view_mode = get_map_value(params, :view_mode)

    Keyword.merge(
      [
        stage: execution_error_stage(error),
        category: execution_error_category(error),
        code: execution_error_code(error),
        view_mode: view_mode
      ],
      extra_opts
    )
  end

  defp execution_error_stage(%{__struct__: module} = error) when module == Selecto.Error do
    case Map.get(error, :type, :query_error) do
      :validation_error -> :input
      :configuration_error -> :configuration
      :field_resolution_error -> :configuration
      :timeout_error -> :timeout
      :connection_error -> :db_execute
      :transformation_error -> :result_process
      :query_error -> if(Map.get(error, :query), do: :db_execute, else: :query_build)
      _ -> :unknown
    end
  end

  defp execution_error_stage(:timeout), do: :timeout
  defp execution_error_stage({:error, :timeout}), do: :timeout
  defp execution_error_stage(_), do: :db_execute

  defp execution_error_category(%{__struct__: module} = error) when module == Selecto.Error do
    case Map.get(error, :type, :query_error) do
      :validation_error -> :validation
      :configuration_error -> :configuration
      :field_resolution_error -> :configuration
      :timeout_error -> :timeout
      :connection_error -> :connection
      :transformation_error -> :processing
      :permission_error -> :authorization
      :query_error -> :query
      _ -> :runtime
    end
  end

  defp execution_error_category(:timeout), do: :timeout
  defp execution_error_category({:error, :timeout}), do: :timeout
  defp execution_error_category(_), do: :query

  defp execution_error_code(%{__struct__: module} = error) when module == Selecto.Error do
    case Map.get(error, :type, :query_error) do
      :validation_error -> :validation_error
      :configuration_error -> :invalid_view_config
      :field_resolution_error -> :unknown_field
      :timeout_error -> :query_timed_out
      :connection_error -> :connection_error
      :transformation_error -> :result_processing_failed
      :permission_error -> :permission_error
      :query_error -> if(Map.get(error, :query), do: :db_query_failed, else: :query_build_failed)
      type -> type
    end
  end

  defp execution_error_code(:timeout), do: :query_timed_out
  defp execution_error_code({:error, :timeout}), do: :query_timed_out
  defp execution_error_code(_), do: :db_query_failed

  defp drop_runtime_only_params(params) when is_map(params),
    do: Map.delete(params, "_presentation_context")

  defp drop_runtime_only_params(params), do: params

  defp get_map_value(map, key, default \\ nil)

  defp get_map_value(map, key, default) when is_map(map) do
    Map.get(map, key, Map.get(map, to_string(key), default))
  end

  defp get_map_value(_map, _key, default), do: default
end
