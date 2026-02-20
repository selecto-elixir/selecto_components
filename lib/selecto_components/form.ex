defmodule SelectoComponents.Form do
  use Phoenix.LiveComponent

  import SelectoComponents.Components.Common
  alias Phoenix.LiveView.JS
  alias SelectoComponents.ErrorHandling.ErrorDisplay
  alias SelectoComponents.Form.FilterRendering
  alias SelectoComponents.Views.Runtime, as: ViewRuntime

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
            <:section :let={{id, _mod, _, _} = view}>
              <.live_component
                module={ViewRuntime.form_component(view)}
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

      # Import all event handlers (this brings in error handling, helpers, and all events)
      use SelectoComponents.Form.EventHandlers

      # Import utility functions for LiveView usage
      import SelectoComponents.Form, only: [dev_mode?: 0, sanitize_error_for_environment: 1]

      # All event handlers are now provided by SelectoComponents.Form.EventHandlers
      # which includes: ViewLifecycle, FilterOperations, DrillDown, ListOperations,
      # QueryOperations, and ModalOperations
    end

    ### quote do
  end

  ### __using___

  defp build_column_list(selecto) do
    Map.values(Selecto.columns(selecto))
    |> Enum.sort(fn a, b -> a.name <= b.name end)
    |> Enum.map(fn c -> {c.colid, c.name, Map.get(c, :format)} end)
  end

  # defp build_available_fields(selecto) do
  #   Selecto.columns(selecto)
  #   |> Enum.map(fn {field_id, column} ->
  #     field_id_str = if is_atom(field_id), do: Atom.to_string(field_id), else: to_string(field_id)
  #     field_name = Map.get(column, :name, field_id_str)
  #     {field_id_str, %{name: field_name}}
  #   end)
  #   |> Map.new()
  # end

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
