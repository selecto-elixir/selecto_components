defmodule SelectoComponents.EnhancedTable.SortingTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.EnhancedTable.Sorting

  test "apply_sort_to_query uses Selecto-compatible order_by expressions" do
    selecto = %{set: %{order_by: []}}

    updated =
      Sorting.apply_sort_to_query(selecto, [
        {"id", :asc},
        {"inserted_at", :desc}
      ])

    assert updated.set.order_by == ["id", {:desc, "inserted_at"}]
  end
end
