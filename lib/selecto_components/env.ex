defmodule SelectoComponents.Env do
  @moduledoc false

  def current do
    cond do
      env = Application.get_env(:selecto_components, :env) ->
        normalize_env(env)

      Code.ensure_loaded?(Mix) and function_exported?(Mix, :env, 0) ->
        Mix.env()

      env = System.get_env("MIX_ENV") ->
        normalize_env(env)

      true ->
        :prod
    end
  end

  def dev?, do: current() == :dev
  def test?, do: current() == :test
  def prod?, do: current() == :prod
  def dev_or_test?, do: current() in [:dev, :test]

  defp normalize_env(env) when env in [:dev, :test, :prod], do: env
  defp normalize_env("dev"), do: :dev
  defp normalize_env("test"), do: :test
  defp normalize_env("prod"), do: :prod
  defp normalize_env(_env), do: :prod
end
