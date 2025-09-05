defmodule SelectoComponents.Form do
  use Phoenix.LiveComponent

  import SelectoComponents.Components.Common
  alias Phoenix.LiveView.JS

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
        use_saved_views: Map.get(assigns, :saved_view_module, false),
        form:
          Ecto.Changeset.cast({%{}, %{}}, assigns.view_config, []) |> to_form(as: "view_config")
      )

    ~H"""
    <div class="border-solid border border-2 rounded-md border-gray-300 min-h-96 max-h-screen overflow-auto p-1 bg-base-100 text-base-content">
      <.form for={@form} phx-change="view-validate" phx-submit="view-apply">
        <!-- Error Display -->
        <div
          :if={Map.get(assigns, :execution_error)}
          class="bg-red-50 border border-red-200 rounded-md p-4 mb-4"
        >
          <div class="flex">
            <div class="flex-shrink-0">
              <svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
                <path
                  fill-rule="evenodd"
                  d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z"
                  clip-rule="evenodd"
                />
              </svg>
            </div>
            <div class="ml-3">
              <h3 class="text-sm font-medium text-red-800">
                Query Execution Failed
              </h3>
              <div class="mt-2 text-sm text-red-700">
                {Selecto.Error.to_display_message(Map.get(assigns, :execution_error))}
              </div>
              <div
                :if={Map.get(assigns, :execution_error) && Map.get(assigns, :execution_error).query}
                class="mt-2"
              >
                <details class="text-xs text-red-600">
                  <summary class="cursor-pointer">Show query details</summary>
                  <pre class="mt-1 whitespace-pre-wrap"><%= Map.get(assigns, :execution_error).query %></pre>
                  <div :if={
                    Map.get(assigns, :execution_error).params &&
                      length(Map.get(assigns, :execution_error).params) > 0
                  }>
                    <strong>Parameters:</strong> {inspect(Map.get(assigns, :execution_error).params)}
                  </div>
                </details>
              </div>
            </div>
          </div>
        </div>
        
    <!-- Tab navigation using LiveView.JS for better client-side performance -->
        <.sc_button type="button" phx-click={JS.push("set_active_tab", value: %{tab: "view"})}>
          View Tab
        </.sc_button>
        <.sc_button type="button" phx-click={JS.push("set_active_tab", value: %{tab: "filter"})}>
          Filter Tab
        </.sc_button>
        <.sc_button
          :if={@use_saved_views}
          type="button"
          phx-click={JS.push("set_active_tab", value: %{tab: "save"})}
        >
          Save View
        </.sc_button>
        <.sc_button type="button" phx-click={JS.push("set_active_tab", value: %{tab: "export"})}>
          Export Tab
        </.sc_button>

        <div class={
          if @active_tab == "view" or @active_tab == nil do
            "border-solid border rounded-md border-gray-300 min-h-96 max-h-screen overflow-auto p-1 bg-base-100 text-base-content"
          else
            "hidden"
          end
        }>
          <span class="text-base-content font-medium">View Type</span>
          <.live_component
            module={SelectoComponents.Components.RadioTabs}
            id="view_mode"
            fieldname="view_mode"
            view_mode={@view_config.view_mode}
            options={@views}
          >
            <:section :let={{id, mod, _, _} = view}>
              <.live_component
                module={String.to_existing_atom("#{mod}.Form")}
                id={"view_#{id}_form"}
                columns={@columns}
                view_config={@view_config}
                view={view}
                selecto={@selecto}
              />
            </:section>
          </.live_component>
        </div>

        <div class={
          if @active_tab == "filter" do
            "border-solid border rounded-md border-grey dark:border-black h-90  p-1"
          else
            "hidden"
          end
        }>
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
        <div
          :if={@use_saved_views}
          class={
            if @active_tab == "save" do
              "border-solid border rounded-md border-grey dark:border-black h-90 overflow-auto p-1"
            else
              "hidden"
            end
          }
        >
          Save View Section
          HOw to ...
          Save As: <.sc_input name="save_as" />
        </div>
        <div class={
          if @active_tab == "export" do
            "border-solid border rounded-md border-grey dark:border-black h-90 overflow-auto p-1"
          else
            "hidden"
          end
        }>
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

      @impl true
      def handle_event("view-validate", params, socket) do
        # Process all parameters including view-specific configs (aggregates, group_by, etc.)
        socket = params_to_state(params, socket)

        # Don't execute view on validation - only on submit
        # This allows users to configure aggregates without immediate updates
        {:noreply, socket}
      end

      ### Save tab open. save view!
      def handle_event("view-apply", params, %{assigns: %{active_tab: "save"}} = socket) do
        Selecto.Helpers.check_safe_phrase(params["save_as"])

        view =
          socket.assigns.saved_view_module.save_view(
            params["save_as"],
            socket.assigns.saved_view_context,
            params
          )

        params = %{"saved_view" => view.name}
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

                # Handle empty field names by trying to find the appropriate field
                # This happens when aggregate components don't properly set filter keys
                field_name = if f == "" or f == nil do
                  # Try to find a suitable field from current group_by configuration
                  current_group_by = socket.assigns.view_config.group_by || []
                  case current_group_by do
                    [first_group | _] -> first_group
                    [] -> "id"  # Fallback to a basic field
                  end
                else
                  f
                end

                conf = Selecto.field(socket.assigns.selecto, field_name)

                {v1, v2} = if conf != nil do
                  case conf.type do
                    x when x in [:utc_datetime, :naive_datetime] ->
                      Selecto.Helpers.Date.val_to_dates(%{"value" => v, "value2" => ""})

                    _ ->
                      {v, ""}
                  end
                else
                  # If no field configuration found, default to string handling
                  {v, ""}
                end

                Map.put(acc, newid, %{
                  "comp" => "=",
                  "filter" => field_name,
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
                      # Handle empty field names by trying to find the appropriate field
                      field_name = if f == "" or f == nil do
                        # Try to find a suitable field from current group_by configuration
                        current_group_by = socket.assigns.view_config.group_by || []
                        case current_group_by do
                          [first_group | _] -> first_group
                          [] -> "id"  # Fallback to a basic field
                        end
                      else
                        f
                      end

                      conf = Selecto.field(socket.assigns.selecto, field_name)

                      result = if conf != nil do
                        case conf.type do
                          x when x in [:utc_datetime, :naive_datetime] ->
                            {v1, v2} =
                              Selecto.Helpers.Date.val_to_dates(%{"value" => v, "value2" => ""})

                            {UUID.uuid4(), "filters",
                             %{"filter" => field_name, "value" => v1, "value2" => v2}}

                          _ ->
                            {UUID.uuid4(), "filters", %{"filter" => field_name, "value" => v}}
                        end
                      else
                        # Default handling if no configuration found
                        {UUID.uuid4(), "filters", %{"filter" => field_name, "value" => v}}
                      end
                      
                      result
                    end)
            }
          )

        {:noreply, view_from_params(view_params, state_to_url(view_params, socket))}
      end

      def handle_event("graph_drill_down", params, socket) do
        # Convert graph_drill_down params to chart_click format
        # The graph component sends slightly different parameter names
        handle_event("chart_click", params, socket)
      end

      def handle_event("chart_click", params, socket) do
        # Extract the label/value from the clicked chart element
        label = params["label"]
        _value = params["value"]
        
        # Get current view mode and graph configuration
        current_view_mode = socket.assigns.view_config.view_mode
        graph_config = socket.assigns.view_config.views[:graph] || %{}
        
        # Determine which field was clicked based on current graph x_axis configuration
        x_axis = graph_config[:x_axis] || []
        field_name = case x_axis do
          [{_id, field, _config} | _] -> 
            # Extract the actual field name from the tuple
            field
          _ -> 
            # If no x_axis configured, try to extract from label context
            "id"
        end
        
        # Create a new filter based on the clicked value
        new_filter_id = UUID.uuid4()
        new_filter_map = %{
          "filter" => field_name, 
          "value" => to_string(label),
          "comp" => "=",  # Set comparison operator for exact match
          "section" => "filters"  # Ensure section is set
        }
        new_filter = {new_filter_id, "filters", new_filter_map}
        
        # Add the filter to existing filters
        updated_filters = socket.assigns.view_config.filters ++ [new_filter]
        
        # Switch to detail view (or configured drill_down view)
        selected_view = String.to_atom(current_view_mode)
        {_, _, _, opt} = Enum.find(socket.assigns.views, fn {id, _, _, _} -> id == selected_view end) || {:detail, nil, nil, %{}}
        new_view_mode = Map.get(opt, :drill_down, :detail)
        
        # Build the complete filter params map including section
        filters_map = Enum.reduce(updated_filters, %{}, fn
          {id, "filters", filter_map}, acc ->
            # Ensure section and comp are set for each filter
            filter_with_defaults = filter_map
              |> Map.put_new("section", "filters")
              |> Map.put_new("comp", "=")
            Map.put(acc, id, filter_with_defaults)
          _, acc ->
            acc
        end)
        
        # Get current params or initialize with empty maps
        current_params = socket.assigns[:used_params] || %{}
        
        # Build complete params structure that view_from_params expects
        # Include view-specific configurations
        view_params = 
          current_params
          |> Map.put("view_mode", Atom.to_string(new_view_mode))
          |> Map.put("filters", filters_map)
          |> Map.put_new("aggregate", %{})  # Ensure aggregate config exists
          |> Map.put_new("detail", %{})     # Ensure detail config exists
          |> Map.put_new("graph", %{})      # Ensure graph config exists
        
        # Update the view configuration
        socket = assign(socket,
          view_config: %{
            socket.assigns.view_config
            | view_mode: Atom.to_string(new_view_mode),
              filters: updated_filters
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

        # Don't execute view - wait for submit
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
        # Don't execute view - wait for submit
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

        # Don't execute view - wait for submit
        {:noreply, socket}
      end

      # Helper function to execute view from current state
      defp execute_view_from_current_state(socket) do
        params = view_config_to_params(socket.assigns.view_config)
        view_from_params(params, socket)
      end

      # Convert view_config back to params format for view execution
      defp view_config_to_params(view_config) do
        params = %{
          "view_mode" => view_config.view_mode,
          "filters" => filters_to_params(view_config.filters)
        }

        # Add view-specific parameters
        view_params =
          case view_config.views[String.to_atom(view_config.view_mode)] do
            nil ->
              %{}

            view_data ->
              # Convert each list (group_by, aggregate, etc.) to params format
              Enum.reduce(view_data, %{}, fn {list_name, items}, acc ->
                items_params =
                  items
                  |> Enum.with_index()
                  |> Enum.reduce(%{}, fn {{id, field, config}, index}, item_acc ->
                    Map.put(
                      item_acc,
                      id,
                      Map.merge(config, %{
                        "field" => field,
                        "index" => to_string(index)
                      })
                    )
                  end)

                Map.put(acc, to_string(list_name), items_params)
              end)
          end

        Map.merge(params, view_params)
      end

      # Convert filters back to params format
      defp filters_to_params(filters) do
        filters
        |> Enum.with_index()
        |> Enum.reduce(%{}, fn {{uuid, section, filter_data}, index}, acc ->
          filter_params =
            case filter_data do
              conj when is_binary(conj) ->
                %{"conjunction" => conj, "section" => section, "index" => to_string(index)}

              filter_map when is_map(filter_map) ->
                Map.merge(filter_map, %{"section" => section, "index" => to_string(index)})
            end

          Map.put(acc, uuid, filter_params)
        end)
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
        # First, clear any existing query results to prevent stale data display
        socket =
          assign(socket,
            query_results: nil,
            executed: false,
            execution_error: nil
          )

        # Create a fresh Selecto structure instead of reusing the cached one
        # This ensures any internal state is properly reset for the new view
        old_selecto = socket.assigns.selecto
        selecto = Selecto.configure(old_selecto.domain, old_selecto.postgrex_opts)
        raw_columns = Selecto.columns(selecto)

        # Convert columns to the format expected by ListPicker components
        # ListPicker expects a list of {id, name, format} tuples
        columns_list =
          raw_columns
          |> Enum.map(fn {key, col} ->
            {key, col.name, col.type}
          end)

        # Create columns lookup map for the process functions
        # This map has both column IDs and field names as keys pointing to column structs
        columns_map =
          raw_columns
          |> Enum.into(%{}, fn {key, col} ->
            col_with_field = Map.put(col, :field, col.name)
            {key, col_with_field}
          end)
          |> then(fn cols ->
            Enum.reduce(cols, cols, fn {_colid, col}, acc ->
              Map.put(acc, col.name, col)
            end)
          end)

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
            columns_map,
            filtered,
            selecto
          )

        selecto = Map.put(selecto, :set, view_set)

        # Execute query using standardized safe API
        case Selecto.execute(selecto) do
          {:ok, {rows, columns, aliases}} ->

            view_meta = Map.merge(view_meta, %{exe_id: UUID.uuid4()})

            assign(socket,
              selecto: selecto,
              columns: columns_list,
              field_filters: Selecto.filters(selecto),
              query_results: {rows, columns, aliases},
              used_params: params,
              applied_view: params["view_mode"],
              view_meta: view_meta,
              executed: true,
              execution_error: nil
            )

          {:error, %Selecto.Error{} = error} ->
            assign(socket,
              selecto: selecto,
              columns: columns_list,
              field_filters: Selecto.filters(selecto),
              query_results: nil,
              used_params: params,
              applied_view: params["view_mode"],
              executed: false,
              execution_error: error
            )
        end
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

      ### Check if view parameters have changed significantly
      defp view_params_changed?(params, socket) do
        used_params = socket.assigns[:used_params] || %{}

        # Key parameters that should trigger a view reset
        significant_changes = [
          # View mode change (aggregate vs detail vs graph)
          params["view_mode"] != used_params["view_mode"],

          # Group by changes in aggregate view
          view_specific_params_changed?(params, used_params, "group_by"),

          # Aggregate fields changes in aggregate view  
          view_specific_params_changed?(params, used_params, "aggregate"),

          # Column selection changes in detail view
          view_specific_params_changed?(params, used_params, "columns"),

          # Order by changes
          view_specific_params_changed?(params, used_params, "order_by"),

          # Filter changes that affect the query structure
          filter_structure_changed?(params, used_params)
        ]

        Enum.any?(significant_changes)
      end

      ### Check if view-specific parameters changed
      defp view_specific_params_changed?(params, used_params, param_key) do
        current = normalize_param_map(Map.get(params, param_key, %{}))
        previous = normalize_param_map(Map.get(used_params, param_key, %{}))
        current != previous
      end

      ### Normalize parameter maps for comparison
      defp normalize_param_map(param_map) when is_map(param_map) do
        param_map
        |> Enum.map(fn {k, v} ->
          {k, Map.take(v, ["field", "format", "alias", "index"])}
        end)
        |> Enum.sort()
      end

      defp normalize_param_map(_), do: []

      ### Check if filter structure changed (not just values)
      defp filter_structure_changed?(params, used_params) do
        current_filters = Map.get(params, "filters", %{}) |> Map.keys() |> Enum.sort()
        previous_filters = Map.get(used_params, "filters", %{}) |> Map.keys() |> Enum.sort()
        current_filters != previous_filters
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

        # Set up columns in the same format as view_from_params
        raw_columns = Selecto.columns(selecto)

        columns_list =
          raw_columns
          |> Enum.map(fn {key, col} ->
            {key, col.name, col.type}
          end)

        [
          selecto: selecto,
          columns: columns_list,
          field_filters: Selecto.filters(selecto),
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
    # Include explicit filters and only columns that are marked as filterable
    filterable_columns =
      Map.values(Selecto.columns(selecto))
      |> Enum.filter(fn column ->
        # Only include columns that are explicitly marked as filterable
        # or don't have component formatting (which indicates they're display-only)
        Map.get(column, :make_filter, false) or
          ((not Map.has_key?(column, :format) or Map.get(column, :format) == nil) and
             not Map.has_key?(column, :component))
      end)

    (Map.values(Selecto.filters(selecto)) ++ filterable_columns)
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
