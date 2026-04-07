defmodule SelectoComponents.Form.FilterOperationsTest do
  use ExUnit.Case, async: true

  defmodule TestLive do
    use Phoenix.LiveView
    use SelectoComponents.Form.EventHandlers.FilterOperations
  end

  test "toggle_filter_selected_value removes an existing selected value" do
    socket =
      socket_with_filter(%{"selected_values" => ["open", "closed"], "value" => "open,closed"})

    {:noreply, updated_socket} =
      TestLive.handle_event(
        "toggle_filter_selected_value",
        %{"filter-uuid" => "f1", "item" => "closed"},
        socket
      )

    assert updated_socket.assigns.view_config.filters == [
             {"f1", "filters", %{"selected_values" => ["open"], "value" => "open"}}
           ]
  end

  test "toggle_filter_selected_value falls back to the stored value list" do
    socket = socket_with_filter(%{"value" => "open,closed,paused"})

    {:noreply, updated_socket} =
      TestLive.handle_event(
        "toggle_filter_selected_value",
        %{"filter-uuid" => "f1", "item" => "closed"},
        socket
      )

    assert updated_socket.assigns.view_config.filters == [
             {"f1", "filters",
              %{"selected_values" => ["open", "paused"], "value" => "open,paused"}}
           ]
  end

  test "clear_filter_selected_values empties the selected values list" do
    socket =
      socket_with_filter(%{"selected_values" => ["open", "closed"], "value" => "open,closed"})

    {:noreply, updated_socket} =
      TestLive.handle_event("clear_filter_selected_values", %{"filter-uuid" => "f1"}, socket)

    assert updated_socket.assigns.view_config.filters == [
             {"f1", "filters", %{"selected_values" => [], "value" => ""}}
           ]
  end

  test "commit_filter_pending_values promotes pending textarea values into selected values" do
    socket = socket_with_filter(%{"selected_values" => ["open"], "value" => "open"})

    {:noreply, updated_socket} =
      TestLive.handle_event(
        "commit_filter_pending_values",
        %{"filter-uuid" => "f1", "pending-values" => "closed\npaused"},
        socket
      )

    assert updated_socket.assigns.view_config.filters == [
             {"f1", "filters",
              %{
                "selected_values" => ["open", "closed", "paused"],
                "value" => "open,closed,paused"
              }}
           ]
  end

  defp socket_with_filter(filter_config) do
    %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        form_state_revision: 0,
        view_config: %{
          filters: [{"f1", "filters", filter_config}]
        }
      }
    }
  end
end
