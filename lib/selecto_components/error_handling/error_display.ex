defmodule SelectoComponents.ErrorHandling.ErrorDisplay do
  @moduledoc """
  LiveComponent for displaying categorized errors with appropriate styling
  and recovery suggestions.
  """

  use Phoenix.LiveComponent
  alias SelectoComponents.ErrorHandling.ErrorCategorizer
  alias SelectoComponents.ErrorHandling.ErrorSanitizer
  alias SelectoComponents.ErrorHandling.ErrorRecovery

  def render(assigns) do
    ~H"""
    <div class="selecto-error-container">
      <%= if @errors && length(@errors) > 0 do %>
        <div class="space-y-2">
          <%= for error_info <- @errors do %>
            <.error_card error_info={error_info} dev_mode={@dev_mode} />
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  def error_card(assigns) do
    # Sanitize error info for production
    sanitized_error_info =
      if ErrorSanitizer.production_env?() and not assigns[:dev_mode] do
        sanitize_error_info(assigns.error_info)
      else
        assigns.error_info
      end

    assigns =
      assign(assigns,
        error_info: sanitized_error_info,
        severity_class: severity_to_class(sanitized_error_info.severity),
        icon: severity_to_icon(sanitized_error_info.severity)
      )

    ~H"""
    <div class={"rounded-md p-4 #{@severity_class}"}>
      <div class="flex">
        <div class="flex-shrink-0">
          {Phoenix.HTML.raw(@icon)}
        </div>
        <div class="ml-3 flex-1">
          <h3 class={"text-sm font-medium #{severity_text_class(@error_info.severity)}"}>
            {category_title(@error_info.category)}
            <%= if @error_info.recoverable do %>
              <span class="ml-2 text-xs font-normal">(Recoverable)</span>
            <% end %>
          </h3>

          <div class={"mt-2 text-sm #{severity_text_class(@error_info.severity, :secondary)}"}>
            <%= if ErrorSanitizer.production_env?() and not @dev_mode do %>
              {ErrorSanitizer.user_friendly_message(@error_info.category)}
            <% else %>
              {ErrorCategorizer.format_message(@error_info)}
            <% end %>
          </div>

          <%= if @error_info[:suggestions] && length(@error_info[:suggestions]) > 0 do %>
            <div class={"mt-3 text-sm #{severity_text_class(@error_info.severity, :secondary)}"}>
              <strong>Suggestions:</strong>
              <ul class="mt-1 list-disc list-inside">
                <%= for suggestion <- @error_info[:suggestions] do %>
                  <li>{suggestion}</li>
                <% end %>
              </ul>
            </div>
          <% end %>

          <%!-- Retry button for retryable errors --%>
          <%= if ErrorRecovery.retryable_error?(@error_info.error) do %>
            <div class="mt-3">
              <ErrorRecovery.retry_button
                retryable={true}
                operation="last_operation"
                retry_in_progress={Map.get(assigns, :retry_in_progress, false)}
              />
            </div>
          <% end %>

          <%= if @dev_mode and not ErrorSanitizer.production_env?() do %>
            <.error_details error_info={@error_info} />
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  def error_details(assigns) do
    ~H"""
    <details class="mt-3 text-xs">
      <summary class="cursor-pointer font-medium">Developer Details</summary>
      <div class="mt-2 space-y-1">
        <div><strong>Category:</strong> {@error_info.category}</div>
        <div><strong>Severity:</strong> {@error_info.severity}</div>
        <div><strong>Source:</strong> {@error_info.source}</div>
        <div><strong>Recoverable:</strong> {@error_info.recoverable}</div>

        <%= if is_struct(@error_info.error, Selecto.Error) do %>
          <.selecto_error_details error={@error_info.error} />
        <% else %>
          <div class="mt-2">
            <strong>Raw Error:</strong>
            <pre class="mt-1 whitespace-pre-wrap text-xs overflow-x-auto">
              <%= inspect(@error_info.error, pretty: true, limit: :infinity) %>
            </pre>
          </div>
        <% end %>
      </div>
    </details>
    """
  end

  def selecto_error_details(assigns) do
    # Never show sensitive details in production, even if dev_mode is somehow enabled
    if ErrorSanitizer.production_env?() do
      ~H"""
      <div class="text-xs text-gray-500 italic">
        Detailed error information is not available in production for security reasons.
      </div>
      """
    else
      ~H"""
      <div class="space-y-1">
        <%= if @error.query do %>
          <div>
            <strong>Query:</strong>
            <pre class="mt-1 whitespace-pre-wrap text-xs bg-gray-100 p-2 rounded">
              <%= @error.query %>
            </pre>
          </div>
        <% end %>

        <%= if @error.params && length(@error.params) > 0 do %>
          <div>
            <strong>Parameters:</strong>
            <pre class="mt-1 text-xs">
              <%= inspect(@error.params, pretty: true) %>
            </pre>
          </div>
        <% end %>

        <%= if @error.details && map_size(@error.details) > 0 do %>
          <div>
            <strong>Details:</strong>
            <pre class="mt-1 whitespace-pre-wrap text-xs">
              <%= inspect(@error.details, pretty: true) %>
            </pre>
          </div>
        <% end %>
      </div>
      """
    end
  end

  def mount(socket) do
    {:ok, assign(socket, errors: [], dev_mode: dev_mode?())}
  end

  def update(%{error: error} = assigns, socket) when not is_nil(error) do
    categorized = ErrorCategorizer.categorize(error)
    # Keep last 5 errors
    errors = [categorized | socket.assigns.errors] |> Enum.take(5)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(errors: errors)}
  end

  def update(%{errors: errors} = assigns, socket) when is_list(errors) do
    categorized = Enum.map(errors, &ErrorCategorizer.categorize/1)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(errors: categorized)}
  end

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  def handle_event("clear_error", %{"index" => index}, socket) do
    {index, _} = Integer.parse(index)
    errors = List.delete_at(socket.assigns.errors, index)
    {:noreply, assign(socket, errors: errors)}
  end

  def handle_event("clear_all_errors", _, socket) do
    {:noreply, assign(socket, errors: [])}
  end

  # Helper functions

  defp severity_to_class(:critical), do: "bg-red-100 border border-red-300"
  defp severity_to_class(:error), do: "bg-red-50 border border-red-200"
  defp severity_to_class(:warning), do: "bg-yellow-50 border border-yellow-200"
  defp severity_to_class(_), do: "bg-blue-50 border border-blue-200"

  defp severity_text_class(:critical), do: "text-red-800"
  defp severity_text_class(:error), do: "text-red-700"
  defp severity_text_class(:warning), do: "text-yellow-700"
  defp severity_text_class(_), do: "text-blue-700"

  defp severity_text_class(:critical, :secondary), do: "text-red-700"
  defp severity_text_class(:error, :secondary), do: "text-red-600"
  defp severity_text_class(:warning, :secondary), do: "text-yellow-600"
  defp severity_text_class(_, :secondary), do: "text-blue-600"

  defp severity_to_icon(:critical) do
    """
    <svg class="h-5 w-5 text-red-600" viewBox="0 0 20 20" fill="currentColor">
      <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
    </svg>
    """
  end

  defp severity_to_icon(:error) do
    """
    <svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
      <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
    </svg>
    """
  end

  defp severity_to_icon(:warning) do
    """
    <svg class="h-5 w-5 text-yellow-400" viewBox="0 0 20 20" fill="currentColor">
      <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
    </svg>
    """
  end

  defp severity_to_icon(_) do
    """
    <svg class="h-5 w-5 text-blue-400" viewBox="0 0 20 20" fill="currentColor">
      <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
    </svg>
    """
  end

  defp category_title(:query), do: "Query Error"
  defp category_title(:database), do: "Database Error"
  defp category_title(:validation), do: "Validation Error"
  defp category_title(:configuration), do: "Configuration Error"
  defp category_title(:connection), do: "Connection Error"
  defp category_title(:lifecycle), do: "Component Lifecycle Error"
  defp category_title(:rendering), do: "Rendering Error"
  defp category_title(:timeout), do: "Operation Timeout"
  defp category_title(:processing), do: "Data Processing Error"
  defp category_title(:runtime), do: "Runtime Error"
  defp category_title(_), do: "Error"

  defp sanitize_error_info(error_info) do
    %{
      category: error_info.category,
      severity: error_info.severity,
      recoverable: error_info.recoverable,
      # Hide actual source
      source: "application",
      suggestions: ErrorSanitizer.safe_suggestions(error_info.category),
      # Remove raw error data
      error: nil
    }
  end

  defp dev_mode? do
    # In production, never enable dev_mode regardless of configuration
    if ErrorSanitizer.production_env?() do
      false
    else
      Application.get_env(:selecto_components, :dev_mode, false) ||
        Application.get_env(:selecto_components, :env) == :dev ||
        System.get_env("DEV_MODE") == "true"
    end
  end
end
