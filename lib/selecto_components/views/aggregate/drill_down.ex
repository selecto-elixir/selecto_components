defmodule SelectoComponents.Views.Aggregate.DrillDown do
  @moduledoc false

  alias SelectoComponents.Form.DrillDownFilters
  alias SelectoComponents.Form.ParamsState
  alias SelectoComponents.SafeAtom

  def apply(socket, params) do
    view_params = DrillDownFilters.build_agg_drill_down_params(params, socket)
    filter_tuples = DrillDownFilters.build_filter_tuples(params, socket)

    selected_view = SafeAtom.to_view_mode(socket.assigns.view_config.view_mode)
    {_, _, _, opt} = Enum.find(socket.assigns.views, fn {id, _, _, _} -> id == selected_view end)
    new_view_mode = Map.get(opt, :drill_down, "detail")

    updated_filters =
      Enum.filter(socket.assigns.view_config.filters, fn
        {_id, "filters", %{} = f} -> !Map.has_key?(params, Map.get(f, "filter"))
        _ -> true
      end) ++ filter_tuples

    updated_socket =
      socket
      |> Phoenix.Component.assign(
        :view_config,
        %{socket.assigns.view_config | view_mode: new_view_mode, filters: updated_filters}
      )
      |> ParamsState.view_from_params(view_params)

    {:ok, updated_socket, view_params}
  end
end
