defmodule SelectoComponents.Form.EventHandlers.ModalOperations do
  @moduledoc """
  Event handlers for modal dialog operations.

  This module handles operations related to modal dialogs, particularly
  the detail view modal that can display record details in an overlay
  without navigating away from the current view.

  ## Imported by

  This module is automatically imported when using `SelectoComponents.Form`.

  ## Info Messages Handled

  - `{:show_detail_modal, detail_data}` - Display detail modal with data
  - `{:close_detail_modal, modal_id}` - Close and clear detail modal

  ## Feature Flag

  Modal detail view is an opt-in feature controlled by the
  `:enable_modal_detail` socket assign. If not enabled, modal
  events are ignored.

  ## Usage Example

      # In your LiveView mount function:
      socket = assign(socket, enable_modal_detail: true)

      # To show a modal from a component:
      send(self(), {:show_detail_modal, row_data})
  """

  defmacro __using__(_opts) do
    quote do
      @doc """
      Displays a detail modal with the provided data.

      Shows a modal overlay with record details if the :enable_modal_detail
      feature flag is set. Otherwise, the event is ignored and no modal is shown.

      ## Parameters
      - detail_data: The data to display in the modal (typically a single record)
      - socket: LiveView socket

      ## Returns
      `{:noreply, socket}` with modal state updated
      """
      @impl true
      def handle_info({:show_detail_modal, detail_data}, socket) do
        # Check if modal detail view is enabled (opt-in feature)
        if Map.get(socket.assigns, :enable_modal_detail, false) do
          # Set modal data in assigns to trigger rendering
          socket =
            assign(socket,
              show_detail_modal: true,
              modal_detail_data: detail_data
            )

          {:noreply, socket}
        else
          # Fallback to default behavior or ignore if not enabled
          {:noreply, socket}
        end
      end

      @doc """
      Closes the detail modal and clears modal data.

      Hides the modal overlay and removes the modal data from socket assigns.

      ## Parameters
      - _modal_id: The modal identifier (currently unused but available for future use)
      - socket: LiveView socket

      ## Returns
      `{:noreply, socket}` with modal state cleared
      """
      @impl true
      def handle_info({:close_detail_modal, _modal_id}, socket) do
        socket =
          assign(socket,
            show_detail_modal: false,
            modal_detail_data: nil
          )

        {:noreply, socket}
      end
    end
  end
end
