defmodule SelectoComponents.ErrorHandling.ErrorRecovery do
  @moduledoc """
  Error recovery mechanisms with retry logic and exponential backoff.
  """
  
  use Phoenix.Component
  import Phoenix.LiveView
  
  @max_retry_attempts 3
  @initial_backoff_ms 1000
  @max_backoff_ms 16000
  @backoff_multiplier 2
  
  # Error types that are retryable
  @retryable_errors [
    :timeout,
    :connection_error,
    :network_error,
    :temporary_failure,
    :service_unavailable,
    :database_locked,
    :rate_limited
  ]
  
  @doc """
  Determines if an error is retryable based on its type.
  """
  def retryable_error?(error) when is_map(error) do
    error_type = Map.get(error, :type) || classify_error(error)
    error_type in @retryable_errors
  end
  
  def retryable_error?(_), do: false
  
  @doc """
  Classifies an error based on its message or metadata.
  """
  def classify_error(error) when is_map(error) do
    message = Map.get(error, :message, "") |> to_string() |> String.downcase()
    
    cond do
      String.contains?(message, ["timeout", "timed out"]) -> :timeout
      String.contains?(message, ["connection", "connect"]) -> :connection_error
      String.contains?(message, ["network", "unreachable"]) -> :network_error
      String.contains?(message, ["temporary", "transient"]) -> :temporary_failure
      String.contains?(message, ["503", "service unavailable"]) -> :service_unavailable
      String.contains?(message, ["database is locked", "db locked"]) -> :database_locked
      String.contains?(message, ["rate limit", "too many requests"]) -> :rate_limited
      true -> :unknown
    end
  end
  
  def classify_error(_), do: :unknown
  
  @doc """
  Initializes retry state for a socket.
  """
  def init_retry_state(socket) do
    assign(socket,
      retry_count: 0,
      retry_timer: nil,
      retry_in_progress: false,
      last_error: nil,
      preserved_state: nil
    )
  end
  
  @doc """
  Attempts to retry an operation with exponential backoff.
  """
  def retry_operation(socket, operation_fn, opts \\ []) do
    max_attempts = Keyword.get(opts, :max_attempts, @max_retry_attempts)
    retry_count = socket.assigns[:retry_count] || 0
    
    if retry_count >= max_attempts do
      socket
      |> assign(retry_exhausted: true)
      |> push_event("retry_exhausted", %{
        attempts: retry_count,
        error: socket.assigns[:last_error]
      })
    else
      backoff = calculate_backoff(retry_count)
      
      socket
      |> assign(
        retry_count: retry_count + 1,
        retry_in_progress: true,
        next_retry_in: backoff
      )
      |> schedule_retry(operation_fn, backoff)
    end
  end
  
  @doc """
  Calculates exponential backoff delay.
  """
  def calculate_backoff(retry_count) do
    delay = @initial_backoff_ms * :math.pow(@backoff_multiplier, retry_count)
    min(round(delay), @max_backoff_ms)
  end
  
  @doc """
  Schedules a retry after the specified delay.
  """
  def schedule_retry(socket, operation_fn, delay_ms) do
    # Cancel any existing retry timer
    if socket.assigns[:retry_timer] do
      Process.cancel_timer(socket.assigns.retry_timer)
    end
    
    timer_ref = Process.send_after(self(), {:execute_retry, operation_fn}, delay_ms)
    
    assign(socket, retry_timer: timer_ref)
  end
  
  @doc """
  Preserves current form state for retry.
  """
  def preserve_state(socket, state_to_preserve) do
    assign(socket, preserved_state: state_to_preserve)
  end
  
  @doc """
  Restores preserved state after successful retry.
  """
  def restore_state(socket) do
    case socket.assigns[:preserved_state] do
      nil -> socket
      state -> 
        socket
        |> assign(state)
        |> assign(preserved_state: nil)
    end
  end
  
  @doc """
  Resets retry state after successful operation.
  """
  def reset_retry_state(socket) do
    # Cancel any pending retry timer
    if socket.assigns[:retry_timer] do
      Process.cancel_timer(socket.assigns.retry_timer)
    end
    
    assign(socket,
      retry_count: 0,
      retry_timer: nil,
      retry_in_progress: false,
      retry_exhausted: false,
      last_error: nil,
      next_retry_in: nil
    )
  end
  
  @doc """
  Component for displaying retry status and controls.
  """
  def retry_status(assigns) do
    ~H"""
    <div :if={@retry_in_progress || @retry_exhausted} class="retry-status">
      <%= if @retry_in_progress do %>
        <div class="flex items-center space-x-3 p-3 bg-yellow-50 border border-yellow-200 rounded-lg">
          <div class="animate-spin rounded-full h-5 w-5 border-b-2 border-yellow-600"></div>
          <div class="flex-1">
            <p class="text-sm font-medium text-yellow-800">
              Retrying operation...
            </p>
            <p class="text-xs text-yellow-600 mt-1">
              Attempt <%= @retry_count %> of <%= @max_attempts %>
              <%= if @next_retry_in do %>
                • Next retry in <%= format_duration(@next_retry_in) %>
              <% end %>
            </p>
          </div>
          
          <button
            type="button"
            phx-click="cancel_retry"
            class="px-3 py-1 text-sm bg-white border border-yellow-300 text-yellow-700 rounded-md hover:bg-yellow-50"
          >
            Cancel
          </button>
        </div>
      <% end %>
      
      <%= if @retry_exhausted do %>
        <div class="p-4 bg-red-50 border border-red-200 rounded-lg">
          <div class="flex items-start">
            <svg class="w-5 h-5 text-red-400 mt-0.5" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
            </svg>
            
            <div class="ml-3 flex-1">
              <h3 class="text-sm font-medium text-red-800">
                Operation failed after <%= @retry_count %> attempts
              </h3>
              <p class="mt-1 text-sm text-red-700">
                The operation could not be completed. Please try again later or contact support if the problem persists.
              </p>
              
              <div class="mt-3 flex space-x-3">
                <button
                  type="button"
                  phx-click="retry_now"
                  class="px-3 py-1.5 bg-red-600 text-white text-sm font-medium rounded-md hover:bg-red-700"
                >
                  Try Again
                </button>
                
                <button
                  type="button"
                  phx-click="dismiss_error"
                  class="px-3 py-1.5 bg-white border border-gray-300 text-gray-700 text-sm font-medium rounded-md hover:bg-gray-50"
                >
                  Dismiss
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
  
  @doc """
  Component for inline retry button in error displays.
  """
  def retry_button(assigns) do
    ~H"""
    <button
      :if={@retryable}
      type="button"
      phx-click="retry_operation"
      phx-value-operation={@operation}
      disabled={@retry_in_progress}
      class={"inline-flex items-center px-3 py-1.5 border text-sm font-medium rounded-md #{
        if @retry_in_progress do
          "border-gray-300 text-gray-400 bg-gray-100 cursor-not-allowed"
        else
          "border-transparent text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
        end
      }"}
    >
      <%= if @retry_in_progress do %>
        <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-gray-400 mr-2"></div>
        Retrying...
      <% else %>
        <svg class="w-4 h-4 mr-1.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
        </svg>
        Retry
      <% end %>
    </button>
    """
  end
  
  # Helper functions
  
  defp format_duration(ms) when ms >= 1000 do
    seconds = div(ms, 1000)
    "#{seconds}s"
  end
  
  defp format_duration(ms), do: "#{ms}ms"
  
  @doc """
  Handle retry-related messages in the parent LiveView.
  """
  def handle_retry_message({:execute_retry, operation_fn}, socket) do
    socket
    |> assign(retry_in_progress: true)
    |> operation_fn.()
  end
  
  def handle_retry_message({:retry_succeeded, result}, socket) do
    socket
    |> reset_retry_state()
    |> restore_state()
    |> assign(result: result)
  end
  
  def handle_retry_message({:retry_failed, error}, socket) do
    if retryable_error?(error) do
      socket
      |> assign(last_error: error)
      |> retry_operation(socket.assigns[:retry_operation_fn])
    else
      socket
      |> assign(
        last_error: error,
        retry_exhausted: true,
        retry_in_progress: false
      )
    end
  end
end