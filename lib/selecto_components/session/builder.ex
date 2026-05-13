defmodule SelectoComponents.Session.Builder do
  @moduledoc """
  Builds the initial SelectoComponents session from configured views.
  """

  alias SelectoComponents.Session
  alias SelectoComponents.Views.Runtime, as: ViewRuntime

  @spec build([SelectoComponents.Views.view_tuple()], term()) :: Session.t()
  def build(views, selecto) when is_list(views) do
    default_view_mode =
      case views do
        [{id, _, _, _} | _] -> Atom.to_string(id)
        _ -> "aggregate"
      end

    view_configs =
      Enum.reduce(views, %{}, fn {view, _module, _name, _opt} = view_tuple, acc ->
        Map.put(acc, view, ViewRuntime.initial_state(view_tuple, selecto))
      end)

    Session.new(%{
      view_mode: default_view_mode,
      views: view_configs,
      filters: [],
      ctes: [],
      active_tab: "view",
      revision: 0,
      applied_revision: 0,
      dirty?: false
    })
  end
end
