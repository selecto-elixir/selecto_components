defmodule SelectoComponents.ActionFormHostTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.ActionFormHost

  test "handle_submit delegates preview and stores component result" do
    socket = socket()

    assert {:noreply, updated_socket} =
             ActionFormHost.handle_submit(
               socket,
               %{intent: "preview", action_id: "archive", request: %{"action" => "archive"}},
               preview: fn action_id, request, received_socket ->
                 assert action_id == "archive"
                 assert request == %{"action" => "archive"}
                 assert received_socket == socket
                 {:ok, %{"action" => action_id, "changes" => %{"state" => "archived"}}}
               end,
               apply: fn _, _, _ -> flunk("apply callback should not run") end
             )

    component_assigns = updated_socket.assigns.modal_detail_data.component_assigns
    assert component_assigns.submitting == nil
    assert component_assigns.last_error == nil
    assert component_assigns.last_result["intent"] == "preview"
    assert component_assigns.last_result["payload"]["changes"] == %{"state" => "archived"}
  end

  test "handle_submit delegates apply, runs after_apply, and stores component result" do
    assert {:noreply, updated_socket} =
             ActionFormHost.handle_submit(
               socket(),
               %{intent: "apply", action_id: "archive", request: %{"action" => "archive"}},
               preview: fn _, _, _ -> flunk("preview callback should not run") end,
               apply: fn _action_id, _request, _socket ->
                 {:ok, %{"result" => %{"mode" => "execute"}}}
               end,
               after_apply: fn socket, _result ->
                 Phoenix.Component.assign(socket, applied_view: "detail")
               end
             )

    assert updated_socket.assigns.applied_view == "detail"

    assert updated_socket.assigns.modal_detail_data.component_assigns.last_result["intent"] ==
             "apply"
  end

  test "handle_submit accepts atom intents for compatibility" do
    assert {:noreply, updated_socket} =
             ActionFormHost.handle_submit(
               socket(),
               %{intent: :apply, action_id: "archive", request: %{"action" => "archive"}},
               preview: fn _, _, _ -> flunk("preview callback should not run") end,
               apply: fn action_id, request, _socket ->
                 assert action_id == "archive"
                 assert request == %{"action" => "archive"}
                 {:ok, %{"result" => %{"mode" => "execute"}}}
               end
             )

    assert updated_socket.assigns.modal_detail_data.component_assigns.last_result["intent"] ==
             "apply"
  end

  test "handle_submit stores formatted errors" do
    assert {:noreply, updated_socket} =
             ActionFormHost.handle_submit(
               socket(),
               %{intent: "preview", action_id: "archive", request: %{}},
               preview: fn _action_id, _request, _socket ->
                 {:error, {:validation_error, "Required", %{}}}
               end,
               apply: fn _, _, _ -> :unused end,
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
        modal_detail_data: %{component_assigns: %{submitting: "preview"}}
      }
    }
  end
end
