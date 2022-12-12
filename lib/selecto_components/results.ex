defmodule SelectoComponents.Results do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
      <div>
        <div :if={@executed}>
          <%= if @applied_view == "detail" do %>
            <.live_component
              module={SelectoComponents.Views.Detail.Component}
              id="dettable"
              selecto={@selecto}
              page={@page}
              view_config={@view_config}
            />
          <% else %>
            <.live_component
              module={SelectoComponents.Views.Aggregate.Component}
              id="aggtable"
              selecto={@selecto}
            />
          <% end %>
        </div>
      </div>
    """
  end

end
