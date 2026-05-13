defmodule SelectoComponents.Explorer.Shell do
  @moduledoc false

  use Phoenix.Component

  alias SelectoComponents.Theme

  attr(:id, :string, required: true)
  attr(:theme, :map, required: true)
  slot(:controls, required: true)
  slot(:results, required: true)

  def surface(assigns) do
    ~H"""
    <section
      id={"selecto-explorer-#{@id}"}
      data-selecto-explorer-shell
      data-selecto-theme={@theme.id}
      style={Theme.style_attr(@theme)}
      class={[Theme.slot(@theme, :root), "space-y-4"]}
    >
      <div data-selecto-explorer-controls>
        {render_slot(@controls)}
      </div>
      <div data-selecto-explorer-results>
        {render_slot(@results)}
      </div>
    </section>
    """
  end
end
