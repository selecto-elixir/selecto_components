defmodule ListableComponentsTailwind.ViewSelector do
  use Phoenix.LiveComponent

  # use Phoenix.Component
  import ListableComponentsTailwind.Components.Common

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
          <.button phx-click="set_active_tab" phx-value-tab="view" phx-target={@myself}>View Tab</.button>
          <.button phx-click="set_active_tab" phx-value-tab="filter" phx-target={@myself}>Filter Tab</.button>
          <.button phx-click="set_active_tab" phx-value-tab="export" phx-target={@myself}>Export Tab</.button>

          <div class={if @active_tab == "view" or @active_tab == nil do "" else "hidden" end} class="border">

      View Type
            <.live_component
              module={ListableComponentsTailwind.Components.RadioTabs}
              id="view_mode"
              fieldname="viewsel"
              view_mode={@view_mode}>
              <:section id="aggregate" label="Aggregate View">

      Group By
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
                    >

              <:filter_form :let={{uuid, index, section, fv}}>
                <.live_component
                    module={ListableComponentsTailwind.Components.FilterForms}
                    id={uuid}
                    uuid={uuid}
                    section={section}
                    index={index}
                    filter={fv}
                    columns={@listable.config.columns}
                    filters_available={@listable.config.filters}
                    >
                </.live_component>
              </:filter_form>

            </.live_component>



          </div>

          <div class={if @active_tab == "export" do "" else "hidden" end} class="border">
            EXPORT SECTION PLANNED
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

      defp _make_string_filter(filter) do
        comp = filter["comp"]
        ignore_case = filter["ignore_case"] ##TODO
        value = filter["value"]
        case comp do
          "=" -> value
          x when x in ~w( != <= >= < >) ->
            {x, value}
          "starts" ->
            {:like, value <> "%"}
          "ends" ->
            {:like, "%" <> value}
        end

      end


      ## Build filters that can be sent to the Listable
      def filter_recurse(listable, filters, section) do
        #### TODO handle errors
        Enum.reduce(Map.get(filters, section, []), [],
        fn
          %{"is_section"=>"Y", "name"=>name, "conj"=> conj} = f, acc -> acc ++ [{section, conj, filter_recurse(listable, filters, section)}]
          f, acc ->
            if listable.config.filters[f["filter"]] do
              listable.config.filters[f["filter"]]
            else

              case listable.config.columns[f["filter"]].type do
                :id ->
                  acc ++ [ {f["filter"], String.to_integer(f["value"])}]
                :string ->
                  acc ++ [ {f["filter"], _make_string_filter(f)}]
              end
            end

        end)
      end

      #Build filter tree that can be sent back to the form
      def filter_form_recurse(listable, filters, section) do
        Enum.reduce(
          Map.get(filters, section, []) |> Enum.sort(fn a, b -> a["index"] <= b["index"] end), [],
        fn
          %{"is_section"=>"Y", "name"=>name, "conj"=> conj} = f, acc ->
              acc ++ [{:section, UUID.uuid4(), conj, filter_form_recurse(listable, filters, f["section_name"])}]
          f, acc -> acc ++ [ {UUID.uuid4(), section, f }]
          end)
      end

      ##TODO validate form entry, display errors to user, keep order stable
      def handle_event("view-update", params, socket) do ##On Change
        filters_by_section = Map.values(Map.get(params, "filters", %{}))
        |> Enum.reduce(%{},
          fn f, acc ->
            ## Custom Form Processor?

            Map.put( acc, f["section"], Map.get(acc, f["section"], []) ++ [f] )
          end )
        ### Just show errors
        #socket = assign(socket, filters: filter_form_recurse(socket.assigns.listable, filters_by_section, "filters[main]"))

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

        filters_by_section = Map.values(Map.get(params, "filters", %{}))
          |> Enum.reduce(%{},
            fn f, acc ->
              ## Custom Form Processor?

              Map.put( acc, f["section"], Map.get(acc, f["section"], []) ++ [f] )
            end )


        ## Build filters walking the filters_by_section

        socket = assign(socket, filters: filter_form_recurse(listable, filters_by_section, "filters[main]"))

        ## THIS CAN FAIL...
        filtered = filter_recurse(listable, filters_by_section, "filters[main]")

        listable =
          Map.put(listable, :set,
          case socket.assigns.view_mode do
            "detail" ->
              selected = params["selected"] |> Map.values()
                |> Enum.sort(fn a,b -> String.to_integer(a["index"]) <= String.to_integer(b["index"]) end)
                |> Enum.map( fn e ->
                  col = columns[ e["field"] ]
                  case col.type do   #move to a validation lib
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
        socket = assign( socket, filters: socket.assigns.filters ++ [{UUID.uuid4(), target, %{"filter"=>new_filter, "value"=>nil}}] )
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
