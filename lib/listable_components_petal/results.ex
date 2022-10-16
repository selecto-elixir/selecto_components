defmodule ListableComponentsPetal.Results do
  use Phoenix.Component
  use PetalComponents

  def results_panel(assigns) do
    results = Listable.execute(assigns.listable)
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
