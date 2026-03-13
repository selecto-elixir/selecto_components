defmodule SelectoComponents.Modal.ActionModalTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias SelectoComponents.Modal.IframeModal
  alias SelectoComponents.Modal.LiveComponentModal

  test "renders iframe modal content" do
    html =
      render_component(IframeModal, %{
        id: "iframe-modal-test",
        record: %{"id" => 7, "name" => "Preview"},
        current_index: 0,
        total_records: 1,
        records: [%{"id" => 7, "name" => "Preview"}],
        title: "Preview #7",
        title_template: ~S(Preview #{{id}}),
        iframe_url: "/workspaces/7/preview",
        url_template: "/workspaces/{{id}}/preview",
        size: :xl,
        navigation_enabled: true,
        iframe_sandbox: "allow-scripts"
      })

    assert html =~ "Preview #7"
    assert html =~ ~s(src="/workspaces/7/preview")
    assert html =~ ~s(sandbox="allow-scripts")
  end

  test "renders iframe modal with fullscreen size class" do
    html =
      render_component(IframeModal, %{
        id: "iframe-modal-fullscreen-test",
        record: %{"id" => 7},
        current_index: 0,
        total_records: 1,
        records: [%{"id" => 7}],
        title: "Preview #7",
        iframe_url: "/workspaces/7/preview",
        size: :fullscreen,
        navigation_enabled: false
      })

    assert html =~ "w-[96vw] max-w-[96vw]"
  end

  test "renders iframe modal with third-width size class" do
    html =
      render_component(IframeModal, %{
        id: "iframe-modal-third-test",
        record: %{"id" => 7},
        current_index: 0,
        total_records: 1,
        records: [%{"id" => 7}],
        title: "Preview #7",
        iframe_url: "/workspaces/7/preview",
        size: :third,
        navigation_enabled: false
      })

    assert html =~ "sm:w-[33vw] sm:max-w-[33vw]"
  end

  test "normalizes human-readable iframe modal size aliases" do
    assert SelectoComponents.Views.Detail.RowActions.resolve_modal_options(
             %{type: :iframe_modal, payload: %{"size" => "full screen"}},
             %{}
           ).size == :fullscreen

    assert SelectoComponents.Views.Detail.RowActions.resolve_modal_options(
             %{type: :iframe_modal, payload: %{"size" => "1/3 screen"}},
             %{}
           ).size == :third
  end

  test "renders live component modal content" do
    html =
      render_component(LiveComponentModal, %{
        id: "live-component-modal-test",
        record: %{"id" => 7, "name" => "Preview"},
        current_index: 0,
        total_records: 1,
        records: [%{"id" => 7, "name" => "Preview"}],
        title: "Component #7",
        title_template: ~S(Component #{{id}}),
        size: :xl,
        navigation_enabled: true,
        component_module: SelectoComponents.Modal.DetailModal,
        component_assigns: %{},
        component_assigns_template: %{}
      })

    assert html =~ "Component #7"
    assert html =~ "Record 1 of 1"
  end
end
