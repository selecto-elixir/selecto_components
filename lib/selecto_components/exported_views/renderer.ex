defmodule SelectoComponents.ExportedViews.Renderer do
  @moduledoc false

  alias SelectoComponents.ExportedViews
  alias SelectoComponents.ExportedViews.StateBuilder
  alias SelectoComponents.Form.ParamsState

  @spec render_snapshot(map(), keyword()) :: {:ok, map(), map()} | {:error, term()}
  def render_snapshot(snapshot, opts \\ []) when is_map(snapshot) do
    selecto =
      Selecto.configure(snapshot.domain, snapshot.postgrex_opts,
        adapter: snapshot.adapter,
        validate: false
      )

    assigns =
      snapshot.views
      |> StateBuilder.initial_assigns(selecto)
      |> Map.put(:path, snapshot[:path])
      |> Map.put(:sort_by, Keyword.get(opts, :sort_by))

    socket = %Phoenix.LiveView.Socket{assigns: assigns}
    params = normalize_params(snapshot.params)
    rendered_socket = ParamsState.view_from_params(params, socket)
    render_payload = build_render_payload(rendered_socket.assigns, params)

    {:ok, render_payload, render_stats(render_payload)}
  rescue
    error -> {:error, error}
  end

  defp build_render_payload(assigns, params) do
    %{
      selecto: assigns.selecto,
      views: assigns.views,
      query_results: assigns.query_results,
      view_meta: Map.put(assigns.view_meta || %{}, :row_click_action, ""),
      applied_view: assigns.applied_view || Map.get(params, "view_mode", "detail"),
      executed: assigns.executed,
      execution_error: assigns.execution_error,
      last_query_info: assigns.last_query_info || %{},
      params: params,
      used_params: params,
      enable_modal_detail: false,
      component_errors: []
    }
  end

  defp render_stats(render_payload) do
    row_count = row_count(render_payload.query_results)
    payload_bytes = byte_size(ExportedViews.encode_term(render_payload))

    %{
      row_count: row_count,
      payload_bytes: payload_bytes,
      execution_time_ms: render_payload.last_query_info[:timing]
    }
  end

  defp row_count({rows, _columns, _aliases}) when is_list(rows), do: length(rows)
  defp row_count(_), do: 0

  defp normalize_params(params) when is_map(params) do
    params =
      params
      |> stringify_keys()
      |> maybe_disable_detail_row_action()

    Map.put_new(params, "view_mode", "detail")
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {to_string(key), stringify_value(value)} end)
  end

  defp stringify_value(value) when is_map(value), do: stringify_keys(value)
  defp stringify_value(value) when is_list(value), do: Enum.map(value, &stringify_value/1)
  defp stringify_value(value), do: value

  defp maybe_disable_detail_row_action(%{"view_mode" => "detail"} = params) do
    Map.put(params, "row_click_action", "")
  end

  defp maybe_disable_detail_row_action(params), do: params
end
