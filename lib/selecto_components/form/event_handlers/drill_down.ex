defmodule SelectoComponents.Form.EventHandlers.DrillDown do
  @moduledoc """
  Event handlers for drill-down operations.

  This module handles drill-down events that allow users to navigate from
  aggregate or graph views to detailed views with contextual filters:
  - Clicking on aggregate values to see underlying records
  - Clicking on graph elements (bars, points, etc.)
  - Creating filters based on the clicked context

  ## Imported by

  This module is automatically imported when using `SelectoComponents.Form`.

  ## Events Handled

  - `agg_add_filters` - Drill down from aggregate view with filters
  - `graph_drill_down` - Drill down from graph view (delegates to chart_click)
  - `chart_click` - Drill down from chart element

  ## Drill-Down Pattern

  All drill-down operations follow a similar pattern:
  1. Extract the clicked value/label
  2. Create filters based on the context
  3. Switch to detail view (or configured drill_down view)
  4. Execute query with new filters
  5. Update URL with new parameters
  """

  defmacro __using__(_opts) do
    quote do
      alias SelectoComponents.Form.{ParamsState, DrillDownFilters}
      import SelectoComponents.Form.ErrorHandling

      @doc """
      Handles drill-down from aggregate view.

      Creates filters based on the aggregate row values and switches to the
      configured drill-down view (typically detail view).

      ## Parameters
      - params: Map containing field values from the clicked aggregate row
      - socket: LiveView socket

      ## Returns
      `{:noreply, socket}` with drill-down filters applied and query executed
      """
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

          socket =
            assign(socket,
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

      @doc """
      Handles drill-down from graph view.

      This is a convenience wrapper that delegates to chart_click with the same
      parameters, as graph_drill_down and chart_click use the same logic.

      ## Parameters
      - params: Map containing label/value from the clicked graph element
      - socket: LiveView socket

      ## Returns
      Result of handle_event("chart_click", params, socket)
      """
      def handle_event("graph_drill_down", params, socket) do
        # Convert graph_drill_down params to chart_click format
        # The graph component sends slightly different parameter names
        handle_event("chart_click", params, socket)
      end

      @doc """
      Handles drill-down from chart/graph elements.

      Creates a filter based on the clicked chart element (bar, point, etc.)
      and switches to detail view to show the underlying records.

      ## Parameters
      - params: Map containing:
        - "label" - The label/value that was clicked
        - "value" - The numeric value (optional)
      - socket: LiveView socket

      ## Returns
      `{:noreply, socket}` with new filter applied and query executed
      """
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

          field_name =
            case x_axis do
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
            # Set comparison operator for exact match
            "comp" => "=",
            # Ensure section is set
            "section" => "filters"
          }

          new_filter = {new_filter_id, "filters", new_filter_map}

          # Add the filter to existing filters
          updated_filters = socket.assigns.view_config.filters ++ [new_filter]

          # Switch to detail view (or configured drill_down view)
          selected_view = String.to_atom(current_view_mode)

          {_, _, _, opt} =
            Enum.find(socket.assigns.views, fn {id, _, _, _} -> id == selected_view end) ||
              {:detail, nil, nil, %{}}

          new_view_mode = Map.get(opt, :drill_down, :detail)

          # Build the complete filter params map including section
          filters_map =
            Enum.reduce(updated_filters, %{}, fn
              {id, "filters", filter_map}, acc ->
                # Ensure section and comp are set for each filter
                filter_with_defaults =
                  filter_map
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
            # Ensure aggregate config exists
            |> Map.put_new("aggregate", %{})
            # Ensure detail config exists
            |> Map.put_new("detail", %{})
            # Ensure graph config exists
            |> Map.put_new("graph", %{})

          # Update the view configuration
          socket =
            assign(socket,
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
    end
  end
end
