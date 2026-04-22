defmodule SelectoComponents.Execution.Result do
  @moduledoc """
  Normalized execution output for one SelectoComponents run.
  """

  defstruct [
    :selecto,
    :columns,
    :field_filters,
    :presentation_context,
    :query_results,
    :used_params,
    :applied_view,
    :view_meta,
    :detail_page_cache,
    :aggregate_page_cache,
    :executed,
    :execution_error,
    :last_query_info
  ]

  @type t :: %__MODULE__{}

  @spec to_assigns(t()) :: map()
  def to_assigns(%__MODULE__{} = result) do
    %{
      selecto: result.selecto,
      columns: result.columns,
      field_filters: result.field_filters,
      presentation_context: result.presentation_context,
      query_results: result.query_results,
      used_params: result.used_params,
      applied_view: result.applied_view,
      view_meta: result.view_meta,
      detail_page_cache: result.detail_page_cache,
      aggregate_page_cache: result.aggregate_page_cache,
      executed: result.executed,
      execution_error: result.execution_error,
      last_query_info: result.last_query_info
    }
  end
end
