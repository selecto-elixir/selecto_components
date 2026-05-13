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
    assert action.scope == "row"
    assert action.operation == "update"
    assert action.capability == "orders.approve"
    assert action.status == "enabled"
    assert action.disabled? == false
    assert action.hidden? == false
    assert action.reason == "Allowed by policy"
    assert action.links["preview"] == "/orders/actions/approve_order/preview"
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

  defp write_contract(extra_actions \\ %{}) do
    %{
      "projection" => "updato_write_contract",
      "actions" =>
        [
          %{
            "id" => "approve_order",
            "label" => "Approve order",
            "scope" => "row",
            "capability" => "orders.approve",
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
