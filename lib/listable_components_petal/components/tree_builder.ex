defmodule ListableComponentsPetal.Components.TreeBuilder do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
      <div>
        <div> Fitler tree builder</div>
        <div> List Of Filters </div>

        <div> Build Area </div>

      </div>
    """
  end

end
