defmodule SelectoComponents.Form do
  use Phoenix.LiveComponent

  import SelectoComponents.Components.Common
  alias Phoenix.LiveView.JS
  alias SelectoComponents.ErrorHandling.ErrorDisplay
  alias SelectoComponents.Components.FilterForms

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
    <div class="border-solid border border-2 rounded-md border-gray-300 p-1 bg-base-100 text-base-content">
      <.form for={@form} phx-change="view-validate" phx-submit="view-apply">
        <!-- Comprehensive Error Display Component -->
        <.live_component
          :if={Map.get(assigns, :execution_error) || Map.get(assigns, :component_errors, [])}
          module={ErrorDisplay}
          id="error_display"
          error={Map.get(assigns, :execution_error)}
          errors={Map.get(assigns, :component_errors, [])}
        />

        <!-- View Config Manager for saving/loading view configurations -->
        <.live_component
          :if={Map.get(assigns, :saved_view_config_module)}
          module={SelectoComponents.ViewConfigManager}
          id="view_config_manager"
          view_config={@view_config}
          saved_view_config_module={Map.get(assigns, :saved_view_config_module)}
          saved_view_context={Map.get(assigns, :saved_view_context)}
          current_user_id={Map.get(assigns, :current_user_id)}
          parent_id={@myself}
        />

        <!-- Main Navigation Tabs -->
        <div class="flex border-b border-gray-200 dark:border-gray-700 mb-4">
          <div class="flex space-x-1" role="tablist" aria-label="Configuration Sections">
            <button
              type="button"
              role="tab"
              aria-selected={@active_tab == "view" or @active_tab == nil}
              aria-controls="main-tabpanel-view"
              id="main-tab-view"
              phx-click={JS.push("set_active_tab", value: %{tab: "view"})}
              class={[
                "px-4 py-2 text-sm font-medium transition-all duration-200",
                "border-b-2 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary",
                if @active_tab == "view" or @active_tab == nil do
                  "border-primary text-primary bg-primary/5"
                else
                  "border-transparent text-gray-600 hover:text-gray-800 hover:border-gray-300 dark:text-gray-400 dark:hover:text-gray-200"
                end
              ]}
            >
              View
            </button>
            
            <button
              type="button"
              role="tab"
              aria-selected={@active_tab == "filter"}
              aria-controls="main-tabpanel-filter"
              id="main-tab-filter"
              phx-click={JS.push("set_active_tab", value: %{tab: "filter"})}
              class={[
                "px-4 py-2 text-sm font-medium transition-all duration-200",
                "border-b-2 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary",
                if @active_tab == "filter" do
                  "border-primary text-primary bg-primary/5"
                else
                  "border-transparent text-gray-600 hover:text-gray-800 hover:border-gray-300 dark:text-gray-400 dark:hover:text-gray-200"
                end
              ]}
            >
              Filters
            </button>
            
            <button
              :if={@use_saved_views}
              type="button"
              role="tab"
              aria-selected={@active_tab == "save"}
              aria-controls="main-tabpanel-save"
              id="main-tab-save"
              phx-click={JS.push("set_active_tab", value: %{tab: "save"})}
              class={[
                "px-4 py-2 text-sm font-medium transition-all duration-200",
                "border-b-2 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary",
                if @active_tab == "save" do
                  "border-primary text-primary bg-primary/5"
                else
                  "border-transparent text-gray-600 hover:text-gray-800 hover:border-gray-300 dark:text-gray-400 dark:hover:text-gray-200"
                end
              ]}
            >
              Save View
            </button>
            
            <button
              type="button"
              role="tab"
              aria-selected={@active_tab == "export"}
              aria-controls="main-tabpanel-export"
              id="main-tab-export"
              phx-click={JS.push("set_active_tab", value: %{tab: "export"})}
              class={[
                "px-4 py-2 text-sm font-medium transition-all duration-200",
                "border-b-2 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary",
                if @active_tab == "export" do
                  "border-primary text-primary bg-primary/5"
                else
                  "border-transparent text-gray-600 hover:text-gray-800 hover:border-gray-300 dark:text-gray-400 dark:hover:text-gray-200"
                end
              ]}
            >
              Export
            </button>
          </div>
        </div>

        <!-- Tab Content Panels -->
        <div 
          role="tabpanel"
          id="main-tabpanel-view"
          aria-labelledby="main-tab-view"
          class={
            if @active_tab == "view" or @active_tab == nil do
              "border-solid border rounded-md border-gray-300 p-3 bg-base-100 text-base-content"
            else
              "hidden"
            end
          }
        >
          <.live_component
            module={SelectoComponents.Components.Tabs}
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

        <div 
          role="tabpanel"
          id="main-tabpanel-filter"
          aria-labelledby="main-tab-filter"
          class={
            if @active_tab == "filter" do
              "border-solid border rounded-md border-gray-300 p-3 bg-base-100 text-base-content"
            else
              "hidden"
            end
          }
        >
          <!-- Filter Sets Component -->
          <.live_component
            :if={Map.get(assigns, :filter_sets_adapter)}
            module={SelectoComponents.Filter.FilterSets}
            id="filter_sets"
            user_id={Map.get(assigns, :user_id)}
            domain={Map.get(assigns, :domain) || Map.get(assigns, :path)}
            current_filters={@view_config.filters}
            filter_sets_adapter={Map.get(assigns, :filter_sets_adapter)}
          />
          
          <.live_component
            module={SelectoComponents.Components.TreeBuilder}
            id="tree_builder"
            available={build_filter_list(@selecto)}
            filters={@view_config.filters}
          >
            <:filter_form :let={{uuid, index, section, filter_value}}>
              <%= render_filter_form(assigns, uuid, index, section, filter_value) %>
            </:filter_form>
          </.live_component>
        </div>
        
        <div
          :if={@use_saved_views}
          role="tabpanel"
          id="main-tabpanel-save"
          aria-labelledby="main-tab-save"
          class={
            if @active_tab == "save" do
              "border-solid border rounded-md border-gray-300 p-3 bg-base-100 text-base-content"
            else
              "hidden"
            end
          }
        >
          <h3 class="text-base-content font-medium mb-2">Save View Configuration</h3>
          <div class="space-y-4">
            <p class="text-sm text-gray-600 dark:text-gray-400">
              Save your current view configuration for later use.
            </p>
            <div class="flex items-center gap-2">
              <label for="save_as" class="text-sm font-medium">Save As:</label>
              <.sc_input name="save_as" id="save_as" placeholder="Enter view name..." class="flex-1" />
            </div>
          </div>
        </div>
        
        <div 
          role="tabpanel"
          id="main-tabpanel-export"
          aria-labelledby="main-tab-export"
          class={
            if @active_tab == "export" do
              "border-solid border rounded-md border-gray-300 p-3 bg-base-100 text-base-content"
            else
              "hidden"
            end
          }
        >
          <h3 class="text-base-content font-medium mb-2">Export Options</h3>
          <div class="space-y-4">
            <p class="text-sm text-gray-600 dark:text-gray-400">
              Export your data in various formats. Features coming soon:
            </p>
            <ul class="list-disc list-inside text-sm text-gray-600 dark:text-gray-400 space-y-1">
              <li>Export formats: Spreadsheet, CSV, JSON, XML, PDF</li>
              <li>Download directly or send via email</li>
              <li>Batch export with custom templates</li>
              <li>Schedule automated exports</li>
            </ul>
          </div>
        </div>

        <.sc_button>Submit</.sc_button>
      </.form>
    </div>
    """
  end

  defmacro __using__(_opts \\ []) do
    quote do
      ### These run in the 'use'ing liveview's context
      
      # Import error handling helpers
      import SelectoComponents.Form, only: [dev_mode?: 0, sanitize_error_for_environment: 1]

      import SelectoComponents.Helpers
      import SelectoComponents.Helpers.Filters
      alias SelectoComponents.ErrorHandling.ErrorCategorizer

      # Error handling wrapper for handle_event callbacks
      defp with_error_handling(socket, operation_name, fun) do
        try do
          fun.()
        rescue
          e in RuntimeError ->
            handle_component_error(socket, e, operation_name, :runtime_error)
          
          e in ArgumentError ->
            handle_component_error(socket, e, operation_name, :argument_error)
            
          e in KeyError ->
            handle_component_error(socket, e, operation_name, :key_error)
            
          e ->
            handle_component_error(socket, e, operation_name, :unknown_error)
        catch
          :exit, reason ->
            handle_component_error(socket, {:exit, reason}, operation_name, :exit)
            
          kind, reason ->
            handle_component_error(socket, {kind, reason}, operation_name, :catch)
        end
      end

      defp handle_component_error(socket, error, operation_name, error_type) do
        categorized = ErrorCategorizer.categorize(error)
        
        if dev_mode?() do
          IO.puts("[COMPONENT ERROR - #{operation_name}] Type: #{error_type}")
          IO.puts("[COMPONENT ERROR] Details: #{inspect(error)}")
          IO.puts("[COMPONENT ERROR] Categorized: #{inspect(categorized)}")
        end
        
        # Add error to component_errors list
        existing_errors = Map.get(socket.assigns, :component_errors, [])
        new_errors = [Map.put(categorized, :operation, operation_name) | existing_errors] |> Enum.take(5)
        
        {:noreply, assign(socket, component_errors: new_errors)}
      end

      @impl true
      def handle_params(%{"saved_view" => name} = params, _uri, socket) do
        view = socket.assigns.saved_view_module.get_view(name, socket.assigns.saved_view_context)
        socket = assign(socket, page_title: "View: #{view.name}")
        # Normalize any existing query results before processing
        socket = normalize_query_results(socket)
        socket = params_to_state(view.params, socket)
        {:noreply, view_from_params(view.params, socket)}
      end

      def handle_params(%{"view_mode" => _m} = params, _uri, socket) do
        # Normalize any existing query results before processing
        socket = normalize_query_results(socket)
        socket = params_to_state(params, socket)
        {:noreply, view_from_params(params, socket)}
      end
      
      defp normalize_query_results(socket) do
        case socket.assigns[:query_results] do
          {rows, columns, aliases} when is_list(rows) and length(rows) > 0 and is_list(hd(rows)) ->
            # Results are in list format, convert to maps
            normalized_rows = Enum.map(rows, fn row ->
              Enum.zip(columns, row) |> Map.new()
            end)
            assign(socket, query_results: {normalized_rows, columns, aliases})
          
          _ ->
            # Results are already normalized or empty
            socket
        end
      end

      ### accept default config
      def handle_params(params, _uri, socket) do
        {:noreply, socket}
      end

      def handle_event("set_active_tab", params, socket) do
        {:noreply, assign(socket, active_tab: Map.get(params, "tab"))}
      end

      @impl true
      def handle_event("view-validate", params, socket) do
        with_error_handling(socket, "view-validate", fn ->
          # Process all parameters including view-specific configs (aggregates, group_by, etc.)
          socket = params_to_state(params, socket)

          # Don't execute view on validation - only on submit
          # This allows users to configure aggregates without immediate updates
          {:noreply, socket}
        end)
      end

      ### Save tab open. save view!
      def handle_event("view-apply", params, %{assigns: %{active_tab: "save"}} = socket) do
        Selecto.Helpers.check_safe_phrase(Map.get(params, "save_as"))

        view =
          socket.assigns.saved_view_module.save_view(
            Map.get(params, "save_as"),
            socket.assigns.saved_view_context,
            params
          )

        params = %{"saved_view" => view.name}
        {:noreply, state_to_url(params, socket)}
      end

      def handle_event("view-apply", params, socket) do
        with_error_handling(socket, "view-apply", fn ->
          {:noreply, view_from_params(params, state_to_url(params, socket))}
        end)
      end

      @impl true
      def handle_event("load_view_config", %{"name" => config_name}, socket) do
        with_error_handling(socket, "load_view_config", fn ->
          view_type = socket.assigns.view_config.view_mode || "detail"

          case socket.assigns.saved_view_config_module.get_view_config(
            config_name,
            socket.assigns.saved_view_context,
            view_type,
            user_id: Map.get(socket.assigns, :current_user_id)
          ) do
            nil ->
              {:noreply, put_flash(socket, :error, "View configuration not found")}

            config ->
              params = socket.assigns.saved_view_config_module.decode_view_config(config)
              socket = view_from_params(params, socket)
              {:noreply, put_flash(socket, :info, "View configuration loaded: #{config.name}")}
          end
        end)
      end

      @impl true
      def handle_event("treedrop", par, socket) do
        new_filter = Map.get(par, "element")
        target = Map.get(par, "target")

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
                    {u, s, _c} -> u != Map.get(params, "uuid") && s != Map.get(params, "uuid")
                  end)
            }
          )

        {:noreply, socket}
      end

      def handle_event("agg_add_filters", params, socket) do
        with_error_handling(socket, "agg_add_filters", fn ->
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
                IO.puts("[FIRST FILTER] Processing param: #{inspect(f)} => #{inspect(v)}")

                # Extract the actual field name from phx-value-* parameters
                field_name = case f do
                  "phx-value-" <> actual_field ->
                    IO.puts("[FIRST FILTER] Extracted '#{actual_field}' from '#{f}'")
                    actual_field
                  "" ->
                    # Try to find a suitable field from current group_by configuration
                    current_group_by = socket.assigns.view_config.group_by || []
                    case current_group_by do
                      [first_group | _] -> first_group
                      [] -> "id"  # Fallback to a basic field
                    end
                  nil ->
                    # Try to find a suitable field from current group_by configuration
                    current_group_by = socket.assigns.view_config.group_by || []
                    case current_group_by do
                      [first_group | _] -> first_group
                      [] -> "id"  # Fallback to a basic field
                    end
                  _ -> f
                end

                conf = Selecto.field(socket.assigns.selecto, field_name)

                {v1, v2} = if conf != nil do
                  # Custom columns might not have a type field
                  field_type = Map.get(conf, :type, :string)
                  case field_type do
                    x when x in [:utc_datetime, :naive_datetime] ->
                      Selecto.Helpers.Date.val_to_dates(%{"value" => v, "value2" => ""})

                    _ ->
                      {v, ""}
                  end
                else
                  # If no field configuration found, default to string handling
                  {v, ""}
                end

                filter_config = %{
                  "comp" => "=",
                  "filter" => field_name,
                  "index" => "0",
                  "section" => "filters",
                  "uuid" => newid,
                  "value" => v1,
                  "value2" => v2
                }
                # Check if we should use a different filter field (e.g., for full_name -> actor_id)
                conf = Selecto.field(socket.assigns.selecto, field_name)
                actual_filter_field = if conf && Map.get(conf, :group_by_filter) do
                  group_by_filter = Map.get(conf, :group_by_filter)
                  group_by_filter
                else
                  field_name
                end

                # Update the filter config to use the correct field
                filter_config = Map.put(filter_config, "filter", actual_filter_field)
                Map.put(acc, newid, filter_config)
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
                    {_id, "filters", %{} = f} -> !Map.has_key?(params, Map.get(f, "filter"))
                    _ -> true
                  end) ++
                    Enum.map(params, fn {f, v} ->
                      # Extract the actual field name from phx-value-* parameters
                      field_name = case f do
                        "phx-value-" <> actual_field ->
                          actual_field
                        "" ->
                          # Try to find a suitable field from current group_by configuration
                          current_group_by = socket.assigns.view_config.group_by || []
                          case current_group_by do
                            [first_group | _] -> first_group
                            [] -> "id"  # Fallback to a basic field
                          end
                        nil ->
                          # Try to find a suitable field from current group_by configuration
                          current_group_by = socket.assigns.view_config.group_by || []
                          case current_group_by do
                            [first_group | _] -> first_group
                            [] -> "id"  # Fallback to a basic field
                          end
                        _ -> f
                      end

                      conf = Selecto.field(socket.assigns.selecto, field_name)

                      result = if conf != nil do
                        # Custom columns might not have a type field
                        field_type = Map.get(conf, :type, :string)
                        case field_type do
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
        end)
      end

      def handle_event("graph_drill_down", params, socket) do
        # Convert graph_drill_down params to chart_click format
        # The graph component sends slightly different parameter names
        handle_event("chart_click", params, socket)
      end

      def handle_event("chart_click", params, socket) do
        with_error_handling(socket, "chart_click", fn ->
          # Extract the label/value from the clicked chart element
          label = Map.get(params, "label")
        _value = Map.get(params, "value")
        
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
        end)
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
        original_list = view_config.views[view][list]

        filtered_list = Enum.filter(original_list, fn
          {id, _, _} when is_binary(id) -> id != item
          [id, _, _] when is_binary(id) -> id != item
          {id, _, _} -> to_string(id) != item
          [id, _, _] -> to_string(id) != item
          _ -> true
        end)

        # Update the view_config
        updated_view_config = put_in(
          view_config.views[view][list],
          filtered_list
        )

        socket =
          assign(socket,
            view_config: updated_view_config
          )

        # Force update of the child component for this specific view
        # Find the view module from the views list
        view_module = Enum.find(socket.assigns.views, fn {id, _, _, _} -> id == view end)

        if view_module do
          {id, mod, _, _} = view_module
          component_id = "view_#{id}_form"

          # Send update to the specific view form component
          send_update(String.to_existing_atom("#{mod}.Form"),
            id: component_id,
            view_config: updated_view_config,
            columns: socket.assigns.columns,
            view: view_module,
            selecto: socket.assigns.selecto
          )
        end

        # Don't execute view - wait for submit
        {:noreply, socket}
      end

      @impl true
      def handle_info({:list_picker_move, view, list, uuid, direction}, socket) do
        view = String.to_atom(view)
        list = String.to_atom(list)
        view_config = socket.assigns.view_config
        item_list = view_config.views[view][list]
        item_index = Enum.find_index(item_list, fn
          {id, _, _} when is_binary(id) -> id == uuid
          [id, _, _] when is_binary(id) -> id == uuid
          {id, _, _} -> to_string(id) == uuid
          [id, _, _] -> to_string(id) == uuid
          _ -> false
        end)

        # Handle case where item not found
        if item_index == nil do
          {:noreply, socket}
        else
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

          updated_view_config = put_in(view_config.views[view][list], item_list)
          socket = assign(socket, view_config: updated_view_config)

          # Force update of the child component
          view_module = Enum.find(socket.assigns.views, fn {id, _, _, _} -> id == view end)
          if view_module do
            {id, mod, _, _} = view_module
            component_id = "view_#{id}_form"
            send_update(String.to_existing_atom("#{mod}.Form"),
              id: component_id,
              view_config: updated_view_config,
              columns: socket.assigns.columns,
              view: view_module,
              selecto: socket.assigns.selecto
            )
          end

          # Don't execute view - wait for submit
          {:noreply, socket}
        end
      end

      @impl true
      def handle_info({:list_picker_add, view, list, item}, socket) do
        view = String.to_atom(view)
        list = String.to_atom(list)
        config = %{}
        id = UUID.uuid4()

        view_config = socket.assigns.view_config

        updated_view_config = put_in(
          view_config.views[view][list],
          Enum.uniq(view_config.views[view][list] ++ [{id, item, config}])
        )

        socket = assign(socket, view_config: updated_view_config)

        # Force update of the child component
        view_module = Enum.find(socket.assigns.views, fn {id, _, _, _} -> id == view end)
        if view_module do
          {id, mod, _, _} = view_module
          component_id = "view_#{id}_form"
          send_update(String.to_existing_atom("#{mod}.Form"),
            id: component_id,
            view_config: updated_view_config,
            columns: socket.assigns.columns,
            view: view_module,
            selecto: socket.assigns.selecto
          )
        end

        # Don't execute view - wait for submit
        {:noreply, socket}
      end
      
      @impl true
      def handle_info({:rerun_query_with_sort, sort_by}, socket) do
        with_error_handling(socket, "rerun_query_with_sort", fn ->
          # Get current parameters or use saved params
          params = socket.assigns[:used_params] || view_config_to_params(socket.assigns.view_config)
          
          # Store sort configuration in socket
          socket = assign(socket, sort_by: sort_by)
          
          # Re-execute the view with current parameters and sorting
          view_from_params_with_sort(params, socket, sort_by)
        end)
      end
      
      @impl true
      def handle_info({:filters_updated, updated_filters}, socket) do
        # Update the view config with new filters
        socket = assign(socket,
          view_config: %{socket.assigns.view_config | filters: updated_filters}
        )
        # Don't auto-execute, wait for user to click Apply
        {:noreply, socket}
      end

      @impl true
      def handle_info({:show_detail_modal, detail_data}, socket) do
        # Check if modal detail view is enabled (opt-in feature)
        if Map.get(socket.assigns, :enable_modal_detail, false) do
          # Set modal data in assigns to trigger rendering
          socket = assign(socket,
            show_detail_modal: true,
            modal_detail_data: detail_data
          )
          {:noreply, socket}
        else
          # Fallback to default behavior or ignore if not enabled
          {:noreply, socket}
        end
      end

      @impl true
      def handle_info({:close_detail_modal, _modal_id}, socket) do
        socket = assign(socket,
          show_detail_modal: false,
          modal_detail_data: nil
        )
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
                  |> Enum.reduce(%{}, fn
                    {{id, field, config}, index}, item_acc ->
                      Map.put(
                        item_acc,
                        id,
                        Map.merge(config, %{
                          "field" => field,
                          "index" => to_string(index)
                        })
                      )

                    {[id, field, config], index}, item_acc ->
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
        |> Enum.sort(fn {_, f1}, {_, f2} ->
          String.to_integer(Map.get(f1, "index", "0")) <= String.to_integer(Map.get(f2, "index", "0"))
        end)
        |> Enum.reduce([], fn
          {u, %{"conjunction" => conj} = f}, acc -> acc ++ [{u, Map.get(f, "section"), conj}]
          {u, f}, acc -> acc ++ [{u, Map.get(f, "section"), f}]
        end)
      end
      
      # Version of view_from_params that applies sorting
      defp view_from_params_with_sort(params, socket, sort_by) do
        # Store the sort_by in socket so the modified view_from_params can use it
        socket = assign(socket, sort_by: sort_by)
        {:noreply, view_from_params(params, socket)}
      end

      defp view_from_params(params, socket) do
        try do
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
            Map.put(acc, Map.get(f, "section"), Map.get(acc, Map.get(f, "section"), []) ++ [f])
          end)

        filtered = filter_recurse(selecto, filters_by_section, "filters")

        selected_view = String.to_atom(Map.get(params, "view_mode"))

        # Handle case where view might not be found
        view_tuple = Enum.find(socket.assigns.views, fn {id, _, _, _} -> id == selected_view end)
        
        {view_set, view_meta} = case view_tuple do
          {_, module, _, opt} ->
            String.to_existing_atom("#{module}.Process").view(
              opt,
              params,
              columns_map,
              filtered,
              selecto
            )
          nil ->
            # View not found - raise error that will be caught
            raise "View mode '#{selected_view}' not found in configured views"
        end

        selecto = Map.put(selecto, :set, view_set)

        # Apply automatic pivot if needed
        selecto = SelectoComponents.Form.maybe_auto_pivot(selecto, params)
        

        # Apply subselects if denorm_groups were configured
        selecto = if Map.has_key?(selecto.set, :denorm_groups) and is_map(selecto.set.denorm_groups) and map_size(selecto.set.denorm_groups) > 0 do
          denorm_groups = selecto.set.denorm_groups
          
          # The selecto already has the selected columns set, we just need to add subselects
          # Use SubselectBuilder to add subselects for denormalizing columns
          try do
            # Add subselects for each denormalizing group
            result = Enum.reduce(denorm_groups, selecto, fn {relationship_path, columns}, acc ->
              # Add subselect for #{relationship_path} with columns: #{inspect(columns)}
              SelectoComponents.SubselectBuilder.add_subselect_for_group(acc, relationship_path, columns)
            end)
            
            result
          rescue
            e ->
              # Failed to apply subselects: #{inspect(e)}
              # Fall back to original selecto if subselects fail
              selecto
          end
        else
          # No denorm_groups to process
          selecto
        end
        
        # Apply sorting if provided
        selecto = if socket.assigns[:sort_by] do
          alias SelectoComponents.EnhancedTable.Sorting
          Sorting.apply_sort_to_query(selecto, socket.assigns.sort_by)
        else
          selecto
        end

        # Execute query using the new metadata-returning function
        # This handles errors gracefully and won't crash the LiveView
        query_result = try do
          Selecto.execute_with_metadata(selecto)
        rescue
          error ->
            # Catch any errors during execution to prevent LiveView crashes
            {:error, Selecto.Error.from_reason(error)}
        catch
          :exit, reason ->
            # Catch exits (like connection failures) to prevent LiveView crashes
            {:error, Selecto.Error.connection_error("Database connection failed", %{exit_reason: reason})}
        end
        
        case query_result do
          {:ok, {rows, columns, aliases}, metadata} ->
            # Extract metadata from the new execute function
            query_sql = Map.get(metadata, :sql)
            query_params = Map.get(metadata, :params, [])
            execution_time = Map.get(metadata, :execution_time, 0)

            # Record query metrics
            SelectoComponents.Performance.MetricsCollector.record_query(
              query_sql,
              execution_time,
              %{
                rows_returned: length(rows),
                columns_count: length(columns),
                view_mode: socket.assigns.view_config.view_mode,
                has_filters: length(selecto.set.filtered) > 0,
                has_grouping: length(selecto.set.group_by) > 0,
                params: query_params
              }
            )

            # Convert rows to maps if they're lists (happens with subselects)
            # But only for detail views - aggregate views need list format
            normalized_rows = if socket.assigns.view_config.view_mode == "detail" and 
                                length(rows) > 0 and is_list(hd(rows)) do
              # Converting list rows to maps for detail view
              Enum.map(rows, fn row ->
                Enum.zip(columns, row) |> Map.new()
              end)
            else
              rows
            end
            
            # Check if any rows have subselect data
            # Debug inspection removed - data structure validated elsewhere

            view_meta = Map.merge(view_meta, %{exe_id: UUID.uuid4()})

            assign(socket,
              selecto: selecto,
              columns: columns_list,
              field_filters: Selecto.filters(selecto),
              query_results: {normalized_rows, columns, aliases},
              used_params: params,
              applied_view: Map.get(params, "view_mode"),
              view_meta: view_meta,
              executed: true,
              execution_error: nil,
              last_query_info: %{
                sql: query_sql,
                params: query_params,
                timing: execution_time
              }
            )

          {:error, %Selecto.Error{} = error} ->
            sanitized_error = sanitize_error_for_environment(error)
            if dev_mode?() do
              IO.puts("[QUERY ERROR] Selecto.Error: #{inspect(error)}")
            end
            
            # Try to extract SQL even in error case for debugging
            {error_sql, error_params} = try do
              case Selecto.to_sql(selecto) do
                {sql, params} -> {sql, params}
                _ -> {nil, []}
              end
            rescue
              _ -> {nil, []}
            end
            
            assign(socket,
              selecto: selecto,
              columns: columns_list,
              field_filters: Selecto.filters(selecto),
              query_results: nil,
              used_params: params,
              applied_view: Map.get(params, "view_mode"),
              view_meta: view_meta,
              executed: false,
              execution_error: sanitized_error,
              last_query_info: %{
                sql: error_sql,
                params: error_params,
                timing: nil
              }
            )
            
          {:error, error} ->
            sanitized_error = sanitize_error_for_environment(%Selecto.Error{
              type: :query_error, 
              message: inspect(error),
              details: %{original_error: error}
            })
            
            if dev_mode?() do
              IO.puts("[QUERY ERROR] Generic error: #{inspect(error)}")
            end
            
            # Try to extract SQL even in error case for debugging
            {error_sql, error_params} = try do
              case Selecto.to_sql(selecto) do
                {sql, params} -> {sql, params}
                _ -> {nil, []}
              end
            rescue
              _ -> {nil, []}
            end
            
            assign(socket,
              selecto: selecto,
              columns: columns_list,
              field_filters: Selecto.filters(selecto),
              query_results: nil,
              used_params: params,
              applied_view: Map.get(params, "view_mode"),
              view_meta: view_meta,
              executed: false,
              execution_error: sanitized_error,
              last_query_info: %{
                sql: error_sql,
                params: error_params,
                timing: nil
              }
            )
        end
        rescue
          error ->
            # Handle any errors that occur during view processing
            sanitized_error = case error do
              %Selecto.Error{} = e -> e
              e when is_binary(e) -> %Selecto.Error{type: :view_error, message: e, details: %{}}
              e -> %Selecto.Error{type: :view_error, message: "Error processing view: #{inspect(e)}", details: %{error: e}}
            end
            
            if dev_mode?() do
              IO.puts("[VIEW ERROR] #{inspect(error)}")
              IO.puts("[VIEW ERROR] Stacktrace: #{inspect(__STACKTRACE__)}")
            end
            
            assign(socket,
              query_results: nil,
              executed: false,
              execution_error: sanitized_error,
              view_meta: %{},
              last_query_info: %{}
            )
        catch
          :exit, reason ->
            # Handle exits (like process crashes)
            if dev_mode?() do
              IO.puts("[VIEW EXIT] #{inspect(reason)}")
            end
            
            assign(socket,
              query_results: nil,
              executed: false,
              execution_error: %Selecto.Error{
                type: :system_error,
                message: "System error occurred while processing view",
                details: %{exit_reason: reason}
              },
              view_meta: %{},
              last_query_info: %{}
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
          Map.get(params, "view_mode") != Map.get(used_params, "view_mode"),

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
  defp render_filter_form(assigns, uuid, index, section, filter_value) do
    # Get the filter definition from the selecto
    filter_id = filter_value["filter"]
    
    filter_def = 
      case Selecto.filters(assigns.selecto) do
        filters when is_map(filters) ->
          Map.get(filters, filter_id)
        _ ->
          nil
      end
    
    # Check if this is a custom filter with a component
    if filter_def && Map.get(filter_def, :type) == :component && Map.get(filter_def, :component) do
      # Render the custom component
      component_assigns = %{
        uuid: uuid,
        valmap: filter_value,
        def: filter_def
      }
      
      assigns = Map.merge(assigns, component_assigns)
      
      ~H"""
      <div>
        <%= @def.component.(assigns) %>
        <input type="hidden" name={"filters[#{@uuid}][uuid]"} value={@uuid}/>
        <input type="hidden" name={"filters[#{@uuid}][section]"} value={section}/>
        <input type="hidden" name={"filters[#{@uuid}][index]"} value={index}/>
        <input type="hidden" name={"filters[#{@uuid}][filter]"} value={filter_value["filter"]}/>
      </div>
      """
    else
      # Render the default filter form
      assigns = Map.merge(assigns, %{
        uuid: uuid,
        section: section,
        index: index,
        filter_value: filter_value
      })
      
      ~H"""
      <div class="grid grid-cols-3 gap-2">
        <select name={"filters[#{@uuid}][comp]"} class="sc-select">
          <option value="=" selected={@filter_value["comp"] == "="}>Equals</option>
          <option value="!=" selected={@filter_value["comp"] == "!="}>Not Equals</option>
          <option value=">" selected={@filter_value["comp"] == ">"}>Greater Than</option>
          <option value=">=" selected={@filter_value["comp"] == ">="}>Greater or Equal</option>
          <option value="<" selected={@filter_value["comp"] == "<"}>Less Than</option>
          <option value="<=" selected={@filter_value["comp"] == "<="}>Less or Equal</option>
          <option value="LIKE" selected={@filter_value["comp"] == "LIKE"}>Contains</option>
          <option value="NOT LIKE" selected={@filter_value["comp"] == "NOT LIKE"}>Does Not Contain</option>
          <option value="IS NULL" selected={@filter_value["comp"] == "IS NULL"}>Is Empty</option>
          <option value="IS NOT NULL" selected={@filter_value["comp"] == "IS NOT NULL"}>Is Not Empty</option>
        </select>
        
        <input 
          type="text" 
          name={"filters[#{@uuid}][value]"} 
          value={@filter_value["value"]}
          placeholder="Enter value..."
          class="sc-input col-span-2"
          disabled={@filter_value["comp"] in ["IS NULL", "IS NOT NULL"]}
        />
        
        <input type="hidden" name={"filters[#{@uuid}][uuid]"} value={@uuid}/>
        <input type="hidden" name={"filters[#{@uuid}][section]"} value={@section}/>
        <input type="hidden" name={"filters[#{@uuid}][index]"} value={@index}/>
        <input type="hidden" name={"filters[#{@uuid}][filter]"} value={@filter_value["filter"]}/>
      </div>
      """
    end
  end

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
  
  defp build_available_fields(selecto) do
    Selecto.columns(selecto)
    |> Enum.map(fn {field_id, column} ->
      field_id_str = if is_atom(field_id), do: Atom.to_string(field_id), else: to_string(field_id)
      field_name = Map.get(column, :name, field_id_str)
      {field_id_str, %{name: field_name}}
    end)
    |> Map.new()
  end

  # Auto-pivot detection and application
  # These functions are used within the macro expansion
  def maybe_auto_pivot(selecto, params) do
    # Check if automatic pivot is needed based on selected columns
    selected_columns = get_selected_columns_from_params(params)
    
    
    if should_auto_pivot?(selecto, selected_columns) do
      target_table = find_pivot_target(selecto, selected_columns)
      
      if target_table do
        # Apply custom pivot for PagilaDomain structure
        
        # Find the join path to the target table
        join_path = find_join_path_to_target(selecto.domain, target_table)
        
        if join_path do
          # Apply the custom pivot transformation
          pivoted = apply_custom_pivot(selecto, target_table, join_path)
          pivoted
        else
          selecto
        end
      else
        selecto
      end
    else
      selecto
    end
  end

  def get_selected_columns_from_params(params) do
    view_mode = Map.get(params, "view_mode", "")
    
    case view_mode do
      "aggregate" ->
        group_by_cols = Map.get(params, "group_by", %{}) 
                       |> Map.values() 
                       |> Enum.map(fn item -> Map.get(item, "field") end)
        
        aggregate_cols = Map.get(params, "aggregate", %{})
                        |> Map.values()
                        |> Enum.map(fn item -> Map.get(item, "field") end)
        
        group_by_cols ++ aggregate_cols
        
      "detail" ->
        # Handle the selected map structure from the UI
        selected_map = Map.get(params, "selected", %{})
        
        # Extract field names from the selected map
        Map.values(selected_map)
        |> Enum.map(fn item ->
          Map.get(item, "field")
        end)
        |> Enum.filter(&(&1 != nil))
        
      _ ->
        []
    end
  end

  def should_auto_pivot?(selecto, selected_columns) do
    # Check if selected columns justify a pivot
    source_columns = get_source_columns(selecto)
    source_column_strs = Enum.map(source_columns, &to_string/1)
    
    # Categorize columns
    {source_cols, qualified_cols_by_table} = Enum.reduce(selected_columns, {[], %{}}, fn col, {src, qualified} ->
      col_str = to_string(col)
      
      if String.contains?(col_str, ".") do
        # It's a qualified column
        parts = String.split(col_str, ".", parts: 2)
        [table_name, _column_name] = parts
        
        if table_name == "selecto_root" || table_name == "" do
          # It's actually a source column with qualification
          {[col_str | src], qualified}
        else
          # Group by table name
          current = Map.get(qualified, table_name, [])
          {src, Map.put(qualified, table_name, [col_str | current])}
        end
      else
        # Unqualified column - check if it's from source
        if column_exists_in_source?(col, source_columns) do
          {[col_str | src], qualified}
        else
          # It's not from source, we can't pivot without knowing where it's from
          {src, qualified}
        end
      end
    end)
    
    
    # Only pivot if:
    # 1. There are qualified columns from other tables
    # 2. NO source columns are selected (they wouldn't be available after pivot)
    # 3. All qualified columns are from tables accessible from a single pivot target
    
    result = case Map.keys(qualified_cols_by_table) do
      [] ->
        # No qualified columns from other tables
        false
      table_names ->
        if source_cols != [] do
          false
        else
          # Check if we can find a pivot target that gives access to all tables
          # For now, use a simple heuristic: pivot to the first/root table in the list
          # In PagilaDomain: film can access language, but language can't access film
          # So if we have [film, language], we can pivot to film
          
          # Simple approach: try to pivot to the first table and assume it has access to others
          # More sophisticated would be to check the actual join hierarchy
          pivot_target = hd(table_names)
          
          # For now, allow pivot to the first table
          # This works for film -> language case
          true
        end
    end
    
    result
  end

  def get_source_columns(selecto) do
    # Get columns from the source table
    source_config = selecto.domain.source
    Map.keys(source_config.columns || %{})
  end

  def column_exists_in_source?(column_name, source_columns) do
    # Check if column exists in source (handle string/atom conversion)
    col_atom = if is_binary(column_name), do: String.to_atom(column_name), else: column_name
    col_string = if is_atom(column_name), do: Atom.to_string(column_name), else: column_name
    
    Enum.any?(source_columns, fn source_col ->
      source_col == col_atom or source_col == col_string or 
      Atom.to_string(source_col) == col_string
    end)
  end

  def find_pivot_target(selecto, selected_columns) do
    # Find the target table from qualified column names
    
    
    # Extract table names from qualified columns
    table_targets = 
      selected_columns
      |> Enum.map(fn col ->
        col_str = to_string(col)
        if String.contains?(col_str, ".") do
          [table_name, _] = String.split(col_str, ".", parts: 2)
          result = String.to_atom(table_name)
          result
        else
          nil
        end
      end)
      |> Enum.filter(&(&1 != nil))
      |> Enum.uniq()
    
    
    # If we have explicit table references, determine the best pivot target
    if length(table_targets) > 0 do
      # When there are multiple tables, we need to find the "root" table
      # that provides access to all the others
      target = if length(table_targets) > 1 do
        # Multiple tables - need to pick the one that can access the others
        # In the hierarchy: actor -> film_actors -> film -> language
        # If we have [language, film], we should pivot to film (not language)
        # because film can access language, but language can't access film
        
        # Simple heuristic: prefer tables that appear earlier in the join chain
        # film comes before language in the hierarchy
        priority_order = [:film, :film_actors, :language, :category, :inventory, :rental, :customer]
        
        sorted_targets = Enum.sort_by(table_targets, fn target ->
          # Find index in priority order, or put at end if not found
          Enum.find_index(priority_order, &(&1 == target)) || 999
        end)
        
        selected_target = hd(sorted_targets)
        selected_target
      else
        target = hd(table_targets)
        target
      end
      
      target
    else
      # Fall back to checking schemas for simple column names
      schemas = Map.get(selecto.domain, :schemas, %{})
      
      result = Enum.find_value(schemas, fn {schema_name, schema_config} ->
        schema_columns = Map.keys(schema_config.columns || %{})
        
        if has_all_columns?(selected_columns, schema_columns) do
          schema_name
        else
          nil
        end
      end)
      
      result
    end
  end

  def has_all_columns?(selected_columns, schema_columns) do
    # Check if schema has all selected columns
    # Handle both simple and qualified column names
    Enum.all?(selected_columns, fn col ->
      col_str = to_string(col)
      
      # If it's a qualified column name, extract just the column part
      col_name = 
        if String.contains?(col_str, ".") do
          [_, column_name] = String.split(col_str, ".", parts: 2)
          column_name
        else
          col_str
        end
      
      col_atom = if is_binary(col_name), do: String.to_atom(col_name), else: col_name
      
      Enum.any?(schema_columns, fn schema_col ->
        schema_col == col_atom or 
        Atom.to_string(schema_col) == col_name
      end)
    end)
  end

  # Find the join path from source to target table in PagilaDomain structure
  def find_join_path_to_target(domain, target_table) do
    target_str = Atom.to_string(target_table)
    
    # Search through the joins hierarchy
    case Map.get(domain, :joins) do
      nil -> 
        nil
      joins ->
        search_joins_recursive(joins, target_str, [])
    end
  end

  defp search_joins_recursive(joins, target, path) when is_map(joins) do
    Enum.find_value(joins, fn {join_name, join_config} ->
      join_name_str = Atom.to_string(join_name)
      
      # Check if this is the target
      if join_name_str == target do
        path ++ [join_name]
      else
        # Check nested joins
        case Map.get(join_config, :joins) do
          nil -> nil
          nested_joins ->
            search_joins_recursive(nested_joins, target, path ++ [join_name])
        end
      end
    end)
  end

  defp search_joins_recursive(_, _, _), do: nil

  # Apply custom pivot transformation
  def apply_custom_pivot(selecto, target_table, join_path) do
    
    # Store the pivot configuration in the selecto set
    pivot_config = %{
      target_table: target_table,
      join_path: join_path,
      original_source: :actor,  # The original source table
      original_filters: Map.get(selecto.set, :filtered, [])
    }
    
    # Update the selecto set with pivot information
    # This will be used by Selecto's query builder to restructure the query
    updated_set = Map.put(selecto.set, :pivot_config, pivot_config)
    
    # Also set a pivot_state for compatibility
    # Use CTE strategy for better performance and cleaner SQL
    pivot_state = %{
      target_schema: target_table,
      join_path: join_path,
      preserve_filters: true,
      subquery_strategy: :cte
    }
    
    updated_set = Map.put(updated_set, :pivot_state, pivot_state)
    
    
    Map.put(selecto, :set, updated_set)
  end
  
  # Environment detection helpers
  def dev_mode? do
    # Check if we're in dev or test environment
    # You can also use Mix.env() if available, or Application.get_env
    case Application.get_env(:selecto_components, :environment) do
      nil ->
        # Fall back to checking common indicators
        System.get_env("MIX_ENV") in ["dev", "test", nil]
      :prod ->
        false
      :production ->
        false
      _ ->
        true
    end
  end
  
  def sanitize_error_for_environment(error) do
    if dev_mode?() do
      # In dev mode, return the full error with all details
      error
    else
      # In production, sanitize the error to remove sensitive information
      %Selecto.Error{
        type: error.type,
        message: get_safe_error_message(error),
        details: %{},  # Remove all details in production
        query: nil,     # Never expose queries in production
        params: []      # Never expose params in production
      }
    end
  end
  
  defp get_safe_error_message(%Selecto.Error{type: type}) do
    # Return user-friendly messages based on error type
    case type do
      :connection_error ->
        "Unable to connect to the database. Please try again later."
      :query_error ->
        "An error occurred while processing your request. Please try again."
      :timeout_error ->
        "The request took too long to complete. Please try again with a simpler query."
      :permission_error ->
        "You don't have permission to access this data."
      :validation_error ->
        "The request contains invalid parameters. Please check your inputs."
      _ ->
        "An unexpected error occurred. Please try again or contact support if the problem persists."
    end
  end

  @doc false
  def build_debug_data(assigns) do
    query_data = Map.get(assigns, :last_query_info, %{})
    
    # Extract row count from query_results
    row_count = case Map.get(assigns, :query_results) do
      {rows, _columns, _aliases} when is_list(rows) ->
        length(rows)
      [] ->
        # Initial state has empty list
        0
      nil ->
        0
      other ->
        # Try to handle other formats
        case other do
          list when is_list(list) -> length(list)
          _ -> 0
        end
    end
    
    %{
      query: Map.get(query_data, :sql),
      params: Map.get(query_data, :params, []),
      timing: Map.get(query_data, :timing),
      row_count: row_count,
      execution_plan: Map.get(query_data, :execution_plan)
    }
  end
end
