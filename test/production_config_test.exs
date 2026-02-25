defmodule SelectoComponents.Debug.ProductionConfigTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.Debug.ProductionConfig

  test "debug is disabled by default without request flag" do
    refute ProductionConfig.debug_enabled?(%{}, %{})
  end

  test "selecto_debug request flag enables debug" do
    assert ProductionConfig.debug_enabled?(%{"selecto_debug" => "true"}, %{})
    assert ProductionConfig.debug_enabled?(%{"selecto_debug" => "1"}, %{})
    assert ProductionConfig.debug_enabled?(%{"selecto_debug" => "on"}, %{})
    assert ProductionConfig.debug_enabled?(%{"selecto_debug" => "yes"}, %{})
  end

  test "debug request flag enables debug" do
    assert ProductionConfig.debug_enabled?(%{"debug" => "true"}, %{})
    assert ProductionConfig.debug_enabled?(%{}, %{"debug" => "1"})
  end

  test "debug token counts as explicit debug request" do
    assert ProductionConfig.debug_enabled?(%{"debug_token" => "token"}, %{})
    assert ProductionConfig.debug_enabled?(%{}, %{"debug_token" => "token"})
  end

  test "falsey request values do not enable debug" do
    refute ProductionConfig.debug_enabled?(%{"selecto_debug" => "false"}, %{})
    refute ProductionConfig.debug_enabled?(%{"debug" => "0"}, %{})
  end
end
