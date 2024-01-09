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
        field_filters: build_filter_list(assigns.selecto),
        use_saved_views: Map.get(assigns, :saved_view_module, false)
      )

    ~H"""
      <div class="border-solid border border-2 rounded-md border-black dark:border-black h-100 overflow-auto p-1">
        <.form phx-change="view-validate" phx-submit="view-apply">
          <!--TODO use LiveView.JS? --> <!-- Make tabs component?-->
          <.sc_button type="button" phx-click="set_active_tab" phx-value-tab="view">View Tab</.sc_button>
          <.sc_button type="button" phx-click="set_active_tab" phx-value-tab="filter">Filter Tab</.sc_button>
          <.sc_button :if={@use_saved_views} type="button" phx-click="set_active_tab" phx-value-tab="save">Save View</.sc_button>
          <.sc_button type="button" phx-click="set_active_tab" phx-value-tab="export">Export Tab</.sc_button>

          <div class={if @active_tab == "view" or @active_tab == nil do "border-solid border rounded-md border-grey dark:border-black h-90 p-1" else "hidden" end}>
            View Type
            <.live_component
              module={SelectoComponents.Components.RadioTabs}
              id="view_mode"
              fieldname="view_mode"
              view_mode={@view_config.view_mode}
              options={@views}
              >

                <:section :let={{id, mod, _, _} = view}>
                  <.live_component
                    module={ String.to_existing_atom("#{mod}.Form") }
                    id={"view_#{id}_form"}
                    columns={@columns}
                    view_config={@view_config}
                    view={view}
                    selecto={@selecto}
                  />
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
                  columns={Selecto.columns(@selecto)}
                  custom_filters={Selecto.filters(@selecto)}
                />
              </:filter_form>
            </.live_component>
          </div>
          <div :if={@use_saved_views} class={if @active_tab == "save" do "border-solid border rounded-md border-grey dark:border-black h-90 overflow-auto p-1" else "hidden" end}>
            Save View Section <%= inspect(@saved_view_context) %>
            HOw to ...
            Save As: <.sc_input name="save_as"/>

          </div>
          <div class={if @active_tab == "export" do "border-solid border rounded-md border-grey dark:border-black h-90 overflow-auto p-1" else "hidden" end}>
            EXPORT SECTION PLANNED

            export format: spreadsheet, text, csv, PDF?, JSON, XML

            download / send via email (add note)

            collate and send to an email address in a column
          </div>

          <.sc_button>Submit</.sc_button>
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
      def handle_params(%{"saved_view" => name} = params, _uri, socket) do
        view = socket.assigns.saved_view_module.get_view(name, socket.assigns.saved_view_context)
        socket = assign(socket, page_title: "View: #{view.name}")
        socket = params_to_state(view.params, socket)
        {:noreply, view_from_params(view.params, socket)}
      end

      def handle_params(%{"view_mode" => _m} = params, _uri, socket) do
        socket = params_to_state(params, socket)
        {:noreply, view_from_params(params, socket)}
      end

      ### accept default config
      def handle_params(params, _uri, socket) do
        {:noreply, socket}
      end

      def handle_event("set_active_tab", params, socket) do
        {:noreply, assign(socket, active_tab: params["tab"])}
      end

      ## TODO REDO this
      @impl true
      def handle_event("view-validate", params, socket) do
        socket = filter_params_to_state(params, socket)
        {:noreply, socket}
      end

      ### Save tab open. save view!
      def handle_event("view-apply", params, %{assigns: %{active_tab: "save"}} = socket) do
        Selecto.Helpers.check_safe_phrase(params["save_as"])
        view = socket.assigns.saved_view_module.save_view(params["save_as"], socket.assigns.saved_view_context, params)
        params = %{"saved_view" => view.name }
        {:noreply, state_to_url(params, socket)}
      end

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
        selected_view = String.to_atom(socket.assigns.view_config.view_mode)

        {_, _, _, opt} =
          Enum.find(socket.assigns.views, fn {id, _, _, _} -> id == selected_view end)

        new_view_mode = Map.get(opt, :drill_down, "detail")

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

                conf = Selecto.field(socket.assigns.selecto, f)
                {v1, v2} = case conf.type do
                  x when x in [:utc_datetime, :naive_datetime] ->
                    Selecto.Helpers.Date.val_to_dates(%{"value"=>v, "value2"=>""})
                  _ -> {v, ""}
                end

                Map.put(acc, newid, %{
                  "comp" => "=",
                  "filter" => f,
                  "index" => "0",
                  "section" => "filters",
                  "uuid" => newid,
                  "value" => v1,
                  "value2" => v2
                })
              end
            )
          )

        socket =
          assign(socket,
            view_config: %{
              socket.assigns.view_config
              | view_mode: new_view_mode,
                filters:
                  Enum.filter(socket.assigns.view_config.filters, fn
                    {_id, "filters", %{} = f} -> !Map.has_key?(params, f["filter"])
                    _ -> true
                  end) ++
                    Enum.map(params, fn {f, v} ->
                      conf = Selecto.field(socket.assigns.selecto, f)
                      case conf.type do
                        x when x in [:utc_datetime, :naive_datetime] ->
                          {v1, v2} = Selecto.Helpers.Date.val_to_dates(%{"value"=>v, "value2"=>""})
                          {UUID.uuid4(), "filters", %{"filter" => f, "value" => v1, "value2"=> v2}}
                        _ -> {UUID.uuid4(), "filters", %{"filter" => f, "value" => v}}
                      end


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
      def handle_info({:list_picker_remove, view, list, item}, socket) do
        view = String.to_atom(view)
        list = String.to_atom(list)

        view_config = socket.assigns.view_config

        socket =
          assign(socket,
            view_config:
              put_in(
                view_config.views[view][list],
                Enum.filter(view_config.views[view][list], fn {id, _, _} -> id != item end)
              )
          )

        {:noreply, socket}
      end

      @impl true
      def handle_info({:list_picker_move, view, list, uuid, direction}, socket) do
        view = String.to_atom(view)
        list = String.to_atom(list)
        view_config = socket.assigns.view_config
        item_list = view_config.views[view][list]
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

        socket = assign(socket, view_config: put_in(view_config.views[view][list], item_list))
        {:noreply, socket}
      end

      @impl true
      def handle_info({:list_picker_add, view, list, item}, socket) do
        view = String.to_atom(view)
        list = String.to_atom(list)
        config = %{}
        id = UUID.uuid4()

        view_config = socket.assigns.view_config

        socket =
          assign(socket,
            view_config:
              put_in(
                view_config.views[view][list],
                Enum.uniq(view_config.views[view][list] ++ [{id, item, config}])
              )
          )

        {:noreply, socket}
      end

      defp view_filter_process(params, item_name) do
        Map.get(params, item_name, %{})
        |> Enum.sort(fn {_, %{"index" => index}}, {_, %{"index" => index2}} ->
          String.to_integer(index) <= String.to_integer(index2)
        end)
        |> Enum.reduce([], fn
          {u, %{"conjunction" => conj} = f}, acc -> acc ++ [{u, f["section"], conj}]
          {u, f}, acc -> acc ++ [{u, f["section"], f}]
        end)
      end

      defp view_from_params(params, socket) do
        # try do
        #IO.inspect(params, label: "View From Params")
        # IO.puts("Build View")

        selecto = socket.assigns.selecto
        columns = Selecto.columns(selecto)

        filters_by_section =
          Map.values(Map.get(params, "filters", %{}))
          |> Enum.reduce(%{}, fn f, acc ->
            Map.put(acc, f["section"], Map.get(acc, f["section"], []) ++ [f])
          end)

        filtered = filter_recurse(selecto, filters_by_section, "filters")

        selected_view = String.to_atom(params["view_mode"])

        {_, module, _, opt} =
          Enum.find(socket.assigns.views, fn {id, _, _, _} -> id == selected_view end)

        {view_set, view_meta} =
          String.to_existing_atom("#{module}.Process").view(
            opt,
            params,
            columns,
            filtered,
            selecto
          )

        selecto = Map.put(selecto, :set, view_set)
        results = Selecto.execute(selecto)
        view_meta = Map.merge(view_meta, %{exe_id: UUID.uuid4()})

        assign(socket,
          selecto: selecto,
          query_results: results,
          used_params: params,
          applied_view: params["view_mode"],
          view_meta: view_meta,
          executed: true
        )

        # rescue
        #   e ->
        #     IO.inspect(e, label: "Error on view creation")
        #     socket
        # end
      end

      ### build view_config from URL
      defp filter_params_to_state(params, socket) do
        filters = view_filter_process(params, "filters")

        assign(socket,
          view_config: %{
            socket.assigns.view_config
            | filters: filters
          }
        )
      end

      ### build view_config from URL
      defp params_to_state(params, socket) do
        filters = view_filter_process(params, "filters")

        view_configs =
          Enum.reduce(socket.assigns.views, %{}, fn {view, module, _name, opt}, acc ->
            Map.merge(acc, %{
              view => String.to_existing_atom("#{module}.Process").param_to_state(params, opt)
            })
          end)

        assign(socket,
          view_config: %{
            filters: filters,
            views: view_configs,
            view_mode: Map.get(params, "view_mode", "aggregate")
          }
        )
      end

      ### Update the URL to include the configured View
      defp state_to_url(params, socket) do
        params = Plug.Conn.Query.encode(params)
        push_patch(socket, to: "#{socket.assigns.my_path}?#{params}")
      end

      def get_initial_state(views, selecto) do
        view_configs =
          view_configs =
          Enum.reduce(views, %{}, fn {view, module, name, opt}, acc ->
            Map.merge(acc, %{
              view => String.to_existing_atom("#{module}.Process").initial_state(selecto, opt)
            })
          end)

        [
          selecto: selecto,
          executed: false,
          query_results: [],
          applied_view: nil,
          active_tab: "view",
          view_config: %{
            view_mode: "aggregate",
            views: view_configs,
            filters: []
          },
          view_meta: %{}
        ]
      end
    end

    ### quote do
  end

  ### __using___

  ### Reorg these to use in pickers
  defp build_filter_list(selecto) do
    (Map.values(Selecto.filters(selecto)) ++
       [Map.values(Selecto.columns(selecto)) |> Enum.filter(fn c -> c.type != :custom_column end)])
    |> List.flatten()
    |> Enum.sort(fn a, b -> a.name <= b.name end)
    |> Enum.map(fn
      %{colid: id} = c -> {id, c.name}
      %{id: id} = c -> {id, c.name}
    end)
  end

  defp build_column_list(selecto) do
    Map.values(Selecto.columns(selecto))
    |> Enum.sort(fn a, b -> a.name <= b.name end)
    |> Enum.map(fn c -> {c.colid, c.name, Map.get(c, :format)} end)
  end
end
