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
   - `{:list_picker_reorder, view, list, dragged_uuid, target_uuid}` - Drag/drop reorder

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
      alias SelectoComponents.Form.ParamsState
      alias SelectoComponents.SafeAtom

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
        handle_info({:list_picker_add, nil, view, list, item}, socket)
      end

      def handle_info({:list_picker_add, form_state_query, view, list, item}, socket) do
        socket = hydrate_list_picker_form_state(socket, form_state_query)

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
            id == SafeAtom.to_view_mode(view)
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
        handle_info({:list_picker_remove, nil, view, list, item}, socket)
      end

      def handle_info({:list_picker_remove, form_state_query, view, list, item}, socket) do
        socket = hydrate_list_picker_form_state(socket, form_state_query)

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
            id == SafeAtom.to_view_mode(view)
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
            id == SafeAtom.to_view_mode(view)
          end)

        if view_module do
          ListPickerOperations.send_view_update(view_module, updated_view_config, socket.assigns)
        end

        {:noreply, socket}
      end

      @doc """
      Handles drag/drop reordering for a picker list.

      ## Parameters
      - view: The view identifier (e.g., "aggregate", "graph")
      - list: The list name (e.g., "group_by", "aggregate", "x_axis")
      - dragged_uuid: The UUID of the dragged item
      - target_uuid: The UUID of the drop target item
      - socket: LiveView socket

      ## Returns
      `{:noreply, socket}` with updated view configuration
      """
      def handle_info({:list_picker_reorder, view, list, dragged_uuid, target_uuid}, socket) do
        handle_info({:list_picker_reorder, nil, view, list, dragged_uuid, target_uuid}, socket)
      end

      def handle_info(
            {:list_picker_reorder, form_state_query, view, list, dragged_uuid, target_uuid},
            socket
          ) do
        socket = hydrate_list_picker_form_state(socket, form_state_query)

        updated_view_config =
          ListPickerOperations.reorder_item_in_list(
            socket.assigns.view_config,
            view,
            list,
            dragged_uuid,
            target_uuid
          )

        socket = assign(socket, view_config: updated_view_config)

        view_module =
          Enum.find(socket.assigns.views, fn {id, _, _, _} ->
            id == SafeAtom.to_view_mode(view)
          end)

        if view_module do
          ListPickerOperations.send_view_update(view_module, updated_view_config, socket.assigns)
        end

        {:noreply, socket}
      end

      defp hydrate_list_picker_form_state(socket, nil), do: socket
      defp hydrate_list_picker_form_state(socket, ""), do: socket

      defp hydrate_list_picker_form_state(socket, form_state_query)
           when is_binary(form_state_query) do
        form_state_query
        |> Plug.Conn.Query.decode()
        |> ParamsState.form_params_to_state(socket)
      end
    end
  end
end
