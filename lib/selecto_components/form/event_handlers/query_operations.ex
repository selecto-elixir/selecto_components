defmodule SelectoComponents.Form.EventHandlers.QueryOperations do
  @moduledoc """
  Event handlers for query execution and result operations.

  This module handles operations related to query execution, results handling,
  and result manipulation:
  - Sorting query results
  - Pagination (detail view pages)
  - Query result updates
  - URL parameter routing (handle_params)

  ## Imported by

  This module is automatically imported when using `SelectoComponents.Form`.

  ## Info Messages Handled

  - `{:rerun_query_with_sort, sort_by}` - Re-execute query with sorting
  - `{:update_detail_page, page}` - Update detail view pagination
  - `{:query_executed, query_info}` - Handle completed query execution
  - `{:update_view_config, updated_config}` - Update view configuration
  - `{:filters_updated, updated_filters}` - Update filters without execution

  ## Callbacks Handled

  - `handle_params/3` - Route URL parameters to appropriate handlers
  """

  defmacro __using__(_opts) do
    quote do
      alias SelectoComponents.Form.ParamsState
      import SelectoComponents.Form.ErrorHandling

      @doc """
      Routes URL parameters to the appropriate handler.

      Handles three types of parameter routing:
      1. Saved view loading (saved_view parameter)
      2. View mode with parameters (view_mode parameter)
      3. Default/initial load (no specific parameters)

      ## Parameters
      - params: URL query parameters
      - uri: The full URI (unused but required by LiveView)
      - socket: LiveView socket

      ## Returns
      `{:noreply, socket}` with state updated from parameters
      """
      @impl true
      def handle_params(%{"saved_view" => name} = params, _uri, socket) do
        socket = assign(socket, :params, params)

        with_error_handling(socket, "load_saved_view", fn ->
          view =
            socket.assigns.saved_view_module.get_view(name, socket.assigns.saved_view_context)

          if is_nil(view) do
            error = %{
              type: :saved_view_not_found,
              message: "Saved view '#{name}' was not found for this page.",
              details: %{saved_view: name}
            }

            {:noreply,
             assign(socket,
               page_title: "Saved View Error",
               executed: false,
               applied_view: nil,
               execution_error: error
             )}
          else
            socket = assign(socket, page_title: "View: #{view.name}")
            socket = normalize_query_results(socket)
            socket = ParamsState.params_to_state(view.params, socket)
            {:noreply, ParamsState.view_from_params(view.params, socket)}
          end
        end)
      end

      def handle_params(%{"view_mode" => _m} = params, _uri, socket) do
        socket = assign(socket, :params, params)

        # Normalize any existing query results before processing
        socket = normalize_query_results(socket)
        socket = ParamsState.params_to_state(params, socket)
        {:noreply, ParamsState.view_from_params(params, socket)}
      end

      ### accept default config
      def handle_params(params, _uri, socket) do
        {:noreply, assign(socket, :params, params)}
      end

      # Normalizes query results from list format to map format.
      #
      # This ensures consistent result format throughout the application.
      # Results are converted from [[val1, val2], ...] format to
      # [%{col1 => val1, col2 => val2}, ...] format.
      #
      # ## Parameters
      # - socket: LiveView socket
      #
      # ## Returns
      # Socket with normalized query_results
      defp normalize_query_results(socket) do
        case socket.assigns[:query_results] do
          {rows, columns, aliases}
          when is_list(rows) and length(rows) > 0 and is_list(hd(rows)) ->
            # Results are in list format, convert to maps
            normalized_rows =
              Enum.map(rows, fn row ->
                Enum.zip(columns, row) |> Map.new()
              end)

            assign(socket, query_results: {normalized_rows, columns, aliases})

          _ ->
            # Results are already normalized or empty
            socket
        end
      end

      @doc """
      Re-executes the current query with sorting applied.

      Used when column headers are clicked to sort results. Maintains
      current view configuration and parameters while applying sort.

      ## Parameters
      - sort_by: Sort configuration (field, direction, etc.)
      - socket: LiveView socket

      ## Returns
      `{:noreply, socket}` with re-executed query results
      """
      @impl true
      def handle_info({:rerun_query_with_sort, sort_by}, socket) do
        with_error_handling(socket, "rerun_query_with_sort", fn ->
          # Get current parameters or use saved params
          params =
            socket.assigns[:used_params] ||
              ParamsState.view_config_to_params(socket.assigns.view_config)

          # Store sort configuration in socket
          socket = assign(socket, sort_by: sort_by)

          # Re-execute the view with current parameters and sorting
          ParamsState.view_from_params_with_sort(params, socket, sort_by)
        end)
      end

      @doc """
      Updates the detail view pagination page.

      Executes the query for the requested page and updates the URL
      to reflect the current page number.

      ## Parameters
      - page: The page number to display (0-indexed)
      - socket: LiveView socket

      ## Returns
      `{:noreply, socket}` with query results for the requested page
      """
      @impl true
      def handle_info({:update_detail_page, page}, socket) do
        safe_page = clamp_detail_page_for_socket(page, socket)
        socket = assign(socket, :current_detail_page, safe_page)

        params =
          socket.assigns[:used_params] ||
            ParamsState.view_config_to_params(socket.assigns.view_config)

        params = Map.put(params, "detail_page", to_string(safe_page))

        # Execute query first, THEN update URL to prevent race condition
        socket = ParamsState.view_from_params(params, socket)
        {:noreply, ParamsState.state_to_url(params, socket)}
      end

      @doc """
      Handles completed query execution.

      Updates socket assigns with query results, metadata, and execution
      information after a query completes successfully.

      ## Parameters
      - query_info: Map containing:
        - :query_results - The query result tuples
        - :last_query_info - Query metadata (timing, etc.)
        - :view_meta - View-specific metadata
        - :applied_view - The view that was applied
      - socket: LiveView socket

      ## Returns
      `{:noreply, socket}` with query results assigned
      """
      @impl true
      def handle_info({:query_executed, query_info}, socket) do
        socket =
          socket
          |> assign(:query_results, query_info.query_results)
          |> assign(:last_query_info, Map.get(query_info, :last_query_info))
          |> assign(:view_meta, Map.get(query_info, :view_meta))
          |> assign(:applied_view, Map.get(query_info, :applied_view))
          |> assign(:detail_page_cache, Map.get(query_info, :detail_page_cache))
          |> assign(:executed, true)

        {:noreply, socket}
      end

      @doc """
      Updates the view configuration.

      This is typically sent by the Form LiveComponent to propagate
      configuration changes to the parent LiveView.

      ## Parameters
      - updated_config: The new view configuration
      - socket: LiveView socket

      ## Returns
      `{:noreply, socket}` with updated view_config
      """
      @impl true
      def handle_info({:update_view_config, updated_config}, socket) do
        # Update the view config in the parent LiveView
        {:noreply, assign(socket, view_config: updated_config)}
      end

      @doc """
      Updates filters without triggering query execution.

      Used when filters are modified but the user hasn't clicked Apply yet.
      Allows configuration of multiple filters before execution.

      ## Parameters
      - updated_filters: The new filters list
      - socket: LiveView socket

      ## Returns
      `{:noreply, socket}` with updated filters (no execution)
      """
      def handle_info({:filters_updated, updated_filters}, socket) do
        # Update the view config with new filters
        socket =
          assign(socket,
            view_config: %{socket.assigns.view_config | filters: updated_filters}
          )

        # Don't auto-execute, wait for user to click Apply
        {:noreply, socket}
      end

      # Helper function to execute view from current state.
      #
      # Converts current view_config to parameters and executes the query.
      #
      # ## Parameters
      # - socket: LiveView socket
      #
      # ## Returns
      # Socket with executed query results
      defp execute_view_from_current_state(socket) do
        params = ParamsState.view_config_to_params(socket.assigns.view_config)
        ParamsState.view_from_params(params, socket)
      end

      defp clamp_detail_page_for_socket(page, socket) when is_integer(page) do
        requested_page = max(page, 0)
        view_meta = socket.assigns[:view_meta] || %{}

        per_page = max(Map.get(view_meta, :per_page, 30), 1)
        total_rows = max(Map.get(view_meta, :total_rows, 0), 0)

        max_page =
          if total_rows > 0 do
            div(total_rows - 1, per_page)
          else
            0
          end

        min(requested_page, max_page)
      end

      defp clamp_detail_page_for_socket(_page, _socket), do: 0
    end
  end
end
