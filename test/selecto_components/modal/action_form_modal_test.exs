defmodule SelectoComponents.Modal.ActionFormModalTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.Modal.ActionFormModal

  test "submit_action_form emits a preview request payload" do
    socket = socket(action(), %{id: 42})

    assert {:noreply, updated_socket} =
             ActionFormModal.handle_event(
               "submit_action_form",
               %{"intent" => "preview", "inputs" => %{"note" => "Ready"}},
               socket
             )

    assert updated_socket.assigns.submitting == "preview"
    assert updated_socket.assigns.last_request["dry_run"] == true

    assert_receive {:selecto_action_form_submit, payload}
    assert payload.intent == "preview"
    assert payload.action_id == "archive"
    assert payload.endpoint == %{"href" => "/actions/archive/preview", "method" => "POST"}

    assert payload.request == %{
             "action" => "archive",
             "target" => %{"id" => 42},
             "inputs" => %{"note" => "Ready"},
             "dry_run" => true,
             "confirmed" => false
           }
  end

  test "submit_action_form emits a confirmed apply request payload" do
    assert {:noreply, _socket} =
             ActionFormModal.handle_event(
               "submit_action_form",
               %{"intent" => "apply", "confirmed" => "true"},
               socket(action(), %{id: 42})
             )

    assert_receive {:selecto_action_form_submit, payload}
    assert payload.intent == "apply"
    assert payload.endpoint == %{"href" => "/actions/archive/apply", "method" => "POST"}
    assert payload.request["confirmed"] == true
    assert payload.request["dry_run"] == false
  end

  defp socket(action, target) do
    %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        action: action,
        target: target,
        record: %{"id" => 42},
        inputs: Map.fetch!(action, "inputs")
      }
    }
  end

  defp action do
    %{
      "id" => "archive",
      "label" => "Archive",
      "scope" => "row",
      "operation" => "update",
      "inputs" => [%{"id" => "note", "type" => "string"}],
      "confirmation" => %{"required" => true, "message" => "Archive?"},
      "endpoints" => %{
        "preview" => %{"href" => "/actions/archive/preview", "method" => "POST"},
        "apply" => %{"href" => "/actions/archive/apply", "method" => "POST"}
      }
    }
  end
end
