defmodule SelectoComponentsErrorHandlingTest do
  use ExUnit.Case, async: true
  alias SelectoComponents.ErrorHandling.ErrorCategorizer

  describe "ErrorCategorizer" do
    test "categorizes Selecto.Error correctly" do
      error = %Selecto.Error{
        type: :query_error,
        message: "Column not found",
        query: "SELECT invalid FROM users",
        params: [],
        details: %{column: "invalid"}
      }

      result = ErrorCategorizer.categorize(error)

      assert result.category == :query
      assert result.severity == :warning
      assert result.recoverable == true
      assert result.source == :selecto
      assert result.error == error
    end

    test "categorizes connection errors as critical" do
      error = %Selecto.Error{
        type: :connection_error,
        message: "Database unreachable",
        details: %{host: "localhost", port: 5432}
      }

      result = ErrorCategorizer.categorize(error)

      assert result.category == :connection
      assert result.severity == :critical
      assert result.recoverable == false
      assert result.source == :selecto
    end

    test "categorizes validation errors correctly" do
      error = %Selecto.Error{
        type: :validation_error,
        message: "Invalid filter value",
        details: %{field: "age", value: "not_a_number"}
      }

      result = ErrorCategorizer.categorize(error)

      assert result.category == :validation
      assert result.severity == :warning
      assert result.recoverable == true
      assert result.source == :selecto
    end

    test "categorizes configuration errors correctly" do
      error = %Selecto.Error{
        type: :configuration_error,
        message: "Invalid domain configuration",
        details: %{domain: "Unknown"}
      }

      result = ErrorCategorizer.categorize(error)

      assert result.category == :configuration
      assert result.severity == :error
      assert result.recoverable == false
      assert result.source == :selecto
    end

    test "categorizes field resolution errors correctly" do
      error = %Selecto.Error{
        type: :field_resolution_error,
        message: "Could not resolve field",
        details: %{field_reference: "user.invalid_field"}
      }

      result = ErrorCategorizer.categorize(error)

      assert result.category == :configuration
      assert result.severity == :warning
      assert result.recoverable == false
      assert result.source == :selecto
    end

    test "categorizes transformation errors correctly" do
      error = %Selecto.Error{
        type: :transformation_error,
        message: "Failed to transform output",
        details: %{format: "json", reason: "invalid structure"}
      }

      result = ErrorCategorizer.categorize(error)

      assert result.category == :rendering
      assert result.severity == :warning
      assert result.recoverable == false
      assert result.source == :selecto
    end

    test "categorizes generic exceptions" do
      error = %RuntimeError{message: "Something went wrong"}

      result = ErrorCategorizer.categorize(error)

      assert result.category == :runtime
      assert result.severity == :error
      assert result.recoverable == false
      assert result.source == :exception
    end

    test "categorizes argument errors as validation" do
      error = %ArgumentError{message: "Invalid argument"}

      result = ErrorCategorizer.categorize(error)

      assert result.category == :validation
      assert result.severity == :error
      assert result.recoverable == false
      assert result.source == :exception
    end

    test "categorizes exit signals" do
      error = {:exit, :timeout}

      result = ErrorCategorizer.categorize(error)

      assert result.category == :connection
      assert result.severity == :critical
      assert result.recoverable == false
      assert result.source == :connection
    end

    test "categorizes string errors" do
      error = {:error, "Something failed"}

      result = ErrorCategorizer.categorize(error)

      assert result.category == :validation
      assert result.severity == :warning
      assert result.recoverable == true
      assert result.source == :validation
    end

    test "categorizes atom errors" do
      error = {:error, :timeout}

      result = ErrorCategorizer.categorize(error)

      assert result.category == :timeout
      assert result.severity == :warning
      assert result.recoverable == true
      assert result.source == :system
    end

    test "provides recovery suggestions for different error types" do
      query_error = %{category: :query, recoverable: true}
      assert ErrorCategorizer.recovery_suggestion(query_error) =~ "filters"

      db_error = %{category: :database, recoverable: true}
      assert ErrorCategorizer.recovery_suggestion(db_error) =~ "try again"

      validation_error = %{category: :validation}
      assert ErrorCategorizer.recovery_suggestion(validation_error) =~ "check your input"

      config_error = %{category: :configuration}
      assert ErrorCategorizer.recovery_suggestion(config_error) =~ "domain setup"

      connection_error = %{category: :connection}
      assert ErrorCategorizer.recovery_suggestion(connection_error) =~ "refresh"

      lifecycle_error = %{category: :lifecycle}
      assert ErrorCategorizer.recovery_suggestion(lifecycle_error) =~ "refreshing the view"

      unknown_error = %{category: :unknown}
      assert ErrorCategorizer.recovery_suggestion(unknown_error) == nil
    end

    test "formats error messages appropriately" do
      query_error = %{
        category: :query,
        error: %Selecto.Error{
          type: :query_error,
          message: "Invalid column"
        }
      }

      assert ErrorCategorizer.format_message(query_error) =~ "Query execution failed"

      validation_error = %{
        category: :validation,
        error: %{message: "Field required"}
      }

      assert ErrorCategorizer.format_message(validation_error) =~ "Validation failed"

      config_error = %{
        category: :configuration,
        error: %{message: "Invalid setup"}
      }

      assert ErrorCategorizer.format_message(config_error) =~ "Configuration error"

      lifecycle_error = %{
        category: :lifecycle,
        error: %{message: "State mismatch"}
      }

      assert ErrorCategorizer.format_message(lifecycle_error) =~ "Component lifecycle error"

      rendering_error = %{
        category: :rendering,
        error: %{message: "Template error"}
      }

      assert ErrorCategorizer.format_message(rendering_error) =~ "Rendering error"

      connection_error = %{
        category: :connection,
        error: %{message: "Database down"}
      }

      assert ErrorCategorizer.format_message(connection_error) =~ "Connection lost"
    end
  end
end
