defmodule SelectoComponents.Form.ErrorHandling do
  @moduledoc """
  Error handling utilities for SelectoComponents form operations.

  This module provides a consistent error handling wrapper for form event handlers,
  capturing and categorizing errors to provide meaningful feedback to users while
  preventing application crashes.

  ## Features

  - Wraps operations in try/rescue blocks
  - Categorizes errors for better user feedback
  - Supports both development and production error modes
  - Maintains error history (up to 5 most recent)
  - Integrates with ErrorCategorizer for detailed error analysis

  ## Usage

      defmodule MyLive do
        use SelectoComponents.Form
        import SelectoComponents.Form.ErrorHandling

        def handle_event("some_operation", params, socket) do
          with_error_handling(socket, "some_operation", fn ->
            # Your operation logic here
            {:noreply, updated_socket}
          end)
        end
      end
  """

  alias SelectoComponents.ErrorHandling.ErrorCategorizer
  import SelectoComponents.Form, only: [dev_mode?: 0]

  @doc """
  Wraps an operation in comprehensive error handling.

  Catches all exceptions and errors, categorizes them, and adds them to the
  socket's component_errors list for display to the user.

  ## Parameters

  - `socket` - The LiveView socket
  - `operation_name` - A string identifying the operation (for debugging/logging)
  - `fun` - A zero-arity function containing the operation to execute

  ## Returns

  The result of the function if successful, or a `{:noreply, socket}` tuple
  with error information added to the socket assigns.

  ## Examples

      with_error_handling(socket, "view-apply", fn ->
        socket = process_params(params, socket)
        {:noreply, socket}
      end)
  """
  def with_error_handling(socket, operation_name, fun) do
    try do
      fun.()
    rescue
      e in RuntimeError ->
        handle_component_error(socket, e, operation_name, :runtime_error)

      e in ArgumentError ->
        handle_component_error(socket, e, operation_name, :argument_error)

      e in KeyError ->
        handle_component_error(socket, e, operation_name, :key_error)

      e ->
        handle_component_error(socket, e, operation_name, :unknown_error)
    catch
      :exit, reason ->
        handle_component_error(socket, {:exit, reason}, operation_name, :exit)

      kind, reason ->
        handle_component_error(socket, {kind, reason}, operation_name, :catch)
    end
  end

  @doc """
  Handles a component error by categorizing it and adding it to the socket's error list.

  This function is typically called internally by `with_error_handling/3`, but can
  be used directly if you need custom error handling logic.

  ## Parameters

  - `socket` - The LiveView socket
  - `error` - The error/exception that occurred
  - `operation_name` - A string identifying the operation
  - `error_type` - An atom categorizing the error type

  ## Returns

  A `{:noreply, socket}` tuple with the error added to component_errors.
  """
  def handle_component_error(socket, error, operation_name, error_type) do
    categorized = ErrorCategorizer.categorize(error)

    if dev_mode?() do
      # In development, log additional context for debugging
      # Error type: #{error_type}
    end

    # Add error to component_errors list (keep last 5)
    existing_errors = Map.get(socket.assigns, :component_errors, [])
    new_errors = [Map.put(categorized, :operation, operation_name) | existing_errors] |> Enum.take(5)

    {:noreply, Phoenix.Component.assign(socket, component_errors: new_errors)}
  end
end
