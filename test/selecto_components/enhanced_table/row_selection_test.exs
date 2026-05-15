defmodule SelectoComponents.EnhancedTable.RowSelectionTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.EnhancedTable.RowSelection

  defp socket(assigns \\ []) do
    Phoenix.Component.assign(
      %Phoenix.LiveView.Socket{},
      Keyword.merge(
        [
          selected_rows: MapSet.new(),
          selection_count: 0,
          selection_mode: :multiple,
          select_all: false
        ],
        assigns
      )
    )
  end

  test "does not notify host liveviews by default" do
    RowSelection.toggle_row_selection(socket(), "1541")

    refute_receive {:selection_changed, _selected_rows}
  end

  test "can notify host liveviews when explicitly enabled" do
    RowSelection.toggle_row_selection(socket(notify_selection_change: true), "1541")

    assert_receive {:selection_changed, selected_rows}
    assert selected_rows == MapSet.new(["1541"])
  end
end
