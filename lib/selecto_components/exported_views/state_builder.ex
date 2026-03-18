defmodule SelectoComponents.ExportedViews.StateBuilder do
  @moduledoc false

  alias SelectoComponents.Extensions
  alias SelectoComponents.Views.Runtime, as: ViewRuntime

  @spec initial_assigns(list(), map()) :: map()
  def initial_assigns(views, selecto) when is_list(views) do
    views = Extensions.merge_views(views, selecto)

    default_view_mode =
      case views do
        [{id, _, _, _} | _] -> Atom.to_string(id)
        _ -> "aggregate"
      end

    view_configs =
      Enum.reduce(views, %{}, fn {view, _module, _name, _opts} = view_tuple, acc ->
        Map.put(acc, view, ViewRuntime.initial_state(view_tuple, selecto))
      end)

    columns =
      selecto
      |> Selecto.columns()
      |> Enum.map(fn {key, col} ->
        {key, col.name, col.type}
      end)

    %{
      __changed__: %{},
      selecto: selecto,
      views: views,
      columns: columns,
      field_filters: Selecto.filters(selecto),
      executed: false,
      execution_error: nil,
      query_results: [],
      detail_page_cache: nil,
      aggregate_page_cache: nil,
      applied_view: nil,
      active_tab: "view",
      sort_by: nil,
      view_meta: %{},
      last_query_info: %{},
      view_config: %{
        view_mode: default_view_mode,
        views: view_configs,
        filters: []
      }
    }
  end
end
