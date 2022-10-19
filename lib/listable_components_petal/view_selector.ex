defmodule ListableComponentsPetal.ViewSelector do
  use Phoenix.LiveComponent

  # use Phoenix.Component
  # use PetalComponents

  def render(assigns) do
    assigns =
      assign(assigns,
        columns:
          Map.values(assigns.listable.config.columns)
          |> Enum.sort(fn a, b -> a.name <= b.name end)
            |> Enum.map(fn c -> {c.colid, c.name} end)

      )

    ~H"""
      <div>
        <.form for={:view} phx-change="view-update">
        <button phx-click="set_active_tab" phx-value-tab="view" phx-target={@myself}>View Tab</button>
        <button phx-click="set_active_tab" phx-value-tab="filter" phx-target={@myself}>Filter Tab</button>
        <button phx-click="set_active_tab" phx-value-tab="export" phx-target={@myself}>Export Tab</button>

        <div :if={@active_tab == "view" or @active_tab == nil} class="border">
          <.live_component
            module={ListableComponentsPetal.Components.RadioTabs}
            id="view_mode"
            fieldname="viewsel"
            view_mode={@view_mode}
          >
            <:section id="aggregate" label="Aggregate View">

              <.live_component
                module={ListableComponentsPetal.Components.ListPicker}
                id="group_by"
                fieldname="group_by"
                available={@columns}
                selected_items={@group_by}
              >
                <:item_form :let={{id, item, _config} }>
                  Group By: <%= id %> <%= item %> (config)
                </:item_form>
              </.live_component>

              Aggregates:
                  Display a list of available and selected columns, and when selected
                  allow user to pick an aggregate. Allow them to reorder

                <.live_component
                  module={ListableComponentsPetal.Components.ListPicker}
                  id="aggregate"
                  fieldname="aggregate"
                  available={@columns}
                  selected_items={@aggregate}>

                <:item_form :let={{id, item, config}}>
                  <.live_component
                    module={ListableComponentsPetal.Components.AggregateConfig}
                    id={id}
                    col={@listable.config.columns[item]}
                    uuid={id}
                    item={item}
                    fieldname="aggregate"
                    config={config}/>
                </:item_form>
              </.live_component>

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
                  <input name={"selected[#{id}]"} type="hidden" value={item}/>
                  <.live_component
                    module={ListableComponentsPetal.Components.ColumnConfig}
                    id={id}
                    col={@listable.config.columns[item]}
                    uuid={id}
                    item={item}
                    fieldname="selected"
                    config={config}/>
                </:item_form>
              </.live_component>

              Order by
              <.live_component
                  module={ListableComponentsPetal.Components.ListPicker}
                  id="order_by"
                  fieldname="order_by"
                  available={@columns}
                  selected_items={@order_by}>
                <:item_form :let={{id, item, _config} }>
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


        </div>
        <div :if={@active_tab == "filter"} class="border">
          FILTER SECTION

          Select a filterable column or filter and add filter criteria

        </div>

        <div :if={@active_tab == "export"} class="border">
          EXPORT SECTION
          export format: spreadsheet, text, csv, PDF?, JSON, XML

          download / send via email (add note)

          collate and send to an email address in a column
        </div>
        <button phx-click="apply_config" phx-target={@myself}>Submit</button>
        </.form>
      </div>

    """
  end


  def handle_event("set_active_tab", params, socket) do
    IO.inspect(params)
    send(self(), {:set_active_tab, params["tab"]})
    {:noreply, socket}
  end

  defmacro __using__(_opts \\ []) do
    quote do

      def handle_event("view-update", par, socket) do
        IO.inspect(par)
        {:noreply, socket}
      end


      ### These run in the 'use'ing liveview's context
      def handle_info({:apply_config}, socket) do
        listable = socket.assigns.listable
        IO.inspect(socket.assigns.selected)

        listable =
          Map.put(listable, :set,
          case socket.assigns.view_mode do
            "detail" ->
              %{  ### TODO add config
                selected: Enum.map(socket.assigns.selected, fn {_, item, _} -> item end),
                order_by: Enum.map(socket.assigns.order_by, fn {_, item, _} -> item end),
                filtered: [],
                group_by: []
              }
            "aggregate" ->
              %{  ### todo add config
                selected: Enum.map(socket.assigns.aggregate, fn {_, item, _} -> {:count, item} end ),
                filtered: [],
                group_by: Enum.map(socket.assigns.group_by, fn {_, item, _} -> item end),
                order_by: [],

              }

          end )


        {:noreply, assign(socket, listable: listable)}
      end

      def handle_info({:set_active_tab, tab}, socket) do
        {:noreply, assign(socket, active_tab: tab)}
      end

      def handle_info({:view_set, view}, socket) do
        {:noreply, assign(socket, view_mode: view)}
      end

      def handle_info({:list_picker_remove, list, item}, socket) do
        list = String.to_atom(list)

        socket =
          assign(socket, list, Enum.filter(socket.assigns[list], fn {id, _, _} -> id != item end))

        {:noreply, socket}
      end

      ### TODO fix this up
      def handle_info({:list_picker_move, list, uuid, direction}, socket) do
        list = String.to_atom(list)
        item_list = socket.assigns[list]
        item_index = Enum.find_index(item_list, fn {i, _, _} -> i == uuid end)
        {item, item_list} = List.pop_at(item_list, item_index)

        item_list =
          List.insert_at(
            item_list,
            case direction do
              "up" -> item_index - 1
              "down" -> item_index + 1
            end,
            item
          )

        socket = assign(socket, list, item_list)
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
