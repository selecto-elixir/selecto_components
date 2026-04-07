defmodule SelectoComponents.ErrorHandling.ErrorBuilder do
  @moduledoc """
  Builds normalized, stage-aware error maps for SelectoComponents.
  """

  alias SelectoComponents.DBSupport

  @normalized_keys ~w(stage category severity code summary user_message recoverable retryable source)a

  @spec build(term(), keyword()) :: map()
  def build(error, opts \\ []) do
    opts_map = Enum.into(opts, %{})

    error
    |> wrap_error(opts_map)
    |> normalize()
  end

  @spec normalize(map()) :: map()
  def normalize(error_info) when is_map(error_info) do
    raw_error = Map.get(error_info, :error, error_info)
    stage = normalize_stage(Map.get(error_info, :stage) || infer_stage(raw_error, error_info))

    category =
      normalize_category(Map.get(error_info, :category) || infer_category(raw_error, stage))

    severity =
      normalize_severity(
        Map.get(error_info, :severity) || infer_severity(raw_error, category, stage)
      )

    recoverable = Map.get(error_info, :recoverable, infer_recoverable(raw_error, category, stage))
    retryable = Map.get(error_info, :retryable, infer_retryable(raw_error, category, stage))
    code = normalize_code(Map.get(error_info, :code) || infer_code(raw_error, category, stage))
    source = Map.get(error_info, :source) || infer_source(raw_error)

    user_message =
      Map.get(error_info, :user_message) || infer_user_message(raw_error, category, stage)

    detail = Map.get(error_info, :detail) || infer_detail(raw_error, user_message)
    suggestion = Map.get(error_info, :suggestion) || infer_suggestion(code, category, stage)
    suggestions = normalize_suggestions(Map.get(error_info, :suggestions), suggestion)
    stage_label = stage_label(stage)
    category_label = category_label(category)
    summary = Map.get(error_info, :summary) || build_summary(category_label, stage_label)
    operation = Map.get(error_info, :operation)
    operation_label = Map.get(error_info, :operation_label) || operation_label(operation)

    %{
      stage: stage,
      stage_label: stage_label,
      category: category,
      category_label: category_label,
      severity: severity,
      code: code,
      summary: summary,
      user_message: user_message,
      detail: detail,
      suggestion: suggestion,
      suggestions: suggestions,
      recoverable: recoverable,
      retryable: retryable,
      source: source,
      operation: operation,
      operation_label: operation_label,
      view_mode: Map.get(error_info, :view_mode),
      query_phase: Map.get(error_info, :query_phase) || query_phase_from_stage(stage),
      context: Map.get(error_info, :context, %{}),
      debug: Map.get(error_info, :debug) || build_debug(raw_error),
      error: raw_error,
      timestamp: Map.get(error_info, :timestamp)
    }
  end

  @spec build_many([term()], keyword()) :: [map()]
  def build_many(errors, opts \\ []) when is_list(errors) do
    Enum.map(errors, &build(&1, opts))
  end

  @spec stage_label(atom()) :: String.t()
  def stage_label(:input), do: "reading your input"
  def stage_label(:configuration), do: "preparing the view"
  def stage_label(:normalization), do: "loading the query state"
  def stage_label(:query_build), do: "building the query"
  def stage_label(:sql_compile), do: "generating SQL"
  def stage_label(:db_execute), do: "executing the query"
  def stage_label(:timeout), do: "waiting for query results"
  def stage_label(:result_process), do: "processing query results"
  def stage_label(:render), do: "rendering the view"
  def stage_label(:export), do: "creating the export"
  def stage_label(:persistence), do: "saving or loading configuration"
  def stage_label(:lifecycle), do: "updating the component"
  def stage_label(_), do: "handling the request"

  @spec category_label(atom()) :: String.t()
  def category_label(:validation), do: "Validation error"
  def category_label(:configuration), do: "Configuration error"
  def category_label(:query), do: "Query error"
  def category_label(:sql), do: "SQL error"
  def category_label(:database), do: "Database error"
  def category_label(:timeout), do: "Timeout"
  def category_label(:connection), do: "Connection error"
  def category_label(:processing), do: "Processing error"
  def category_label(:rendering), do: "Rendering error"
  def category_label(:authorization), do: "Authorization error"
  def category_label(:persistence), do: "Persistence error"
  def category_label(:lifecycle), do: "Lifecycle error"
  def category_label(:runtime), do: "Runtime error"
  def category_label(_), do: "Error"

  @spec infer_stage_from_operation(String.t() | nil) :: atom() | nil
  def infer_stage_from_operation("export_data"), do: :export
  def infer_stage_from_operation("save_view"), do: :persistence
  def infer_stage_from_operation("load_view_config"), do: :persistence
  def infer_stage_from_operation("load_saved_view"), do: :persistence
  def infer_stage_from_operation("regen_exported_view"), do: :persistence
  def infer_stage_from_operation("rotate_exported_view_signature"), do: :persistence
  def infer_stage_from_operation("toggle_exported_view_disabled"), do: :persistence
  def infer_stage_from_operation("delete_exported_view"), do: :persistence
  def infer_stage_from_operation("create_exported_view"), do: :persistence
  def infer_stage_from_operation("view-apply"), do: :configuration
  def infer_stage_from_operation("view-validate"), do: :configuration
  def infer_stage_from_operation("rerun_query_with_sort"), do: :db_execute
  def infer_stage_from_operation("update_detail_page"), do: :db_execute
  def infer_stage_from_operation("update_aggregate_page"), do: :db_execute
  def infer_stage_from_operation("set_active_tab"), do: :lifecycle
  def infer_stage_from_operation(_), do: nil

  @spec operation_label(String.t() | nil) :: String.t() | nil
  def operation_label("view-apply"), do: "Apply view"
  def operation_label("view-validate"), do: "Validate view"
  def operation_label("load_view_config"), do: "Load view"
  def operation_label("save_view"), do: "Save view"
  def operation_label("export_data"), do: "Export data"
  def operation_label("update_detail_page"), do: "Change detail page"
  def operation_label("update_aggregate_page"), do: "Change aggregate page"
  def operation_label(_), do: nil

  defp wrap_error(error, opts_map) do
    if normalized?(error) do
      Map.merge(error, opts_map)
    else
      Map.put(opts_map, :error, error)
    end
  end

  defp normalized?(error) when is_map(error) do
    Enum.any?(@normalized_keys, &Map.has_key?(error, &1))
  end

  defp normalized?(_), do: false

  defp build_summary(category_label, stage_label), do: "#{category_label} while #{stage_label}"

  defp infer_stage(raw_error, error_info) do
    case Map.get(error_info, :operation) |> infer_stage_from_operation() do
      nil -> infer_stage_from_error(raw_error)
      stage -> stage
    end
  end

  defp infer_stage_from_error(%{__struct__: module} = error) when module == Selecto.Error do
    case Map.get(error, :type, :query_error) do
      :validation_error -> :input
      :configuration_error -> :configuration
      :field_resolution_error -> :configuration
      :timeout_error -> :timeout
      :connection_error -> :db_execute
      :transformation_error -> :result_process
      :query_error -> if Map.get(error, :query), do: :db_execute, else: :query_build
      _ -> infer_stage_from_details(Map.get(error, :details)) || :unknown
    end
  end

  defp infer_stage_from_error(%{stage: stage}) when is_atom(stage), do: stage

  defp infer_stage_from_error(%{details: details}) when is_map(details) do
    infer_stage_from_details(details) || :unknown
  end

  defp infer_stage_from_error({:error, :timeout}), do: :timeout

  defp infer_stage_from_error({:error, error}) when is_map(error) do
    if DBSupport.database_error?(error), do: :db_execute, else: :unknown
  end

  defp infer_stage_from_error({:error, _}), do: :unknown
  defp infer_stage_from_error({:exit, :timeout}), do: :timeout
  defp infer_stage_from_error({:exit, _}), do: :lifecycle
  defp infer_stage_from_error(%ArgumentError{}), do: :input
  defp infer_stage_from_error(%KeyError{}), do: :configuration
  defp infer_stage_from_error(%MatchError{}), do: :result_process
  defp infer_stage_from_error(%FunctionClauseError{}), do: :result_process
  defp infer_stage_from_error(%Phoenix.LiveView.Socket{}), do: :lifecycle
  defp infer_stage_from_error(_), do: :unknown

  defp infer_stage_from_details(%{stage: stage}) when is_atom(stage), do: stage

  defp infer_stage_from_details(%{"stage" => stage}) when is_binary(stage),
    do: normalize_stage_from_string(stage)

  defp infer_stage_from_details(_), do: nil

  defp infer_category(%{category: category}, _stage) when is_atom(category), do: category

  defp infer_category(%{__struct__: module} = error, _stage) when module == Selecto.Error do
    case Map.get(error, :type, :query_error) do
      :query_error -> :query
      :connection_error -> :connection
      :validation_error -> :validation
      :configuration_error -> :configuration
      :timeout_error -> :timeout
      :field_resolution_error -> :configuration
      :transformation_error -> :processing
      :permission_error -> :authorization
      _ -> :query
    end
  end

  defp infer_category({:error, error}, _stage) when is_map(error) do
    if DBSupport.database_error?(error), do: :database, else: :unknown
  end

  defp infer_category({:error, :timeout}, _stage), do: :timeout
  defp infer_category({:error, :closed}, _stage), do: :connection
  defp infer_category({:error, :invalid}, _stage), do: :validation
  defp infer_category({:error, :not_found}, _stage), do: :query
  defp infer_category({:error, _reason}, _stage), do: :validation
  defp infer_category({:exit, :timeout}, _stage), do: :timeout
  defp infer_category({:exit, _reason}, _stage), do: :connection
  defp infer_category(%ArgumentError{}, _stage), do: :validation
  defp infer_category(%RuntimeError{}, _stage), do: :runtime
  defp infer_category(%KeyError{}, _stage), do: :configuration
  defp infer_category(%MatchError{}, _stage), do: :processing
  defp infer_category(%FunctionClauseError{}, _stage), do: :processing
  defp infer_category(%Phoenix.LiveView.Socket{}, _stage), do: :lifecycle
  defp infer_category(:timeout, _stage), do: :timeout

  defp infer_category(error, _stage) when is_map(error) do
    if DBSupport.database_error?(error), do: :database, else: :unknown
  end

  defp infer_category(_raw_error, _stage), do: :unknown

  defp infer_severity(%{__struct__: module} = error, _category, _stage)
       when module == Selecto.Error do
    case Map.get(error, :type, :query_error) do
      :connection_error -> :critical
      :timeout_error -> :error
      :query_error -> :warning
      :validation_error -> :warning
      :configuration_error -> :error
      _ -> :warning
    end
  end

  defp infer_severity(_raw_error, :connection, _stage), do: :critical
  defp infer_severity(_raw_error, :database, _stage), do: :error
  defp infer_severity(_raw_error, :timeout, _stage), do: :error
  defp infer_severity(_raw_error, :validation, _stage), do: :warning
  defp infer_severity(_raw_error, :configuration, :configuration), do: :warning
  defp infer_severity(_raw_error, :unknown, _stage), do: :error
  defp infer_severity(_raw_error, _category, _stage), do: :error

  defp infer_recoverable(%{__struct__: module} = error, _category, _stage)
       when module == Selecto.Error do
    case Map.get(error, :type, :query_error) do
      :query_error -> true
      :validation_error -> true
      :timeout_error -> true
      :connection_error -> false
      :configuration_error -> false
      :field_resolution_error -> false
      _ -> false
    end
  end

  defp infer_recoverable(_raw_error, :validation, _stage), do: true
  defp infer_recoverable(_raw_error, :configuration, _stage), do: true
  defp infer_recoverable(_raw_error, :database, _stage), do: true
  defp infer_recoverable(_raw_error, :timeout, _stage), do: true
  defp infer_recoverable(_raw_error, :connection, _stage), do: false
  defp infer_recoverable(_raw_error, _category, _stage), do: false

  defp infer_retryable(%{retryable: retryable}, _category, _stage) when is_boolean(retryable),
    do: retryable

  defp infer_retryable(_raw_error, :timeout, _stage), do: true
  defp infer_retryable(_raw_error, :connection, _stage), do: true
  defp infer_retryable(_raw_error, :database, :db_execute), do: false
  defp infer_retryable(_raw_error, _category, _stage), do: false

  defp infer_code(%{code: code}, _category, _stage) when not is_nil(code), do: code

  defp infer_code(%{__struct__: module} = error, _category, _stage)
       when module == Selecto.Error do
    case Map.get(error, :type, :query_error) do
      :query_error -> :query_error
      :connection_error -> :connection_error
      :validation_error -> :validation_error
      :configuration_error -> :invalid_view_config
      :timeout_error -> :query_timed_out
      :field_resolution_error -> :unknown_field
      :transformation_error -> :result_processing_failed
      type -> type
    end
  end

  defp infer_code({:error, :timeout}, _category, _stage), do: :query_timed_out
  defp infer_code({:error, error}, :database, _stage) when is_map(error), do: :db_query_failed
  defp infer_code(%ArgumentError{}, _category, _stage), do: :invalid_argument
  defp infer_code(%KeyError{}, _category, _stage), do: :missing_key
  defp infer_code(%MatchError{}, _category, _stage), do: :result_shape_mismatch
  defp infer_code(%FunctionClauseError{}, _category, _stage), do: :invalid_function_clause
  defp infer_code(_raw_error, _category, _stage), do: :unknown_error

  defp infer_source(%{source: source}) when is_atom(source), do: source
  defp infer_source(%{__struct__: module}) when module == Selecto.Error, do: :selecto
  defp infer_source(%Phoenix.LiveView.Socket{}), do: :liveview
  defp infer_source({:exit, _}), do: :connection

  defp infer_source({:error, error}) when is_map(error) do
    if DBSupport.database_error?(error), do: :database, else: :validation
  end

  defp infer_source({:error, reason}) when is_binary(reason), do: :validation
  defp infer_source({:error, _}), do: :system
  defp infer_source(%{__exception__: true}), do: :exception
  defp infer_source(_), do: :unknown

  defp infer_user_message(%{user_message: message}, _category, _stage) when is_binary(message),
    do: message

  defp infer_user_message(%{__struct__: module} = error, :query, _stage)
       when module == Selecto.Error do
    if Code.ensure_loaded?(Selecto.Error) and
         function_exported?(Selecto.Error, :to_display_message, 1) do
      Selecto.Error.to_display_message(error)
    else
      Map.get(error, :message) || default_user_message(:query_build, :query, :query_error)
    end
  end

  defp infer_user_message(%{__struct__: module} = error, _category, stage)
       when module == Selecto.Error do
    Map.get(error, :message) ||
      default_user_message(stage, infer_category(error, stage), infer_code(error, nil, stage))
  end

  defp infer_user_message({:error, error}, :database, _stage) when is_map(error) do
    DBSupport.format_database_error(error)
  end

  defp infer_user_message({:error, reason}, :validation, _stage) when is_binary(reason),
    do: reason

  defp infer_user_message({:error, reason}, _category, _stage) when is_atom(reason),
    do: to_string(reason)

  defp infer_user_message({:exit, :timeout}, _category, _stage),
    do: default_user_message(:timeout, :timeout, :query_timed_out)

  defp infer_user_message({:exit, _reason}, _category, _stage),
    do: "The operation exited unexpectedly."

  defp infer_user_message(%{message: message}, _category, _stage) when is_binary(message),
    do: message

  defp infer_user_message(%RuntimeError{message: message}, _category, _stage), do: message
  defp infer_user_message(%ArgumentError{message: message}, _category, _stage), do: message
  defp infer_user_message(error, _category, _stage) when is_binary(error), do: error
  defp infer_user_message(_error, category, stage), do: default_user_message(stage, category, nil)

  defp infer_detail(%{detail: detail}, _user_message) when is_binary(detail), do: detail

  defp infer_detail(%{details: details}, user_message) when is_map(details) do
    cond do
      is_binary(Map.get(details, :error)) and Map.get(details, :error) != user_message ->
        Map.get(details, :error)

      is_binary(Map.get(details, "error")) and Map.get(details, "error") != user_message ->
        Map.get(details, "error")

      true ->
        nil
    end
  end

  defp infer_detail(_error, _user_message), do: nil

  defp infer_suggestion(:invalid_aggregate_grid_shape, _category, _stage),
    do: "Use exactly 2 group-by fields and 1 aggregate, or disable Grid mode."

  defp infer_suggestion(:unknown_field, _category, _stage),
    do: "Choose a field that exists in this domain and try again."

  defp infer_suggestion(:sql_compile_failed, _category, _stage),
    do: "Check calculated fields, grouping, filters, and ordering."

  defp infer_suggestion(:db_query_failed, _category, _stage),
    do: "Check selected fields, filters, and groupings."

  defp infer_suggestion(:query_timed_out, _category, _stage),
    do: "Narrow filters or reduce the result size, then retry."

  defp infer_suggestion(_code, :query, _stage),
    do: "Check your filters and try adjusting the query parameters."

  defp infer_suggestion(_code, :validation, _stage), do: "Please check your input and try again."

  defp infer_suggestion(_code, :configuration, _stage),
    do: "Review the current view configuration and try again."

  defp infer_suggestion(_code, :database, _stage), do: "Review the query setup and try again."

  defp infer_suggestion(_code, :timeout, _stage),
    do: "Try a smaller result set and run the query again."

  defp infer_suggestion(_code, :connection, _stage), do: "Refresh the page and try again."

  defp infer_suggestion(_code, :processing, _stage),
    do: "Try simplifying the current view and rerun the query."

  defp infer_suggestion(_code, :persistence, _stage), do: "Try the save or load action again."
  defp infer_suggestion(_, _, _), do: nil

  defp default_user_message(:db_execute, :database, _code),
    do: "The query was sent to the database, but the database rejected it."

  defp default_user_message(:sql_compile, :query, _code),
    do: "The current configuration could not be compiled into valid SQL."

  defp default_user_message(:query_build, :query, _code),
    do: "The current configuration could not be turned into a valid query."

  defp default_user_message(:timeout, :timeout, _code),
    do: "The query took too long to finish and was stopped."

  defp default_user_message(:configuration, :configuration, _code),
    do: "The current view configuration is not valid."

  defp default_user_message(:result_process, :processing, _code),
    do: "The query ran, but the results could not be processed for display."

  defp default_user_message(:render, :rendering, _code),
    do: "The data loaded, but the component could not render the result."

  defp default_user_message(:export, _category, _code), do: "The export could not be completed."

  defp default_user_message(:persistence, _category, _code),
    do: "The configuration could not be saved or loaded."

  defp default_user_message(_stage, :validation, _code), do: "The request contains invalid input."

  defp default_user_message(_stage, :connection, _code),
    do: "The connection failed before the request could complete."

  defp default_user_message(_stage, _category, _code),
    do: "An unexpected error occurred while handling the request."

  defp build_debug(%{__struct__: module} = error) when module == Selecto.Error do
    %{
      raw_error: error,
      sql: Map.get(error, :query),
      params: Map.get(error, :params),
      details: Map.get(error, :details)
    }
  end

  defp build_debug(error), do: %{raw_error: error}

  defp normalize_suggestions(suggestions, _suggestion)
       when is_list(suggestions) and suggestions != [], do: suggestions

  defp normalize_suggestions(_suggestions, nil), do: []
  defp normalize_suggestions(_suggestions, suggestion), do: [suggestion]

  defp query_phase_from_stage(:query_build), do: :build
  defp query_phase_from_stage(:sql_compile), do: :compile
  defp query_phase_from_stage(:db_execute), do: :execute
  defp query_phase_from_stage(:result_process), do: :process
  defp query_phase_from_stage(_), do: nil

  defp normalize_stage(stage)
       when stage in [
              :input,
              :configuration,
              :normalization,
              :query_build,
              :sql_compile,
              :db_execute,
              :timeout,
              :result_process,
              :render,
              :export,
              :persistence,
              :lifecycle,
              :unknown
            ],
       do: stage

  defp normalize_stage(_), do: :unknown

  defp normalize_stage_from_string(stage) do
    case stage do
      "input" -> :input
      "configuration" -> :configuration
      "normalization" -> :normalization
      "query_build" -> :query_build
      "sql_compile" -> :sql_compile
      "db_execute" -> :db_execute
      "timeout" -> :timeout
      "result_process" -> :result_process
      "render" -> :render
      "export" -> :export
      "persistence" -> :persistence
      "lifecycle" -> :lifecycle
      _ -> :unknown
    end
  end

  defp normalize_category(category)
       when category in [
              :validation,
              :configuration,
              :query,
              :sql,
              :database,
              :timeout,
              :connection,
              :processing,
              :rendering,
              :authorization,
              :persistence,
              :runtime,
              :lifecycle,
              :unknown
            ],
       do: category

  defp normalize_category(_), do: :unknown

  defp normalize_severity(severity) when severity in [:info, :warning, :error, :critical],
    do: severity

  defp normalize_severity(_), do: :error

  defp normalize_code(code) when is_atom(code) or is_binary(code), do: code
  defp normalize_code(_), do: :unknown_error
end
