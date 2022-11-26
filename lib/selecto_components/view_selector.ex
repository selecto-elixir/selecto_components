defmodule SelectoComponents.ViewSelector do
  use Phoenix.LiveComponent

  # use Phoenix.Component
  import SelectoComponents.Components.Common

  def render(assigns) do
    filters =
      (Map.values(assigns.selecto.config.filters) ++
         [
           Map.values(assigns.selecto.config.columns)
           |> Enum.filter(fn c -> c.type != :custom_column end)
         ])
      |> List.flatten()
      |> Enum.sort(fn a, b -> a.name <= b.name end)
      |> Enum.map(fn
        %{colid: id} = c -> {id, c.name}
        %{id: id} = c -> {id, c.name}
      end)

    assigns =
      assign(assigns,
        columns:
          Map.values(assigns.selecto.config.columns)
          |> Enum.sort(fn a, b -> a.name <= b.name end)
          |> Enum.map(fn c -> {c.colid, c.name, Map.get(c, :format)} end),
        field_filters: filters
      )

    ~H"""
      <div class="border-solid border rounded-md border-grey dark:border-black h-100 overflow-auto p-1">

        <.form for={:view} phx-change="view-validate" phx-submit="view-apply">
          <!--TODO use LiveView.JS? --> <!-- Make tabs component?-->
          <.button type="button" phx-click="set_active_tab" phx-value-tab="view" phx-target={@myself}>View Tab</.button>
          <.button type="button" phx-click="set_active_tab" phx-value-tab="filter" phx-target={@myself}>Filter Tab</.button>
          <.button type="button" phx-click="set_active_tab" phx-value-tab="export" phx-target={@myself}>Export Tab</.button>

          <div class={if @active_tab == "view" or @active_tab == nil do "border-solid border rounded-md border-grey dark:border-black h-90 p-1" else "hidden" end}>

      View Type
            <.live_component
              module={SelectoComponents.Components.RadioTabs}
              id="view_mode"
              fieldname="view_mode"
              view_mode={@view_mode}>
              <:section id="aggregate" label="Aggregate View">

      Group By
                <.live_component
                  module={SelectoComponents.Components.ListPicker}
                  id="group_by"
                  fieldname="group_by"
                  available={Enum.filter( @columns, fn {_f, _n, format} -> format not in [:component, :link] end)}
                  selected_items={@group_by}>
                  <:item_form :let={{id, item, config, index} }>
                    <input name={"group_by[#{id}][field]"} type="hidden" value={item}/>
                    <input name={"group_by[#{id}][index]"} type="hidden" value={index}/>
                    <.live_component
                      module={SelectoComponents.Components.GroupByConfig}
                      id={id}
                      col={@selecto.config.columns[item]}
                      uuid={id}
                      item={item}
                      fieldname="group_by"
                      config={config}/>
                  </:item_form>
                </.live_component>

      Aggregates:
                  <.live_component
                    module={SelectoComponents.Components.ListPicker}
                    id="aggregate"
                    fieldname="aggregate"
                    available={@columns}
                    selected_items={@aggregate}>
                  <:item_form :let={{id, item, config, index}}>
                    <input name={"aggregate[#{id}][field]"} type="hidden" value={item}/>
                    <input name={"aggregate[#{id}][index]"} type="hidden" value={index}/>
                    <.live_component
                      module={SelectoComponents.Components.AggregateConfig}
                      id={id}
                      col={@selecto.config.columns[item]}
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
                    module={SelectoComponents.Components.ListPicker}
                    id="selected"
                    fieldname="selected"
                    available={@columns}
                    selected_items={@selected}>
                  <:item_form :let={{id, item, config, index} }>
                    <input name={"selected[#{id}][field]"} type="hidden" value={item}/>
                    <input name={"selected[#{id}][index]"} type="hidden" value={index}/>
                    <input name={"selected[#{id}][uuid]"} type="hidden" value={id}/>
                    <.live_component
                      module={SelectoComponents.Components.ColumnConfig}
                      id={id}
                      col={@selecto.config.columns[item]}
                      uuid={id}
                      item={item}
                      fieldname="selected"
                      config={config}/>
                  </:item_form>
                </.live_component>


      Order by

                <.live_component
                    module={SelectoComponents.Components.ListPicker}
                    id="order_by"
                    fieldname="order_by"
                    available={@columns}
                    selected_items={@order_by}>
                  <:item_form :let={{id, item, config, index} }>
                    <%!-- MAKE THIS INTO COMPOENT SO IT DOESN"T REDRAW ALL THE TIME and lose its form! --%>
                    <input name={"order_by[#{id}][field]"} type="hidden" value={item}/>
                    <input name={"order_by[#{id}][index]"} type="hidden" value={index}/>

                    <.live_component
                      module={SelectoComponents.Components.OrderByConfig}
                      id={id}
                      col={@selecto.config.columns[item]}
                      item={item}
                      fieldname="order_by"
                      config={config}/>
                  </:item_form>
                </.live_component>

      Pagination
                Per Page:
                <select name="per_page">
                  <option :for={i <- [30]} selected={@per_page == i} value={i}><%= i %></option>
                </select>

              </:section>
            </.live_component>
          </div>

          <div class={if @active_tab == "filter" do "border-solid border rounded-md border-grey dark:border-black h-90  p-1" else "hidden" end}>

      FILTER SECTION
            <.live_component
                    module={SelectoComponents.Components.TreeBuilder}
                    id="filter_tree"
                    available={@field_filters}
                    filters={@filters}
                    >

              <:filter_form :let={{uuid, index, section, fv}}>
                <.live_component
                    module={SelectoComponents.Components.FilterForms}
                    id={uuid}
                    uuid={uuid}
                    section={section}
                    index={index}
                    filter={fv}
                    columns={@selecto.config.columns}
                    custom_filters={@selecto.config.filters}
                    >
                </.live_component>
              </:filter_form>

            </.live_component>



          </div>

          <div class={if @active_tab == "export" do "border-solid border rounded-md border-grey dark:border-black h-90 overflow-auto p-1" else "hidden" end}>
            EXPORT SECTION PLANNED
            export format: spreadsheet, text, csv, PDF?, JSON, XML

            download / send via email (add note)

            collate and send to an email address in a column
          </div>

          <.button>Submit</.button>


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

      @impl true
      def handle_params(params, _uri, socket) do
        selecto = socket.assigns.selecto

        socket =
          assign(socket,
            ### required for selecto components

            executed: false,
            applied_view: nil,
            view_mode: params["view_mode"] || "detail",
            active_tab: params["active_tab"] || "view",
            per_page:
              if params["per_page"] do
                String.to_integer(params["per_page"])
              else
                30
              end,
            page:
              if params["page"] do
                String.to_integer(params["page"])
              else
                0
              end,
            aggregate: Map.get(selecto.domain, :default_aggregate, []) |> set_defaults(),
            group_by: Map.get(selecto.domain, :default_group_by, []) |> set_defaults(),
            order_by: Map.get(selecto.domain, :default_order_by, []) |> set_defaults(),
            selected: Map.get(selecto.domain, :default_selected, []) |> set_defaults(),
            filters: []
          )

        {:noreply, socket}
      end

      defp set_defaults(list) do
        list
        |> Enum.map(fn
          i when is_bitstring(i) -> {UUID.uuid4(), i, %{}}
          {i, conf} -> {UUID.uuid4(), i, conf}
        end)
      end

      defp _make_num_filter(filter) do
        comp = filter["comp"]

        case comp do
          "=" ->
            String.to_integer(filter["value"])

          "null" ->
            nil

          "not_null" ->
            :not_null

          "between" ->
            {:between, String.to_integer(filter["value"]), String.to_integer(filter["value2"])}

          x when x in ~w( != <= >= < >) ->
            {x, String.to_integer(filter["value"])}
        end
      end

      defp _make_string_filter(filter) do
        comp = filter["comp"]
        ## TODO
        ignore_case = filter["ignore_case"]
        value = filter["value"]

        case comp do
          "=" -> value
          "null" -> nil
          "not_null" -> :not_null
          x when x in ~w( != <= >= < >) -> {x, value}
          ### TODO sanitize like value
          "starts" -> {:like, value <> "%"}
          "ends" -> {:like, "%" <> value}
          "contains" -> {:like, "%" <> value <> "%"}
        end
      end

      defp _make_date_filter(filter) do
        comp = filter["comp"]
        ## TODO handle time zones...
        {:ok, value, _} = DateTime.from_iso8601(filter["value"] <> ":00Z")
        {:ok, value2, _} = DateTime.from_iso8601(filter["value2"] <> ":00Z")
        ### Add more options

        {:between, value, value2}
      end

      ## Build filters that can be sent to the selecto
      def filter_recurse(selecto, filters, section) do
        #### TODO handle errors
        Enum.reduce(Map.get(filters, section, []), [], fn
          %{"is_section" => "Y", "uuid" => uuid, "conjunction" => conj} = f, acc ->
            acc ++
              [
                {case conj do
                   "AND" -> :and
                   "OR" -> :or
                 end, filter_recurse(selecto, filters, uuid)}
              ]

          f, acc ->
            if selecto.config.filters[f["filter"]] do
              ## Change this to be called from Selecto instead, eg add a layer between FORM PROCESS and FILTER APPLY TODO???
              acc ++ [selecto.config.filters[f["filter"]].apply.(selecto, f)]
            else
              case selecto.config.columns[f["filter"]].type do
                x when x in [:id, :integer, :float, :decimal] ->
                  acc ++ [{f["filter"], _make_num_filter(f)}]

                :boolean ->
                  acc ++
                    [
                      {f["filter"],
                       case f["value"] do
                         "true" -> true
                         _ -> false
                       end}
                    ]

                :string ->
                  acc ++ [{f["filter"], _make_string_filter(f)}]

                x when x in [:naive_datetime, :utc_datetime] ->
                  acc ++ [{f["filter"], _make_date_filter(f)}]

                {:parameterized, _, enum_conf} ->
                  # TODO check selected against enum_conf.mappings!
                  acc ++ [{f["filter"], f["selected"]}]
              end
            end
        end)
      end

      ## TODO validate form entry, display errors to user, keep order stable
      ## On Change
      @impl true
      def handle_event("view-validate", params, socket) do
        filters =
          Map.get(params, "filters", %{})
          |> Map.values()
          |> Enum.sort(fn a, b -> a <= b end)
          |> Enum.reduce(
            [],
            fn f, acc ->
              acc ++
                [
                  {f["uuid"], f["section"],
                   case Map.get(f, "conjunction", nil) do
                     nil -> f
                     a -> a
                   end}
                ]
            end
          )

        socket = assign(socket, :per_page, String.to_integer(params["per_page"]))

        {:noreply, assign(socket, filters: filters)}
      end

      def do_view(selecto) do
      end

      # on submit
      @impl true
      def handle_event("view-apply", params, socket) do
        try do
          IO.inspect(params, label: "Params")
          # move this somewhere shared
          date_formats = %{
            "MM-DD-YYYY HH:MM" => "MM-DD-YYYY HH:MM",
            "YYYY-MM-DD HH:MM" => "YYYY-MM-DD HH:MM"
          }

          selecto = socket.assigns.selecto
          columns = selecto.config.columns

          selected = params["selected"]
          order_by = Map.get(params, "order_by", %{})
          aggregate = params["aggregate"]
          group_by_params = Map.get(params, "group_by", %{})

          filters_by_section =
            Map.values(Map.get(params, "filters", %{}))
            |> Enum.reduce(
              %{},
              fn f, acc ->
                ## Custom Form Processor?

                Map.put(acc, f["section"], Map.get(acc, f["section"], []) ++ [f])
              end
            )

          ## Build filters walking the filters_by_section
          socket =
            assign(socket,
              filters:
                Map.values(Map.get(params, "filters", %{}))
                |> Enum.map(fn
                  %{"is_section" => "Y"} = f -> {f["uuid"], f["section"], f["conjunction"]}
                  f -> {f["uuid"], f["section"], f}
                end)
            )

          ## THIS CAN FAIL...
          filtered = filter_recurse(selecto, filters_by_section, "filters")

          detail_columns =
            selected
            |> Map.values()
            |> Enum.sort(fn a, b ->
              String.to_integer(a["index"]) <= String.to_integer(b["index"])
            end)
            |> IO.inspect(label: "Detail Cols")

          detail_selected =
            detail_columns
            |> Enum.map(fn e ->
              col = columns[e["field"]]
              uuid = e["uuid"]
              # move to a validation lib
              case col.type do
                x when x in [:naive_datetime, :utc_datetime] ->
                  {:field, {:to_char, {col.colid, date_formats[e["format"]]}}, uuid}

                :custom_column ->
                  case Map.get(col, :requires_select) do
                    x when is_list(x) -> {:row, col.requires_select, uuid}
                    x when is_function(x) -> {:row, col.requires_select.(e), uuid}
                    nil -> {:field, col.colid, uuid}
                  end
                  _ ->
                    {:field, col.colid, uuid}
              end
            end)
            |> List.flatten()
            |> IO.inspect(label: "Detail Sel")

          detail_order_by =
            order_by
            |> Map.values()
            |> Enum.sort(fn a, b -> a["index"] <= b["index"] end)
            |> Enum.map(fn e ->
              case e["dir"] do
                "desc" -> {:desc, e["field"]}
                _ -> e["field"]
              end
            end)
            |> IO.inspect(label: "Detail Order")

          detail_set = %{
            columns: detail_columns,
            selected: detail_selected,
            order_by: detail_order_by,
            filtered: filtered,
            group_by: [],
            groups: []
          }

          selecto =
            Map.put(
              selecto,
              :set,
              case params["view_mode"] do
                "detail" ->
                  detail_set

                ### TODO add config
                "aggregate" ->
                  aggregate =
                    aggregate
                    |> Map.values()
                    |> Enum.sort(fn a, b -> a["index"] <= b["index"] end)
                    |> Enum.map(fn e ->
                      {String.to_atom(
                         case e["format"] do
                           nil -> "count"
                           _ -> e["format"]
                         end
                       ), e["field"]}
                    end)

                  group_by =
                    group_by_params
                    |> Map.values()
                    |> Enum.sort(fn a, b -> a["index"] <= b["index"] end)
                    |> Enum.map(fn e ->
                      col = columns[e["field"]]
                      uuid = e["uuid"]

                      ### Group by filter, _select, format...
                      sel =
                        if Map.get(col, :group_by_filter_select) do
                          case col.group_by_filter_select do
                            x when is_list(x) -> {:row, col.group_by_filter_select, uuid}
                            x when is_function(x) -> {:row, col.group_by_filter_select.(e), uuid}
                          end
                        else
                          case col.type do
                            x when x in [:naive_datetime, :utc_datetime] ->
                              {:extract, col.colid, e["format"]}


                            :custom_column ->
                              case Map.get(col, :requires_select) do
                                x when is_list(x) -> {:row, col.requires_select, uuid}
                                x when is_function(x) -> {:row, col.requires_select.(e), uuid}
                                nil -> col.colid
                              end
                              _ ->
                                col.colid

                          end
                        end
                      {col, sel}
                    end)

                  %{
                    groups: group_by,
                    gb_params: group_by_params,
                    aggregates: aggregate,
                    selected: Enum.map(group_by, fn {_c, sel} -> sel end) ++ aggregate,
                    filtered: filtered,
                    group_by: [
                      {:rollup, Enum.map(1..Enum.count(group_by), fn g -> {:literal, g} end)}
                    ],
                    order_by: Enum.map(1..Enum.count(group_by), fn g -> {:literal, g} end),
                    detail_set: detail_set
                  }
              end
            )

          ### Set these assigns to reset the view!
          {:noreply,
           assign(socket,
             selecto: selecto,
             applied_view: socket.assigns.view_mode,
             executed: true,
             page: 0,
             per_page: String.to_integer(params["per_page"])
           )}
        rescue
          e ->
            IO.inspect(e)
            {:noreply, socket}
        end
      end

      @impl true
      def handle_event("treedrop", par, socket) do
        new_filter = par["element"]
        target = par["target"]

        socket =
          assign(socket,
            filters:
              socket.assigns.filters ++
                case new_filter do
                  "__AND__" -> [{UUID.uuid4(), target, "AND"}]
                  "__OR__" -> [{UUID.uuid4(), target, "OR"}]
                  _ -> [{UUID.uuid4(), target, %{"filter" => new_filter, "value" => nil}}]
                end
          )

        {:noreply, socket}
      end

      def handle_event("filter_remove", params, socket) do
        IO.inspect(params)

        socket =
          assign(socket,
            filters:
              socket.assigns.filters |> Enum.filter( fn
                {u, s, _c} -> u != params["uuid"] && s != params["uuid"]
              end )
          )

        {:noreply, socket}
      end

      def handle_event("agg_add_filters", params, socket) do
        selecto =
          Map.put(
            socket.assigns.selecto,
            :set,
            socket.assigns.selecto.set.detail_set
          )
          |> Selecto.filter(Enum.map(params, fn {f, v} -> {f, v} end))

        IO.inspect(params)
        IO.inspect(socket.assigns.filters)

        socket =
          assign(socket,
            selecto: selecto,
            view_mode: "detail",
            applied_view: "detail",
            filters:
              Enum.filter(socket.assigns.filters, fn
                  {_id, "filters", %{} = f} -> !Map.has_key?(params, f["filter"])
                  _ -> true
              end) ++
                Enum.map(params, fn {f, v} ->
                  {UUID.uuid4(), "filters", %{"filter" => f, "value" => v}}
                end)
          )

        {:noreply, socket}
      end

      @impl true
      def handle_info({:set_active_tab, tab}, socket) do
        {:noreply, assign(socket, active_tab: tab)}
      end

      @impl true
      def handle_info({:view_set, view}, socket) do
        {:noreply, assign(socket, view_mode: view)}
      end

      @impl true
      def handle_info({:set_detail_page, page}, socket) do
        {:noreply, assign(socket, page: String.to_integer(page))}
      end

      @impl true
      def handle_info({:list_picker_remove, list, item}, socket) do
        list = String.to_atom(list)

        socket =
          assign(socket, list, Enum.filter(socket.assigns[list], fn {id, _, _} -> id != item end))

        {:noreply, socket}
      end

      ### TODO fix this up

      @impl true
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

      @impl true
      def handle_info({:list_picker_add, list, item}, socket) do
        list = String.to_atom(list)
        config = %{}
        id = UUID.uuid4()
        socket = assign(socket, list, Enum.uniq(socket.assigns[list] ++ [{id, item, config}]))
        {:noreply, socket}
      end

      # :list_picker_config_item, list, uuid, newconf
    end
  end
end
