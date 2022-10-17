defmodule ListableComponentsPetal.ViewSelector do
  use Phoenix.LiveComponent

  #use Phoenix.Component
  use PetalComponents

  def render(assigns) do
    assigns = assign(assigns, columns: Map.values(assigns.listable.config.columns))
    ~H"""
      <div>
      replace accordion with somethign that pops out from side? Or tabs?
        <.accordion>
          <:item heading="View Options">
            Pick Aggregate or Detail View or Plugged-in view
            <div :for={c <- @columns}>
              <%= c.colid %>
            </div>
          </:item>
          <:item heading="Filter Options">
            <div :for={c <- @columns}>
              <%= c.colid %>
            </div>
          </:item>
          <:item heading="Export Options">
            Export a: spreadsheet, JSON, XML, txt/csv, the SQL query (if permitted), a JSON file containing this config,
            a link with query string to bookmark this config,
          </:item>
        </.accordion>
      </div>
    """
  end

end
