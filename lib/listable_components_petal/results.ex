defmodule ListableComponentsPetal.Results do
  use Phoenix.LiveComponent

  #use Phoenix.Component
  use PetalComponents

  #attr :listable, Listable, required: true
  #attr :view_control, %{}

  def render(assigns) do
    {results, aliases} = Listable.execute(assigns.listable)
    assigns = assign(assigns, results: results)

    ~H"""
      <div>
        Results TODO MAKE FANCY TABLE
          <div :for={r <- @results}>
            <%= inspect(r) %>
          </div>
      </div>
    """
  end

end
