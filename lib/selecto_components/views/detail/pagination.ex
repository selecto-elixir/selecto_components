defmodule SelectoComponents.Views.Detail.Pagination do
  @moduledoc false

  alias SelectoComponents.Form.ParamsState

  def apply_page(socket, page) when is_integer(page) do
    safe_page = clamp_page(page, socket.assigns[:view_meta] || %{})

    params =
      socket.assigns[:used_params] ||
        ParamsState.view_config_to_params(socket.assigns.view_config)

    params = Map.put(params, "detail_page", Integer.to_string(safe_page))

    updated_socket =
      socket
      |> Phoenix.Component.assign(:current_detail_page, safe_page)
      |> ParamsState.view_from_params(params)

    {:ok, updated_socket, params}
  end

  def apply_page(socket, _page), do: apply_page(socket, 0)

  def clamp_page(page, view_meta) do
    requested_page = max(page, 0)
    per_page = max(Map.get(view_meta, :per_page, 30), 1)
    total_rows = max(Map.get(view_meta, :total_rows, 0), 0)

    max_page =
      if total_rows > 0 do
        div(total_rows - 1, per_page)
      else
        0
      end

    min(requested_page, max_page)
  end
end
