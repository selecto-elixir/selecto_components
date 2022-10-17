defmodule ListableComponentsPetal.ViewSelector do
  use Phoenix.LiveComponent

  #use Phoenix.Component
  #use PetalComponents
  import ListableComponentsPetal.Components.RadioTabs

  def render(assigns) do
    assigns = assign(assigns, columns: Map.values(assigns.listable.config.columns))
    ~H"""
      <div>
        <.live_component
          module={ListableComponentsPetal.Components.RadioTabs}
          id="view_sel"
          fieldname="viewsel"
          view_sel={@view_sel}
        >
          <:section id="aggregate" label="Aggregate View">
            AGG
          </:section>

          <:section id="detail" label="Detail View">
            DET
          </:section>
        </.live_component>

              Group By:
                Display a list of columns which can be group-by,
                each time a new seletion is made allow them to add another.
                Allow them to reorder
              Aggregates:
                Display a list of available and selected columns, and when selected
                allow user to pick an aggregate. Allow them to reorder

              Columns:
                Display a list of available and selected columns, and when selected
                allow user to pick formatting info. Allow them to reorder
              Ordering:
                Similar to group-by

      </div>
    """
  end


end
