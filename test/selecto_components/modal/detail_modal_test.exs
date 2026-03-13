defmodule SelectoComponents.Modal.DetailModalTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias SelectoComponents.Modal.DetailModal

  test "renders without icon assign" do
    html =
      render_component(DetailModal, %{
        id: "detail-modal-test",
        record: %{"id" => 1, "name" => "HQ"},
        current_index: 0,
        total_records: 1,
        records: [%{"id" => 1, "name" => "HQ"}],
        fields: ["id", "name"],
        related_data: %{},
        title: "Workspace #1 - HQ",
        subtitle_field: nil,
        size: :lg,
        navigation_enabled: true,
        edit_enabled: false
      })

    assert html =~ "Workspace #1 - HQ"
    assert html =~ "Record 1 of 1"
    assert html =~ "HQ"
    assert html =~ "bg-gray-900/35"
    assert html =~ "phx-window-keydown"
  end

  test "renders title from template using current record" do
    html =
      render_component(DetailModal, %{
        id: "detail-modal-title-template-test",
        record: %{"id" => 2, "name" => "Berlin Hub"},
        current_index: 1,
        total_records: 3,
        records: [
          %{"id" => 1, "name" => "HQ"},
          %{"id" => 2, "name" => "Berlin Hub"},
          %{"id" => 3, "name" => "Paris Hub"}
        ],
        fields: ["id", "name"],
        related_data: %{},
        title_template: ~S(Workspace #{{id}} - {{name}}),
        subtitle_field: nil,
        size: :lg,
        navigation_enabled: true,
        edit_enabled: false
      })

    assert html =~ "Workspace #2 - Berlin Hub"
    assert html =~ "phx-value-direction=\"prev\""
    assert html =~ "phx-value-direction=\"next\""
  end

  test "navigate_record updates title from template" do
    {:ok, socket} = DetailModal.mount(%Phoenix.LiveView.Socket{})

    socket =
      Phoenix.Component.assign(socket,
        id: "detail-modal-nav-test",
        title: "Workspace #1 - HQ",
        title_template: ~S(Workspace #{{id}} - {{name}}),
        record: %{"id" => 1, "name" => "HQ"},
        records: [
          %{"id" => 1, "name" => "HQ"},
          %{"id" => 2, "name" => "Berlin Hub"}
        ],
        current_index: 0,
        total_records: 2
      )

    assert {:noreply, updated_socket} =
             DetailModal.handle_event("navigate_record", %{"direction" => "next"}, socket)

    assert updated_socket.assigns.current_index == 1
    assert updated_socket.assigns.record == %{"id" => 2, "name" => "Berlin Hub"}
    assert updated_socket.assigns.title == "Workspace #2 - Berlin Hub"
  end
end
