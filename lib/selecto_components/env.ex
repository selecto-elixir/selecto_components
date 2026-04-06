defmodule SelectoComponents.Env do
  @moduledoc false

  def current do
    cond do
      Code.ensure_loaded?(Mix) and function_exported?(Mix, :env, 0) ->
        Mix.env()

      env = Application.get_env(:selecto_components, :env) ->
        env

      env = System.get_env("MIX_ENV") ->
        String.to_atom(env)

      true ->
        :prod
    end
  end

  def dev?, do: current() == :dev
  def test?, do: current() == :test
  def prod?, do: current() == :prod
  def dev_or_test?, do: current() in [:dev, :test]
end
