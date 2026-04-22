defmodule SelectoComponents.SessionTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.Session
  alias SelectoComponents.Session.Builder
  alias SelectoComponents.Session.Store

  defmodule StubView do
    @behaviour SelectoComponents.Views.System

    @impl true
    def initial_state(_selecto, _options), do: %{selected: [], order_by: []}

    @impl true
    def param_to_state(_params, _options), do: %{}

    @impl true
    def view(_options, _params, _columns_map, _filtered, _selecto), do: {%{}, %{}}

    @impl true
    def form_component, do: __MODULE__

    @impl true
    def result_component, do: __MODULE__
  end

  test "builder creates an initial session from configured views" do
    session =
      Builder.build(
        [
          {:detail, StubView, "Detail", %{}},
          {:aggregate, StubView, "Aggregate", %{}}
        ],
        %{}
      )

    assert %Session{} = session
    assert session.view_mode == "detail"
    assert session.active_tab == "view"
    assert session.filters == []
    assert session.views.detail == %{selected: [], order_by: []}
    assert session.views.aggregate == %{selected: [], order_by: []}
  end

  test "initial assigns expose session and compatibility view_config state" do
    session =
      Session.new(%{
        view_mode: "detail",
        views: %{detail: %{selected: []}},
        active_tab: "view"
      })

    assigns = Store.initial_assigns(session)

    assert Keyword.fetch!(assigns, :session) == session
    assert Keyword.fetch!(assigns, :applied_session).dirty? == false

    assert Keyword.fetch!(assigns, :view_config) == %{
             view_mode: "detail",
             views: %{detail: %{selected: []}},
             filters: [],
             ctes: []
           }

    assert Keyword.fetch!(assigns, :active_tab) == "view"
  end

  test "assign_view_config updates session alongside compatibility assigns" do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        active_tab: "view",
        form_state_revision: 2,
        applied_form_state_revision: 1,
        applied_view_config: %{view_mode: "detail", views: %{}, filters: [], ctes: []},
        view_config: %{view_mode: "detail", views: %{}, filters: [], ctes: []}
      }
    }

    updated_socket =
      Store.assign_view_config(socket, %{
        view_mode: "aggregate",
        views: %{},
        filters: [],
        ctes: []
      })

    assert updated_socket.assigns.view_config.view_mode == "aggregate"
    assert updated_socket.assigns.form_state_revision == 3
    assert updated_socket.assigns.view_config_dirty? == true
    assert updated_socket.assigns.session.view_mode == "aggregate"
    assert updated_socket.assigns.session.revision == 3
    assert updated_socket.assigns.session.applied_revision == 1
    assert updated_socket.assigns.session.dirty? == true
  end

  test "assign_active_tab keeps session in sync" do
    session = Session.new(%{view_mode: "detail", active_tab: "view"})

    socket = %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        active_tab: "view",
        session: session,
        applied_session: session,
        view_config: Session.to_view_config(session)
      }
    }

    updated_socket = Store.assign_active_tab(socket, "save")

    assert updated_socket.assigns.active_tab == "save"
    assert updated_socket.assigns.session.active_tab == "save"
    assert updated_socket.assigns.applied_session.active_tab == "save"
  end
end
