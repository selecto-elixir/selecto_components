defmodule SelectoComponents.Form.ExportOperationsTest do
  use ExUnit.Case, async: true

  defmodule DeliveryStub do
    @behaviour SelectoComponents.ExportDelivery

    @impl true
    def deliver_email(export_payload, delivery_config, _opts) do
      send(self(), {:deliver_email, export_payload, delivery_config})
      {:ok, %{message_id: "msg_123"}}
    end
  end

  defmodule TestLive do
    use Phoenix.LiveView
    use SelectoComponents.Form.EventHandlers.ExportOperations
  end

  test "send_export_email delivers the current results through the configured adapter" do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        query_results: {
          [["Order A", 10], ["Order B", 12]],
          ["title", "quantity"],
          []
        },
        applied_view: nil,
        view_config: %{view_mode: "detail", views: %{}},
        export_delivery_module: DeliveryStub,
        path: "/orders",
        tenant_context: %{tenant_id: 7},
        current_user_id: "42",
        flash: %{}
      }
    }

    assert {:noreply, updated_socket} =
             TestLive.handle_event(
               "send_export_email",
               %{
                 "recipients" => "ops@example.com, finance@example.com",
                 "format" => "csv",
                 "subject" => "Daily orders",
                 "body" => "Attached is the latest export."
               },
               socket
             )

    assert_receive {:deliver_email, export_payload, delivery_config}
    assert export_payload.attachment.filename =~ ".csv"
    assert export_payload.path == "/orders"
    assert delivery_config.email.recipients == ["ops@example.com", "finance@example.com"]
    assert Phoenix.Flash.get(updated_socket.assigns.flash, :info) =~ "Email export sent"
  end

  test "send_export_email reports missing delivery adapter configuration" do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        query_results: {[["Order A"]], ["title"], []},
        applied_view: nil,
        view_config: %{view_mode: "detail", views: %{}},
        export_delivery_module: nil,
        path: "/orders",
        flash: %{}
      }
    }

    assert {:noreply, updated_socket} =
             TestLive.handle_event(
               "send_export_email",
               %{"recipients" => "ops@example.com", "format" => "csv"},
               socket
             )

    assert Phoenix.Flash.get(updated_socket.assigns.flash, :error) =~ "Email export requires"
  end
end
