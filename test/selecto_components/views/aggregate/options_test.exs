defmodule SelectoComponents.Views.Aggregate.OptionsTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.Views.Aggregate.Options

  test "normalizes aggregate per-page values" do
    assert Options.normalize_per_page_param("30") == "30"
    assert Options.normalize_per_page_param("100") == "100"
    assert Options.normalize_per_page_param("200") == "200"
    assert Options.normalize_per_page_param("300") == "300"
    assert Options.normalize_per_page_param("all") == "all"
  end

  test "falls back to default for invalid per-page values" do
    assert Options.normalize_per_page_param("500") == Options.default_per_page()
    assert Options.normalize_per_page_param("invalid") == Options.default_per_page()
    assert Options.normalize_per_page_param(nil) == Options.default_per_page()
  end

  test "converts per-page values to integer limits" do
    assert Options.per_page_to_int("30", 1000) == 30
    assert Options.per_page_to_int("all", 250) == 250
    assert Options.per_page_to_int("all", 0) == 1
  end

  test "detects aggregate view mode for atom and string" do
    assert Options.aggregate_view_mode?(%{view_mode: :aggregate})
    assert Options.aggregate_view_mode?(%{"view_mode" => "aggregate"})
    refute Options.aggregate_view_mode?(%{view_mode: :detail})
  end
end
