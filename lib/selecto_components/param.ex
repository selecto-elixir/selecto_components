defmodule SelectoComponents.Param do
  @moduledoc false

  @spec integer(term(), integer()) :: integer()
  def integer(value, default \\ 0)

  def integer(value, _default) when is_integer(value), do: value

  def integer(value, default) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {parsed, ""} -> parsed
      _ -> default
    end
  end

  def integer(_value, default), do: default
end
