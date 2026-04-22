defmodule SelectoComponents.Execution.Executor do
  @moduledoc """
  Query execution and result normalization for SelectoComponents.
  """

  alias SelectoComponents.Execution.Result
  alias SelectoComponents.Form
  alias SelectoComponents.Form.ParamsState
  alias SelectoComponents.Performance.MetricsCollector
  alias SelectoComponents.Views.Aggregate.Options, as: AggregateOptions
  alias SelectoComponents.Views.Detail.Options, as: DetailOptions

  @spec run(SelectoComponents.Execution.Plan.t(), Phoenix.LiveView.Socket.t()) :: Result.t()
  def run(plan, socket) do
    {query_result, view_meta, page_query_cache} =
      ParamsState.execute_query_for_plan(plan.selecto, plan.params, plan.view_meta, socket)

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
      ParamsState.cap_aggregate_rows_for_result(rows, view_meta, plan.params)

    normalized_rows =
      ParamsState.normalize_rows_for_result(
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
      ParamsState.build_query_cache_debug_info_for_result(
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
      used_params: ParamsState.drop_runtime_only_params_public(plan.params),
      applied_view: ParamsState.get_map_value_public(plan.params, :view_mode),
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
        ParamsState.execution_error_opts_public(error, plan.params, operation: "view-apply")
      )

    {error_sql, error_params} = safe_to_sql(plan.selecto)

    %Result{
      selecto: plan.selecto,
      columns: plan.columns_list,
      field_filters: Selecto.filters(plan.selecto),
      presentation_context: plan.presentation_context,
      query_results: nil,
      used_params: ParamsState.drop_runtime_only_params_public(plan.params),
      applied_view: ParamsState.get_map_value_public(plan.params, :view_mode),
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
        ParamsState.execution_error_opts_public(error, plan.params, operation: "view-apply")
      )

    {error_sql, error_params} = safe_to_sql(plan.selecto)

    %Result{
      selecto: plan.selecto,
      columns: plan.columns_list,
      field_filters: Selecto.filters(plan.selecto),
      presentation_context: plan.presentation_context,
      query_results: nil,
      used_params: ParamsState.drop_runtime_only_params_public(plan.params),
      applied_view: ParamsState.get_map_value_public(plan.params, :view_mode),
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
end
