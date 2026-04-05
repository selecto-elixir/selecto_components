defmodule SelectoComponents.Form.TabPanel do
  use Phoenix.Component

  alias SelectoComponents.Theme

  attr(:active_tab, :string, default: nil)
  attr(:tab, :string, required: true)
  attr(:theme, :map, required: true)
  attr(:title, :string, default: nil)
  slot(:inner_block, required: true)

  def panel(assigns) do
    ~H"""
    <div
      role="tabpanel"
      id={"main-tabpanel-#{@tab}"}
      aria-labelledby={"main-tab-#{@tab}"}
      class={if @active_tab == @tab, do: Theme.slot(@theme, :panel) <> " p-3", else: "hidden"}
    >
      <h3 :if={@title} class="text-base-content font-medium mb-2">{@title}</h3>
      {render_slot(@inner_block)}
    </div>
    """
  end
end
