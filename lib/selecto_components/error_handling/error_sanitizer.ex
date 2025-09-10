defmodule SelectoComponents.ErrorHandling.ErrorSanitizer do
  @moduledoc """
  Sanitizes error messages for production environments to prevent sensitive information leakage.
  """

  @doc """
  Determines if the current environment is production.
  """
  def production_env? do
    # Check if Mix is available (it's not in releases)
    if Code.ensure_loaded?(Mix) do
      Mix.env() == :prod
    else
      # If Mix is not available, we're likely in a release (production)
      true
    end
  end

  @doc """
  Sanitizes an error for display based on the current environment.
  In production, removes sensitive details like SQL queries, parameters, and stack traces.
  """
  def sanitize_error(error, opts \\ []) do
    if production_env?() and not bypass_sanitization?(opts) do
      sanitize_for_production(error)
    else
      # In development/test, return the error as-is
      error
    end
  end

  @doc """
  Sanitizes error details map for production.
  """
  def sanitize_details(details, opts \\ []) do
    if production_env?() and not bypass_sanitization?(opts) do
      details
      |> Map.delete(:sql)
      |> Map.delete(:sql_params)
      |> Map.delete(:stack_trace)
      |> Map.delete(:component_state)
      |> Map.delete(:raw_error)
      |> Map.put(:sanitized, true)
    else
      details
    end
  end

  @doc """
  Sanitizes suggestions to be production-safe.
  """
  def sanitize_suggestions(suggestions) when is_list(suggestions) do
    if production_env?() do
      suggestions
      |> Enum.map(&sanitize_suggestion/1)
      |> Enum.reject(&is_nil/1)
    else
      suggestions
    end
  end
  def sanitize_suggestions(suggestions), do: suggestions

  # Private functions

  defp bypass_sanitization?(opts) do
    # Allow bypassing sanitization for specific cases (e.g., admin users)
    # This should be configured based on your security requirements
    Keyword.get(opts, :bypass_sanitization, false)
  end

  defp sanitize_for_production(error) when is_map(error) do
    error
    |> Map.put(:message, sanitize_message(error[:message]))
    |> Map.put(:details, sanitize_details(error[:details] || %{}))
    |> Map.put(:suggestions, sanitize_suggestions(error[:suggestions] || []))
    |> Map.delete(:sql)
    |> Map.delete(:sql_params)
    |> Map.delete(:stack_trace)
  end
  defp sanitize_for_production(error), do: error

  defp sanitize_message(nil), do: "An error occurred"
  defp sanitize_message(message) when is_binary(message) do
    message
    |> remove_sql_content()
    |> remove_parameter_values()
    |> remove_table_names()
    |> generic_fallback()
  end
  defp sanitize_message(_), do: "An error occurred"

  defp remove_sql_content(message) do
    # Remove SQL queries from error messages
    message
    |> String.replace(~r/SELECT .* FROM .*/i, "[SQL query removed]")
    |> String.replace(~r/INSERT INTO .*/i, "[SQL query removed]")
    |> String.replace(~r/UPDATE .* SET .*/i, "[SQL query removed]")
    |> String.replace(~r/DELETE FROM .*/i, "[SQL query removed]")
    |> String.replace(~r/WHERE .*/i, "[condition removed]")
  end

  defp remove_parameter_values(message) do
    # Remove parameter values like $1, $2 or actual values in brackets
    message
    |> String.replace(~r/\$\d+/, "[param]")
    |> String.replace(~r/\[.*?\]/, "[value]")
    |> String.replace(~r/= '.*?'/, "= [value]")
    |> String.replace(~r/= ".*?"/, "= [value]")
    |> String.replace(~r/= \d+/, "= [value]")
  end

  defp remove_table_names(message) do
    # Remove potential table/column names (basic heuristic)
    message
    |> String.replace(~r/"[\w_]+"\.?"[\w_]+"/, "[table.column]")
    |> String.replace(~r/"[\w_]+"/, "[identifier]")
    |> String.replace(~r/`[\w_]+`/, "[identifier]")
  end

  defp generic_fallback(message) do
    # If message still contains sensitive patterns, use generic message
    cond do
      String.contains?(message, ["password", "secret", "token", "key"]) ->
        "A security-related error occurred"
      
      String.contains?(message, ["database", "postgres", "mysql", "sqlite"]) ->
        "A database error occurred"
      
      String.contains?(message, ["connection", "timeout", "refused"]) ->
        "A connection error occurred"
      
      String.length(message) > 200 ->
        # Very long messages might contain dumps, truncate them
        String.slice(message, 0, 100) <> "... [truncated for security]"
      
      true ->
        message
    end
  end

  defp sanitize_suggestion(suggestion) when is_binary(suggestion) do
    cond do
      # Remove suggestions that might reveal schema
      String.contains?(suggestion, ["table", "column", "index", "constraint"]) ->
        "Please check your data configuration"
      
      # Remove suggestions with specific field names
      String.contains?(suggestion, ~r/field: :\w+/) ->
        "Please verify your field selection"
      
      # Keep generic helpful suggestions
      String.contains?(suggestion, ["try", "check", "verify", "ensure"]) ->
        suggestion
        |> remove_sql_content()
        |> remove_parameter_values()
        |> remove_table_names()
      
      true ->
        suggestion
    end
  end
  defp sanitize_suggestion(_), do: nil

  @doc """
  Returns a safe, user-friendly error message based on error type.
  """
  def user_friendly_message(error_type) do
    case error_type do
      :connection_error ->
        "Unable to connect to the data source. Please try again later."
      
      :timeout_error ->
        "The operation took too long to complete. Please try again with a smaller dataset."
      
      :permission_error ->
        "You don't have permission to perform this operation."
      
      :validation_error ->
        "The provided data is invalid. Please check your input."
      
      :configuration_error ->
        "There's a configuration issue. Please contact support."
      
      :query_error ->
        "Unable to retrieve the requested data. Please try a different query."
      
      :aggregate_error ->
        "Unable to calculate aggregates. Please check your grouping configuration."
      
      :filter_error ->
        "Unable to apply filters. Please check your filter configuration."
      
      _ ->
        "An unexpected error occurred. Please try again or contact support if the issue persists."
    end
  end

  @doc """
  Returns production-safe suggestions based on error type.
  """
  def safe_suggestions(error_type) do
    case error_type do
      :connection_error ->
        [
          "Check your internet connection",
          "Try refreshing the page",
          "Contact support if the issue persists"
        ]
      
      :timeout_error ->
        [
          "Try using fewer filters",
          "Select a smaller date range",
          "Reduce the number of grouped columns"
        ]
      
      :permission_error ->
        [
          "Verify you're logged in",
          "Check with your administrator for access",
          "Try a different view or report"
        ]
      
      :validation_error ->
        [
          "Check all required fields are filled",
          "Ensure dates are in the correct format",
          "Verify numeric values are valid"
        ]
      
      :query_error ->
        [
          "Try simplifying your query",
          "Remove complex filters temporarily",
          "Start with a basic view and add complexity"
        ]
      
      _ ->
        [
          "Try refreshing the page",
          "Clear your browser cache",
          "Contact support with error details"
        ]
    end
  end
end