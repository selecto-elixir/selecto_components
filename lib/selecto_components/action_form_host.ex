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

  - `:after_apply` - callback invoked as `(socket, result)` before modal result assignment.
    It may return the updated socket or `{socket, reload_metadata}` when the
    host refreshed data after the write.
  - `:authorize` - callback invoked before preview/apply execution. It may be
    arity 4 `(action_id, request, socket, intent)` or arity 3
    `(action_id, request, socket)`. Return `:ok`, `{:ok, metadata}`, or
    `{:error, reason}`.
  - `:format_error` - callback invoked as `(reason)` for host-specific error messages
  """
  def handle_submit(socket, payload, opts) when is_map(payload) do
    with {:ok, payload} <- normalize_submit_payload(payload) do
      action_id = Map.fetch!(payload, :action_id)
      request = Map.fetch!(payload, :request)
      intent = payload |> Map.get(:intent) |> normalize_intent()

      with :ok <- authorize_action(action_id, request, socket, intent, opts),
           {:ok, result} <-
             opts
             |> Keyword.fetch!(intent)
             |> call_action(action_id, request, socket, payload) do
        {socket, metadata} = maybe_after_apply(socket, intent, result, opts)
        {:noreply, assign_result(socket, Atom.to_string(intent), result, metadata)}
      else
        {:error, reason} ->
          {:noreply, assign_error(socket, error_message(reason, opts), reason)}
      end
    else
      {:error, reason} ->
        {:noreply, assign_error(socket, error_message(reason, opts), reason)}
    end
  end

  def handle_submit(socket, _payload, opts) do
    reason = {:invalid_action_form_payload, "expected action form payload map", %{}}
    {:noreply, assign_error(socket, error_message(reason, opts), reason)}
  end

  def assign_result(socket, intent, result, metadata \\ %{}) do
    update_component_assigns(socket, %{
      submitting: nil,
      last_error: nil,
      last_error_details: nil,
      last_result:
        %{
          "status" => "ok",
          "intent" => intent,
          "payload" => QueryContract.json_safe(result)
        }
        |> maybe_put("reload", Map.get(metadata, :reload) || Map.get(metadata, "reload"))
    })
  end

  def assign_error(socket, message, reason \\ nil) do
    update_component_assigns(socket, %{
      submitting: nil,
      last_result: nil,
      last_error: message,
      last_error_details: error_details(reason)
    })
  end

  def update_component_assigns(socket, updates) when is_map(updates) do
    case Map.get(socket.assigns, :modal_detail_data) do
      nil ->
        socket

      modal_detail_data ->
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
  end

  defp normalize_submit_payload(payload) do
    action_id = Map.get(payload, :action_id, Map.get(payload, "action_id"))
    request = Map.get(payload, :request, Map.get(payload, "request"))
    intent = Map.get(payload, :intent, Map.get(payload, "intent"))

    cond do
      not is_binary(action_id) or action_id == "" ->
        {:error,
         {:invalid_action_form_payload, "action form payload is missing action_id",
          %{field: :action_id}}}

      not is_map(request) ->
        {:error,
         {:invalid_action_form_payload, "action form payload is missing request",
          %{field: :request}}}

      true ->
        {:ok,
         payload
         |> QueryContract.json_safe()
         |> Map.put(:action_id, action_id)
         |> Map.put(:request, request)
         |> Map.put(:intent, intent)}
    end
  end

  defp call_action(callback, action_id, request, socket, payload) when is_function(callback, 4),
    do: callback.(action_id, request, socket, payload)

  defp call_action(callback, action_id, request, socket, _payload) when is_function(callback, 3),
    do: callback.(action_id, request, socket)

  defp call_action(callback, action_id, request, _socket, _payload) when is_function(callback, 2),
    do: callback.(action_id, request)

  defp authorize_action(action_id, request, socket, intent, opts) do
    case Keyword.get(opts, :authorize) do
      callback when is_function(callback, 4) ->
        normalize_authorization_result(callback.(action_id, request, socket, intent))

      callback when is_function(callback, 3) ->
        normalize_authorization_result(callback.(action_id, request, socket))

      _callback ->
        :ok
    end
  end

  defp normalize_authorization_result(:ok), do: :ok
  defp normalize_authorization_result({:ok, _metadata}), do: :ok
  defp normalize_authorization_result({:error, reason}), do: {:error, reason}
  defp normalize_authorization_result(false), do: {:error, :capability_denied}
  defp normalize_authorization_result(true), do: :ok
  defp normalize_authorization_result(other), do: {:error, other}

  defp call_after_apply(callback, socket, result) when is_function(callback, 2) do
    case callback.(socket, result) do
      {%Phoenix.LiveView.Socket{} = socket, metadata} when is_map(metadata) ->
        {socket, metadata}

      %Phoenix.LiveView.Socket{} = socket ->
        {socket, %{}}
    end
  end

  defp default_after_apply(socket, _result), do: {socket, %{}}

  defp normalize_intent(intent) when intent in [:apply, "apply"], do: :apply
  defp normalize_intent(_intent), do: :preview

  defp maybe_after_apply(socket, :apply, result, opts) do
    opts
    |> Keyword.get(:after_apply, &default_after_apply/2)
    |> call_after_apply(socket, result)
  end

  defp maybe_after_apply(socket, :preview, _result, _opts), do: {socket, %{}}

  defp error_message(reason, opts) do
    case Keyword.get(opts, :format_error) do
      callback when is_function(callback, 1) -> callback.(reason)
      _ -> default_error_message(reason)
    end
  end

  defp default_error_message({:validation_error, message, _details}), do: message
  defp default_error_message({:capability_denied, message, _details}), do: message
  defp default_error_message({:invalid_request, message}), do: message
  defp default_error_message({:invalid_action_form_payload, message, _details}), do: message
  defp default_error_message(:capability_denied), do: "Action is not allowed."
  defp default_error_message(reason) when is_binary(reason), do: reason
  defp default_error_message(reason), do: inspect(reason)

  defp error_details({:validation_error, message, details}) do
    details
    |> QueryContract.json_safe()
    |> map_or_empty()
    |> Map.put_new("message", message)
    |> Map.put_new("type", "validation_error")
  end

  defp error_details({:capability_denied, message, details}) do
    details
    |> QueryContract.json_safe()
    |> map_or_empty()
    |> Map.put_new("message", message)
    |> Map.put_new("type", "capability_denied")
  end

  defp error_details({:invalid_request, message}) do
    %{"type" => "invalid_request", "message" => message}
  end

  defp error_details({:invalid_action_form_payload, message, details}) do
    details
    |> QueryContract.json_safe()
    |> map_or_empty()
    |> Map.put_new("message", message)
    |> Map.put_new("type", "invalid_action_form_payload")
  end

  defp error_details(:capability_denied) do
    %{"type" => "capability_denied", "message" => "Action is not allowed."}
  end

  defp error_details(nil), do: nil

  defp error_details(reason) do
    %{"type" => "error", "reason" => QueryContract.json_safe(reason)}
  end

  defp map_or_empty(map) when is_map(map), do: map
  defp map_or_empty(_value), do: %{}

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, value) when value == %{}, do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, QueryContract.json_safe(value))
end
