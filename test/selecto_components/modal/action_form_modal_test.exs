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
    assert payload.action_label == "Archive"
    assert payload.action_scope == "row"
    assert payload.action_operation == "update"
    assert payload.confirmation_required? == true
    assert payload.target == %{"id" => 42}
    assert payload.inputs == %{"note" => "Ready"}

    assert payload.endpoints == %{
             "preview" => %{"href" => "/actions/archive/preview", "method" => "POST"},
             "apply" => %{"href" => "/actions/archive/apply", "method" => "POST"}
           }

    assert payload.action["id"] == "archive"

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
    assert payload.request["confirmed"] == true
    assert payload.request["dry_run"] == false
    assert payload.confirmation_required? == true
    assert payload.target == %{"id" => 42}
  end

  test "submit_action_form includes capability and link metadata when present" do
    action =
      action()
      |> Map.put("capability", "work_items.archive")
      |> Map.put("links", %{"audit" => %{"href" => "/actions/archive/audit"}})

    assert {:noreply, _socket} =
             ActionFormModal.handle_event(
               "submit_action_form",
               %{"intent" => "preview", "inputs" => %{"note" => "Ready"}},
               socket(action, %{id: 42})
             )

    assert_receive {:selecto_action_form_submit, payload}
    assert payload.capability == "work_items.archive"
    assert payload.links == %{"audit" => %{"href" => "/actions/archive/audit"}}
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
    assert html =~ ~s(data-action-status="applied")

    assert html =~
             ~r/data-selecto-action-form-input="note"[\s\S]*name="inputs\[note\]"[\s\S]*disabled/

    assert html =~ ~r/name="confirmed"[\s\S]*disabled/
    assert html =~ ~r/value="preview"[\s\S]*disabled/
    assert html =~ ~r/value="apply"[\s\S]*disabled/
    assert html =~ ~r/value="preview"[\s\S]*bg-slate-100[\s\S]*disabled/
    assert html =~ ~r/value="apply"[\s\S]*bg-slate-100[\s\S]*disabled/
  end

  test "render exposes stable action metadata and submit hooks" do
    html =
      render_component(ActionFormModal, %{
        id: "action-form",
        action: Map.put(action(), "capability", "work_items.archive"),
        target: %{id: 42},
        record: %{"id" => 42},
        confirmed: true
      })

    assert html =~ ~s(data-selecto-action-form-modal)
    assert html =~ ~s(data-action-id="archive")
    assert html =~ ~s(data-action-capability="work_items.archive")
    assert html =~ ~s(data-action-operation="update")
    assert html =~ ~s(data-action-scope="row")
    assert html =~ ~s(data-action-status="enabled")
    assert html =~ ~s(data-selecto-action-form-input="note")
    assert html =~ ~s(data-selecto-action-form-submit="preview")
    assert html =~ ~s(data-selecto-action-form-submit="apply")
  end

  test "render carries numeric input constraints from action metadata" do
    html =
      render_component(ActionFormModal, %{
        id: "action-form",
        action: %{
          action()
          | "inputs" => [
              %{
                "id" => "estimate_hours",
                "type" => "integer",
                "required" => true,
                "default" => 4,
                "min" => 0,
                "max" => 40,
                "step" => 1
              }
            ]
        },
        target: %{id: 42},
        record: %{"id" => 42}
      })

    assert html =~ ~r/data-selecto-action-form-input="estimate_hours"[\s\S]*type="number"/
    assert html =~ ~r/data-selecto-action-form-input="estimate_hours"[\s\S]*min="0"/
    assert html =~ ~r/data-selecto-action-form-input="estimate_hours"[\s\S]*max="40"/
    assert html =~ ~r/data-selecto-action-form-input="estimate_hours"[\s\S]*step="1"/
  end

  test "reset_action_form clears non-applied result state" do
    socket =
      socket(action(), %{id: 42})
      |> Phoenix.Component.assign(
        submitting: "preview",
        last_request: %{"action" => "archive"},
        last_result: %{"intent" => "preview", "payload" => %{"action" => "archive"}},
        last_error: "Preview failed"
      )

    assert {:noreply, updated_socket} =
             ActionFormModal.handle_event("reset_action_form", %{}, socket)

    assert updated_socket.assigns.submitting == nil
    assert updated_socket.assigns.last_request == nil
    assert updated_socket.assigns.last_result == nil
    assert updated_socket.assigns.last_error == nil
  end

  test "reset_action_form preserves applied result lock" do
    socket =
      socket(action(), %{id: 42})
      |> Phoenix.Component.assign(
        last_result: %{"intent" => "apply", "payload" => %{"action" => "archive"}}
      )

    assert {:noreply, updated_socket} =
             ActionFormModal.handle_event("reset_action_form", %{}, socket)

    assert updated_socket.assigns.last_result == %{
             "intent" => "apply",
             "payload" => %{"action" => "archive"}
           }
  end

  test "change_action_form merges partial LiveView input payloads without clearing prior fields" do
    action =
      Map.put(action(), "inputs", [
        %{"id" => "documents_complete", "type" => "boolean"},
        %{"id" => "checked_in_at", "type" => "utc_datetime"},
        %{"id" => "arrival_notes", "type" => "string"}
      ])

    socket =
      action
      |> socket(%{id: 42})
      |> Phoenix.Component.assign(
        form_inputs: %{
          "checked_in_at" => "2026-05-16T21:24",
          "arrival_notes" => "Front desk"
        }
      )

    assert {:noreply, updated_socket} =
             ActionFormModal.handle_event(
               "change_action_form",
               %{
                 "_target" => ["inputs", "documents_complete"],
                 "inputs" => %{
                   "_unused_checked_in_at" => "",
                   "_unused_arrival_notes" => "",
                   "documents_complete" => "true"
                 }
               },
               socket
             )

    assert updated_socket.assigns.form_inputs == %{
             "checked_in_at" => "2026-05-16T21:24",
             "arrival_notes" => "Front desk",
             "documents_complete" => "true"
           }
  end

  test "change_action_form ignores blank non-target payloads when a prior value exists" do
    action =
      Map.put(action(), "inputs", [
        %{"id" => "documents_complete", "type" => "boolean"},
        %{"id" => "checked_in_at", "type" => "utc_datetime"},
        %{"id" => "arrival_notes", "type" => "string"}
      ])

    socket =
      action
      |> socket(%{id: 42})
      |> Phoenix.Component.assign(
        form_inputs: %{
          "checked_in_at" => "2026-05-16T21:28",
          "arrival_notes" => "Front desk"
        }
      )

    assert {:noreply, updated_socket} =
             ActionFormModal.handle_event(
               "change_action_form",
               %{
                 "_target" => ["inputs", "arrival_notes"],
                 "inputs" => %{
                   "checked_in_at" => "",
                   "arrival_notes" => "Front desk ready"
                 }
               },
               socket
             )

    assert updated_socket.assigns.form_inputs == %{
             "checked_in_at" => "2026-05-16T21:28",
             "arrival_notes" => "Front desk ready"
           }
  end

  test "submit_action_form omits optional blank inputs without defaults" do
    action =
      Map.put(action(), "inputs", [
        %{"id" => "documents_complete", "type" => "boolean"},
        %{"id" => "checked_in_at", "type" => "utc_datetime", "required" => false},
        %{"id" => "arrival_notes", "type" => "string", "required" => false}
      ])

    assert {:noreply, updated_socket} =
             ActionFormModal.handle_event(
               "submit_action_form",
               %{
                 "intent" => "preview",
                 "inputs" => %{
                   "documents_complete" => "true",
                   "checked_in_at" => "",
                   "arrival_notes" => ""
                 }
               },
               socket(action, %{id: 42})
             )

    assert updated_socket.assigns.form_inputs == %{"documents_complete" => true}

    assert_receive {:selecto_action_form_submit, payload}
    assert payload.request["inputs"] == %{"documents_complete" => true}
  end

  test "submit_action_form preserves component state when submit payload blanks a changed datetime" do
    action =
      Map.put(action(), "inputs", [
        %{"id" => "documents_complete", "type" => "boolean"},
        %{"id" => "checked_in_at", "type" => "utc_datetime", "required" => false},
        %{"id" => "arrival_notes", "type" => "string", "required" => false}
      ])

    socket =
      action
      |> socket(%{id: 42})
      |> Phoenix.Component.assign(
        form_inputs: %{
          "documents_complete" => true,
          "checked_in_at" => "2026-05-16T21:35",
          "arrival_notes" => "Front desk"
        }
      )

    assert {:noreply, updated_socket} =
             ActionFormModal.handle_event(
               "submit_action_form",
               %{
                 "intent" => "apply",
                 "confirmed" => "true",
                 "inputs" => %{
                   "documents_complete" => "true",
                   "checked_in_at" => "",
                   "arrival_notes" => ""
                 }
               },
               socket
             )

    assert updated_socket.assigns.form_inputs == %{
             "documents_complete" => true,
             "checked_in_at" => "2026-05-16T21:35:00Z",
             "arrival_notes" => "Front desk"
           }

    assert_receive {:selecto_action_form_submit, payload}

    assert payload.request["inputs"] == %{
             "documents_complete" => true,
             "checked_in_at" => "2026-05-16T21:35:00Z",
             "arrival_notes" => "Front desk"
           }
  end

  test "change_action_form marks changed boolean inputs false when unchecked" do
    action =
      Map.put(action(), "inputs", [
        %{"id" => "documents_complete", "type" => "boolean"},
        %{"id" => "checked_in_at", "type" => "utc_datetime"}
      ])

    socket =
      action
      |> socket(%{id: 42})
      |> Phoenix.Component.assign(
        form_inputs: %{
          "documents_complete" => true,
          "checked_in_at" => "2026-05-16T21:24"
        }
      )

    assert {:noreply, updated_socket} =
             ActionFormModal.handle_event(
               "change_action_form",
               %{
                 "_target" => ["inputs", "documents_complete"],
                 "inputs" => %{"_unused_checked_in_at" => ""}
               },
               socket
             )

    assert updated_socket.assigns.form_inputs == %{
             "documents_complete" => false,
             "checked_in_at" => "2026-05-16T21:24"
           }
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
    assert preview_html =~ ~s(data-selecto-action-form-reset)
    assert preview_html =~ ~s({&quot;state&quot;:&quot;archived&quot;})
    refute preview_html =~ ~s(data-selecto-action-form-result-details)

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
    refute apply_html =~ ~s(data-selecto-action-form-result-details)
    refute apply_html =~ ~s(Response details)
  end

  test "render surfaces host-owned reload semantics after apply" do
    html =
      render_component(ActionFormModal, %{
        id: "action-form",
        action: action(),
        target: %{id: 42},
        record: %{"id" => 42},
        last_result: %{
          "intent" => "apply",
          "payload" => %{
            "result" => %{"mode" => "execute", "record" => %{"id" => 42}}
          },
          "reload" => %{
            "status" => "refreshed",
            "surface" => "selecto_results",
            "message" => "Current results were rerun."
          }
        }
      })

    assert html =~ ~s(data-selecto-action-form-reload="refreshed")
    assert html =~ "Results refreshed: Selecto results"
    assert html =~ "Current results were rerun."
  end

  test "render surfaces structured host error details" do
    html =
      render_component(ActionFormModal, %{
        id: "action-form",
        action: action(),
        target: %{id: 42},
        record: %{"id" => 42},
        last_error: "Action precondition failed.",
        last_error_details: %{
          "metadata" => %{
            "code" => "action_precondition_failed",
            "state" => "archived"
          }
        }
      })

    assert html =~ ~s(data-selecto-action-form-error)
    assert html =~ ~s(data-selecto-action-form-error-details)
    assert html =~ ~s(data-selecto-action-form-error-detail="code")
    assert html =~ "action_precondition_failed"
  end

  test "render keeps raw request and response JSON behind an explicit debug flag" do
    default_html =
      render_component(ActionFormModal, %{
        id: "action-form",
        action: action(),
        target: %{id: 42},
        record: %{"id" => 42},
        last_result: %{"intent" => "preview", "payload" => %{"action" => "archive"}}
      })

    refute default_html =~ "Request template"
    refute default_html =~ "Response details"

    debug_html =
      render_component(ActionFormModal, %{
        id: "action-form",
        action: action(),
        target: %{id: 42},
        record: %{"id" => 42},
        show_debug_json?: true,
        last_result: %{"intent" => "preview", "payload" => %{"action" => "archive"}}
      })

    assert debug_html =~ "Request template"
    assert debug_html =~ "Response details"
    assert debug_html =~ ~s(data-selecto-action-form-result-details)
  end

  test "render summarizes bulk apply results without expanding every record in the summary" do
    html =
      render_component(ActionFormModal, %{
        id: "action-form",
        action: action(),
        target: %{"ids" => ["1541", "1542", "1543"]},
        record: %{},
        last_result: %{
          "intent" => "apply",
          "payload" => %{
            "preview" => %{"action" => "bulk_archive"},
            "result" => %{
              "mode" => "execute",
              "target" => %{"table" => "work_items", "ids" => [1541, 1542, 1543]},
              "record" => [
                %{"id" => 1541, "state" => "archived"},
                %{"id" => 1542, "state" => "archived"},
                %{"id" => 1543, "state" => "archived"}
              ]
            }
          }
        }
      })

    assert html =~ ~s(data-selecto-action-form-result-summary-item="records")
    assert html =~ "3 records"
    assert html =~ ~s(data-selecto-action-form-result-summary-item="target_ids")
    assert html =~ "[1541,1542,1543]"
    assert html =~ ~s(data-selecto-action-form-result-summary-item="affected")
    assert html =~ ">3<"
    refute html =~ ~s(data-selecto-action-form-result-summary-item="record")
    refute html =~ ~s(data-selecto-action-form-result-details)
  end

  test "render summarizes bulk preview target and would-update counts" do
    html =
      render_component(ActionFormModal, %{
        id: "action-form",
        action: action(),
        target: %{"ids" => ["1541", "1542"]},
        record: %{},
        last_result: %{
          "intent" => "preview",
          "payload" => %{
            "action" => "bulk_archive",
            "target" => %{"ids" => [1541, 1542]},
            "result" => %{
              "mode" => "dry_run",
              "would_update" => [
                %{"id" => 1541, "state" => "archived"},
                %{"id" => 1542, "state" => "archived"}
              ]
            }
          }
        }
      })

    assert html =~ ~s(data-selecto-action-form-result-summary-item="target_ids")
    assert html =~ "[1541,1542]"
    assert html =~ ~s(data-selecto-action-form-result-summary-item="affected")
    assert html =~ ">2<"
  end

  test "render summarizes variant and collection action results" do
    html =
      render_component(ActionFormModal, %{
        id: "action-form",
        action: action(),
        target: %{"id" => "9002"},
        record: %{},
        last_result: %{
          "intent" => "apply",
          "payload" => %{
            "action" => "check_in_camper",
            "result" => %{
              "mode" => "execute",
              "variant" => "missing_documents",
              "record" => %{"id" => 9002, "status" => "checked_in"},
              "collection_results" => %{
                "missing_documents" => %{
                  "operations" => [
                    %{"action" => "insert", "record" => %{"document_type" => "waiver"}}
                  ]
                }
              }
            }
          }
        }
      })

    assert html =~ ~s(data-selecto-action-form-result-summary-item="variant")
    assert html =~ "missing_documents"
    assert html =~ ~s(data-selecto-action-form-result-summary-item="collections")
    assert html =~ "1 collection operations"
    refute html =~ ~s(data-selecto-action-form-result-details)
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
    assert html =~ ~s(data-action-status="disabled")
    assert html =~ "Action precondition failed for state."

    assert html =~
             ~r/data-selecto-action-form-input="note"[\s\S]*name="inputs\[note\]"[\s\S]*disabled/

    assert html =~ ~r/name="confirmed"[\s\S]*disabled/
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
    assert html =~ ~r/<select[^>]+name="inputs\[archive_disposition\]"/
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

    assert html =~ ~r/<select[^>]+name="inputs\[archive_disposition\]"/
    assert html =~ ~s(<option value="completed" selected)
    assert html =~ ~r/<textarea[^>]+name="inputs\[archive_reason\]"[^>]+rows="3"/
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

  test "submit_action_form accepts browser checkbox values and preserves non-scalar defaults" do
    action =
      Map.put(action(), "inputs", [
        %{"id" => "documents_complete", "type" => "boolean"},
        %{"id" => "checked_in_at", "type" => "utc_datetime", "default" => ["system", "now"]}
      ])

    assert {:noreply, updated_socket} =
             ActionFormModal.handle_event(
               "submit_action_form",
               %{
                 "intent" => "preview",
                 "inputs" => %{"documents_complete" => "on", "checked_in_at" => ""}
               },
               socket(action, %{id: 42})
             )

    assert updated_socket.assigns.form_inputs == %{
             "documents_complete" => true,
             "checked_in_at" => ["system", "now"]
           }

    assert_receive {:selecto_action_form_submit, payload}

    assert payload.request["inputs"] == %{
             "documents_complete" => true,
             "checked_in_at" => ["system", "now"]
           }
  end

  test "submit_action_form normalizes utc datetime-local values to ISO8601" do
    action =
      Map.put(action(), "inputs", [
        %{"id" => "checked_in_at", "type" => "utc_datetime"}
      ])

    assert {:noreply, updated_socket} =
             ActionFormModal.handle_event(
               "submit_action_form",
               %{
                 "intent" => "preview",
                 "inputs" => %{"checked_in_at" => "2026-05-16T21:24"}
               },
               socket(action, %{id: 42})
             )

    assert updated_socket.assigns.form_inputs == %{
             "checked_in_at" => "2026-05-16T21:24:00Z"
           }

    assert_receive {:selecto_action_form_submit, payload}
    assert payload.request["inputs"]["checked_in_at"] == "2026-05-16T21:24:00Z"
  end

  test "submit_action_form normalizes generic datetime-local values to ISO8601" do
    action =
      Map.put(action(), "inputs", [
        %{"id" => "checked_in_at", "type" => "datetime"}
      ])

    assert {:noreply, updated_socket} =
             ActionFormModal.handle_event(
               "submit_action_form",
               %{
                 "intent" => "preview",
                 "inputs" => %{"checked_in_at" => "2026-05-16T21:24"}
               },
               socket(action, %{id: 42})
             )

    assert updated_socket.assigns.form_inputs == %{
             "checked_in_at" => "2026-05-16T21:24:00Z"
           }

    assert_receive {:selecto_action_form_submit, payload}
    assert payload.request["inputs"]["checked_in_at"] == "2026-05-16T21:24:00Z"
  end

  test "submit_action_form uses action input definitions when socket has no persisted inputs assign" do
    action =
      Map.put(action(), "inputs", [
        %{"id" => "documents_complete", "type" => "boolean"},
        %{"id" => "checked_in_at", "type" => "utc_datetime"}
      ])

    socket =
      %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          action: action,
          target: %{id: 42},
          record: %{"id" => 42},
          form_inputs: %{"checked_in_at" => "2026-05-16T21:24"}
        }
      }

    assert {:noreply, updated_socket} =
             ActionFormModal.handle_event(
               "submit_action_form",
               %{
                 "intent" => "preview",
                 "inputs" => %{
                   "documents_complete" => "true",
                   "checked_in_at" => "2026-05-16T21:24"
                 }
               },
               socket
             )

    assert updated_socket.assigns.form_inputs == %{
             "documents_complete" => true,
             "checked_in_at" => "2026-05-16T21:24:00Z"
           }

    assert_receive {:selecto_action_form_submit, payload}

    assert payload.request["inputs"] == %{
             "documents_complete" => true,
             "checked_in_at" => "2026-05-16T21:24:00Z"
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
    assert html =~ ~r/<input[^>]+name="inputs\[notify_customer\]"[^>]+value="true"/
    refute html =~ ~r/<input[^>]+name="inputs\[notify_customer\]"[^>]+\srequired(?:\s|>)/
  end

  test "render leaves non-scalar defaults out of browser input values" do
    html =
      render_component(ActionFormModal, %{
        id: "action-form",
        action:
          Map.put(action(), "inputs", [
            %{
              "id" => "checked_in_at",
              "type" => "utc_datetime",
              "default" => ["system", "now"]
            }
          ]),
        target: %{id: 42},
        record: %{"id" => 42}
      })

    assert html =~ ~r/data-selecto-action-form-input="checked_in_at"[\s\S]*type="datetime-local"/
    refute html =~ "systemnow"
  end

  test "render adapts normalized utc datetimes back to datetime-local values" do
    html =
      render_component(ActionFormModal, %{
        id: "action-form",
        action:
          Map.put(action(), "inputs", [
            %{"id" => "checked_in_at", "type" => "utc_datetime"}
          ]),
        target: %{id: 42},
        record: %{"id" => 42},
        form_inputs: %{"checked_in_at" => "2026-05-16T21:45:00Z"}
      })

    assert html =~ ~r/data-selecto-action-form-input="checked_in_at"[\s\S]*type="datetime-local"/
    assert html =~ ~s(value="2026-05-16T21:45:00")
    refute html =~ ~s(value="2026-05-16T21:45:00Z")
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
