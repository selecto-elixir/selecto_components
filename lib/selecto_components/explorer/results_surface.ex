defmodule SelectoComponents.Explorer.ResultsSurface do
  @moduledoc false

  use Phoenix.Component

  attr(:id, :string, required: true)
  attr(:assigns_map, :map, required: true)

  def panel(assigns) do
    ~H"""
    <.live_component module={SelectoComponents.Results} id={"#{@id}-results"} {@assigns_map} />
    """
  end
end
