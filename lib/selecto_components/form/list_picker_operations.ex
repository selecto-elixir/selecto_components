defmodule SelectoComponents.Form.ListPickerOperations do
  @moduledoc """
  Handles list picker operations for SelectoComponents forms.

  This module contains the business logic for:
  - Adding items to picker lists (selected columns, order_by, group_by, aggregate)
  - Removing items from picker lists
  - Reordering items within picker lists (move up/down)
  - Updating view configuration after list changes
  """

  @doc """
  Remove an item from a picker list in the view configuration.

  Returns the updated view_config with the item removed from the specified list.
  """
  def remove_item_from_list(view_config, view, list, item) do
    view = String.to_atom(view)
    list = String.to_atom(list)

    original_list = view_config.views[view][list]

    filtered_list = Enum.filter(original_list, fn
      {id, _, _} when is_binary(id) -> id != item
      [id, _, _] when is_binary(id) -> id != item
      {id, _, _} -> to_string(id) != item
      [id, _, _] -> to_string(id) != item
      _ -> true
    end)

    # Update the view_config
    put_in(view_config.views[view][list], filtered_list)
  end

  @doc """
  Move an item up or down in a picker list.

  Direction should be "up" or "down".
  Returns the updated view_config with the item moved, or the original view_config if item not found.
  """
  def move_item_in_list(view_config, view, list, uuid, direction) do
    view = String.to_atom(view)
    list = String.to_atom(list)

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
      view_config
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

      put_in(view_config.views[view][list], item_list)
    end
  end

  @doc """
  Add an item to a picker list in the view configuration.

  Returns the updated view_config with the item appended to the specified list.
  """
  def add_item_to_list(view_config, view, list, item) do
    view = String.to_atom(view)
    list = String.to_atom(list)

    # Get the current list
    current_list = view_config.views[view][list] || []

    # Append the new item
    updated_list = current_list ++ [item]

    # Update the view_config
    put_in(view_config.views[view][list], updated_list)
  end

  @doc """
  Send an update to the view form component after a list change.

  This ensures the UI reflects the latest view_config state.
  """
  def send_view_update(view_module, updated_view_config, socket_assigns) do
    {id, mod, _, _} = view_module
    component_id = "view_#{id}_form"

    # Send update to the specific view form component
    Phoenix.LiveView.send_update(String.to_existing_atom("#{mod}.Form"),
      id: component_id,
      view_config: updated_view_config,
      columns: socket_assigns.columns,
      view: view_module,
      selecto: socket_assigns.selecto
    )
  end
end