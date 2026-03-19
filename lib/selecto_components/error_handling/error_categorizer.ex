defmodule SelectoComponents.ErrorHandling.ErrorCategorizer do
  @moduledoc """
  Backward-compatible wrapper around the normalized error builder.
  """

  alias SelectoComponents.ErrorHandling.ErrorBuilder

  @spec categorize(term(), keyword()) :: map()
  def categorize(error, opts \\ []) do
    ErrorBuilder.build(error, opts)
  end

  @spec infer_stage_from_operation(String.t() | nil) :: atom() | nil
  def infer_stage_from_operation(operation),
    do: ErrorBuilder.infer_stage_from_operation(operation)

  @spec format_message(map()) :: String.t()
  def format_message(%{user_message: message, detail: detail})
      when is_binary(detail) and detail != "" do
    message <> " " <> detail
  end

  def format_message(%{user_message: message}) when is_binary(message), do: message
  def format_message(error_info), do: error_info |> categorize() |> format_message()

  @spec recovery_suggestion(map()) :: String.t() | nil
  def recovery_suggestion(%{suggestion: suggestion}) when is_binary(suggestion), do: suggestion

  def recovery_suggestion(%{stage: _stage, category: _category} = error_info) do
    error_info
    |> ErrorBuilder.normalize()
    |> Map.get(:suggestion)
  end

  def recovery_suggestion(error_info), do: error_info |> categorize() |> recovery_suggestion()
end
