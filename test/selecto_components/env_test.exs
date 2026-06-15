defmodule SelectoComponents.EnvTest do
  use ExUnit.Case, async: false

  alias SelectoComponents.Env

  setup do
    previous = Application.get_env(:selecto_components, :env)

    on_exit(fn ->
      if is_nil(previous) do
        Application.delete_env(:selecto_components, :env)
      else
        Application.put_env(:selecto_components, :env, previous)
      end
    end)
  end

  test "normalizes configured string env values" do
    Application.put_env(:selecto_components, :env, "dev")

    assert Env.current() == :dev
  end

  test "does not create atoms for unknown configured env values" do
    env = "unknown_env_#{System.unique_integer([:positive])}"

    assert_raise ArgumentError, fn -> String.to_existing_atom(env) end

    Application.put_env(:selecto_components, :env, env)

    assert Env.current() == :prod
    assert_raise ArgumentError, fn -> String.to_existing_atom(env) end
  end
end
