defmodule SelectoComponentsTest do
  use ExUnit.Case
  doctest SelectoComponents

  test "module loads" do
    assert Code.ensure_loaded?(SelectoComponents)
  end
end
