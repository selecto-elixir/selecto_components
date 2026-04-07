defmodule SelectoComponentsErrorHandlingTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.ErrorHandling.ErrorBuilder
  alias SelectoComponents.ErrorHandling.ErrorCategorizer
  alias SelectoComponents.Form

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

      assert result.stage == :db_execute
      assert result.category == :query
      assert result.severity == :warning
      assert result.recoverable == true
      assert result.summary == "Query error while executing the query"
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

      assert result.stage == :db_execute
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

      assert result.stage == :input
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

      assert result.stage == :configuration
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

      assert result.stage == :configuration
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

      assert result.stage == :result_process
      assert result.category == :processing
      assert result.severity == :warning
      assert result.recoverable == false
      assert result.source == :selecto
    end

    test "categorizes generic exceptions" do
      error = %RuntimeError{message: "Something went wrong"}

      result = ErrorCategorizer.categorize(error)

      assert result.stage == :unknown
      assert result.category == :runtime
      assert result.severity == :error
      assert result.recoverable == false
      assert result.source == :exception
    end

    test "categorizes argument errors as validation" do
      error = %ArgumentError{message: "Invalid argument"}

      result = ErrorCategorizer.categorize(error)

      assert result.stage == :input
      assert result.category == :validation
      assert result.severity == :warning
      assert result.recoverable == true
      assert result.source == :exception
    end

    test "categorizes exit signals" do
      error = {:exit, :timeout}

      result = ErrorCategorizer.categorize(error)

      assert result.stage == :timeout
      assert result.category == :timeout
      assert result.severity == :error
      assert result.recoverable == true
      assert result.source == :connection
    end

    test "categorizes string errors" do
      error = {:error, "Something failed"}

      result = ErrorCategorizer.categorize(error)

      assert result.stage == :unknown
      assert result.category == :validation
      assert result.severity == :warning
      assert result.recoverable == true
      assert result.source == :validation
    end

    test "categorizes atom errors" do
      error = {:error, :timeout}

      result = ErrorCategorizer.categorize(error)

      assert result.stage == :timeout
      assert result.category == :timeout
      assert result.severity == :error
      assert result.recoverable == true
      assert result.source == :system
    end

    test "preserves explicitly provided stage metadata" do
      error = %RuntimeError{message: "boom"}

      result = ErrorCategorizer.categorize(error, stage: :render, operation: "view-apply")

      assert result.stage == :render
      assert result.summary == "Runtime error while rendering the view"
      assert result.operation == "view-apply"
    end

    test "provides recovery suggestions for different error types" do
      query_error = %{category: :query, stage: :query_build, recoverable: true}
      assert ErrorCategorizer.recovery_suggestion(query_error) =~ "filters"

      db_error = %{category: :database, stage: :db_execute, recoverable: true}
      assert ErrorCategorizer.recovery_suggestion(db_error) =~ "query setup"

      validation_error = %{category: :validation, stage: :input}
      assert ErrorCategorizer.recovery_suggestion(validation_error) =~ "check your input"

      config_error = %{category: :configuration, stage: :configuration}
      assert ErrorCategorizer.recovery_suggestion(config_error) =~ "view configuration"

      connection_error = %{category: :connection, stage: :db_execute}
      assert ErrorCategorizer.recovery_suggestion(connection_error) =~ "Refresh"

      lifecycle_error = %{category: :lifecycle, stage: :lifecycle}
      assert ErrorCategorizer.recovery_suggestion(lifecycle_error) == nil

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
        stage: :input,
        category: :validation,
        error: %{message: "Field required"}
      }

      assert ErrorCategorizer.format_message(validation_error) =~ "Field required"

      config_error = %{
        stage: :configuration,
        category: :configuration,
        error: %{message: "Invalid setup"}
      }

      assert ErrorCategorizer.format_message(config_error) =~ "Invalid setup"

      lifecycle_error = %{
        stage: :lifecycle,
        category: :lifecycle,
        error: %{message: "State mismatch"}
      }

      assert ErrorCategorizer.format_message(lifecycle_error) =~ "State mismatch"

      rendering_error = %{
        stage: :render,
        category: :rendering,
        error: %{message: "Template error"}
      }

      assert ErrorCategorizer.format_message(rendering_error) =~ "Template error"

      connection_error = %{
        stage: :db_execute,
        category: :connection,
        error: %{message: "Database down"}
      }

      assert ErrorCategorizer.format_message(connection_error) =~ "Database down"
    end
  end

  describe "ErrorBuilder" do
    test "builds a stage-aware summary and default suggestion" do
      result =
        ErrorBuilder.build(%{message: "bad sql"},
          stage: :sql_compile,
          category: :query,
          code: :sql_compile_failed
        )

      assert result.summary == "Query error while generating SQL"
      assert result.user_message == "bad sql"
      assert result.suggestion =~ "grouping"
      assert result.suggestions == [result.suggestion]
    end

    test "infers stage from operation name" do
      result =
        ErrorBuilder.build(%RuntimeError{message: "export broke"},
          operation: "export_data"
        )

      assert result.stage == :export
      assert result.summary == "Runtime error while creating the export"
    end

    test "form error sanitization returns normalized errors with explicit stage metadata" do
      error = Form.build_selecto_error(:query_error, "broken query", %{sql: "select * from nope"})

      result =
        Form.sanitize_error_for_environment(error,
          stage: :sql_compile,
          code: :sql_compile_failed,
          operation: "view-apply",
          view_mode: "aggregate"
        )

      assert result.stage == :sql_compile
      assert result.code == :sql_compile_failed
      assert result.summary == "Query error while generating SQL"
      assert result.operation == "view-apply"
      assert result.view_mode == "aggregate"
    end
  end
end
