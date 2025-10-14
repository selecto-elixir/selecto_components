defmodule SelectoComponents.Form.EventHandlers.FilterOperations do
  @moduledoc """
  Event handlers for filter operations.

  This module handles filter-related events such as:
  - Adding filters via drag-and-drop (treedrop)
  - Removing filters
  - Filter configuration updates

  ## Imported by

  This module is automatically imported when using `SelectoComponents.Form`.

  ## Events Handled

  - `treedrop` - Add filter via drag-and-drop from filter tree
  - `filter_remove` - Remove a filter from the filter list
  - `polymorphic_type_toggle` - Toggle entity type selection in polymorphic filters

  ## Design Notes

  Filter operations set the `skip_next_validation` flag to prevent unnecessary
  query execution when filters are being added or removed. This allows users
  to configure multiple filters before executing the query.
  """

  defmacro __using__(_opts) do
    quote do
      @doc """
      Handles adding a filter via drag-and-drop.

      Creates a new filter item (either a field filter or logical operator)
      and adds it to the filters list. Sets skip_next_validation to prevent
      immediate query execution.

      ## Parameters
      - params: Map containing:
        - "element" - The filter/operator being dropped (field name, "__AND__", or "__OR__")
        - "target" - The target section for the filter
      - socket: LiveView socket

      ## Returns
      `{:noreply, socket}` with updated filters and skip_next_validation flag set
      """
      def handle_event("treedrop", par, socket) do
        new_filter = Map.get(par, "element")
        target = Map.get(par, "target")

        new_filter_item =
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

      @doc """
      Handles removing a filter from the filter list.

      Removes the filter with the matching UUID and sets skip_next_validation
      to prevent immediate query execution.

      ## Parameters
      - params: Map containing "uuid" key with the filter ID to remove
      - socket: LiveView socket

      ## Returns
      `{:noreply, socket}` with updated filters and skip_next_validation flag set
      """
      def handle_event("filter_remove", params, socket) do
        # Update filters without triggering view execution
        updated_filters =
          socket.assigns.view_config.filters
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

      @doc """
      Handles toggling entity type selection in polymorphic filters.

      When a user checks/unchecks an entity type (Product, Order, Customer),
      this event updates the filter's selected_types list in the view config.

      ## Parameters
      - params: Map containing:
        - "filter-uuid" - The UUID of the polymorphic filter
        - "entity-type" - The entity type being toggled
        - "_target" - The checkbox input element
      - socket: LiveView socket

      ## Returns
      `{:noreply, socket}` with updated filter configuration
      """
      def handle_event("polymorphic_type_toggle", params, socket) do
        filter_uuid = Map.get(params, "filter-uuid")
        entity_type = Map.get(params, "entity-type")

        # Update the specific filter in the filters list
        updated_filters =
          Enum.map(socket.assigns.view_config.filters, fn
            {uuid, section, filter_config} = filter_tuple when uuid == filter_uuid ->
              # Get current polymorphic_selection or initialize it
              current_selection = Map.get(filter_config, "polymorphic_selection", %{})
              current_types = Map.get(current_selection, "types", [])

              # Toggle the entity type
              new_types = if entity_type in current_types do
                List.delete(current_types, entity_type)
              else
                current_types ++ [entity_type]
              end

              # Update the filter config
              new_selection = Map.put(current_selection, "types", new_types)
              new_config = Map.put(filter_config, "polymorphic_selection", new_selection)

              {uuid, section, new_config}

            other_filter ->
              other_filter
          end)

        socket =
          assign(socket,
            view_config: %{socket.assigns.view_config | filters: updated_filters},
            skip_next_validation: true
          )

        {:noreply, socket}
      end
    end
  end
end
