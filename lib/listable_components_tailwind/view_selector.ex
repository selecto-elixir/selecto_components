defmodule ListableComponentsTailwind.ViewSelector do
  use Phoenix.LiveComponent

  # use Phoenix.Component

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

        <.form for={:view} phx-change="view-update" phx-submit="view-apply">
          <!--TODO use LiveView.JS? --> <!-- Make tabs component?-->
          <button phx-click="set_active_tab" phx-value-tab="view" phx-target={@myself}>View Tab</button>
          <button phx-click="set_active_tab" phx-value-tab="filter" phx-target={@myself}>Filter Tab</button>
          <button phx-click="set_active_tab" phx-value-tab="export" phx-target={@myself}>Export Tab</button>

          <div class={if @active_tab == "view" or @active_tab == nil do "" else "hidden" end} class="border">
            <.live_component
              module={ListableComponentsTailwind.Components.RadioTabs}
              id="view_mode"
              fieldname="viewsel"
              view_mode={@view_mode}>
              <:section id="aggregate" label="Aggregate View">
                <.live_component
                  module={ListableComponentsTailwind.Components.ListPicker}
                  id="group_by"
                  fieldname="group_by"
                  available={@columns}
                  selected_items={@group_by}>
                  <:item_form :let={{id, item, _config, index} }>
                    <input name={"group_by[#{id}][field]"} type="hidden" value={item}/>
                    <input name={"group_by[#{id}][index]"} type="hidden" value={index}/>
                    Group By: <%= id %> <%= item %> (config)
                  </:item_form>
                </.live_component>
                  Aggregates:
                  <.live_component
                    module={ListableComponentsTailwind.Components.ListPicker}
                    id="aggregate"
                    fieldname="aggregate"
                    available={@columns}
                    selected_items={@aggregate}>
                  <:item_form :let={{id, item, config, index}}>
                    <input name={"aggregate[#{id}][field]"} type="hidden" value={item}/>
                    <input name={"aggregate[#{id}][index]"} type="hidden" value={index}/>
                    <.live_component
                      module={ListableComponentsTailwind.Components.AggregateConfig}
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
                    module={ListableComponentsTailwind.Components.ListPicker}
                    id="selected"
                    fieldname="selected"
                    available={@columns}
                    selected_items={@selected}>
                  <:item_form :let={{id, item, config, index} }>
                    <input name={"selected[#{id}][field]"} type="hidden" value={item}/>
                    <input name={"selected[#{id}][index]"} type="hidden" value={index}/>
                    <.live_component
                      module={ListableComponentsTailwind.Components.ColumnConfig}
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
                    module={ListableComponentsTailwind.Components.ListPicker}
                    id="order_by"
                    fieldname="order_by"
                    available={@columns}
                    selected_items={@order_by}>
                  <:item_form :let={{id, item, config, index} }>
                    <input name={"order_by[#{id}][field]"} type="hidden" value={item}/>
                    <input name={"order_by[#{id}][index]"} type="hidden" value={index}/>
                    <%= item %>
                    <label><input name={"order_by[#{id}][dir]"} type="radio" value="asc" checked={Map.get(config, "dir")=="asc"}/>Ascending</label>
                    <label><input name={"order_by[#{id}][dir]"} type="radio" value="desc" checked={Map.get(config, "dir")=="desc"}/>Descending</label>
                  </:item_form>
                </.live_component>
              </:section>
            </.live_component>


          </div>
          <div class={if @active_tab == "filter" do "" else "hidden" end} class="border">
            FILTER SECTION
            <.live_component
                    module={ListableComponentsTailwind.Components.TreeBuilder}
                    id="filter_tree"
                    available={@columns}
                    filters={@filters}
                    selected_items={@filters}>
              <:filter_form :let={{uuid, section, filter, value}}>
                <.live_component
                    module={ListableComponentsTailwind.Components.FilterForms}
                    id={uuid}
                    uuid={uuid}
                    section={section}
                    filter={filter}
                    value={value}
                    columns={@listable.config.columns}
                    filters_available={@listable.config.filters}
                    >
                </.live_component>

              </:filter_form>
            </.live_component>
            Select a filterable column or filter and add filter criteria

          </div>

          <div class={if @active_tab == "export" do "" else "hidden" end} class="border">
            EXPORT SECTION
            export format: spreadsheet, text, csv, PDF?, JSON, XML

            download / send via email (add note)

            collate and send to an email address in a column
          </div>
          <button>Submit</button>
        </.form>
      </div>

    """
  end



  def handle_event("set_active_tab", params, socket) do
    send(self(), {:set_active_tab, params["tab"]})
    {:noreply, socket}
  end

  defmacro __using__(_opts \\ []) do
    quote do

      ### These run in the 'use'ing liveview's context

      def handle_event("view-update", par, socket) do ##On Change
        {:noreply, socket}
      end

      def handle_event("view-apply", params, socket) do #on submit

        IO.inspect(params)

        date_formats = %{ #move this somewhere shared
          "MM-DD-YYYY HH:MM" => "MM-DD-YYYY HH:MM",
          "YYYY-MM-DD HH:MM" => "YYYY-MM-DD HH:MM",
        };
        listable = socket.assigns.listable
        filtered = listable.set.filtered
        columns = listable.config.columns
        listable =
          Map.put(listable, :set,
          case socket.assigns.view_mode do
            "detail" ->
              selected = params["selected"] |> Map.values()
                |> Enum.sort(fn a,b -> String.to_integer(a["index"]) <= String.to_integer(b["index"]) end)
                |> Enum.map( fn e ->
                  col = columns[ e["field"] ]
                  case col.type do
                    x when x in [:naive_datetime, :utc_datetime] ->
                      {:to_char, {col.colid, date_formats[e["format"]]}, col.colid }


                    _ -> col.colid
                  end

                end)
              order_by = Map.get(params, "order_by", %{}) |> Map.values() |> Enum.sort(fn a,b -> a["index"] <= b["index"] end)
                |> Enum.map(
                  fn e ->
                    case e["dir"] do
                      "desc" -> {:desc, e["field"]}
                      _ -> e["field"]
                    end
                  end)

                %{  ### TODO add config
                selected: selected,
                order_by: order_by,
                filtered: filtered,
                group_by: []
              }
            "aggregate" ->
              aggregate = params["aggregate"] |> Map.values() |> Enum.sort(fn a,b -> a["index"] <= b["index"] end)
                |> Enum.map( fn e -> e["field"] end) ### TODO apply config

              group_by = Map.get(params, "group_by", %{}) |> Map.values() |> Enum.sort(fn a,b -> a["index"] <= b["index"] end)
                |> Enum.map( fn e -> e["field"] end) ### TODO apply config

              %{  ### todo add config
                selected: aggregate,
                filtered: filtered,
                group_by: group_by,
                order_by: [],

              }

          end )
        {:noreply, assign(socket, listable: listable)}
      end


      def handle_event("treedrop", par, socket) do
        new_filter = par["element"]
        target = par["target"]

        socket = assign( socket, filters: socket.assigns.filters ++ [{UUID.uuid4(), target, new_filter, nil}] )


        {:noreply, socket}
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
