defmodule ListableComponentsPetal.ViewSelector do
  use Phoenix.LiveComponent

  #use Phoenix.Component
  use PetalComponents

  def render(assigns) do
    assigns = assign(assigns, columns: Map.values(assigns.listable.config.columns))
    ~H"""
      <div>
        <.container max-width="full">
          <.container max-width="full">
            <label>
              <input type="radio" name={:view_type} value="summary"/>
                Aggregate View
            </label>
            <.container max-width="full">
              Group By:
                Display a list of columns which can be group-by,
                each time a new seletion is made allow them to add another.
                Allow them to reorder
            </.container>

            <.container max-width="full">
              Aggregates:
                Display a list of available and selected columns, and when selected
                allow user to pick an aggregate. Allow them to reorder
            </.container>
          </.container>

          <.container max-width="full">
            <label>
              <input type="radio" name={:view_type} value="detail"/>
              Detail View
            </label>
            <.container max-width="full">
              Columns:
                Display a list of available and selected columns, and when selected
                allow user to pick formatting info. Allow them to reorder
            </.container>
            <.container max-width="full">
              Ordering:
                Similar to group-by
            </.container>

          </.container>
          ===Custom View HERE===
        </.container>
      </div>
    """
  end

end
