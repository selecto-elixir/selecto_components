defmodule SelectoComponents.Form.EventHandlers.ListOperations do
  @moduledoc """
  Event handlers for list picker operations.

  This module handles operations on list-based view configurations such as:
  - Adding fields to aggregate/group_by lists
  - Removing fields from lists
  - Reordering items in lists (move up/down)

  These operations are typically triggered by the ListPicker component
  and update the view configuration for aggregate, graph, and detail views.

  ## Imported by

  This module is automatically imported when using `SelectoComponents.Form`.

  ## Info Messages Handled

  - `{:list_picker_add, view, list, item}` - Add item to list
  - `{:list_picker_remove, view, list, item}` - Remove item from list
  - `{:list_picker_move, view, list, uuid, direction}` - Reorder item in list

  ## Design Pattern

  All list operations follow the same pattern:
  1. Update view_config with the list change
  2. Find the relevant view module
  3. Send update to the view module for re-rendering
  4. Return updated socket

  List operations do NOT trigger query execution - they only update the
  configuration. Users must click "Apply" to execute with the new configuration.
  """

  defmacro __using__(_opts) do
    quote do
      alias SelectoComponents.Form.ListPickerOperations

      @doc """
      Handles adding an item to a list.

      Creates a new item tuple with a UUID and adds it to the specified list
      in the view configuration.

      ## Parameters
      - view: The view identifier (e.g., "aggregate", "graph")
      - list: The list name (e.g., "group_by", "aggregate", "x_axis")
      - item: The item to add (typically a field name)
      - socket: LiveView socket

      ## Returns
      `{:noreply, socket}` with updated view configuration
      """
      def handle_info({:list_picker_add, view, list, item}, socket) do
        # Create item tuple with UUID and empty config
        item_tuple = {UUID.uuid4(), item, %{}}

        # Use helper module to add item
        updated_view_config =
          ListPickerOperations.add_item_to_list(
            socket.assigns.view_config,
            view,
            list,
            item_tuple
          )

        socket = assign(socket, view_config: updated_view_config)

        # Find and update the view module
        view_module =
          Enum.find(socket.assigns.views, fn {id, _, _, _} ->
            id == String.to_atom(view)
          end)

        if view_module do
          ListPickerOperations.send_view_update(view_module, updated_view_config, socket.assigns)
        end

        {:noreply, socket}
      end

      @doc """
      Handles removing an item from a list.

      Removes the item with the matching identifier from the specified list
      in the view configuration.

      ## Parameters
      - view: The view identifier (e.g., "aggregate", "graph")
      - list: The list name (e.g., "group_by", "aggregate", "x_axis")
      - item: The item identifier to remove (UUID or field name)
      - socket: LiveView socket

      ## Returns
      `{:noreply, socket}` with updated view configuration
      """
      def handle_info({:list_picker_remove, view, list, item}, socket) do
        # Use helper module to remove item
        updated_view_config =
          ListPickerOperations.remove_item_from_list(
            socket.assigns.view_config,
            view,
            list,
            item
          )

        socket = assign(socket, view_config: updated_view_config)

        # Find and update the view module
        view_module =
          Enum.find(socket.assigns.views, fn {id, _, _, _} ->
            id == String.to_atom(view)
          end)

        if view_module do
          ListPickerOperations.send_view_update(view_module, updated_view_config, socket.assigns)
        end

        {:noreply, socket}
      end

      @doc """
      Handles reordering an item in a list.

      Moves an item up or down in the specified list, updating the order
      in the view configuration.

      ## Parameters
      - view: The view identifier (e.g., "aggregate", "graph")
      - list: The list name (e.g., "group_by", "aggregate", "x_axis")
      - uuid: The UUID of the item to move
      - direction: The direction to move (:up or :down)
      - socket: LiveView socket

      ## Returns
      `{:noreply, socket}` with updated view configuration
      """
      def handle_info({:list_picker_move, view, list, uuid, direction}, socket) do
        # Use helper module to move item
        updated_view_config =
          ListPickerOperations.move_item_in_list(
            socket.assigns.view_config,
            view,
            list,
            uuid,
            direction
          )

        socket = assign(socket, view_config: updated_view_config)

        # Find and update the view module
        view_module =
          Enum.find(socket.assigns.views, fn {id, _, _, _} ->
            id == String.to_atom(view)
          end)

        if view_module do
          ListPickerOperations.send_view_update(view_module, updated_view_config, socket.assigns)
        end

        {:noreply, socket}
      end
    end
  end
end
