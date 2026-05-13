defmodule SelectoComponents.Explorer.Controls do
  @moduledoc false

  use Phoenix.Component

  attr(:id, :string, required: true)
  attr(:assigns_map, :map, required: true)

  def panel(assigns) do
    ~H"""
    <.live_component module={SelectoComponents.Form} id={"#{@id}-controls"} {@assigns_map} />
    """
  end
end
