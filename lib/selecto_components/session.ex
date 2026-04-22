defmodule SelectoComponents.Session do
  @moduledoc """
  Canonical editable session state for SelectoComponents exploration.

  This struct is the first internal seam in the runtime simplification work.
  It intentionally models editable explorer state only; query results and
  execution output stay outside the session.
  """

  @type t :: %__MODULE__{
          view_mode: String.t(),
          views: map(),
          filters: list(),
          ctes: list(),
          sort: term(),
          paging: map(),
          feature_state: map(),
          active_tab: String.t(),
          revision: non_neg_integer(),
          applied_revision: non_neg_integer(),
          dirty?: boolean()
        }

  defstruct view_mode: "aggregate",
            views: %{},
            filters: [],
            ctes: [],
            sort: nil,
            paging: %{},
            feature_state: %{},
            active_tab: "view",
            revision: 0,
            applied_revision: 0,
            dirty?: false

  @spec new(map()) :: t()
  def new(attrs \\ %{}) when is_map(attrs) do
    struct(__MODULE__, attrs)
  end

  @spec from_view_config(map(), keyword()) :: t()
  def from_view_config(view_config, opts \\ []) when is_map(view_config) do
    revision = Keyword.get(opts, :revision, 0)

    %__MODULE__{
      view_mode: get_value(view_config, :view_mode, "aggregate"),
      views: get_value(view_config, :views, %{}),
      filters: get_value(view_config, :filters, []),
      ctes: get_value(view_config, :ctes, []),
      sort: Keyword.get(opts, :sort),
      paging: Keyword.get(opts, :paging, %{}),
      feature_state: Keyword.get(opts, :feature_state, %{}),
      active_tab: Keyword.get(opts, :active_tab, "view"),
      revision: revision,
      applied_revision: Keyword.get(opts, :applied_revision, revision),
      dirty?: Keyword.get(opts, :dirty?, false)
    }
  end

  @spec to_view_config(t()) :: map()
  def to_view_config(%__MODULE__{} = session) do
    %{
      view_mode: session.view_mode,
      views: session.views,
      filters: session.filters,
      ctes: session.ctes
    }
  end

  defp get_value(map, atom_key, default) do
    Map.get(map, atom_key, Map.get(map, Atom.to_string(atom_key), default))
  end
end
