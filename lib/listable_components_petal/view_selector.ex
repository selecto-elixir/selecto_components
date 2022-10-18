defmodule ListableComponentsPetal.ViewSelector do
  use Phoenix.LiveComponent

  #use Phoenix.Component
  #use PetalComponents
  import ListableComponentsPetal.Components.RadioTabs
  import ListableComponentsPetal.Components.ListPicker


  def render(assigns) do
    assigns = assign(assigns,
      columns: Map.values(assigns.listable.config.columns),
    )
    ~H"""
      <div>
        <.live_component
          module={ListableComponentsPetal.Components.RadioTabs}
          id="view_sel"
          fieldname="viewsel"
          view_sel={@view_sel}
        >
          <:section id="aggregate" label="Aggregate View">

            <.live_component
              module={ListableComponentsPetal.Components.ListPicker}
              id="group_by"
              fieldname="group_by"
              available={@columns}
              selected_items={@group_by}
            >
              <:item_form :let={item}>
                Selected: <%= item %>
              </:item_form>
            </.live_component>

            Aggregates:
                Display a list of available and selected columns, and when selected
                allow user to pick an aggregate. Allow them to reorder


          </:section>

          <:section id="detail" label="Detail View">
            Columns:
              Display a list of available and selected columns, and when selected
              allow user to pick formatting info. Allow them to reorder
            Ordering:
              Similar to group-by

          </:section>
        </.live_component>



      </div>
    """
  end


  defmacro __using__(opts \\ []) do
    quote do
      ### These run in the 'use'ing liveview's context
      def handle_info({:view_set, view }, socket) do
        {:noreply, assign(socket, view_sel: view)}
      end

      def handle_info({:list_picker_add, list, item },socket) do
        socket = assign(socket, group_by: Enum.uniq(socket.assigns.group_by ++ [item]) )
        {:noreply, socket}
      end


    end

  end



end
