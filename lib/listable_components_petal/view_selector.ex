defmodule ListableComponentsPetal.ViewSelector do
  use Phoenix.LiveComponent

  #use Phoenix.Component
  use PetalComponents

  def render(assigns) do
    ~H"""
      <div>
        <.accordion>
          <:item heading="View Options">
            VIEW OPTS
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
