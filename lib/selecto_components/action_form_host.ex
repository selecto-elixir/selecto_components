defmodule SelectoComponents.ActionFormHost do
  @moduledoc """
  Host-side helpers for wiring `SelectoComponents.Modal.ActionFormModal`.

  The modal owns form rendering and request construction. The host still owns
  preview/apply execution, but can delegate the common LiveView state updates to
  this module.
  """

  import Phoenix.Component, only: [assign: 2]

  alias SelectoComponents.QueryContract

  @doc """
  Handles a `{:selecto_action_form_submit, payload}` message.

  Required options:

  - `:preview` - callback invoked as `(action_id, request, socket)`
  - `:apply` - callback invoked as `(action_id, request, socket)`

  Optional options:

  - `:after_apply` - callback invoked as `(socket, result)` before modal result assignment
  - `:format_error` - callback invoked as `(reason)` for host-specific error messages
  """
  def handle_submit(socket, %{intent: "apply"} = payload, opts) do
    action_id = Map.fetch!(payload, :action_id)
    request = Map.fetch!(payload, :request)

    opts
    |> Keyword.fetch!(:apply)
    |> call_action(action_id, request, socket)
    |> case do
      {:ok, result} ->
        socket =
          opts
          |> Keyword.get(:after_apply, &default_after_apply/2)
          |> call_after_apply(socket, result)

        {:noreply, assign_result(socket, "apply", result)}

      {:error, reason} ->
        {:noreply, assign_error(socket, error_message(reason, opts))}
    end
  end

  def handle_submit(socket, payload, opts) when is_map(payload) do
    action_id = Map.fetch!(payload, :action_id)
    request = Map.fetch!(payload, :request)

    opts
    |> Keyword.fetch!(:preview)
    |> call_action(action_id, request, socket)
    |> case do
      {:ok, result} ->
        {:noreply, assign_result(socket, "preview", result)}

      {:error, reason} ->
        {:noreply, assign_error(socket, error_message(reason, opts))}
    end
  end

  def assign_result(socket, intent, result) do
    update_component_assigns(socket, %{
      submitting: nil,
      last_error: nil,
      last_result: %{
        "intent" => intent,
        "payload" => QueryContract.json_safe(result)
      }
    })
  end

  def assign_error(socket, message) do
    update_component_assigns(socket, %{
      submitting: nil,
      last_result: nil,
      last_error: message
    })
  end

  def update_component_assigns(socket, updates) when is_map(updates) do
    modal_detail_data = Map.get(socket.assigns, :modal_detail_data, %{})
    component_assigns = Map.get(modal_detail_data, :component_assigns, %{})

    assign(socket,
      modal_detail_data:
        Map.put(
          modal_detail_data,
          :component_assigns,
          Map.merge(component_assigns, updates)
        )
    )
  end

  defp call_action(callback, action_id, request, socket) when is_function(callback, 3),
    do: callback.(action_id, request, socket)

  defp call_action(callback, action_id, request, _socket) when is_function(callback, 2),
    do: callback.(action_id, request)

  defp call_after_apply(callback, socket, result) when is_function(callback, 2),
    do: callback.(socket, result)

  defp default_after_apply(socket, _result), do: socket

  defp error_message(reason, opts) do
    case Keyword.get(opts, :format_error) do
      callback when is_function(callback, 1) -> callback.(reason)
      _ -> default_error_message(reason)
    end
  end

  defp default_error_message({:validation_error, message, _details}), do: message
  defp default_error_message({:invalid_request, message}), do: message
  defp default_error_message(reason) when is_binary(reason), do: reason
  defp default_error_message(reason), do: inspect(reason)
end
