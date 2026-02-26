defmodule SelectoComponents.Views.Detail.Options do
  @moduledoc false

  @max_rows_options ~w(100 1000 10000 all)
  @default_max_rows "1000"

  def max_rows_options, do: @max_rows_options
  def default_max_rows, do: @default_max_rows

  def normalize_max_rows_param(value) when is_binary(value) do
    normalized = value |> String.trim() |> String.downcase()

    if normalized in @max_rows_options do
      normalized
    else
      @default_max_rows
    end
  end

  def normalize_max_rows_param(value) when is_integer(value),
    do: normalize_max_rows_param(Integer.to_string(value))

  def normalize_max_rows_param(value) when is_atom(value),
    do: normalize_max_rows_param(Atom.to_string(value))

  def normalize_max_rows_param(_value), do: @default_max_rows

  def normalize_max_rows_limit(value) do
    case normalize_max_rows_param(value) do
      "all" ->
        nil

      normalized ->
        case Integer.parse(normalized) do
          {limit, ""} when limit > 0 -> limit
          _ -> String.to_integer(@default_max_rows)
        end
    end
  end

  def detail_view_mode?(params) when is_map(params) do
    case Map.get(params, :view_mode, Map.get(params, "view_mode")) do
      :detail -> true
      "detail" -> true
      mode when is_atom(mode) -> Atom.to_string(mode) == "detail"
      _ -> false
    end
  end

  def detail_view_mode?(_params), do: false
end
