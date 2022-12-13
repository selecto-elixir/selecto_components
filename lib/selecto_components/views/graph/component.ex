defmodule SelectoComponents.Views.Graph.Component do

  alias VegaLite, as: Vl

  use Phoenix.LiveComponent
  import SelectoComponents.Components.Common

  def render(assigns) do

    ~H"""
      <div> GRAPH </div>

    """
  end

end
