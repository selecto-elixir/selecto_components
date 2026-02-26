defmodule SelectoComponents.Views.Aggregate.Options do
  @moduledoc false

  @per_page_options [30, 100, 200, 300, "all"]
  @default_per_page "100"

  def per_page_options, do: @per_page_options
  def default_per_page, do: @default_per_page

  def normalize_per_page_param(value) when is_binary(value) do
    normalized = value |> String.trim() |> String.downcase()
    allowed_options = Enum.map(@per_page_options, &to_string/1)

    if normalized in allowed_options do
      normalized
    else
      @default_per_page
    end
  end

  def normalize_per_page_param(value) when is_integer(value),
    do: normalize_per_page_param(Integer.to_string(value))

  def normalize_per_page_param(value) when is_atom(value),
    do: normalize_per_page_param(Atom.to_string(value))

  def normalize_per_page_param(_value), do: @default_per_page

  def per_page_to_int("all", total_rows), do: max(total_rows, 1)

  def per_page_to_int(per_page, _total_rows) when is_binary(per_page) do
    case Integer.parse(per_page) do
      {value, ""} when value > 0 -> value
      _ -> String.to_integer(@default_per_page)
    end
  end

  def per_page_to_int(_per_page, _total_rows), do: String.to_integer(@default_per_page)

  def aggregate_view_mode?(params) when is_map(params) do
    case Map.get(params, :view_mode, Map.get(params, "view_mode")) do
      :aggregate -> true
      "aggregate" -> true
      mode when is_atom(mode) -> Atom.to_string(mode) == "aggregate"
      _ -> false
    end
  end

  def aggregate_view_mode?(_params), do: false
end
