defmodule SelectoComponents.Results do
  use Phoenix.LiveComponent

  def render(assigns) do
    assigns =
      case assigns.applied_view do
        nil ->
          assigns

        _ ->
          selected_view = String.to_atom(assigns.applied_view)

          {_, module, _, opt} =
            Enum.find(assigns.views, fn {id, _, _, _} -> id == selected_view end)

          assigns = assign(assigns, module: module, view_opts: opt)
      end

    ~H"""
      <div>
      <% IO.inspect(@executed, label: "Executed?") %>
        <div :if={@executed}>
            <.live_component
              module={String.to_existing_atom("#{@module}.Component")}
              id="view_results"
              selecto={@selecto}
              query_results={@query_results}
              view_meta={@view_meta}
              view_opts={@view_opts}
            />
        </div>
      </div>
    """
  end
end
