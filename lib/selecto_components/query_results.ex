defmodule SelectoComponents.QueryResults do
  @moduledoc false

  def normalize_query_results({rows, columns, aliases}) do
    {normalize_rows(rows), columns, aliases}
  end

  def normalize_query_results(other), do: other

  def normalize_rows(rows) when is_list(rows) do
    Enum.map(rows, &normalize_row/1)
  end

  def normalize_rows(other), do: other

  def normalize_value(value) when is_binary(value), do: normalize_binary(value)
  def normalize_value(value) when is_list(value), do: Enum.map(value, &normalize_value/1)
  def normalize_value(value) when is_struct(value), do: value

  def normalize_value(value) when is_map(value) do
    Map.new(value, fn {key, item} -> {normalize_key(key), normalize_value(item)} end)
  end

  def normalize_value(value) when is_tuple(value) do
    value
    |> Tuple.to_list()
    |> Enum.map(&normalize_value/1)
  end

  def normalize_value(value) when is_atom(value) and value not in [true, false, nil] do
    Atom.to_string(value)
  end

  def normalize_value(value), do: value

  defp normalize_row(row) when is_tuple(row) do
    row
    |> Tuple.to_list()
    |> normalize_row()
  end

  defp normalize_row(row) when is_list(row), do: Enum.map(row, &normalize_value/1)

  defp normalize_row(row) when is_map(row) do
    Map.new(row, fn {key, value} -> {normalize_key(key), normalize_value(value)} end)
  end

  defp normalize_row(value), do: normalize_value(value)

  defp normalize_key(key) when is_binary(key), do: normalize_binary(key)
  defp normalize_key(key), do: key

  defp normalize_binary(value) do
    cond do
      String.valid?(value) and String.printable?(value) ->
        value

      uuid_binary?(value) ->
        {:ok, uuid} = Ecto.UUID.load(value)
        uuid

      true ->
        "\\x" <> Base.encode16(value, case: :lower)
    end
  end

  defp uuid_binary?(value) when is_binary(value) and byte_size(value) == 16 do
    match?({:ok, _uuid}, Ecto.UUID.load(value))
  end

  defp uuid_binary?(_value), do: false
end
