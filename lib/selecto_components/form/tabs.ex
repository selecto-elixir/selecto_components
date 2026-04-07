defmodule SelectoComponents.Form.Tabs do
  use Phoenix.Component

  alias Phoenix.LiveView.JS
  alias SelectoComponents.Theme

  attr(:active_tab, :string, default: nil)
  attr(:theme, :map, required: true)
  attr(:use_saved_views, :boolean, default: false)

  def nav(assigns) do
    ~H"""
    <div class="mb-4 flex border-b" style="border-color: var(--sc-surface-border)">
      <div class="flex space-x-1" role="tablist" aria-label="Configuration Sections">
        <.tab_button
          active={@active_tab == "view" or @active_tab == nil}
          theme={@theme}
          tab="view"
        >
          View
        </.tab_button>

        <.tab_button active={@active_tab == "filter"} theme={@theme} tab="filter">
          Filters
        </.tab_button>

        <.tab_button :if={@use_saved_views} active={@active_tab == "save"} theme={@theme} tab="save">
          Save View
        </.tab_button>

        <.tab_button active={@active_tab == "export"} theme={@theme} tab="export">
          Export
        </.tab_button>
      </div>
    </div>
    """
  end

  attr(:active, :boolean, required: true)
  attr(:theme, :map, required: true)
  attr(:tab, :string, required: true)
  slot(:inner_block, required: true)

  defp tab_button(assigns) do
    ~H"""
    <button
      type="button"
      role="tab"
      aria-selected={@active}
      aria-controls={"main-tabpanel-#{@tab}"}
      id={"main-tab-#{@tab}"}
      phx-click={JS.push("set_active_tab", value: %{tab: @tab})}
      class={[
        "px-4 py-2 text-sm font-medium",
        if(@active, do: Theme.slot(@theme, :tab_active), else: Theme.slot(@theme, :tab_inactive))
      ]}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end
end
