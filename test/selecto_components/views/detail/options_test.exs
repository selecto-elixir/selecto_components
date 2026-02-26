defmodule SelectoComponents.Views.Detail.OptionsTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.Views.Detail.Options

  test "normalizes detail max rows values" do
    assert Options.normalize_max_rows_param("100") == "100"
    assert Options.normalize_max_rows_param("1000") == "1000"
    assert Options.normalize_max_rows_param("10000") == "10000"
    assert Options.normalize_max_rows_param("all") == "all"
  end

  test "falls back to default for invalid max rows" do
    assert Options.normalize_max_rows_param("0") == Options.default_max_rows()
    assert Options.normalize_max_rows_param("invalid") == Options.default_max_rows()
    assert Options.normalize_max_rows_param(nil) == Options.default_max_rows()
  end

  test "normalizes max rows limit" do
    assert Options.normalize_max_rows_limit("100") == 100
    assert Options.normalize_max_rows_limit("1000") == 1000
    assert Options.normalize_max_rows_limit("all") == nil
  end

  test "detects detail view mode for atom and string" do
    assert Options.detail_view_mode?(%{view_mode: :detail})
    assert Options.detail_view_mode?(%{"view_mode" => "detail"})
    refute Options.detail_view_mode?(%{view_mode: :aggregate})
  end
end
