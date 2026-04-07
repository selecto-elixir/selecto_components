defmodule SelectoComponents.Form.ModalRouterTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias SelectoComponents.Form.ModalRouter

  defmodule CustomModal do
    use Phoenix.LiveComponent

    def render(assigns) do
      ~H"""
      <div data-custom-modal="true">{inspect(@detail_data)}</div>
      """
    end
  end

  test "renders nothing when the modal is not visible" do
    html = render_component(&ModalRouter.router/1, %{visible: false, modal_detail_data: %{}})

    assert html == ""
  end

  test "routes to a custom modal component when one is provided" do
    html =
      render_component(&ModalRouter.router/1, %{
        visible: true,
        detail_modal_component: CustomModal,
        modal_detail_data: %{record: %{id: 1, title: "Launch"}}
      })

    assert html =~ ~s(data-custom-modal="true")
    assert html =~ "Launch"
  end

  test "routes iframe modal actions to the iframe modal component" do
    html =
      render_component(&ModalRouter.router/1, %{
        visible: true,
        modal_detail_data: %{
          action_type: :iframe_modal,
          record: %{id: 1},
          records: [%{id: 1}],
          current_index: 0,
          total_records: 1,
          iframe_url: "https://example.com/detail/1"
        }
      })

    assert html =~ "Open in new tab"
    assert html =~ "https://example.com/detail/1"
  end
end
