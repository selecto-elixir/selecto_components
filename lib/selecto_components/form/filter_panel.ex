defmodule SelectoComponents.Form.FilterPanel do
  use Phoenix.Component

  alias SelectoComponents.Theme

  attr(:active_tab, :string, default: nil)
  attr(:theme, :map, required: true)
  attr(:filter_sets_adapter, :any, default: nil)
  attr(:user_id, :any, default: nil)
  attr(:domain, :any, default: nil)
  attr(:current_filters, :list, default: [])
  attr(:id, :any, required: true)
  attr(:tree_builder_suffix, :string, required: true)
  attr(:available_filters, :list, required: true)
  attr(:filters, :list, default: [])

  slot(:filter_form, required: true)

  def panel(assigns) do
    ~H"""
    <div
      role="tabpanel"
      id="main-tabpanel-filter"
      aria-labelledby="main-tab-filter"
      class={if @active_tab == "filter", do: Theme.slot(@theme, :panel) <> " p-3", else: "hidden"}
    >
      <.live_component
        :if={@filter_sets_adapter}
        module={SelectoComponents.Filter.FilterSets}
        id="filter_sets"
        user_id={@user_id}
        domain={@domain}
        current_filters={@current_filters}
        filter_sets_adapter={@filter_sets_adapter}
      />

      <.live_component
        module={SelectoComponents.Components.TreeBuilder}
        id={"#{@id}_tree_builder_#{@tree_builder_suffix}"}
        theme={@theme}
        available={@available_filters}
        filters={@filters}
      >
        <:filter_form :let={filter_context}>
          {render_slot(@filter_form, filter_context)}
        </:filter_form>
      </.live_component>
    </div>
    """
  end
end
