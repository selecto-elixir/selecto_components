defmodule SelectoComponents.ActionsTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.Actions

  test "builds enabled action items from a write contract document" do
    assert [action] =
             Actions.available(write_contract(),
               decisions: %{
                 "approve_order" => %{
                   status: :enabled,
                   reason: "Allowed by policy"
                 }
               }
             )

    assert action.id == "approve_order"
    assert action.label == "Approve order"
    assert action.description == "Approve the selected order."
    assert action.scope == "row"
    assert action.operation == "update"
    assert action.capability == "orders.approve"
    assert action.icon == "check"
    assert action.status == "enabled"
    assert action.disabled? == false
    assert action.hidden? == false
    assert action.destructive? == false
    assert action.requires_confirmation? == true
    assert action.confirmation == %{"message" => "Approve this order?", "required" => true}
    assert action.confirmation_message == "Approve this order?"
    assert action.reason == "Allowed by policy"
    assert action.links["preview"] == "/orders/actions/approve_order/preview"
    assert action.preview_link == "/orders/actions/approve_order/preview"
    assert action.apply_link == "/orders/actions/approve_order/apply"

    assert action.attrs == %{
             "data-action-capability" => "orders.approve",
             "data-action-confirmation" => true,
             "data-action-destructive" => false,
             "data-action-id" => "approve_order",
             "data-action-operation" => "update",
             "data-action-scope" => "row",
             "data-action-status" => "enabled"
           }
  end

  test "keeps disabled actions visible with reason metadata" do
    assert [action] =
             Actions.available(write_contract(),
               decisions: %{
                 "orders.approve" => %{
                   "status" => "disabled",
                   "reason" => "Approval window is closed"
                 }
               }
             )

    assert action.id == "approve_order"
    assert action.status == "disabled"
    assert action.disabled? == true
    assert action.hidden? == false
    assert action.reason == "Approval window is closed"
  end

  test "filters hidden actions and can scope visible actions" do
    contract =
      write_contract(%{
        "bulk_archive" => %{
          "id" => "bulk_archive",
          "label" => "Archive selected",
          "scope" => "bulk",
          "capability" => "orders.archive",
          "execution" => %{"operation" => "update"}
        }
      })

    actions =
      Actions.available(contract,
        scope: :bulk,
        decisions: %{
          "approve_order" => %{status: :hidden, reason: "No row access"},
          "bulk_archive" => :enabled
        }
      )

    assert Enum.map(actions, & &1.id) == ["bulk_archive"]
  end

  test "merges preview decisions by action id" do
    decisions = Actions.put_decision(%{}, :approve_order, %{status: :disabled})

    assert decisions == %{"approve_order" => %{"status" => "disabled"}}
  end

  test "extracts decisions from action result payloads" do
    decisions =
      %{}
      |> Actions.put_result_decision(:approve_order, %{
        "preview" => %{
          "capability_decision" => %{
            "status" => "enabled",
            "reason" => "Ready"
          }
        }
      })

    assert decisions == %{"approve_order" => %{"status" => "enabled", "reason" => "Ready"}}
  end

  test "converts validation errors into disabled decisions" do
    decisions =
      Actions.put_result_decision(
        %{},
        :approve_order,
        {:error,
         {:validation_error, "Action precondition failed for state.",
          %{"code" => "action_precondition_failed", "field" => "state"}}}
      )

    assert decisions["approve_order"]["status"] == "disabled"
    assert decisions["approve_order"]["reason"] == "Action precondition failed for state."
    assert decisions["approve_order"]["code"] == "action_precondition_failed"
    assert decisions["approve_order"]["metadata"]["field"] == "state"
  end

  test "summarizes and groups visible action items" do
    actions =
      write_contract(%{
        "bulk_archive" => %{
          "id" => "bulk_archive",
          "label" => "Archive selected",
          "scope" => "bulk",
          "capability" => "orders.archive",
          "execution" => %{"operation" => "update"}
        }
      })
      |> Actions.available(
        decisions: %{
          "approve_order" => :enabled,
          "bulk_archive" => %{status: :disabled, reason: "No selected rows"}
        }
      )

    assert Actions.status_counts(actions) == %{"enabled" => 1, "disabled" => 1}
    assert actions |> Actions.by_scope() |> Map.keys() |> Enum.sort() == ["bulk", "row"]

    assert actions |> Actions.by_scope() |> Map.fetch!("bulk") |> hd() |> Map.fetch!(:id) ==
             "bulk_archive"
  end

  test "marks delete-like or destructive actions for guarded UI treatment" do
    contract =
      write_contract(%{
        "delete_order" => %{
          "id" => "delete_order",
          "label" => "Delete order",
          "scope" => "row",
          "capability" => "orders.delete",
          "execution" => %{"operation" => "delete"},
          "confirmation" => %{"required" => true, "destructive" => true}
        }
      })

    assert action = Enum.find(Actions.available(contract), &(&1.id == "delete_order"))
    assert action.destructive? == true
    assert action.requires_confirmation? == true
  end

  defp write_contract(extra_actions \\ %{}) do
    %{
      "projection" => "updato_write_contract",
      "actions" =>
        [
          %{
            "id" => "approve_order",
            "label" => "Approve order",
            "description" => "Approve the selected order.",
            "scope" => "row",
            "capability" => "orders.approve",
            "icon" => "check",
            "confirmation" => %{"required" => true, "message" => "Approve this order?"},
            "execution" => %{"operation" => "update"},
            "links" => %{
              "preview" => "/orders/actions/approve_order/preview",
              "apply" => "/orders/actions/approve_order/apply"
            }
          }
        ] ++ Map.values(extra_actions)
    }
  end
end
