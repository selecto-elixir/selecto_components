defmodule SelectoComponents.Form.EventHandlers do
  @moduledoc """
  Consolidated event handlers for SelectoComponents forms.

  This module serves as a single entry point for all form event handlers,
  organizing them into logical groups based on functionality:

  - **ViewLifecycle** - View configuration, validation, and application
  - **FilterOperations** - Adding, removing, and configuring filters
  - **DrillDown** - Drill-down operations from aggregates and graphs
  - **ListOperations** - List picker operations (add, remove, reorder)
  - **QueryOperations** - Query execution, sorting, and pagination
   - **ModalOperations** - Modal dialog display and interaction
   - **ExportOperations** - Export current results as CSV/JSON

  ## Architecture

  Each event handler group is defined in its own module under
  `SelectoComponents.Form.EventHandlers.*` namespace. This provides:

  - Better code organization and maintainability
  - Clear separation of concerns
  - Easier testing of individual handler groups
  - Improved documentation and discoverability

  ## Usage

  This module is automatically imported when using `SelectoComponents.Form`:

      defmodule MyLive do
        use SelectoComponents.Form
        # All event handlers are now available
      end

  ## Event Handler Groups

  ### ViewLifecycle
  - `set_active_tab` - Switch between view/filter/save tabs
  - `view-validate` - Form validation without execution
  - `view-apply` - Form submission and query execution
  - `load_view_config` - Load saved view configuration

  ### FilterOperations
  - `treedrop` - Add filter via drag-and-drop
  - `filter_remove` - Remove filter from list

  ### DrillDown
  - `agg_add_filters` - Drill down from aggregate view
  - `graph_drill_down` - Drill down from graph
  - `chart_click` - Drill down from chart element

  ### ListOperations
  - `{:list_picker_add, ...}` - Add item to list
  - `{:list_picker_remove, ...}` - Remove item from list
  - `{:list_picker_move, ...}` - Reorder item in list

  ### QueryOperations
  - `handle_params/3` - URL parameter routing
  - `{:rerun_query_with_sort, ...}` - Sort query results
  - `{:update_detail_page, ...}` - Pagination
  - `{:query_executed, ...}` - Handle query completion
  - `{:update_view_config, ...}` - Update configuration
  - `{:filters_updated, ...}` - Update filters

   ### ModalOperations
   - `{:show_detail_modal, ...}` - Show detail modal
   - `{:close_detail_modal, ...}` - Close detail modal

   ### ExportOperations
   - `export_data` - Export current results (CSV/JSON)

  ## Adding New Event Handlers

  When adding new event handlers:

  1. Identify the appropriate handler group (or create a new one)
  2. Add the handler to the corresponding module
  3. Document the handler with @doc
  4. Add integration tests
  5. Update this module's documentation

  ## Implementation Notes

  All event handler modules use the `__using__` macro pattern to inject
  handlers into the calling LiveView. This allows handlers to access the
  LiveView's socket and assigns directly while keeping code organized.

  Error handling is provided by `SelectoComponents.Form.ErrorHandling`,
  which wraps operations in try/rescue blocks and provides user-friendly
  error messages.
  """

  defmacro __using__(_opts) do
    quote do
      # Import all event handler groups
      use SelectoComponents.Form.EventHandlers.ViewLifecycle
      use SelectoComponents.Form.EventHandlers.FilterOperations
      use SelectoComponents.Form.EventHandlers.DrillDown
      use SelectoComponents.Form.EventHandlers.ListOperations
      use SelectoComponents.Form.EventHandlers.QueryOperations
      use SelectoComponents.Form.EventHandlers.ModalOperations
      use SelectoComponents.Form.EventHandlers.ExportOperations

      # Import error handling utilities
      import SelectoComponents.Form.ErrorHandling

      # Import helper modules commonly used by event handlers
      import SelectoComponents.Helpers
      import SelectoComponents.Helpers.Filters

      # Alias commonly used modules
      alias SelectoComponents.ErrorHandling.ErrorCategorizer
      alias SelectoComponents.Form.ParamsState
      alias SelectoComponents.Form.ListPickerOperations
      alias SelectoComponents.Form.DrillDownFilters
      alias SelectoComponents.Extensions, as: ComponentExtensions
      alias SelectoComponents.Views.Runtime, as: ViewRuntime

      @doc """
      Sets up initial state for SelectoComponents form.

      This function initializes the socket assigns with the necessary
      configuration for views, columns, filters, and view configuration.

      ## Parameters
      - views: List of view tuples [{id, module, name, opts}, ...]
      - selecto: The Selecto domain configuration

      ## Returns
      Keyword list of initial socket assigns
      """
      def get_initial_state(views, selecto) do
        views = ComponentExtensions.merge_views(views, selecto)

        default_view_mode =
          case views do
            [{id, _, _, _} | _] -> Atom.to_string(id)
            _ -> "aggregate"
          end

        view_configs =
          Enum.reduce(views, %{}, fn {view, _module, _name, _opt} = view_tuple, acc ->
            Map.merge(acc, %{
              view => ViewRuntime.initial_state(view_tuple, selecto)
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
          views: views,
          columns: columns_list,
          field_filters: Selecto.filters(selecto),
          executed: false,
          execution_error: nil,
          query_results: [],
          detail_page_cache: nil,
          applied_view: nil,
          active_tab: "view",
          view_config: %{
            view_mode: default_view_mode,
            views: view_configs,
            filters: []
          },
          view_meta: %{}
        ]
      end

      @doc """
      Handles view mode changes via info messages.

      Updates the view_config to switch to a different view mode
      (aggregate, detail, graph, etc.).

      ## Parameters
      - view: The view mode to switch to (atom)
      - socket: LiveView socket

      ## Returns
      `{:noreply, socket}` with updated view_mode
      """
      @impl true
      def handle_info({:view_set, view}, socket) do
        {:noreply, assign(socket, view_config: %{socket.assigns.view_config | view_mode: view})}
      end
    end
  end
end
