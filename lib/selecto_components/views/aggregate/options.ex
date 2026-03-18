defmodule SelectoComponents.Views.Aggregate.Options do
  @moduledoc false

  @per_page_options [30, 100, 200, 300, "all"]
  @default_per_page "100"
  @default_max_client_rows 10_000
  @grid_color_scale_modes ["linear", "log"]
  @default_grid_color_scale_mode "linear"

  def per_page_options, do: @per_page_options
  def default_per_page, do: @default_per_page
  def default_max_client_rows, do: @default_max_client_rows
  def grid_color_scale_modes, do: @grid_color_scale_modes
  def default_grid_color_scale_mode, do: @default_grid_color_scale_mode

  def max_client_rows do
    configured =
      Application.get_env(
        :selecto_components,
        :aggregate_max_client_rows,
        @default_max_client_rows
      )

    normalize_max_client_rows(configured)
  end

  def normalize_max_client_rows(:infinity), do: :infinity

  def normalize_max_client_rows(value) when is_integer(value) and value > 0,
    do: value

  def normalize_max_client_rows(value) when is_binary(value) do
    normalized = String.trim(value) |> String.downcase()

    case normalized do
      "infinity" ->
        :infinity

      _ ->
        case Integer.parse(normalized) do
          {parsed, ""} when parsed > 0 -> parsed
          _ -> @default_max_client_rows
        end
    end
  end

  def normalize_max_client_rows(_value), do: @default_max_client_rows

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

  def normalize_grid_color_scale_mode(value) when is_binary(value) do
    normalized = value |> String.trim() |> String.downcase()

    if normalized in @grid_color_scale_modes do
      normalized
    else
      @default_grid_color_scale_mode
    end
  end

  def normalize_grid_color_scale_mode(value) when is_atom(value),
    do: normalize_grid_color_scale_mode(Atom.to_string(value))

  def normalize_grid_color_scale_mode(_value), do: @default_grid_color_scale_mode

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
