defmodule SelectoComponents.EnhancedTable.BulkActionsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias SelectoComponents.EnhancedTable.BulkActions

  test "renders generated bulk action forms from a domain contract" do
    html =
      render_component(BulkActions, %{
        id: "bulk-actions",
        action_contract: bulk_contract(),
        selected_rows: MapSet.new(["42"]),
        selection_count: 1
      })

    assert html =~ ~s(data-bulk-action-id="domain_bulk_action_form_bulk_archive")
    assert html =~ ~s(data-bulk-action-source="generated_bulk_action_form")
    assert html =~ ~s(data-bulk-action-scope="bulk")
    assert html =~ "Archive selected"
    assert html =~ ~s(id="bulk-actions-menu")
  end

  test "renders a visible empty state when no bulk actions are available" do
    html =
      render_component(BulkActions, %{
        id: "bulk-actions-empty",
        actions: [],
        selected_rows: MapSet.new(["42"]),
        selection_count: 1
      })

    assert html =~ ~s(id="bulk-actions-empty-menu")
    assert html =~ ~s(data-bulk-actions-empty)
    assert html =~ "No bulk actions available"
  end

  test "opens a generated bulk action form with selected ids as the target" do
    {:ok, socket} =
      BulkActions.mount(%Phoenix.LiveView.Socket{
        assigns: %{__changed__: %{}}
      })

    {:ok, socket} =
      BulkActions.update(
        %{
          id: "bulk-actions",
          action_contract: bulk_contract(),
          selected_rows: MapSet.new(["42", "43"]),
          selection_count: 2
        },
        socket
      )

    assert {:noreply, updated_socket} =
             BulkActions.handle_event(
               "execute_action",
               %{"action" => "domain_bulk_action_form_bulk_archive"},
               socket
             )

    assert_receive {:show_detail_modal, detail_data}

    assert updated_socket.assigns.bulk_action.id == "domain_bulk_action_form_bulk_archive"
    assert detail_data.action_source == :generated_bulk_action_form
    assert detail_data.action_type == :live_component
    assert detail_data.component_module == SelectoComponents.Modal.ActionFormModal
    assert detail_data.component_assigns.target.ids == ["42", "43"]
    assert detail_data.component_assigns.action.id == "bulk_archive"
    assert detail_data.component_assigns.action.scope == "bulk"
    assert detail_data.record == %{"ids" => ["42", "43"], "count" => 2}
    assert detail_data.navigation_enabled == false
  end

  defp bulk_contract do
    %{
      actions: %{
        bulk_archive: %{
          id: :bulk_archive,
          label: "Archive selected",
          description: "Archive every selected row.",
          scope: :bulk,
          capability: "orders.archive",
          execution: %{operation: :update},
          links: %{
            preview: "/orders/actions/bulk_archive/preview",
            apply: "/orders/actions/bulk_archive/apply"
          }
        }
      }
    }
  end
end
