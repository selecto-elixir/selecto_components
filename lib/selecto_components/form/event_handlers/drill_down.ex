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
      alias SelectoComponents.Form.ParamsState
      alias SelectoComponents.Views.Aggregate.DrillDown, as: AggregateDrillDown
      alias SelectoComponents.Views.Graph.DrillDown, as: GraphDrillDown
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
          {:ok, updated_socket, view_params} = AggregateDrillDown.apply(socket, params)
          {:noreply, ParamsState.state_to_url(view_params, updated_socket)}
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
          case GraphDrillDown.apply(socket, params) do
            {:ok, updated_socket, view_params} ->
              {:noreply, ParamsState.state_to_url(view_params, updated_socket)}

            {:error, message} ->
              {:noreply, put_flash(socket, :error, message)}
          end
        end)
      end
    end
  end
end
