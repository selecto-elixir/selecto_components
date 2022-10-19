defmodule ListableComponentsPetal.ViewSelector do
  use Phoenix.LiveComponent

  # use Phoenix.Component
  # use PetalComponents

  def render(assigns) do
    assigns =
      assign(assigns,
        columns:
          Map.values(assigns.listable.config.columns) |> Enum.map(fn c -> {c.colid, c.name} end),
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
              <:item_form :let={{id, item, config} }>
                Group By: <%= id %> <%= item %> (config)
              </:item_form>
            </.live_component>

            Aggregates:
                Display a list of available and selected columns, and when selected
                allow user to pick an aggregate. Allow them to reorder


          </:section>

          <:section id="detail" label="Detail View">
            Columns
            <.live_component
                module={ListableComponentsPetal.Components.ListPicker}
                id="selected"
                fieldname="selected"
                available={@columns}
                selected_items={@selected}>
              <:item_form :let={{id, item, config} }>
                <% IO.inspect(@listable.config.columns[item]) %>
                <%= case @listable.config.columns[item].type do%>
                  <% :string -> %>
                    String: <%= id %> / <%= item %> (config)
                  <% x when x in [:int, :id] -> %>
                    Int/ID: <%= id %> / <%= item %> (config)
                  <% :float -> %>
                    Float: <%= id %> / <%= item %> (config)
                  <% :number -> %>
                    Decimal: <%= id %> / <%= item %> (config)
                  <% :boolean -> %>
                    Bool: <%= id %> / <%= item %> (config)
                  <% :naive_datetime -> %>
                    Datetime: <%= id %> / <%= item %> (config)

                  <% _ -> %>
                    Other: <%= id %> / <%= item %> (config)
                  <% end %>
              </:item_form>
            </.live_component>
            Order by
            <.live_component
                module={ListableComponentsPetal.Components.ListPicker}
                id="order_by"
                fieldname="order_by"
                available={@columns}
                selected_items={@order_by}>
              <:item_form :let={{id, item, config} }>
                Order By:
                  <%= id %> /
                  <%= item %>
                  (config)
              </:item_form>
            </.live_component>

            Columns:
              Display a list of available and selected columns, and when selected
              allow user to pick formatting info. Allow them to reorder
            Ordering:
              Similar to group-by

          </:section>
        </.live_component>

        <button phx-click="apply_config" phx-target={@myself}>Submit</button>

      </div>
    """
  end


  def handle_event("apply_config", params, socket) do
    send(self(), {:apply_config})
    {:noreply, socket}
  end

  defmacro __using__(opts \\ []) do
    quote do
      ### These run in the 'use'ing liveview's context
      def handle_info({:apply_config}, socket) do
        listable = socket.assigns.listable
        IO.inspect(socket.assigns.selected)
        listable = Map.put(listable, :set, %{
          selected: Enum.map(socket.assigns.selected, fn {_, item, _} -> item end),
          order_by: [], #Enum.map(socket.assigns.order_by, fn {_, item, _} -> item end),
          filtered: [],
          group_by: [],
        })
        {:noreply, assign(socket, listable: listable)}
      end

      def handle_info({:view_set, view}, socket) do
        {:noreply, assign(socket, view_sel: view)}
      end

      def handle_info({:list_picker_remove, list, item}, socket) do
        list = String.to_atom(list)
        socket = assign(socket, list, Enum.filter(socket.assigns[list], fn {id, _, _} -> id != item end))
        {:noreply, socket}
      end

      def handle_info({:list_picker_add, list, item}, socket) do
        list = String.to_atom(list)
        id = UUID.uuid4()
        socket = assign(socket, list, Enum.uniq(socket.assigns[list] ++ [{id, item, %{}}]))
        {:noreply, socket}
      end

      # :list_picker_config_item, list, uuid, newconf

    end
  end
end
