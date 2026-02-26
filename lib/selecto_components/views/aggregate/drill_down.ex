defmodule SelectoComponents.Views.Aggregate.DrillDown do
  @moduledoc false

  alias SelectoComponents.Form.DrillDownFilters
  alias SelectoComponents.Form.ParamsState
  alias SelectoComponents.SafeAtom

  def apply(socket, params) do
    selected_view = SafeAtom.to_view_mode(socket.assigns.view_config.view_mode)
    {_, _, _, opt} = Enum.find(socket.assigns.views, fn {id, _, _, _} -> id == selected_view end)
    new_view_mode = normalize_view_mode(Map.get(opt, :drill_down, "detail"))

    view_params =
      DrillDownFilters.build_agg_drill_down_params(params, socket)
      |> Map.put("view_mode", new_view_mode)

    filter_tuples = DrillDownFilters.build_filter_tuples(params, socket)

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

    updated_socket = ParamsState.view_from_params(view_params, updated_socket)

    {:ok, updated_socket, view_params}
  end

  defp normalize_view_mode(view_mode) when is_atom(view_mode), do: Atom.to_string(view_mode)
  defp normalize_view_mode(view_mode) when is_binary(view_mode), do: view_mode
  defp normalize_view_mode(_view_mode), do: "detail"
end
