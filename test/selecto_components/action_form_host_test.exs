defmodule SelectoComponents.ActionFormHostTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.ActionFormHost

  test "handle_submit stores preview results in a stable result envelope" do
    socket = socket()

    assert {:noreply, updated_socket} =
             ActionFormHost.handle_submit(socket, payload("preview"),
               preview: fn action_id, request, _socket ->
                 {:ok, %{action: action_id, changes: %{state: "archived"}, request: request}}
               end,
               apply: fn _action_id, _request, _socket -> {:ok, %{}} end
             )

    result = updated_socket.assigns.modal_detail_data.component_assigns.last_result

    assert result["status"] == "ok"
    assert result["intent"] == "preview"
    assert result["payload"]["action"] == "archive"
    refute Map.has_key?(result, "reload")
  end

  test "handle_submit accepts host reload metadata from after_apply" do
    socket = socket()

    assert {:noreply, updated_socket} =
             ActionFormHost.handle_submit(socket, payload("apply"),
               preview: fn _action_id, _request, _socket -> {:ok, %{}} end,
               apply: fn action_id, _request, _socket -> {:ok, %{action: action_id}} end,
               after_apply: fn socket, _result ->
                 {socket,
                  %{
                    reload: %{
                      status: "refreshed",
                      surface: "selecto_results",
                      message: "The host reran the current query."
                    }
                  }}
               end
             )

    result = updated_socket.assigns.modal_detail_data.component_assigns.last_result

    assert result["intent"] == "apply"

    assert result["reload"] == %{
             "message" => "The host reran the current query.",
             "status" => "refreshed",
             "surface" => "selecto_results"
           }
  end

  test "handle_submit still allows after_apply to close the modal before result assignment" do
    assert {:noreply, updated_socket} =
             ActionFormHost.handle_submit(socket(), payload("apply"),
               preview: fn _action_id, _request, _socket -> {:ok, %{}} end,
               apply: fn _action_id, _request, _socket ->
                 {:ok, %{"result" => %{"mode" => "execute"}}}
               end,
               after_apply: fn socket, _result ->
                 Phoenix.Component.assign(socket,
                   show_detail_modal: false,
                   modal_detail_data: nil
                 )
               end
             )

    assert updated_socket.assigns.show_detail_modal == false
    assert updated_socket.assigns.modal_detail_data == nil
  end

  test "handle_submit accepts atom intents for compatibility" do
    assert {:noreply, updated_socket} =
             ActionFormHost.handle_submit(socket(), payload(:apply),
               preview: fn _action_id, _request, _socket -> {:ok, %{}} end,
               apply: fn action_id, request, _socket ->
                 assert action_id == "archive"
                 assert request == %{"action" => "archive", "target" => %{"id" => 42}}
                 {:ok, %{"result" => %{"mode" => "execute"}}}
               end
             )

    assert updated_socket.assigns.modal_detail_data.component_assigns.last_result["intent"] ==
             "apply"
  end

  test "handle_submit accepts string-keyed payloads" do
    assert {:noreply, updated_socket} =
             ActionFormHost.handle_submit(socket(), string_payload("preview"),
               preview: fn action_id, request, _socket ->
                 assert action_id == "archive"
                 assert request == %{"action" => "archive", "target" => %{"id" => 42}}
                 {:ok, %{action: action_id}}
               end,
               apply: fn _action_id, _request, _socket -> {:ok, %{}} end
             )

    assert updated_socket.assigns.modal_detail_data.component_assigns.last_result["intent"] ==
             "preview"
  end

  test "handle_submit can pass normalized submit metadata to action callbacks" do
    assert {:noreply, updated_socket} =
             ActionFormHost.handle_submit(socket(), payload("preview"),
               preview: fn action_id, request, _socket, payload ->
                 assert action_id == "archive"
                 assert request["target"] == %{"id" => 42}
                 assert payload.action_id == "archive"
                 assert payload.intent == "preview"

                 {:ok,
                  %{
                    action: action_id,
                    target: payload["target"],
                    endpoint: get_in(payload, ["endpoints", "preview", "href"])
                  }}
               end,
               apply: fn _action_id, _request, _socket -> {:ok, %{}} end
             )

    result = updated_socket.assigns.modal_detail_data.component_assigns.last_result
    assert result["payload"]["target"] == %{"id" => 42}
    assert result["payload"]["endpoint"] == "/actions/archive/preview"
  end

  test "handle_submit reports malformed submit payloads without raising" do
    assert {:noreply, updated_socket} =
             ActionFormHost.handle_submit(socket(), %{"intent" => "preview"},
               preview: fn _action_id, _request, _socket ->
                 flunk("preview callback should not run")
               end,
               apply: fn _action_id, _request, _socket -> {:ok, %{}} end
             )

    component_assigns = updated_socket.assigns.modal_detail_data.component_assigns

    assert component_assigns.last_error == "action form payload is missing action_id"

    assert component_assigns.last_error_details == %{
             "field" => "action_id",
             "message" => "action form payload is missing action_id",
             "type" => "invalid_action_form_payload"
           }
  end

  test "handle_submit preserves machine-readable error details for the component" do
    socket = socket()

    assert {:noreply, updated_socket} =
             ActionFormHost.handle_submit(socket, payload("apply"),
               preview: fn _action_id, _request, _socket -> {:ok, %{}} end,
               apply: fn _action_id, _request, _socket ->
                 {:error,
                  {:validation_error, "Action precondition failed.",
                   %{code: :action_precondition_failed, state: "archived"}}}
               end
             )

    component_assigns = updated_socket.assigns.modal_detail_data.component_assigns

    assert component_assigns.last_error == "Action precondition failed."

    assert component_assigns.last_error_details == %{
             "code" => "action_precondition_failed",
             "message" => "Action precondition failed.",
             "state" => "archived",
             "type" => "validation_error"
           }

    assert component_assigns.last_result == nil
  end

  test "handle_submit authorizes before executing preview or apply callbacks" do
    assert {:noreply, updated_socket} =
             ActionFormHost.handle_submit(socket(), payload("apply"),
               authorize: fn action_id, request, _socket, intent ->
                 assert action_id == "archive"
                 assert request["target"] == %{"id" => 42}
                 assert intent == :apply

                 {:error,
                  {:capability_denied, "Managers only.",
                   %{code: :manager_required, capability: "work_items.archive"}}}
               end,
               preview: fn _action_id, _request, _socket ->
                 flunk("preview callback should not run")
               end,
               apply: fn _action_id, _request, _socket ->
                 flunk("apply callback should not run")
               end
             )

    component_assigns = updated_socket.assigns.modal_detail_data.component_assigns
    assert component_assigns.submitting == nil
    assert component_assigns.last_result == nil
    assert component_assigns.last_error == "Managers only."

    assert component_assigns.last_error_details == %{
             "capability" => "work_items.archive",
             "code" => "manager_required",
             "message" => "Managers only.",
             "type" => "capability_denied"
           }
  end

  test "handle_submit keeps host-formatted error messages" do
    assert {:noreply, updated_socket} =
             ActionFormHost.handle_submit(socket(), payload("preview"),
               preview: fn _action_id, _request, _socket ->
                 {:error, {:validation_error, "Required", %{}}}
               end,
               apply: fn _action_id, _request, _socket -> {:ok, %{}} end,
               format_error: fn {:validation_error, message, _details} ->
                 "Formatted: #{message}"
               end
             )

    component_assigns = updated_socket.assigns.modal_detail_data.component_assigns
    assert component_assigns.last_result == nil
    assert component_assigns.last_error == "Formatted: Required"
  end

  defp socket do
    %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        modal_detail_data: %{component_assigns: %{submitting: "apply"}}
      }
    }
  end

  defp payload(intent) do
    %{
      intent: intent,
      action_id: "archive",
      request: %{"action" => "archive", "target" => %{"id" => 42}},
      target: %{"id" => 42},
      endpoints: %{
        "preview" => %{"href" => "/actions/archive/preview"},
        "apply" => %{"href" => "/actions/archive/apply"}
      }
    }
  end

  defp string_payload(intent) do
    %{
      "intent" => intent,
      "action_id" => "archive",
      "request" => %{"action" => "archive", "target" => %{"id" => 42}}
    }
  end
end
