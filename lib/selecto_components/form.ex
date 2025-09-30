defmodule SelectoComponents.Form do
  use Phoenix.LiveComponent

  import SelectoComponents.Components.Common
  alias Phoenix.LiveView.JS
  alias SelectoComponents.ErrorHandling.ErrorDisplay

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
            id={"#{@id}_tree_builder_#{hash_filter_structure(@view_config.filters)}"}
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
    IO.puts("\n=== DATETIME FILTER CHANGE (LiveComponent) ===")
    IO.inspect(params, label: "Params received")

    # Extract UUID from _target or params
    uuid = params["uuid"] ||
           (case get_in(params, ["_target"]) do
              ["filters", uuid_val, "comp"] -> uuid_val
              _ -> nil
            end)

    # Get the new comparison value directly from filters
    new_comp = get_in(params, ["filters", uuid, "comp"])

    IO.puts("UUID: #{uuid}")
    IO.puts("New comparison: #{inspect(new_comp)}")

    # Update the view_config in the socket assigns
    IO.inspect(socket.assigns.view_config.filters, label: "Current filters")

    updated_filters = socket.assigns.view_config.filters
      |> Enum.map(fn
        {u, section, filter} when u == uuid ->
          IO.puts("Found matching filter to update: #{u}")
          # Update the comparison operator and reset value when changing modes
          updated_filter = case new_comp do
            "BETWEEN" ->
              IO.puts("Switching to BETWEEN mode")
              # Reset to empty values for between mode
              Map.merge(filter, %{"comp" => new_comp, "value" => nil, "value_start" => nil, "value_end" => nil})
            "DATE_BETWEEN" ->
              IO.puts("Switching to DATE_BETWEEN mode")
              # Reset to empty values for date between mode
              Map.merge(filter, %{"comp" => new_comp, "value" => nil, "value_start" => nil, "value_end" => nil})
            "DATE=" ->
              IO.puts("Switching to DATE= mode")
              # Keep existing value or set to today's date
              Map.merge(filter, %{"comp" => new_comp, "value" => filter["value"] || Date.utc_today()})
            "DATE!=" ->
              IO.puts("Switching to DATE!= mode")
              # Keep existing value or set to today's date
              Map.merge(filter, %{"comp" => new_comp, "value" => filter["value"] || Date.utc_today()})
            "SHORTCUT" ->
              IO.puts("Switching to SHORTCUT mode")
              # Default to "today" for shortcuts
              Map.merge(filter, %{"comp" => new_comp, "value" => "today"})
            "RELATIVE" ->
              IO.puts("Switching to RELATIVE mode")
              # Default to empty for relative
              Map.merge(filter, %{"comp" => new_comp, "value" => ""})
            _ ->
              IO.puts("Switching to standard mode: #{new_comp}")
              # Keep existing value for standard operators
              Map.put(filter, "comp", new_comp)
          end
          IO.inspect(updated_filter, label: "Updated filter value")
          {u, section, updated_filter}
        other ->
          other
      end)

    IO.inspect(updated_filters, label: "All filters after update")

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
        # Check if we should skip this validation (e.g., after filter add/remove)
        if socket.assigns[:skip_next_validation] do
          # Clear the flag and skip processing
          {:noreply, assign(socket, skip_next_validation: false)}
        else
          with_error_handling(socket, "view-validate", fn ->
            # Process all parameters including view-specific configs (aggregates, group_by, etc.)
            socket = params_to_state(params, socket)

            # Mark as not executed so components show "Loading..." instead of stale data
            # This prevents displaying mismatched headers and data when config changes
            # Query will execute on form submit (view-apply) which updates URL params
            socket = assign(socket, executed: false)

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
        {:noreply, state_to_url(params, socket)}
      end

      def handle_event("view-apply", params, socket) do
        with_error_handling(socket, "view-apply", fn ->
          socket = assign(socket, :current_detail_page, 0)
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
              # Decode the saved configuration
              saved_params = socket.assigns.saved_view_config_module.decode_view_config(config)

              # The saved params only contain the view-specific configuration
              # We need to convert it to full params format
              params = convert_saved_config_to_full_params(saved_params, view_type)

              # First update the view_config state from params
              socket = params_to_state(params, socket)

              # Then apply the view
              socket = view_from_params(params, socket)
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
          IO.puts("\n=== AGG_ADD_FILTERS DEBUG ===")
          IO.inspect(params, label: "Params received")
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

                # Extract the actual field name from phx-value-* parameters
                field_name = case f do
                  "phx-value-" <> actual_field ->
                    actual_field
                  "" ->
                    # Try to find a suitable field from current group_by configuration
                    # The group_by is in the used_params, not view_config
                    current_group_by = Map.get(socket.assigns.used_params, "group_by", %{})
                    first_group = current_group_by
                      |> Map.values()
                      |> Enum.sort(fn a, b ->
                        String.to_integer(Map.get(a, "index", "0")) <= String.to_integer(Map.get(b, "index", "0"))
                      end)
                      |> List.first()

                    case first_group do
                      %{"field" => field} -> field
                      _ -> "id"  # Fallback to a basic field
                    end
                  nil ->
                    # Try to find a suitable field from current group_by configuration
                    # The group_by is in the used_params, not view_config
                    current_group_by = Map.get(socket.assigns.used_params, "group_by", %{})
                    first_group = current_group_by
                      |> Map.values()
                      |> Enum.sort(fn a, b ->
                        String.to_integer(Map.get(a, "index", "0")) <= String.to_integer(Map.get(b, "index", "0"))
                      end)
                      |> List.first()

                    case first_group do
                      %{"field" => field} -> field
                      _ -> "id"  # Fallback to a basic field
                    end
                  _ -> f
                end

                IO.puts("Extracted field_name: #{field_name}")
                conf = Selecto.field(socket.assigns.selecto, field_name)

                # Check if this is an age bucket field from group_by config
                group_by_config = Map.get(socket.assigns.used_params, "group_by", %{})
                field_group_config = Enum.find_value(Map.values(group_by_config), fn config ->
                  if Map.get(config, "field") == field_name do
                    config
                  else
                    nil
                  end
                end)

                is_age_bucket = field_group_config && Map.get(field_group_config, "format") == "age_buckets"

                # Detect date format patterns and set appropriate comparison mode
                {comp_mode, v1, v2} = cond do
                  # Check for bucket range patterns like "1-10", "11+", "Other", etc.
                  String.match?(v, ~r/^\d+-\d+$/) || String.match?(v, ~r/^\d+\+$/) || v == "Other" ->
                    # This is a bucket range - parse it to create appropriate filter
                    if is_age_bucket && conf && Map.get(conf, :type) in [:utc_datetime, :naive_datetime, :date] do
                      # For age buckets on date fields, convert age ranges to date ranges
                      today = Date.utc_today()

                      cond do
                        # Range like "1-10" or "0-10" - convert to date range
                        String.match?(v, ~r/^(\d+)-(\d+)$/) ->
                          [min_days_str, max_days_str] = String.split(v, "-")
                          max_days = String.to_integer(max_days_str)
                          min_days = String.to_integer(min_days_str)
                          # Dates are max_days ago to min_days ago
                          start_date = Date.add(today, -(max_days + 1))
                          end_date = Date.add(today, -min_days)
                          {"DATE_BETWEEN", Date.to_iso8601(start_date), Date.to_iso8601(end_date)}

                        # Open-ended range like "11+" - older than N days
                        String.match?(v, ~r/^(\d+)\+$/) ->
                          days = v |> String.replace("+", "") |> String.to_integer()
                          cutoff_date = Date.add(today, -days)
                          {"<=", Date.to_iso8601(cutoff_date), ""}

                        # "Other" bucket - skip for now
                        v == "Other" ->
                          {"=", "", ""}

                        true ->
                          {"=", v, ""}
                      end
                    else
                      # Not age bucket or not a date field - handle as numeric bucket
                      cond do
                        # Range like "1-10" or "0-10"
                        String.match?(v, ~r/^(\d+)-(\d+)$/) ->
                          [min_str, max_str] = String.split(v, "-")
                          {"BETWEEN", min_str, max_str}

                        # Open-ended range like "11+"
                        String.match?(v, ~r/^(\d+)\+$/) ->
                          min_str = String.replace(v, "+", "")
                          {">=", min_str, ""}

                        # "Other" bucket - skip creating a filter for now
                        v == "Other" ->
                          {"=", "", ""}  # This will be filtered out by empty value check

                        true ->
                          {"=", v, ""}
                      end
                    end

                  # YYYY-MM-DD format - exact date match
                  String.match?(v, ~r/^\d{4}-\d{2}-\d{2}$/) ->
                    if conf && Map.get(conf, :type) in [:utc_datetime, :naive_datetime, :date] do
                      {"DATE=", v, ""}
                    else
                      {"=", v, ""}
                    end

                  # YYYY-MM format - match entire month
                  String.match?(v, ~r/^\d{4}-\d{2}$/) ->
                    if conf && Map.get(conf, :type) in [:utc_datetime, :naive_datetime, :date] do
                      # Convert to date range for the month
                      [year_str, month_str] = String.split(v, "-")
                      {year, _} = Integer.parse(year_str)
                      {month, _} = Integer.parse(month_str)

                      start_date = Date.new!(year, month, 1)
                      # Get last day of the month
                      days_in_month = Date.days_in_month(start_date)
                      end_date = Date.new!(year, month, days_in_month) |> Date.add(1)

                      {"DATE_BETWEEN", Date.to_iso8601(start_date), Date.to_iso8601(end_date)}
                    else
                      {"=", v, ""}
                    end

                  # YYYY format - match entire year
                  String.match?(v, ~r/^\d{4}$/) ->
                    if conf && Map.get(conf, :type) in [:utc_datetime, :naive_datetime, :date] do
                      {year, _} = Integer.parse(v)
                      start_date = Date.new!(year, 1, 1)
                      end_date = Date.new!(year + 1, 1, 1)

                      {"DATE_BETWEEN", Date.to_iso8601(start_date), Date.to_iso8601(end_date)}
                    else
                      {"=", v, ""}
                    end

                  # Default handling for datetime fields
                  conf != nil ->
                    field_type = Map.get(conf, :type, :string)
                    case field_type do
                      x when x in [:utc_datetime, :naive_datetime] ->
                        {v1_parsed, v2_parsed} = Selecto.Helpers.Date.val_to_dates(%{"value" => v, "value2" => ""})
                        {"=", v1_parsed, v2_parsed}
                      _ ->
                        {"=", v, ""}
                    end

                  # No field configuration found
                  true ->
                    {"=", v, ""}
                end

                filter_config = %{
                  "comp" => comp_mode,
                  "filter" => field_name,
                  "index" => "0",
                  "section" => "filters",
                  "uuid" => newid,
                  "value" => v1,
                  "value2" => v2,
                  "value_start" => if(comp_mode in ["DATE_BETWEEN", "BETWEEN"], do: v1, else: nil),
                  "value_end" => if(comp_mode in ["DATE_BETWEEN", "BETWEEN"], do: v2, else: nil)
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
      def handle_info({:update_view_config, updated_config}, socket) do
        IO.puts("\n=== UPDATING VIEW CONFIG IN PARENT (handle_info) ===")
        IO.inspect(updated_config.filters, label: "New filters")
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

        params = socket.assigns[:used_params] || view_config_to_params(socket.assigns.view_config)
        params = Map.put(params, "detail_page", to_string(page))

        {:noreply, view_from_params(params, state_to_url(params, socket))}
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
        |> Enum.filter(fn {_uuid, f} ->
          # Only include actual filters, not aggregate/group_by configurations
          # Filters should have at least these keys: filter, comp, value, section
          is_map(f) && Map.has_key?(f, "filter") && Map.has_key?(f, "comp")
        end)
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
            # Preserve the original field identifier as colid
            col_with_metadata = col
              |> Map.put(:field, col.name)
              |> Map.put(:colid, key)  # Store the actual field identifier
            {key, col_with_metadata}
          end)
          |> then(fn cols ->
            # Also add entries by display name for lookup convenience
            Enum.reduce(cols, cols, fn {_colid, col}, acc ->
              Map.put(acc, col.name, col)
            end)
          end)

        require Logger
        Logger.debug("=== FILTER PROCESSING IN view_from_params ===")
        Logger.debug("Raw filters from params: #{inspect(Map.get(params, "filters", %{}), pretty: true)}")

        filters_by_section =
          Map.get(params, "filters", %{})
          |> Map.values()
          |> Enum.filter(fn f ->
            # Only include actual filters with required fields
            is_valid = is_map(f) && Map.has_key?(f, "filter") && Map.has_key?(f, "comp") && Map.has_key?(f, "section")
            if not is_valid do
              Logger.debug("Rejecting invalid filter entry: #{inspect(f, pretty: true)}")
            end
            is_valid
          end)
          |> Enum.reduce(%{}, fn f, acc ->
            Map.put(acc, Map.get(f, "section"), Map.get(acc, Map.get(f, "section"), []) ++ [f])
          end)

        Logger.debug("Filters by section after validation: #{inspect(filters_by_section, pretty: true)}")

        filtered = filter_recurse(selecto, filters_by_section, "filters")
        Logger.debug("Filtered result from filter_recurse: #{inspect(filtered, pretty: true)}")

        selected_view = String.to_atom(Map.get(params, "view_mode"))

        # Include the current detail page if we're in detail view
        params = if selected_view == :detail && Map.has_key?(socket.assigns, :current_detail_page) do
          Map.put(params, "detail_page", to_string(socket.assigns.current_detail_page))
        else
          params
        end

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

        require Logger
        Logger.debug("=== FORM VIEW_SET ASSIGNMENT ===")
        Logger.debug("View_set being assigned to selecto.set: #{inspect(view_set, pretty: true)}")
        Logger.debug("View_set.filtered field: #{inspect(Map.get(view_set, :filtered), pretty: true)}")
        selecto = Map.put(selecto, :set, view_set)
        Logger.debug("selecto.set.filtered after assignment: #{inspect(selecto.set.filtered, pretty: true)}")

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

            # Store query info in component state
            socket = assign(socket,
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

            # Send query info to parent LiveView so it can pass to Results component
            send(self(), {:query_executed, %{
              query_results: {normalized_rows, columns, aliases},
              last_query_info: %{
                sql: query_sql,
                params: query_params,
                timing: execution_time
              },
              view_meta: view_meta,
              applied_view: Map.get(params, "view_mode")
            }})

            socket

          {:error, %Selecto.Error{} = error} ->
            sanitized_error = sanitize_error_for_environment(error)
            if dev_mode?() do
              # Selecto.Error occurred
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
              # Generic error occurred
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
              # View error occurred
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
              # View exit: #{inspect(reason)}
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

        # Preserve existing view_config and only update what's in params
        existing_config = socket.assigns[:view_config] || %{}

        assign(socket,
          view_config: Map.merge(existing_config, %{
            filters: filters,
            views: view_configs,
            view_mode: Map.get(params, "view_mode", existing_config[:view_mode] || "aggregate")
          })
        )
      end

      # Convert saved view configuration to full params format
      defp convert_saved_config_to_full_params(saved_params, view_type) do
        # The saved params look like: %{"detail" => %{selected: [...], order_by: [...], ...}}
        # We need to convert to params format that params_to_state expects

        view_config = Map.get(saved_params, view_type, %{})

        # Convert the view-specific lists to params format
        params = %{
          "view_mode" => view_type
        }

        # Convert selected items
        params = if selected = Map.get(view_config, :selected) do
          selected_params = selected
          |> Enum.with_index()
          |> Enum.reduce(%{}, fn
            {[uuid, field, config], index}, acc ->
              Map.put(acc, uuid, Map.merge(config, %{
                "field" => field,
                "index" => to_string(index)
              }))
            {{uuid, field, config}, index}, acc ->
              Map.put(acc, uuid, Map.merge(config, %{
                "field" => field,
                "index" => to_string(index)
              }))
          end)
          Map.put(params, "selected", selected_params)
        else
          params
        end

        # Convert order_by items - always set this to ensure replacement
        order_by = Map.get(view_config, :order_by, [])
        order_by_params = order_by
        |> Enum.with_index()
        |> Enum.reduce(%{}, fn
          {[uuid, field, config], index}, acc ->
            # Ensure all keys and values in config are strings
            string_config = case config do
              nil -> %{}
              map when is_map(map) ->
                Map.new(map, fn {k, v} -> {to_string(k), to_string(v)} end)
              _ -> %{}
            end
            Map.put(acc, uuid, Map.merge(string_config, %{
              "field" => field,
              "index" => to_string(index)
            }))
          {{uuid, field, config}, index}, acc ->
            # Ensure all keys and values in config are strings
            string_config = case config do
              nil -> %{}
              map when is_map(map) ->
                Map.new(map, fn {k, v} -> {to_string(k), to_string(v)} end)
              _ -> %{}
            end
            Map.put(acc, uuid, Map.merge(string_config, %{
              "field" => field,
              "index" => to_string(index)
            }))
        end)
        params = Map.put(params, "order_by", order_by_params)

        # Add other view-specific params
        params
        |> Map.put("per_page", to_string(Map.get(view_config, :per_page, "30")))
        |> Map.put("prevent_denormalization", to_string(Map.get(view_config, :prevent_denormalization, true)))
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

  ### Reorg these to use in pickers
  defp render_filter_form(assigns, uuid, index, section, filter_value) do
    IO.puts("\n=== RENDER_FILTER_FORM called ===")
    IO.puts("UUID: #{uuid}, Filter: #{filter_value["filter"]}")
    IO.inspect(filter_value, label: "Filter value in render_filter_form")

    # Get the filter definition from the selecto
    filter_id = filter_value["filter"]

    filter_def =
      case Selecto.filters(assigns.selecto) do
        filters when is_map(filters) ->
          Map.get(filters, filter_id)
        _ ->
          nil
      end

    # Also try to get the column definition if filter_def is nil
    column_def = if filter_def == nil do
      columns = Selecto.columns(assigns.selecto)
      Enum.find_value(columns, fn {_key, col} ->
        if col.colid == filter_id or to_string(col.colid) == filter_id do
          col
        else
          nil
        end
      end)
    else
      filter_def
    end

    # Determine the field type
    field_type = cond do
      filter_def && Map.has_key?(filter_def, :type) -> Map.get(filter_def, :type)
      column_def && Map.has_key?(column_def, :type) -> Map.get(column_def, :type)
      true -> :string
    end

    # Check if this is a custom filter with a component
    if filter_def && Map.get(filter_def, :type) == :component && Map.get(filter_def, :component) do
      # Render the custom component
      component_assigns = %{
        uuid: uuid,
        valmap: filter_value,
        def: filter_def
      }

      assigns =
        assigns
        |> Map.merge(component_assigns)
        |> Map.put(:section, section)
        |> Map.put(:index, index)
        |> Map.put(:filter_value, filter_value)

      ~H"""
      <div>
        <%= @def.component.(assigns) %>
        <input type="hidden" name={"filters[#{@uuid}][uuid]"} value={@uuid}/>
        <input type="hidden" name={"filters[#{@uuid}][section]"} value={@section}/>
        <input type="hidden" name={"filters[#{@uuid}][index]"} value={@index}/>
        <input type="hidden" name={"filters[#{@uuid}][filter]"} value={@filter_value["filter"]}/>
      </div>
      """
    else
      # Render the default filter form based on field type
      assigns = Map.merge(assigns, %{
        uuid: uuid,
        section: section,
        index: index,
        filter_value: filter_value,
        field_type: field_type
      })

      # Render different forms based on field type
      case field_type do
        type when type in [:naive_datetime, :utc_datetime, :date] ->
          render_datetime_filter(assigns)
        _ ->
          render_standard_filter(assigns)
      end
    end
  end

  # Render datetime filter with appropriate controls
  defp render_datetime_filter(assigns) do
    # Check if value is a shortcut or relative date
    filter_value = assigns[:filter_value] || %{}

    IO.puts("\n=== RENDER DATETIME FILTER ===")
    IO.inspect(filter_value, label: "Filter value in render")
    IO.puts("Comparison mode: #{filter_value["comp"]}")

    is_shortcut = is_date_shortcut(filter_value["value"])
    is_relative = is_relative_date(filter_value["value"])

    assigns =
      assigns
      |> Map.put(:is_shortcut, is_shortcut)
      |> Map.put(:is_relative, is_relative)
      |> Map.put(:filter_value, filter_value)

    ~H"""
    <div class="space-y-2">
      <div class="grid grid-cols-3 gap-2">
        <select
          name={"filters[#{@uuid}][comp]"}
          class="sc-select"
          phx-change="datetime-filter-change"
          phx-target={@myself}
          phx-value-uuid={@uuid}>
          <option value="=" selected={@filter_value["comp"] == "="}>On</option>
          <option value="!=" selected={@filter_value["comp"] == "!="}>Not On</option>
          <option value="DATE=" selected={@filter_value["comp"] == "DATE="}>Date Equals</option>
          <option value="DATE!=" selected={@filter_value["comp"] == "DATE!="}>Date Not Equals</option>
          <option value=">" selected={@filter_value["comp"] == ">"}>After</option>
          <option value=">=" selected={@filter_value["comp"] == ">="}>On or After</option>
          <option value="<" selected={@filter_value["comp"] == "<"}>Before</option>
          <option value="<=" selected={@filter_value["comp"] == "<="}>On or Before</option>
          <option value="BETWEEN" selected={@filter_value["comp"] == "BETWEEN"}>Between</option>
          <option value="DATE_BETWEEN" selected={@filter_value["comp"] == "DATE_BETWEEN"}>Date Between</option>
          <option value="SHORTCUT" selected={@filter_value["comp"] == "SHORTCUT"}>Quick Select</option>
          <option value="RELATIVE" selected={@filter_value["comp"] == "RELATIVE"}>Relative Days</option>
          <option value="IS NULL" selected={@filter_value["comp"] == "IS NULL"}>Is Empty</option>
          <option value="IS NOT NULL" selected={@filter_value["comp"] == "IS NOT NULL"}>Is Not Empty</option>
        </select>

        <%= cond do %>
          <% @filter_value["comp"] in ["BETWEEN", "DATE_BETWEEN"] -> %>
            <div class="col-span-2 grid grid-cols-2 gap-2">
              <input
                type="date"
                name={"filters[#{@uuid}][value_start]"}
                value={format_datetime_value(@filter_value["value_start"], :date)}
                class="sc-input"
                placeholder="Start"
                phx-debounce="300"
              />
              <input
                type="date"
                name={"filters[#{@uuid}][value_end]"}
                value={format_datetime_value(@filter_value["value_end"], :date)}
                class="sc-input"
                placeholder="End (exclusive)"
                phx-debounce="300"
              />
            </div>

          <% @filter_value["comp"] == "SHORTCUT" -> %>
            <select name={"filters[#{@uuid}][value]"} class="sc-select col-span-2">
              <optgroup label="Days">
                <option value="today" selected={@filter_value["value"] == "today"}>Today</option>
                <option value="yesterday" selected={@filter_value["value"] == "yesterday"}>Yesterday</option>
                <option value="tomorrow" selected={@filter_value["value"] == "tomorrow"}>Tomorrow</option>
              </optgroup>
              <optgroup label="Weeks">
                <option value="this_week" selected={@filter_value["value"] == "this_week"}>This Week</option>
                <option value="last_week" selected={@filter_value["value"] == "last_week"}>Last Week</option>
                <option value="next_week" selected={@filter_value["value"] == "next_week"}>Next Week</option>
              </optgroup>
              <optgroup label="Months">
                <option value="this_month" selected={@filter_value["value"] == "this_month"}>This Month</option>
                <option value="last_month" selected={@filter_value["value"] == "last_month"}>Last Month</option>
                <option value="next_month" selected={@filter_value["value"] == "next_month"}>Next Month</option>
                <option value="mtd" selected={@filter_value["value"] == "mtd"}>Month to Date</option>
              </optgroup>
              <optgroup label="Quarters">
                <option value="this_quarter" selected={@filter_value["value"] == "this_quarter"}>This Quarter</option>
                <option value="last_quarter" selected={@filter_value["value"] == "last_quarter"}>Last Quarter</option>
                <option value="next_quarter" selected={@filter_value["value"] == "next_quarter"}>Next Quarter</option>
                <option value="qtd" selected={@filter_value["value"] == "qtd"}>Quarter to Date</option>
              </optgroup>
              <optgroup label="Years">
                <option value="this_year" selected={@filter_value["value"] == "this_year"}>This Year</option>
                <option value="last_year" selected={@filter_value["value"] == "last_year"}>Last Year</option>
                <option value="next_year" selected={@filter_value["value"] == "next_year"}>Next Year</option>
                <option value="ytd" selected={@filter_value["value"] == "ytd"}>Year to Date</option>
              </optgroup>
              <optgroup label="Relative Periods">
                <option value="last_7_days" selected={@filter_value["value"] == "last_7_days"}>Last 7 Days</option>
                <option value="last_30_days" selected={@filter_value["value"] == "last_30_days"}>Last 30 Days</option>
                <option value="last_60_days" selected={@filter_value["value"] == "last_60_days"}>Last 60 Days</option>
                <option value="last_90_days" selected={@filter_value["value"] == "last_90_days"}>Last 90 Days</option>
                <option value="next_7_days" selected={@filter_value["value"] == "next_7_days"}>Next 7 Days</option>
                <option value="next_30_days" selected={@filter_value["value"] == "next_30_days"}>Next 30 Days</option>
              </optgroup>
              <optgroup label="Year Comparisons">
                <option value="last_ytd" selected={@filter_value["value"] == "last_ytd"}>Last Year YTD (same period)</option>
                <option value="ytd_vs_last" selected={@filter_value["value"] == "ytd_vs_last"}>This Year and Last Year YTD</option>
                <option value="qtd_vs_last" selected={@filter_value["value"] == "qtd_vs_last"}>This Quarter and Last Quarter QTD</option>
                <option value="mtd_vs_last" selected={@filter_value["value"] == "mtd_vs_last"}>This Month and Last Month MTD</option>
                <option value="mtd_vs_last_year" selected={@filter_value["value"] == "mtd_vs_last_year"}>This Month MTD and Last Year's MTD</option>
              </optgroup>
            </select>

          <% @filter_value["comp"] == "RELATIVE" -> %>
            <div class="col-span-2 flex gap-2">
              <input
                type="text"
                name={"filters[#{@uuid}][value]"}
                value={@filter_value["value"]}
                class="sc-input flex-1"
                placeholder="e.g., 5 (5 days ago), 3-7 (3-7 days ago), -30 (>30 days ago), 30- (within 30 days)"
                pattern="^-?\d+(-\d+)?-?$"
                phx-debounce="500"
              />
              <div class="text-xs text-gray-500 self-center">
                <span class="font-semibold">Examples:</span>
                1 = yesterday,
                3-7 = 3-7 days ago,
                -30 = over 30 days ago,
                30- = within 30 days
              </div>
            </div>

          <% @filter_value["comp"] in ["DATE=", "DATE!="] -> %>
            <input
              type="date"
              name={"filters[#{@uuid}][value]"}
              value={format_datetime_value(@filter_value["value"], :date)}
              class="sc-input col-span-2"
            />

          <% @filter_value["comp"] in ["IS NULL", "IS NOT NULL"] -> %>
            <div class="col-span-2 text-gray-500 text-sm self-center">
              No value needed
            </div>

          <% true -> %>
            <input
              type={if @field_type == :date, do: "date", else: "datetime-local"}
              name={"filters[#{@uuid}][value]"}
              value={format_datetime_value(@filter_value["value"], @field_type)}
              class="sc-input col-span-2"
              disabled={@filter_value["comp"] in ["IS NULL", "IS NOT NULL"]}
            />
        <% end %>
      </div>

      <input type="hidden" name={"filters[#{@uuid}][uuid]"} value={@uuid}/>
      <input type="hidden" name={"filters[#{@uuid}][section]"} value={@section}/>
      <input type="hidden" name={"filters[#{@uuid}][index]"} value={@index}/>
      <input type="hidden" name={"filters[#{@uuid}][filter]"} value={@filter_value["filter"]}/>
    </div>
    """
  end

  # Render standard text/number filter
  defp render_standard_filter(assigns) do
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
        phx-debounce="300"
        disabled={@filter_value["comp"] in ["IS NULL", "IS NOT NULL"]}
      />

      <input type="hidden" name={"filters[#{@uuid}][uuid]"} value={@uuid}/>
      <input type="hidden" name={"filters[#{@uuid}][section]"} value={@section}/>
      <input type="hidden" name={"filters[#{@uuid}][index]"} value={@index}/>
      <input type="hidden" name={"filters[#{@uuid}][filter]"} value={@filter_value["filter"]}/>
    </div>
    """
  end

  # Format datetime value for HTML input
  defp format_datetime_value(nil, _type), do: ""
  defp format_datetime_value("", _type), do: ""
  defp format_datetime_value(value, :date) when is_binary(value) do
    # Try to parse and format as YYYY-MM-DD
    case Date.from_iso8601(value) do
      {:ok, date} -> Date.to_string(date)
      _ -> String.slice(value, 0..9)
    end
  end
  defp format_datetime_value(value, type) when type in [:naive_datetime, :utc_datetime] and is_binary(value) do
    # Try to parse and format as YYYY-MM-DDTHH:MM for datetime-local input
    cond do
      String.contains?(value, "T") -> String.slice(value, 0..15)
      String.length(value) >= 16 -> String.slice(value, 0..9) <> "T" <> String.slice(value, 11..15)
      true -> value
    end
  end
  defp format_datetime_value(value, _type), do: value

  # Check if a value is a date shortcut
  defp is_date_shortcut(value) when is_binary(value) do
    value in ~w(today yesterday tomorrow this_week last_week next_week
                this_month last_month next_month mtd
                this_quarter last_quarter next_quarter qtd
                this_year last_year next_year ytd
                last_7_days last_30_days last_60_days last_90_days
                next_7_days next_30_days
                ytd_vs_last qtd_vs_last mtd_vs_last last_ytd mtd_vs_last_year)
  end
  defp is_date_shortcut(_), do: false

  # Check if a value is a relative date format
  defp is_relative_date(value) when is_binary(value) do
    # Matches patterns like: 5, 3-7, -30, 30-
    Regex.match?(~r/^-?\d+(-\d+)?-?$/, value)
  end
  defp is_relative_date(_), do: false

  # Process datetime filter values before query execution
  def process_datetime_filter(filter_config) do
    case Map.get(filter_config, "comp") do
      "BETWEEN" ->
        # Convert to SQL between with inclusive start and exclusive end
        start_date = parse_datetime_value(filter_config["value_start"])
        end_date = parse_datetime_value(filter_config["value_end"])

        # Return two filters: >= start and < end
        [
          %{filter_config | "comp" => ">=", "value" => start_date},
          %{filter_config | "comp" => "<", "value" => end_date}
        ]

      "SHORTCUT" ->
        process_date_shortcut(filter_config["value"], filter_config)

      "RELATIVE" ->
        process_relative_date(filter_config["value"], filter_config)

      _ ->
        # Standard comparison, just parse the value
        %{filter_config | "value" => parse_datetime_value(filter_config["value"])}
    end
  end

  # Process date shortcuts into actual date ranges
  defp process_date_shortcut(shortcut, base_config) do
    today = get_local_today()

    case shortcut do
      "today" ->
        start_of_day = NaiveDateTime.new!(today, ~T[00:00:00])
        end_of_day = NaiveDateTime.new!(Date.add(today, 1), ~T[00:00:00])
        [
          %{base_config | "comp" => ">=", "value" => start_of_day},
          %{base_config | "comp" => "<", "value" => end_of_day}
        ]

      "yesterday" ->
        yesterday = Date.add(today, -1)
        start_of_day = NaiveDateTime.new!(yesterday, ~T[00:00:00])
        end_of_day = NaiveDateTime.new!(today, ~T[00:00:00])
        [
          %{base_config | "comp" => ">=", "value" => start_of_day},
          %{base_config | "comp" => "<", "value" => end_of_day}
        ]

      "tomorrow" ->
        tomorrow = Date.add(today, 1)
        start_of_day = NaiveDateTime.new!(tomorrow, ~T[00:00:00])
        end_of_day = NaiveDateTime.new!(Date.add(tomorrow, 1), ~T[00:00:00])
        [
          %{base_config | "comp" => ">=", "value" => start_of_day},
          %{base_config | "comp" => "<", "value" => end_of_day}
        ]

      "this_week" ->
        start_of_week = beginning_of_week(today)
        end_of_week = Date.add(start_of_week, 7)
        [
          %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(start_of_week, ~T[00:00:00])},
          %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(end_of_week, ~T[00:00:00])}
        ]

      "last_week" ->
        start_of_week = beginning_of_week(Date.add(today, -7))
        end_of_week = Date.add(start_of_week, 7)
        [
          %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(start_of_week, ~T[00:00:00])},
          %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(end_of_week, ~T[00:00:00])}
        ]

      "this_month" ->
        start_of_month = Date.beginning_of_month(today)
        start_of_next_month = Date.beginning_of_month(Date.add(today, 32))
        [
          %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(start_of_month, ~T[00:00:00])},
          %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(start_of_next_month, ~T[00:00:00])}
        ]

      "last_month" ->
        last_month = Date.add(today, -today.day)
        start_of_month = Date.beginning_of_month(last_month)
        end_of_month = Date.beginning_of_month(today)
        [
          %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(start_of_month, ~T[00:00:00])},
          %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(end_of_month, ~T[00:00:00])}
        ]

      "next_week" ->
        start_of_next_week = beginning_of_week(Date.add(today, 7))
        end_of_next_week = Date.add(start_of_next_week, 7)
        [
          %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(start_of_next_week, ~T[00:00:00])},
          %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(end_of_next_week, ~T[00:00:00])}
        ]

      "next_month" ->
        # Get first day of next month
        {start_of_next_month, end_of_next_month} = if today.month == 12 do
          {Date.new!(today.year + 1, 1, 1), Date.new!(today.year + 1, 2, 1)}
        else
          start_month = Date.new!(today.year, today.month + 1, 1)
          # Handle month after next
          end_month = if today.month == 11 do
            Date.new!(today.year + 1, 1, 1)
          else
            Date.new!(today.year, today.month + 2, 1)
          end
          {start_month, end_month}
        end
        [
          %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(start_of_next_month, ~T[00:00:00])},
          %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(end_of_next_month, ~T[00:00:00])}
        ]

      "last_quarter" ->
        # Calculate last quarter
        current_quarter = div(today.month - 1, 3)
        {start_of_quarter, end_of_quarter} = if current_quarter == 0 do
          # Last quarter of previous year (Q4)
          {Date.new!(today.year - 1, 10, 1), Date.new!(today.year, 1, 1)}
        else
          # Previous quarter this year
          start_month = (current_quarter - 1) * 3 + 1
          end_month = current_quarter * 3 + 1
          {Date.new!(today.year, start_month, 1), Date.new!(today.year, end_month, 1)}
        end
        [
          %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(start_of_quarter, ~T[00:00:00])},
          %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(end_of_quarter, ~T[00:00:00])}
        ]

      "next_quarter" ->
        # Calculate next quarter
        current_quarter = div(today.month - 1, 3)
        {start_of_quarter, end_of_quarter} = if current_quarter == 3 do
          # First quarter of next year (Q1)
          {Date.new!(today.year + 1, 1, 1), Date.new!(today.year + 1, 4, 1)}
        else
          # Next quarter this year
          start_month = (current_quarter + 1) * 3 + 1
          end_month = if current_quarter == 2, do: 1, else: (current_quarter + 2) * 3 + 1
          end_year = if current_quarter == 2, do: today.year + 1, else: today.year
          {Date.new!(today.year, start_month, 1), Date.new!(end_year, end_month, 1)}
        end
        [
          %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(start_of_quarter, ~T[00:00:00])},
          %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(end_of_quarter, ~T[00:00:00])}
        ]

      "last_year" ->
        start_of_last_year = Date.new!(today.year - 1, 1, 1)
        start_of_this_year = Date.new!(today.year, 1, 1)
        [
          %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(start_of_last_year, ~T[00:00:00])},
          %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(start_of_this_year, ~T[00:00:00])}
        ]

      "next_year" ->
        start_of_next_year = Date.new!(today.year + 1, 1, 1)
        start_of_year_after = Date.new!(today.year + 2, 1, 1)
        [
          %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(start_of_next_year, ~T[00:00:00])},
          %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(start_of_year_after, ~T[00:00:00])}
        ]

      "mtd" ->
        # Month to date
        start_of_month = Date.beginning_of_month(today)
        tomorrow = Date.add(today, 1)
        [
          %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(start_of_month, ~T[00:00:00])},
          %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(tomorrow, ~T[00:00:00])}
        ]

      "this_quarter" ->
        start_of_quarter = beginning_of_quarter(today)
        # Calculate start of next quarter properly
        next_quarter_month = rem(div(today.month - 1, 3) + 1, 4) * 3 + 1
        next_quarter_year = if next_quarter_month == 1, do: today.year + 1, else: today.year
        start_of_next_quarter = Date.new!(next_quarter_year, next_quarter_month, 1)
        [
          %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(start_of_quarter, ~T[00:00:00])},
          %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(start_of_next_quarter, ~T[00:00:00])}
        ]

      "qtd" ->
        # Quarter to date
        start_of_quarter = beginning_of_quarter(today)
        tomorrow = Date.add(today, 1)
        [
          %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(start_of_quarter, ~T[00:00:00])},
          %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(tomorrow, ~T[00:00:00])}
        ]

      "this_year" ->
        start_of_year = Date.new!(today.year, 1, 1)
        start_of_next_year = Date.new!(today.year + 1, 1, 1)
        [
          %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(start_of_year, ~T[00:00:00])},
          %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(start_of_next_year, ~T[00:00:00])}
        ]

      "ytd" ->
        # Year to date
        start_of_year = Date.new!(today.year, 1, 1)
        tomorrow = Date.add(today, 1)
        [
          %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(start_of_year, ~T[00:00:00])},
          %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(tomorrow, ~T[00:00:00])}
        ]

      "last_" <> days when days in ~w(7_days 30_days 60_days 90_days) ->
        num_days = String.to_integer(String.replace(days, "_days", ""))
        # "Last 7 days" means from 6 days ago through today (inclusive), which is 7 days total
        start_date = Date.add(today, -(num_days - 1))
        [
          %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(start_date, ~T[00:00:00])},
          %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(Date.add(today, 1), ~T[00:00:00])}
        ]

      "next_" <> days when days in ~w(7_days 30_days) ->
        num_days = String.to_integer(String.replace(days, "_days", ""))
        end_date = Date.add(today, num_days + 1)
        [
          %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(today, ~T[00:00:00])},
          %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(end_date, ~T[00:00:00])}
        ]

      "ytd_vs_last" ->
        # For simplicity, just show this year's YTD for now
        # TODO: Implement proper OR support for comparing periods
        start_of_year = Date.new!(today.year, 1, 1)
        tomorrow = Date.add(today, 1)
        [
          %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(start_of_year, ~T[00:00:00])},
          %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(tomorrow, ~T[00:00:00])}
        ]

      "last_ytd" ->
        # Last year's YTD to the same day
        start_of_last_year = Date.new!(today.year - 1, 1, 1)
        # Handle leap year edge case for Feb 29
        same_day_last_year = try do
          Date.new!(today.year - 1, today.month, today.day)
        rescue
          _ -> Date.new!(today.year - 1, today.month, today.day - 1)
        end
        [
          %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(start_of_last_year, ~T[00:00:00])},
          %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(Date.add(same_day_last_year, 1), ~T[00:00:00])}
        ]

      "qtd_vs_last" ->
        # For simplicity, just show this quarter's QTD for now
        # TODO: Implement proper OR support for comparing periods
        start_of_quarter = beginning_of_quarter(today)
        tomorrow = Date.add(today, 1)
        [
          %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(start_of_quarter, ~T[00:00:00])},
          %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(tomorrow, ~T[00:00:00])}
        ]

      "mtd_vs_last" ->
        # For simplicity, just show this month's MTD for now
        # TODO: Implement proper OR support for comparing periods
        start_of_month = Date.beginning_of_month(today)
        tomorrow = Date.add(today, 1)
        [
          %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(start_of_month, ~T[00:00:00])},
          %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(tomorrow, ~T[00:00:00])}
        ]

      "mtd_vs_last_year" ->
        # This month MTD - simplified for now
        # TODO: Implement proper OR support for comparing periods
        start_of_month = Date.beginning_of_month(today)
        tomorrow = Date.add(today, 1)
        [
          %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(start_of_month, ~T[00:00:00])},
          %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(tomorrow, ~T[00:00:00])}
        ]

      _ ->
        # Unknown shortcut, return as-is
        base_config
    end
  end

  # Process relative date patterns
  defp process_relative_date(pattern, base_config) do
    today = get_local_today()

    cond do
      # Pattern: "5" - exactly 5 days ago
      Regex.match?(~r/^\d+$/, pattern) ->
        days_ago = String.to_integer(pattern)
        target_date = Date.add(today, -days_ago)
        start_of_day = NaiveDateTime.new!(target_date, ~T[00:00:00])
        end_of_day = NaiveDateTime.new!(Date.add(target_date, 1), ~T[00:00:00])
        [
          %{base_config | "comp" => ">=", "value" => start_of_day},
          %{base_config | "comp" => "<", "value" => end_of_day}
        ]

      # Pattern: "3-7" - between 3 and 7 days ago (inclusive range in the past)
      # For "13-7": 13 days ago to 7 days ago
      Regex.match?(~r/^(\d+)-(\d+)$/, pattern) ->
        [_, first_str, second_str] = Regex.run(~r/^(\d+)-(\d+)$/, pattern)
        first_days = String.to_integer(first_str)
        second_days = String.to_integer(second_str)
        # Determine the older and newer dates (larger number = further in past)
        older_days = max(first_days, second_days)
        newer_days = min(first_days, second_days)
        start_date = Date.add(today, -older_days)  # Further in the past
        end_date = Date.add(today, -newer_days + 1)  # More recent (exclusive end)
        [
          %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(start_date, ~T[00:00:00])},
          %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(end_date, ~T[00:00:00])}
        ]

      # Pattern: "-5" - all dates before 5 days ago (older than 5 days ago)
      # -0 means all dates before today (all past)
      # -1 means all dates before yesterday
      Regex.match?(~r/^-(\d+)$/, pattern) ->
        [_, days_str] = Regex.run(~r/^-(\d+)$/, pattern)
        days = String.to_integer(days_str)
        # < means before the start of N days ago
        cutoff_date = Date.add(today, -days)
        %{base_config | "comp" => "<", "value" => NaiveDateTime.new!(cutoff_date, ~T[00:00:00])}

      # Pattern: "5-" - from 5 days ago onwards (including 5 days ago, today and future)
      # 0- means today and all future
      # 1- means from yesterday onwards
      Regex.match?(~r/^(\d+)-$/, pattern) ->
        [_, days_str] = Regex.run(~r/^(\d+)-$/, pattern)
        days = String.to_integer(days_str)
        start_date = Date.add(today, -days)
        # >= means from that day onwards
        %{base_config | "comp" => ">=", "value" => NaiveDateTime.new!(start_date, ~T[00:00:00])}

      true ->
        base_config
    end
  end

  # Helper to find beginning of week (Monday)
  defp beginning_of_week(date) do
    day_of_week = Date.day_of_week(date, :monday)
    Date.add(date, -(day_of_week - 1))
  end

  # Helper to find beginning of quarter
  defp beginning_of_quarter(date) do
    quarter_month = div(date.month - 1, 3) * 3 + 1
    Date.new!(date.year, quarter_month, 1)
  end

  # Get the server's local date (no timezone adjustments)
  defp get_local_today() do
    # Use the server's local date from Erlang calendar functions
    {{year, month, day}, _time} = :calendar.local_time()
    Date.new!(year, month, day)
  end

  # Parse datetime value from string
  defp parse_datetime_value(value) when is_binary(value) do
    cond do
      String.contains?(value, "T") ->
        case NaiveDateTime.from_iso8601(value <> ":00") do
          {:ok, dt} -> dt
          _ -> value
        end
      String.length(value) == 10 ->
        case Date.from_iso8601(value) do
          {:ok, date} -> NaiveDateTime.new!(date, ~T[00:00:00])
          _ -> value
        end
      true ->
        value
    end
  end
  defp parse_datetime_value(value), do: value

  # Hash only the filter structure (IDs and sections), not the values
  # This ensures the component remounts when filters are added/removed
  # but not when filter values or comparisons change
  defp hash_filter_structure(filters) do
    # Include the entire filter structure in the hash so changes to comp, value, etc.
    # will trigger a re-render of the TreeBuilder component
    filters
    |> Enum.map(fn
      {uuid, section, config} -> {uuid, section, config}
    end)
    |> :erlang.phash2()
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
    require Logger
    Logger.debug("=== MAYBE_AUTO_PIVOT START ===")
    Logger.debug("selecto.set.filtered before pivot: #{inspect(selecto.set.filtered, pretty: true)}")

    # Check if automatic pivot is needed based on selected columns
    selected_columns = get_selected_columns_from_params(params)


    if should_auto_pivot?(selecto, selected_columns) do
      target_table = find_pivot_target(selecto, selected_columns)

      if target_table do
        Logger.debug("Applying pivot to target: #{inspect(target_table)}")
        # Apply custom pivot for domain structure

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
    _source_column_strs = Enum.map(source_columns, &to_string/1)

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
          # Example: if source can access target, but target can't access source,
          # pivot to the table that has broader access

          # Simple approach: try to pivot to the first table and assume it has access to others
          # More sophisticated would be to check the actual join hierarchy
          _pivot_target = hd(table_names)

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
        # Example hierarchy: source -> intermediate -> target -> child
        # If we have [child, target], we should pivot to target (not child)
        # because target can access child, but child can't access target

        # Simple heuristic: prefer tables that appear earlier in the join chain
        # This is domain-specific and should be customized
        priority_order = []

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

  # Find the join path from source to target table in domain structure
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
