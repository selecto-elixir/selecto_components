defmodule SelectoComponents.ErrorHandling.ErrorCategorizer do
  @moduledoc """
  Categorizes and classifies errors that occur within SelectoComponents.
  Provides consistent error classification for proper display and handling.
  """

  @doc """
  Categorizes an error and returns detailed classification.
  """
  @spec categorize(term()) :: map()
  def categorize(%Selecto.Error{} = error) do
    %{
      category: categorize_selecto_error(error.type),
      severity: determine_severity(error.type),
      recoverable: is_recoverable?(error.type),
      error: error,
      source: :selecto
    }
  end

  def categorize(%Phoenix.LiveView.Socket{} = _socket) do
    %{
      category: :lifecycle,
      severity: :warning,
      recoverable: true,
      error: %{message: "LiveView lifecycle error"},
      source: :liveview
    }
  end

  def categorize(%{__exception__: true} = exception) do
    %{
      category: categorize_exception(exception),
      severity: :error,
      recoverable: false,
      error: exception,
      source: :exception
    }
  end

  def categorize({:error, %Postgrex.Error{} = error}) do
    %{
      category: :database,
      severity: :error,
      recoverable: is_db_error_recoverable?(error),
      error: error,
      source: :database
    }
  end

  def categorize({:error, reason}) when is_binary(reason) do
    %{
      category: :validation,
      severity: :warning,
      recoverable: true,
      error: %{message: reason},
      source: :validation
    }
  end

  def categorize({:error, reason}) when is_atom(reason) do
    %{
      category: categorize_atom_error(reason),
      severity: :warning,
      recoverable: true,
      error: %{message: to_string(reason)},
      source: :system
    }
  end

  def categorize({:exit, reason}) do
    %{
      category: :connection,
      severity: :critical,
      recoverable: false,
      error: %{message: "Connection failed", reason: reason},
      source: :connection
    }
  end

  def categorize(error) do
    %{
      category: :unknown,
      severity: :error,
      recoverable: false,
      error: %{message: inspect(error)},
      source: :unknown
    }
  end

  @doc """
  Returns a user-friendly message for the categorized error.
  """
  @spec format_message(map()) :: String.t()
  def format_message(%{category: :query, error: %Selecto.Error{} = error}) do
    Selecto.Error.to_display_message(error)
  end

  def format_message(%{category: :database, error: %Postgrex.Error{} = error}) do
    format_database_error(error)
  end

  def format_message(%{category: :validation, error: %{message: message}}) do
    "Validation failed: #{message}"
  end

  def format_message(%{category: :configuration, error: %{message: message}}) do
    "Configuration error: #{message}"
  end

  def format_message(%{category: :lifecycle, error: %{message: message}}) do
    "Component lifecycle error: #{message}"
  end

  def format_message(%{category: :rendering, error: %{message: message}}) do
    "Rendering error: #{message}"
  end

  def format_message(%{category: :connection, error: %{message: message}}) do
    "Connection lost: #{message}"
  end

  def format_message(%{error: %{message: message}}) when is_binary(message) do
    message
  end

  def format_message(%{error: error}) do
    inspect(error)
  end

  @doc """
  Provides recovery suggestions based on error category.
  """
  @spec recovery_suggestion(map()) :: String.t() | nil
  def recovery_suggestion(%{category: :query, recoverable: true}) do
    "Check your filters and try adjusting the query parameters."
  end

  def recovery_suggestion(%{category: :database, recoverable: true}) do
    "The database operation failed. Please try again."
  end

  def recovery_suggestion(%{category: :validation}) do
    "Please check your input and ensure all required fields are valid."
  end

  def recovery_suggestion(%{category: :configuration}) do
    "The component configuration is invalid. Please check the domain setup."
  end

  def recovery_suggestion(%{category: :connection}) do
    "Connection to the database was lost. Please refresh the page."
  end

  def recovery_suggestion(%{category: :lifecycle}) do
    "The component state may be out of sync. Try refreshing the view."
  end

  def recovery_suggestion(_), do: nil

  # Private functions

  defp categorize_selecto_error(:query_error), do: :query
  defp categorize_selecto_error(:connection_error), do: :connection
  defp categorize_selecto_error(:validation_error), do: :validation
  defp categorize_selecto_error(:configuration_error), do: :configuration
  defp categorize_selecto_error(:timeout_error), do: :timeout
  defp categorize_selecto_error(:field_resolution_error), do: :configuration
  defp categorize_selecto_error(:transformation_error), do: :rendering
  defp categorize_selecto_error(_), do: :query

  defp categorize_exception(%ArgumentError{}), do: :validation
  defp categorize_exception(%RuntimeError{}), do: :runtime
  defp categorize_exception(%KeyError{}), do: :configuration
  defp categorize_exception(%MatchError{}), do: :processing
  defp categorize_exception(%FunctionClauseError{}), do: :processing
  defp categorize_exception(_), do: :runtime

  defp categorize_atom_error(:timeout), do: :timeout
  defp categorize_atom_error(:closed), do: :connection
  defp categorize_atom_error(:invalid), do: :validation
  defp categorize_atom_error(:not_found), do: :query
  defp categorize_atom_error(_), do: :unknown

  defp determine_severity(:connection_error), do: :critical
  defp determine_severity(:timeout_error), do: :error
  defp determine_severity(:query_error), do: :warning
  defp determine_severity(:validation_error), do: :warning
  defp determine_severity(:configuration_error), do: :error
  defp determine_severity(_), do: :warning

  defp is_recoverable?(:query_error), do: true
  defp is_recoverable?(:validation_error), do: true
  defp is_recoverable?(:timeout_error), do: true
  defp is_recoverable?(:connection_error), do: false
  defp is_recoverable?(:configuration_error), do: false
  defp is_recoverable?(_), do: false

  defp is_db_error_recoverable?(%Postgrex.Error{postgres: %{code: code}}) do
    code in ["23505", "23503", "23502"]  # Constraint violations are recoverable
  end
  defp is_db_error_recoverable?(_), do: false

  defp format_database_error(%Postgrex.Error{postgres: %{code: "23505", constraint: constraint}}) do
    "Duplicate value violates uniqueness constraint: #{constraint}"
  end

  defp format_database_error(%Postgrex.Error{postgres: %{code: "23503", constraint: constraint}}) do
    "Foreign key constraint violation: #{constraint}"
  end

  defp format_database_error(%Postgrex.Error{postgres: %{code: "23502", column: column}}) do
    "Required field '#{column}' cannot be empty"
  end

  defp format_database_error(%Postgrex.Error{postgres: %{message: message}}) do
    "Database error: #{message}"
  end

  defp format_database_error(%Postgrex.Error{message: message}) do
    "Database error: #{message}"
  end
end