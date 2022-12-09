defmodule SelectoComponents.Form do
  use Phoenix.LiveComponent

  import SelectoComponents.Components.Common

  @doc """
  Form for configuing Selecto View

  attrs:
  selecto: the selecto structure
  view_config: attr which contains the data to draw the view

  """

  def render(assigns) do
    assigns =
      assign(assigns,
        columns: build_column_list(assigns.selecto),
        field_filters: build_filter_list(assigns.selecto)
      )

    ~H"""
      <div class="border-solid border rounded-md border-grey dark:border-black h-100 overflow-auto p-1">
        <%= @active_tab %>
        <.form for={:view} phx-change="view-validate" phx-submit="view-apply">
          <!--TODO use LiveView.JS? --> <!-- Make tabs component?-->
          <.button type="button" phx-click="set_active_tab" phx-value-tab="view">View Tab</.button>
          <.button type="button" phx-click="set_active_tab" phx-value-tab="filter">Filter Tab</.button>
          <.button type="button" phx-click="set_active_tab" phx-value-tab="export">Export Tab</.button>

          <div class={if @active_tab == "view" or @active_tab == nil do "border-solid border rounded-md border-grey dark:border-black h-90 p-1" else "hidden" end}>

      View Type
            <.live_component
              module={SelectoComponents.Components.RadioTabs}
              id="view_mode"
              fieldname="view_mode"
              view_mode={@view_config.view_mode}>

              <:section id="aggregate" label="Aggregate View">
      Group By
                <.live_component
                  module={SelectoComponents.Components.ListPicker}
                  id="group_by"
                  fieldname="group_by"
                  available={Enum.filter( @columns, fn {_f, _n, format} -> format not in [:component, :link] end)}
                  selected_items={@view_config.group_by}>
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
                    selected_items={@view_config.aggregate}>
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
                    selected_items={@view_config.selected}>
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
                    selected_items={@view_config.order_by}>
                  <:item_form :let={{id, item, config, index} }>
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
                  <option :for={i <- [30]} selected={@view_config.per_page == i} value={i}><%= i %></option>
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
                    filters={@view_config.filters}
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

  defmacro __using__(_opts \\ []) do
    quote do
      ### These run in the 'use'ing liveview's context

      import SelectoComponents.Helpers
      import SelectoComponents.Helpers.Filters

      @impl true
      def handle_params(%{"view_mode" => _m} = params, _uri, socket) do
        IO.puts("Handle Params")
        socket = params_to_state(params, socket)
        {:noreply, view_from_params(params, socket)}
      end

      ### accept default config
      def handle_params(params, _uri, socket) do
        {:noreply, socket}
      end

      def handle_event("set_active_tab", params, socket) do
        IO.inspect(params)
        {:noreply, assign(socket, active_tab: params["tab"] )}
      end

      ## TODO REDO this
      @impl true
      def handle_event("view-validate", params, socket) do
        socket = filter_params_to_state(params, socket)
        {:noreply, socket}
      end

      @impl true
      ### TODO view-apply should call view_from_params, and also update URI to include params
      def handle_event("view-apply", params, socket) do
        {:noreply, view_from_params(params, state_to_url(params, socket))}
      end

      @impl true
      def handle_event("treedrop", par, socket) do
        new_filter = par["element"]
        target = par["target"]

        socket =
          assign(socket,
            view_config: %{
              socket.assigns.view_config
              | filters:
                  socket.assigns.view_config.filters ++
                    case new_filter do
                      "__AND__" ->
                        [{UUID.uuid4(), target, "AND"}]

                      "__OR__" ->
                        [{UUID.uuid4(), target, "OR"}]

                      _ ->
                        [
                          {UUID.uuid4(), target,
                           %{"filter" => new_filter, "value" => nil, "index" => 2000}}
                        ]
                    end
            }
          )

        {:noreply, socket}
      end

      def handle_event("filter_remove", params, socket) do
        socket =
          assign(socket,
            view_config: %{
              socket.assigns.view_config
              | filters:
                  socket.assigns.view_config.filters
                  |> Enum.filter(fn
                    {u, s, _c} -> u != params["uuid"] && s != params["uuid"]
                  end)
            }
          )

        {:noreply, socket}
      end

      def handle_event("agg_add_filters", params, socket) do
        view_params =
          %{socket.assigns.used_params | "view_mode" => "detail"}
          |> Map.put(
            "filters",
            Enum.reduce(
              params,
              ### TODO remove existing section=filters uses of this filter
              Map.get(socket.assigns.used_params, "filters", %{}),
              fn {f, v}, acc ->
                newid = UUID.uuid4()

                Map.put(acc, newid, %{
                  "comp" => "=",
                  "filter" => f,
                  "index" => "0",
                  "section" => "filters",
                  "uuid" => newid,
                  "value" => v,
                  "value2" => ""
                })
              end
            )
          )

        socket =
          assign(socket,
            view_config: %{
              socket.assigns.view_config
              | view_mode: "detail",
                filters:
                  Enum.filter(socket.assigns.view_config.filters, fn
                    {_id, "filters", %{} = f} -> !Map.has_key?(params, f["filter"])
                    _ -> true
                  end) ++
                    Enum.map(params, fn {f, v} ->
                      {UUID.uuid4(), "filters", %{"filter" => f, "value" => v}}
                    end)
            }
          )

        {:noreply, view_from_params(view_params, state_to_url(view_params, socket))}
      end



      @impl true
      def handle_info({:view_set, view}, socket) do
        {:noreply, assign(socket, view_config: %{socket.assigns.view_config | view_mode: view})}
      end

      @impl true
      def handle_info({:set_detail_page, page}, socket) do
        {:noreply, assign(socket, page: String.to_integer(page))}
      end

      @impl true
      def handle_info({:list_picker_remove, list, item}, socket) do
        list = String.to_atom(list)

        socket =
          assign(socket,
            view_config:
              Map.put(
                socket.assigns.view_config,
                list,
                Enum.filter(socket.assigns.view_config[list], fn {id, _, _} -> id != item end)
              )
          )

        {:noreply, socket}
      end

      ### TODO fix this up

      @impl true
      def handle_info({:list_picker_move, list, uuid, direction}, socket) do
        list = String.to_atom(list)
        item_list = socket.assigns.view_config[list]
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

        socket = assign(socket, view_config: Map.put(socket.assigns.view_config, list, item_list))
        {:noreply, socket}
      end

      @impl true
      def handle_info({:list_picker_add, list, item}, socket) do
        list = String.to_atom(list)
        config = %{}
        id = UUID.uuid4()

        socket =
          assign(socket,
            view_config:
              Map.put(
                socket.assigns.view_config,
                list,
                Enum.uniq(socket.assigns.view_config[list] ++ [{id, item, config}])
              )
          )

        {:noreply, socket}
      end

      defp view_filter_process(params, item_name) do
        Map.get(params, item_name, %{})

        |> IO.inspect()
        |> Enum.sort(fn {_, %{"index" => index}}, {_, %{"index" => index2}} ->
          String.to_integer(index) <= String.to_integer(index2)
        end)
        |> Enum.reduce([], fn
            {u, %{"conjunction"=>conj} = f}, acc -> acc ++ [{u, f["section"], conj}]
            {u, f}, acc -> acc ++ [{u, f["section"], f}]
          end)

      end

      defp view_param_process(params, item_name, section) do
        Map.get(params, item_name, %{})
        |> Enum.reduce([], fn {u, f}, acc -> acc ++ [{u, f[section], f}] end)
        |> Enum.sort(fn {_u, _s, %{"index" => index}}, {_u2, _s2, %{"index" => index2}} ->
          String.to_integer(index) <= String.to_integer(index2)
        end)
      end

      defp view_from_params(params, socket) do
        try do
          IO.inspect(params, label: "View From Params")

          selecto = socket.assigns.selecto
          columns = selecto.config.columns

          filters_by_section =
            Map.values(Map.get(params, "filters", %{}))
            |> Enum.reduce(%{}, fn f, acc ->
              Map.put(acc, f["section"], Map.get(acc, f["section"], []) ++ [f])
            end)

          filtered =
          filter_recurse(
              selecto,
              filters_by_section,
              "filters"
            )

          detail_columns =
            Map.get(params, "selected", %{})
            |> Map.values()
            |> Enum.sort(fn a, b ->
              String.to_integer(a["index"]) <= String.to_integer(b["index"])
            end)

          ### Selecto Set for Detail View
          detail_set = %{
            columns: detail_columns,
            selected: detail_columns |> process_selected(columns),
            order_by:
              Map.get(params, "order_by", %{})
              |> process_order_by(columns),
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

                "aggregate" ->
                  group_by_params = Map.get(params, "group_by", %{})

                  aggregate =
                    Map.get(params, "aggregate", %{})
                    |> process_aggregates(columns)

                  group_by =
                    group_by_params |> process_group_by(columns)

                  %{
                    groups: group_by,
                    gb_params: group_by_params,
                    aggregates: aggregate,
                    selected: Enum.map(group_by, fn {_c, sel} -> sel end) ++ aggregate,
                    filtered: filtered,
                    group_by: [
                      {:rollup, Enum.map(1..Enum.count(group_by), fn g -> {:literal, g} end)}
                    ],
                    ### when using rollup, we need to workaround postgres bug
                    order_by: Enum.map(1..Enum.count(group_by), fn g -> {:literal, g} end),
                    detail_set: detail_set
                  }
              end
            )

          ### TODO update the selected, group_by, aggregate, order_by, filters from params into the form drawer

          assign(socket,
            selecto: selecto,
            used_params: params,
            applied_view: params["view_mode"],
            executed: true,
            page: 0,
            view_config: %{
              socket.assigns.view_config
              | per_page: String.to_integer(params["per_page"])
            }
          )
        rescue
          e ->
            IO.inspect(e, label: "Error on view creation")
            socket
        end
      end

      ### build view_config from URL
      defp filter_params_to_state(params, socket) do
        filters = view_filter_process(params, "filters")
        assign(socket,
          view_config: %{
            socket.assigns.view_config |
            filters: filters,
          }
        )
      end

      ### build view_config from URL
      defp params_to_state(params, socket) do
        filters = view_filter_process(params, "filters")
        selected = view_param_process(params, "selected", "field")
        group_by = view_param_process(params, "group_by", "field")
        aggregate = view_param_process(params, "aggregate", "field")
        order_by = view_param_process(params, "order_by", "field")

        assign(socket,
          view_config: %{
            filters: filters,
            selected: selected,
            aggregate: aggregate,
            group_by: group_by,
            order_by: order_by,
            view_mode: Map.get(params, "view_mode", "aggregate"),
            per_page: Map.get(params, "per_page", 30)
          }
        )
      end

      ### Update the URL to include the configured View
      defp state_to_url(params, socket) do
        params = Plug.Conn.Query.encode(params)
        push_patch(socket, to: "#{socket.assigns.my_path}?#{params}")
      end

      def get_initial_state(selecto) do
        [
          selecto: selecto,
          executed: false,
          applied_view: nil,
          active_tab: "view",
          page: 0,
          view_config: %{
            view_mode: "aggregate",
            per_page: 30,
            aggregate: Map.get(selecto.domain, :default_aggregate, []) |> set_defaults(),
            group_by: Map.get(selecto.domain, :default_group_by, []) |> set_defaults(),
            order_by: Map.get(selecto.domain, :default_order_by, []) |> set_defaults(),
            selected: Map.get(selecto.domain, :default_selected, []) |> set_defaults(),
            filters: []
          }
        ]
      end

      defp set_defaults(list) do
        list
        |> Enum.map(fn
          i when is_bitstring(i) -> {UUID.uuid4(), i, %{}}
          {i, conf} -> {UUID.uuid4(), i, conf}
        end)
      end



    end
    ### quote do
  end
  ### __using___

  ### Reorg these to use in pickers
  defp build_filter_list(selecto) do
    (Map.values(selecto.config.filters) ++
       [Map.values(selecto.config.columns) |> Enum.filter(fn c -> c.type != :custom_column end)])
    |> List.flatten()
    |> Enum.sort(fn a, b -> a.name <= b.name end)
    |> Enum.map(fn
      %{colid: id} = c -> {id, c.name}
      %{id: id} = c -> {id, c.name}
    end)
  end

  defp build_column_list(selecto) do
    Map.values(selecto.config.columns)
    |> Enum.sort(fn a, b -> a.name <= b.name end)
    |> Enum.map(fn c -> {c.colid, c.name, Map.get(c, :format)} end)
  end
end
