defmodule SelectoComponents.Views.Detail.PaginationTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.Views.Detail.Pagination

  test "clamps page to valid range" do
    view_meta = %{per_page: 30, total_rows: 95}

    assert Pagination.clamp_page(0, view_meta) == 0
    assert Pagination.clamp_page(1, view_meta) == 1
    assert Pagination.clamp_page(9, view_meta) == 3
    assert Pagination.clamp_page(-5, view_meta) == 0
  end

  test "clamps page to zero when no rows" do
    view_meta = %{per_page: 30, total_rows: 0}

    assert Pagination.clamp_page(0, view_meta) == 0
    assert Pagination.clamp_page(5, view_meta) == 0
  end
end
