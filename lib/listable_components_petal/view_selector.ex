defmodule ListableComponentsPetal.ViewSelector do
  use Phoenix.Component
  use PetalComponents


  def view_panel(assigns) do
    ~H"""
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

    """
  end

end
