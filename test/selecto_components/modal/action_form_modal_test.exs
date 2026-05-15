defmodule SelectoComponents.Modal.ActionFormModalTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

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

  test "render disables further submissions after apply succeeds" do
    html =
      render_component(ActionFormModal, %{
        id: "action-form",
        action: action(),
        target: %{id: 42},
        record: %{"id" => 42},
        confirmed: true,
        last_result: %{"intent" => "apply", "payload" => %{"action" => "archive"}}
      })

    assert html =~ ~s(data-selecto-action-form-applied)
    assert html =~ ~r/value="preview"[\s\S]*disabled/
    assert html =~ ~r/value="apply"[\s\S]*disabled/
  end

  test "render summarizes preview and apply results" do
    preview_html =
      render_component(ActionFormModal, %{
        id: "action-form",
        action: action(),
        target: %{id: 42},
        record: %{"id" => 42},
        last_result: %{
          "intent" => "preview",
          "payload" => %{"action" => "archive", "changes" => %{"state" => "archived"}}
        }
      })

    assert preview_html =~ ~s(data-selecto-action-form-result-summary)
    assert preview_html =~ ~s(data-selecto-action-form-result-summary-item="action")
    assert preview_html =~ ~s(data-selecto-action-form-result-summary-item="changes")
    assert preview_html =~ ~s({&quot;state&quot;:&quot;archived&quot;})

    apply_html =
      render_component(ActionFormModal, %{
        id: "action-form",
        action: action(),
        target: %{id: 42},
        record: %{"id" => 42},
        last_result: %{
          "intent" => "apply",
          "payload" => %{
            "preview" => %{"action" => "archive", "changes" => %{"state" => "archived"}},
            "result" => %{"mode" => "execute", "record" => %{"id" => 42, "state" => "archived"}}
          }
        }
      })

    assert apply_html =~ ~s(data-selecto-action-form-result-summary-item="mode")
    assert apply_html =~ ~s(execute)
    assert apply_html =~ ~s(data-selecto-action-form-result-summary-item="record")
  end

  test "render disables unavailable action forms with the host reason" do
    html =
      render_component(ActionFormModal, %{
        id: "action-form",
        action:
          Map.merge(action(), %{
            "status" => "disabled",
            "disabled?" => true,
            "reason" => "Action precondition failed for state."
          }),
        target: %{id: 42},
        record: %{"id" => 42},
        confirmed: true
      })

    assert html =~ ~s(data-selecto-action-form-disabled)
    assert html =~ "Action precondition failed for state."
    assert html =~ ~r/value="preview"[\s\S]*disabled/
    assert html =~ ~r/value="apply"[\s\S]*disabled/
  end

  test "render supports textarea and select action inputs" do
    html =
      render_component(ActionFormModal, %{
        id: "action-form",
        action:
          Map.put(action(), "inputs", [
            %{"id" => "archive_reason", "type" => "textarea", "label" => "Archive reason"},
            %{
              "id" => "archive_disposition",
              "type" => "string",
              "label" => "Disposition",
              "default" => "obsolete",
              "options" => [
                %{"value" => "obsolete", "label" => "Obsolete"},
                %{"value" => "duplicate", "label" => "Duplicate"}
              ]
            }
          ]),
        target: %{id: 42},
        record: %{"id" => 42}
      })

    assert html =~ ~s(<textarea)
    assert html =~ ~s(name="inputs[archive_reason]")
    assert html =~ ~s(<select name="inputs[archive_disposition]")
    assert html =~ ~s(<option value="obsolete" selected)
    assert html =~ "Duplicate"
  end

  test "render supports normalized contract inputs with raw option metadata" do
    html =
      render_component(ActionFormModal, %{
        id: "action-form",
        action:
          Map.put(action(), "inputs", [
            %{
              "id" => "archive_disposition",
              "type" => "string",
              "label" => "Disposition",
              "default" => "completed",
              "raw" => %{
                "options" => [
                  %{"value" => "completed", "label" => "Completed"},
                  %{"value" => "obsolete", "label" => "Obsolete"}
                ]
              }
            },
            %{
              "id" => "archive_reason",
              "type" => "textarea",
              "label" => "Archive reason",
              "raw" => %{"rows" => 3}
            }
          ]),
        target: %{id: 42},
        record: %{"id" => 42}
      })

    assert html =~ ~s(<select name="inputs[archive_disposition]")
    assert html =~ ~s(<option value="completed" selected)
    assert html =~ ~s(<textarea name="inputs[archive_reason]" rows="3")
  end

  test "submit_action_form normalizes declared boolean inputs while preserving extras" do
    action =
      Map.put(action(), "inputs", [
        %{"id" => "note", "type" => "string"},
        %{"id" => "notify_customer", "type" => "boolean"}
      ])

    assert {:noreply, updated_socket} =
             ActionFormModal.handle_event(
               "submit_action_form",
               %{"intent" => "preview", "inputs" => %{"note" => "Ready", "unexpected" => "kept"}},
               socket(action, %{id: 42})
             )

    assert updated_socket.assigns.form_inputs == %{
             "note" => "Ready",
             "notify_customer" => false,
             "unexpected" => "kept"
           }

    assert_receive {:selecto_action_form_submit, payload}

    assert payload.request["inputs"] == %{
             "note" => "Ready",
             "notify_customer" => false,
             "unexpected" => "kept"
           }
  end

  test "submit_action_form blocks missing required inputs before notifying host" do
    action =
      Map.put(action(), "inputs", [
        %{
          "id" => "archive_reason",
          "type" => "textarea",
          "label" => "Archive reason",
          "required" => true
        },
        %{"id" => "notify_customer", "type" => "boolean", "required" => true}
      ])

    assert {:noreply, updated_socket} =
             ActionFormModal.handle_event(
               "submit_action_form",
               %{
                 "intent" => "preview",
                 "inputs" => %{"archive_reason" => "   ", "notify_customer" => "false"}
               },
               socket(action, %{id: 42})
             )

    assert updated_socket.assigns.submitting == nil
    assert updated_socket.assigns.last_error == "Required inputs missing: Archive reason."
    refute_received {:selecto_action_form_submit, _payload}
  end

  test "render marks non-boolean required inputs for browser validation" do
    html =
      render_component(ActionFormModal, %{
        id: "action-form",
        action:
          Map.put(action(), "inputs", [
            %{
              "id" => "archive_reason",
              "type" => "textarea",
              "label" => "Archive reason",
              "required" => true
            },
            %{
              "id" => "notify_customer",
              "type" => "boolean",
              "label" => "Notify",
              "required" => true
            }
          ]),
        target: %{id: 42},
        record: %{"id" => 42}
      })

    assert html =~ ~r/<textarea[^>]+name="inputs\[archive_reason\]"[^>]+required/
    assert html =~ ~r/<input[^>]+name="inputs\[notify_customer\]"[^>]+type="checkbox"/
    refute html =~ ~r/<input[^>]+name="inputs\[notify_customer\]"[^>]+\srequired(?:\s|>)/
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
