defmodule SelectoComponents.Form.EventHandlers.ChoiceSourceOperations do
  @moduledoc """
  LiveView event handlers for choice-source option and membership lookups.

  These handlers keep server-owned scope on the socket. Browser payloads may
  carry search text and a choice-source id, but actor, tenant, and the current
  Selecto Domain of Interest filters are derived from socket assigns.
  """

  defmacro __using__(_opts) do
    quote do
      @doc """
      Resolves choice-source options through the current LiveView socket.
      """
      def handle_event("selecto_choice_source_options", params, socket) do
        {:reply, SelectoComponents.Form.ChoiceSourceLive.options_reply(params, socket), socket}
      end

      @doc """
      Validates a submitted choice-source value through the current LiveView socket.
      """
      def handle_event("selecto_choice_source_validate", params, socket) do
        {:reply, SelectoComponents.Form.ChoiceSourceLive.validate_reply(params, socket), socket}
      end
    end
  end
end
