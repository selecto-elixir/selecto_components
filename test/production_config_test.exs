defmodule SelectoComponents.Debug.ProductionConfigTest do
  use ExUnit.Case, async: false

  alias SelectoComponents.Debug.ProductionConfig
  alias SelectoComponents.Session

  setup do
    original_env = Application.get_env(:selecto_components, :env)
    original_serve_endpoints = Application.get_env(:phoenix, :serve_endpoints)
    Application.put_env(:selecto_components, :env, :test)

    on_exit(fn ->
      restore_app_env(:selecto_components, :env, original_env)
      restore_app_env(:phoenix, :serve_endpoints, original_serve_endpoints)
    end)

    :ok
  end

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

  test "session structs are normalized for debug checks" do
    refute ProductionConfig.debug_enabled?(%{}, %Session{
             view_mode: "detail",
             views: %{},
             filters: []
           })
  end

  test "disabled Phoenix endpoints do not bypass production token checks" do
    Application.put_env(:selecto_components, :env, :prod)
    Application.put_env(:phoenix, :serve_endpoints, false)

    refute ProductionConfig.debug_enabled?(%{"selecto_debug" => "true"}, %{})
  end

  defp restore_app_env(app, key, nil), do: Application.delete_env(app, key)
  defp restore_app_env(app, key, value), do: Application.put_env(app, key, value)
end
