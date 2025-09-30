defmodule SelectoComponents.Form do
  use Phoenix.LiveComponent

  import SelectoComponents.Components.Common
  alias Phoenix.LiveView.JS
  alias SelectoComponents.ErrorHandling.ErrorDisplay
  alias SelectoComponents.Form.FilterRendering

  @doc """
  Form for configuing Selecto View

  attrs:
  selecto: the selecto structure
  view_config: attr which contains the data to draw the view

  """

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns,
        columns: build_column_list(assigns.selecto),
        field_filters: FilterRendering.build_filter_list(assigns.selecto),
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
            id={"#{@id}_tree_builder_#{FilterRendering.hash_filter_structure(@view_config.filters)}"}
            available={FilterRendering.build_filter_list(@selecto)}
            filters={@view_config.filters}
          >
            <:filter_form :let={{uuid, index, section, filter_value}}>
              <%= FilterRendering.render_filter_form(assigns, uuid, index, section, filter_value) %>
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

      <%!-- Render modal if enabled and triggered --%>
      <%= if Map.get(assigns, :enable_modal_detail) && Map.get(assigns, :show_detail_modal) do %>
        <.live_component
          module={SelectoComponents.Modal.DetailModal}
          id="detail-modal"
          record={@modal_detail_data.record}
          current_index={@modal_detail_data.current_index}
          total_records={@modal_detail_data.total_records}
          records={@modal_detail_data.records}
          fields={@modal_detail_data.fields}
          related_data={@modal_detail_data.related_data}
          title="Record Details"
          size={:lg}
          navigation_enabled={true}
          edit_enabled={false}
        />
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("datetime-filter-change", params, socket) do
    # This event is triggered when datetime filter comparison mode changes
    # We need to update the view config to reflect the change
    require Logger
    Logger.debug("Datetime filter change event received")

    # Extract UUID from _target or params
    uuid = params["uuid"] ||
           (case get_in(params, ["_target"]) do
              ["filters", uuid_val, "comp"] -> uuid_val
              _ -> nil
            end)

    # Get the new comparison value directly from filters
    new_comp = get_in(params, ["filters", uuid, "comp"])

    Logger.debug("UUID: #{uuid}, New comparison: #{new_comp}")

    # Update the view_config in the socket assigns
    updated_filters = socket.assigns.view_config.filters
      |> Enum.map(fn
        {u, section, filter} when u == uuid ->
          # Update the comparison operator and reset value when changing modes
          updated_filter = case new_comp do
            "BETWEEN" ->
              # Reset to empty values for between mode
              Map.merge(filter, %{"comp" => new_comp, "value" => nil, "value_start" => nil, "value_end" => nil})
            "DATE_BETWEEN" ->
              # Reset to empty values for date between mode
              Map.merge(filter, %{"comp" => new_comp, "value" => nil, "value_start" => nil, "value_end" => nil})
            "DATE=" ->
              # Keep existing value or set to today's date
              Map.merge(filter, %{"comp" => new_comp, "value" => filter["value"] || Date.utc_today()})
            "DATE!=" ->
              # Keep existing value or set to today's date
              Map.merge(filter, %{"comp" => new_comp, "value" => filter["value"] || Date.utc_today()})
            "SHORTCUT" ->
              # Default to "today" for shortcuts
              Map.merge(filter, %{"comp" => new_comp, "value" => "today"})
            "RELATIVE" ->
              # Default to empty for relative
              Map.merge(filter, %{"comp" => new_comp, "value" => ""})
            _ ->
              # Keep existing value for standard operators
              Map.put(filter, "comp", new_comp)
          end
          {u, section, updated_filter}
        other ->
          other
      end)

    updated_config = put_in(socket.assigns.view_config, [:filters], updated_filters)

    # Send the updated config to the parent LiveView
    send(self(), {:update_view_config, updated_config})

    # Also update the LiveComponent's state for immediate rendering
    {:noreply, assign(socket, view_config: updated_config)}
  end

  defmacro __using__(_opts \\ []) do
    quote do
      ### These run in the 'use'ing liveview's context

      # Import error handling helpers
      import SelectoComponents.Form, only: [dev_mode?: 0, sanitize_error_for_environment: 1]

      import SelectoComponents.Helpers
      import SelectoComponents.Helpers.Filters
      alias SelectoComponents.ErrorHandling.ErrorCategorizer
      alias SelectoComponents.Form.ParamsState
      alias SelectoComponents.Form.ListPickerOperations
      alias SelectoComponents.Form.DrillDownFilters

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
          # Error type: #{error_type}
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
        socket = ParamsState.params_to_state(view.params, socket)
        {:noreply, ParamsState.view_from_params(view.params, socket)}
      end

      def handle_params(%{"view_mode" => _m} = params, _uri, socket) do
        # Normalize any existing query results before processing
        socket = normalize_query_results(socket)
        socket = ParamsState.params_to_state(params, socket)
        {:noreply, ParamsState.view_from_params(params, socket)}
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
        # Check if we should skip this validation (e.g., after filter add/remove)
        if socket.assigns[:skip_next_validation] do
          # Clear the flag and skip processing
          {:noreply, assign(socket, skip_next_validation: false)}
        else
          with_error_handling(socket, "view-validate", fn ->
            # Process all parameters including view-specific configs (aggregates, group_by, etc.)
            socket = ParamsState.params_to_state(params, socket)

            # Don't execute view on validation - only on submit
            # This allows users to configure aggregates without immediate updates
            {:noreply, socket}
          end)
        end
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
        socket = assign(socket, :current_detail_page, 0)
        {:noreply, ParamsState.state_to_url(params, socket)}
      end

      def handle_event("view-apply", params, socket) do
        with_error_handling(socket, "view-apply", fn ->
          socket = assign(socket, :current_detail_page, 0)
          # Execute query first, THEN update URL to prevent race condition
          socket = ParamsState.view_from_params(params, socket)
          {:noreply, ParamsState.state_to_url(params, socket)}
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
              # Decode the saved configuration
              saved_params = socket.assigns.saved_view_config_module.decode_view_config(config)

              # The saved params only contain the view-specific configuration
              # We need to convert it to full params format
              params = ParamsState.convert_saved_config_to_full_params(saved_params, view_type)

              # First update the view_config state from params
              socket = ParamsState.params_to_state(params, socket)

              # Then apply the view
              socket = ParamsState.view_from_params(params, socket)
              {:noreply, put_flash(socket, :info, "View configuration loaded: #{config.name}")}
          end
        end)
      end

      @impl true
      def handle_event("treedrop", par, socket) do
        new_filter = Map.get(par, "element")
        target = Map.get(par, "target")

        new_filter_item = case new_filter do
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

        updated_filters = socket.assigns.view_config.filters ++ new_filter_item

        socket =
          assign(socket,
            view_config: %{
              socket.assigns.view_config
              | filters: updated_filters
            },
            # Set a flag to skip query execution on next validation
            skip_next_validation: true
          )

        {:noreply, socket}
      end

      def handle_event("filter_remove", params, socket) do
        # Update filters without triggering view execution
        updated_filters = socket.assigns.view_config.filters
          |> Enum.filter(fn
            {u, s, _c} -> u != Map.get(params, "uuid") && s != Map.get(params, "uuid")
          end)

        socket =
          assign(socket,
            view_config: %{socket.assigns.view_config | filters: updated_filters},
            # Set a flag to skip query execution on next validation
            skip_next_validation: true
          )

        {:noreply, socket}
      end

      # The datetime-filter-change event is now handled by the LiveComponent directly
      # This prevents conflicts and ensures proper state management

      def handle_event("agg_add_filters", params, socket) do
        with_error_handling(socket, "agg_add_filters", fn ->
          # Use helper module to build drill-down parameters
          view_params = DrillDownFilters.build_agg_drill_down_params(params, socket)

          # Build filter tuples for view_config
          filter_tuples = DrillDownFilters.build_filter_tuples(params, socket)

          # Update view_config with new filters
          selected_view = String.to_atom(socket.assigns.view_config.view_mode)
          {_, _, _, opt} = Enum.find(socket.assigns.views, fn {id, _, _, _} -> id == selected_view end)
          new_view_mode = Map.get(opt, :drill_down, "detail")

          # Remove existing filters for the same fields and add new ones
          updated_filters =
            Enum.filter(socket.assigns.view_config.filters, fn
              {_id, "filters", %{} = f} -> !Map.has_key?(params, Map.get(f, "filter"))
              _ -> true
            end) ++ filter_tuples

          socket = assign(socket,
            view_config: %{
              socket.assigns.view_config
              | view_mode: new_view_mode,
                filters: updated_filters
            }
          )

          # Execute query first, THEN update URL to prevent race condition
          socket = ParamsState.view_from_params(view_params, socket)
          {:noreply, ParamsState.state_to_url(view_params, socket)}
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

          # Execute query first, THEN update URL to prevent race condition
          socket = ParamsState.view_from_params(view_params, socket)
          {:noreply, ParamsState.state_to_url(view_params, socket)}
        end)
      end

      @impl true
      def handle_info({:view_set, view}, socket) do
        {:noreply, assign(socket, view_config: %{socket.assigns.view_config | view_mode: view})}
      end

      @impl true
      def handle_info({:list_picker_remove, view, list, item}, socket) do
        # Use helper module to remove item
        updated_view_config = ListPickerOperations.remove_item_from_list(
          socket.assigns.view_config,
          view,
          list,
          item
        )

        socket = assign(socket, view_config: updated_view_config)

        # Find and update the view module
        view_module = Enum.find(socket.assigns.views, fn {id, _, _, _} ->
          id == String.to_atom(view)
        end)

        if view_module do
          ListPickerOperations.send_view_update(view_module, updated_view_config, socket.assigns)
        end

        {:noreply, socket}
      end

      @impl true
      def handle_info({:list_picker_move, view, list, uuid, direction}, socket) do
        # Use helper module to move item
        updated_view_config = ListPickerOperations.move_item_in_list(
          socket.assigns.view_config,
          view,
          list,
          uuid,
          direction
        )

        socket = assign(socket, view_config: updated_view_config)

        # Find and update the view module
        view_module = Enum.find(socket.assigns.views, fn {id, _, _, _} ->
          id == String.to_atom(view)
        end)

        if view_module do
          ListPickerOperations.send_view_update(view_module, updated_view_config, socket.assigns)
        end

        {:noreply, socket}
      end

      @impl true
      def handle_info({:list_picker_add, view, list, item}, socket) do
        # Create item tuple with UUID and empty config
        item_tuple = {UUID.uuid4(), item, %{}}

        # Use helper module to add item
        updated_view_config = ListPickerOperations.add_item_to_list(
          socket.assigns.view_config,
          view,
          list,
          item_tuple
        )

        socket = assign(socket, view_config: updated_view_config)

        # Find and update the view module
        view_module = Enum.find(socket.assigns.views, fn {id, _, _, _} ->
          id == String.to_atom(view)
        end)

        if view_module do
          ListPickerOperations.send_view_update(view_module, updated_view_config, socket.assigns)
        end

        {:noreply, socket}
      end

      @impl true
      def handle_info({:rerun_query_with_sort, sort_by}, socket) do
        with_error_handling(socket, "rerun_query_with_sort", fn ->
          # Get current parameters or use saved params
          params = socket.assigns[:used_params] || ParamsState.view_config_to_params(socket.assigns.view_config)

          # Store sort configuration in socket
          socket = assign(socket, sort_by: sort_by)

          # Re-execute the view with current parameters and sorting
          ParamsState.view_from_params_with_sort(params, socket, sort_by)
        end)
      end

      @impl true
      def handle_info({:update_view_config, updated_config}, socket) do
        # Update the view config in the parent LiveView
        {:noreply, assign(socket, view_config: updated_config)}
      end

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

      @impl true
      def handle_info({:update_detail_page, page}, socket) do
        socket = assign(socket, :current_detail_page, page)

        params = socket.assigns[:used_params] || ParamsState.view_config_to_params(socket.assigns.view_config)
        params = Map.put(params, "detail_page", to_string(page))

        # Execute query first, THEN update URL to prevent race condition
        socket = ParamsState.view_from_params(params, socket)
        {:noreply, ParamsState.state_to_url(params, socket)}
      end

      # Helper function to execute view from current state
      defp execute_view_from_current_state(socket) do
        params = ParamsState.view_config_to_params(socket.assigns.view_config)
        ParamsState.view_from_params(params, socket)
      end


      @impl true
      def handle_info({:query_executed, query_info}, socket) do
        socket =
          socket
          |> assign(:query_results, query_info.query_results)
          |> assign(:last_query_info, Map.get(query_info, :last_query_info))
          |> assign(:view_meta, Map.get(query_info, :view_meta))
          |> assign(:applied_view, Map.get(query_info, :applied_view))
          |> assign(:executed, true)

        {:noreply, socket}
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

  # Helper to extract selected columns from params for pivot detection
  # This function is used both internally and by Selecto.AutoPivot

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
