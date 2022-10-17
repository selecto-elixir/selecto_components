defmodule ListableComponentsPetal.ViewSelector do
  use Phoenix.LiveComponent

  #use Phoenix.Component
  use PetalComponents

  def render(assigns) do
    assigns = assign(assigns, columns: Map.values(assigns.listable.config.columns))
    ~H"""
      <div>
        <.accordion>
          <:item heading="View Options">
            <div :for={c <- @columns}>
              <%= c.colid %>
            </div>
          </:item>
          <:item heading="Filter Options">
            Filter OPTS
          </:item>
          <:item heading="Export Options">
            Export OPTS
          </:item>
        </.accordion>
      </div>
    """
  end

end
