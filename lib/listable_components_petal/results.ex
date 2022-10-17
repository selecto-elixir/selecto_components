defmodule ListableComponentsPetal.Results do
  use Phoenix.LiveComponent

  #use Phoenix.Component
  use PetalComponents

  #attr :listable, Listable, required: true
  #attr :view_control, %{}

  def render(assigns) do
    {results, aliases} = Listable.execute(assigns.listable)
    assigns = assign(assigns, results: results, aliases: aliases)

    ~H"""
    <div>
      <.container max-width="full">
        <.table>
          <.tr>
            <.th :for={r <- @aliases}>
              <%= r %>
            </.th>
          </.tr>
          <.tr :for={r <- @results}>
            <.td :for={c <- @aliases}>
              <%= r[c] %>
            </.td>
          </.tr>
        </.table>
      </.container>
    </div>
    """
  end

end
