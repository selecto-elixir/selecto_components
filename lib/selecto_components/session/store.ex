defmodule SelectoComponents.Session.Store do
  @moduledoc """
  Assign/update helpers for the session compatibility bridge.

  This keeps the current `view_config`-based runtime working while introducing
  `SelectoComponents.Session` as the internal source of editable state.
  """

  alias Phoenix.Component
  alias SelectoComponents.Session

  @spec initial_assigns(Session.t()) :: keyword()
  def initial_assigns(%Session{} = session) do
    view_config = Session.to_view_config(session)
    applied_session = %{session | dirty?: false}

    [
      session: session,
      applied_session: applied_session,
      form_state_revision: session.revision,
      applied_form_state_revision: session.applied_revision,
      applied_view_config: view_config,
      view_config_dirty?: session.dirty?,
      active_tab: session.active_tab,
      view_config: view_config
    ]
  end

  @spec assign_view_config(Phoenix.LiveView.Socket.t(), map()) :: Phoenix.LiveView.Socket.t()
  def assign_view_config(socket, view_config) when is_map(view_config) do
    session =
      Session.from_view_config(view_config,
        active_tab: Map.get(socket.assigns, :active_tab, "view"),
        revision: next_form_state_revision(socket),
        applied_revision: current_applied_revision(socket),
        dirty?: view_config != Map.get(socket.assigns, :applied_view_config)
      )

    Component.assign(socket,
      session: session,
      view_config: view_config,
      form_state_revision: session.revision,
      view_config_dirty?: session.dirty?
    )
  end

  @spec mark_form_state_applied(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def mark_form_state_applied(socket) do
    current_view_config = Map.get(socket.assigns, :view_config) || %{}
    applied_revision = normalize_form_state_revision(socket.assigns[:form_state_revision])

    session =
      socket
      |> current_session(current_view_config)
      |> Map.put(:applied_revision, applied_revision)
      |> Map.put(:dirty?, false)

    Component.assign(socket,
      session: session,
      applied_session: session,
      applied_form_state_revision: applied_revision,
      applied_view_config: current_view_config,
      view_config_dirty?: false
    )
  end

  @spec assign_active_tab(Phoenix.LiveView.Socket.t(), String.t()) :: Phoenix.LiveView.Socket.t()
  def assign_active_tab(socket, tab) when is_binary(tab) do
    session =
      socket
      |> current_session(Map.get(socket.assigns, :view_config, %{}))
      |> Map.put(:active_tab, tab)

    socket =
      Component.assign(socket,
        active_tab: tab,
        session: session
      )

    case Map.get(socket.assigns, :applied_session) do
      %Session{} = applied_session ->
        Component.assign(socket, :applied_session, %{applied_session | active_tab: tab})

      _ ->
        socket
    end
  end

  defp current_session(socket, view_config) do
    case Map.get(socket.assigns, :session) do
      %Session{} = session ->
        session

      _ ->
        Session.from_view_config(view_config,
          active_tab: Map.get(socket.assigns, :active_tab, "view"),
          revision:
            normalize_form_state_revision(Map.get(socket.assigns, :form_state_revision, 0)),
          applied_revision: current_applied_revision(socket),
          dirty?: Map.get(socket.assigns, :view_config_dirty?, false)
        )
    end
  end

  defp current_applied_revision(socket) do
    socket.assigns
    |> Map.get(:applied_form_state_revision, Map.get(socket.assigns, :form_state_revision, 0))
    |> normalize_form_state_revision()
  end

  defp next_form_state_revision(socket) do
    socket.assigns
    |> Map.get(:form_state_revision, 0)
    |> normalize_form_state_revision()
    |> Kernel.+(1)
  end

  defp normalize_form_state_revision(value) when is_integer(value), do: value

  defp normalize_form_state_revision(value) when is_binary(value) do
    case Integer.parse(value) do
      {parsed, ""} -> parsed
      _ -> 0
    end
  end

  defp normalize_form_state_revision(_value), do: 0
end
