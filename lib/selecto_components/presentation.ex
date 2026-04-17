defmodule SelectoComponents.Presentation do
  @moduledoc false

  alias Decimal, as: D

  @unit_system_defaults %{
    metric: %{
      temperature: :celsius,
      length: :meter,
      distance: :kilometer,
      mass: :kilogram,
      volume: :liter,
      area: :square_meter,
      speed: :kilometer_per_hour
    },
    us_customary: %{
      temperature: :fahrenheit,
      length: :foot,
      distance: :mile,
      mass: :pound,
      volume: :gallon,
      area: :square_foot,
      speed: :mile_per_hour
    }
  }

  @unit_labels %{
    celsius: "C",
    fahrenheit: "F",
    kelvin: "K",
    millimeter: "mm",
    centimeter: "cm",
    meter: "m",
    kilometer: "km",
    inch: "in",
    foot: "ft",
    yard: "yd",
    mile: "mi",
    gram: "g",
    kilogram: "kg",
    ounce: "oz",
    pound: "lb",
    milliliter: "mL",
    liter: "L",
    fluid_ounce: "fl oz",
    gallon: "gal",
    square_meter: "m2",
    square_foot: "ft2",
    acre: "acre",
    hectare: "ha",
    meter_per_second: "m/s",
    kilometer_per_hour: "km/h",
    mile_per_hour: "mph"
  }

  @comma_decimal_locales ~w(
    bg cs da de el es et fi fr hr hu it lt lv nb nl pl pt ro sk sl sr sv tr uk
  )

  @spec resolve_context(map() | nil) :: map()
  def resolve_context(context) when is_map(context) do
    %{
      locale: normalize_locale(Map.get(context, :locale) || Map.get(context, "locale")),
      timezone: normalize_timezone(Map.get(context, :timezone) || Map.get(context, "timezone")),
      unit_system:
        normalize_unit_system(Map.get(context, :unit_system) || Map.get(context, "unit_system")),
      unit_overrides:
        normalize_unit_overrides(
          Map.get(context, :unit_overrides) || Map.get(context, "unit_overrides", %{})
        ),
      conventions: Map.get(context, :conventions) || Map.get(context, "conventions") || %{},
      locale_adapter:
        normalize_locale_adapter(
          Map.get(context, :locale_adapter) || Map.get(context, "locale_adapter")
        ),
      locale_adapter_options:
        normalize_locale_adapter_options(
          Map.get(context, :locale_adapter_options) || Map.get(context, "locale_adapter_options")
        )
    }
  end

  def resolve_context(_context) do
    %{
      locale: nil,
      timezone: "Etc/UTC",
      unit_system: :metric,
      unit_overrides: %{},
      conventions: %{},
      locale_adapter: nil,
      locale_adapter_options: %{}
    }
  end

  @spec format_value(term(), map() | nil, map() | nil, keyword()) :: term()
  def format_value(value, column, context, opts \\ [])

  def format_value(value, _column, _context, _opts) when value in [nil, ""], do: value

  def format_value(value, column, context, opts) do
    context = resolve_context(context)
    mode = Keyword.get(opts, :mode, :display)

    if mode == :raw do
      value
    else
      do_format_value(value, column, context, opts)
    end
  end

  @spec format_cell(term(), map() | nil, map() | nil, keyword()) :: String.t()
  def format_cell(value, column, context, opts \\ []) do
    formatted = format_value(value, column, context, opts)
    value_to_string(formatted)
  end

  @spec parse_number(term(), map() | nil) :: float() | nil
  def parse_number(value, context \\ nil)

  def parse_number(value, _context) when is_integer(value), do: value * 1.0
  def parse_number(value, _context) when is_float(value), do: value
  def parse_number(%D{} = value, _context), do: D.to_float(value)

  def parse_number(value, context) when is_binary(value) do
    context = resolve_context(context)

    case parse_number_with_adapter(value, context) do
      {:ok, float} when is_float(float) ->
        float

      _ ->
        with normalized when is_binary(normalized) and normalized != "" <-
               normalize_number_string(value, context),
             {float, ""} <- Float.parse(normalized) do
          float
        else
          _ -> nil
        end
    end
  end

  def parse_number(_value, _context), do: nil

  @spec display_unit(map() | nil, map() | nil) :: atom() | String.t() | nil
  def display_unit(column, context) do
    presentation = presentation(column)
    context = resolve_context(context)
    quantity = Map.get(presentation || %{}, :quantity)
    overrides = Map.get(context, :unit_overrides, %{})

    cond do
      is_nil(presentation) ->
        nil

      quantity && Map.has_key?(overrides, quantity) ->
        Map.get(overrides, quantity)

      quantity && Map.has_key?(@unit_system_defaults[context.unit_system] || %{}, quantity) ->
        Map.get(@unit_system_defaults[context.unit_system] || %{}, quantity)

      true ->
        Map.get(presentation, :default_unit) || Map.get(presentation, :canonical_unit)
    end
  end

  @spec display_unit_label(map() | nil, map() | nil) :: String.t() | nil
  def display_unit_label(column, context) do
    case display_unit(column, context) do
      nil -> nil
      unit -> Map.get(@unit_labels, unit, to_string(unit))
    end
  end

  defp do_format_value(value, column, context, opts) do
    presentation = presentation(column)

    cond do
      match?(%{semantic_type: :measurement}, presentation) ->
        format_measurement(value, presentation, context, opts)

      match?(%{semantic_type: :temporal}, presentation) ->
        format_temporal(value, column, presentation, context, opts)

      true ->
        format_plain_value(value, context, opts)
    end
  end

  defp format_measurement(value, presentation, context, opts) do
    canonical_unit = Map.get(presentation, :canonical_unit)
    target_unit = display_unit(%{presentation: presentation}, context)
    converted_value = convert_measurement(value, canonical_unit, target_unit)
    show_unit? = Keyword.get(opts, :show_unit, true)
    text_value = format_number(converted_value, presentation, context)

    if show_unit? and target_unit do
      text_value <> " " <> Map.get(@unit_labels, target_unit, to_string(target_unit))
    else
      text_value
    end
  end

  defp format_temporal(value, column, presentation, context, opts) do
    timezone = Map.get(context, :timezone, "Etc/UTC")
    temporal_kind = Map.get(presentation, :temporal_kind)
    local_value = temporal_to_display(value, column, temporal_kind, timezone)
    include_timezone? = Keyword.get(opts, :include_timezone, false)

    case local_value do
      %Date{} = date ->
        Date.to_iso8601(date)

      %NaiveDateTime{} = naive ->
        Calendar.strftime(naive, "%Y-%m-%d %H:%M")

      %DateTime{} = datetime ->
        formatted = Calendar.strftime(datetime, "%Y-%m-%d %H:%M")
        if include_timezone?, do: formatted <> " " <> timezone_label(datetime), else: formatted

      other ->
        value_to_string(other)
    end
  end

  defp format_plain_value(value, _context, _opts) do
    value_to_string(value)
  end

  defp presentation(%{presentation: presentation}) when is_map(presentation), do: presentation
  defp presentation(column) when is_map(column), do: Selecto.Presentation.presentation(column)
  defp presentation(_column), do: nil

  defp normalize_locale(nil), do: nil

  defp normalize_locale(locale) when is_binary(locale) do
    case String.trim(locale) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_locale(_locale), do: nil

  defp normalize_locale_adapter(value) when is_atom(value), do: value
  defp normalize_locale_adapter(_value), do: nil

  defp normalize_locale_adapter_options(options) when is_map(options), do: options
  defp normalize_locale_adapter_options(_options), do: %{}

  defp normalize_timezone(nil), do: "Etc/UTC"

  defp normalize_timezone(timezone) when is_binary(timezone) do
    case String.trim(timezone) do
      "" -> "Etc/UTC"
      trimmed -> trimmed
    end
  end

  defp normalize_timezone(_timezone), do: "Etc/UTC"

  defp normalize_unit_system(value) when value in [:metric, :us_customary], do: value
  defp normalize_unit_system("us"), do: :us_customary
  defp normalize_unit_system("us_customary"), do: :us_customary
  defp normalize_unit_system("metric"), do: :metric
  defp normalize_unit_system(_value), do: :metric

  defp normalize_unit_overrides(overrides) when is_map(overrides) do
    Map.new(overrides, fn {quantity, unit} ->
      {normalize_override_key(quantity), normalize_override_unit(unit)}
    end)
  end

  defp normalize_unit_overrides(_), do: %{}

  defp normalize_override_key(value) when is_atom(value), do: value

  defp normalize_override_key(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.downcase()
    |> String.replace(~r/[\s-]+/u, "_")
    |> safe_existing_atom_or_string()
  end

  defp normalize_override_key(value), do: value

  defp normalize_override_unit(value) when is_atom(value), do: value

  defp normalize_override_unit(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.downcase()
    |> String.replace(~r/[\s-]+/u, "_")
    |> safe_existing_atom_or_string()
  end

  defp normalize_override_unit(value), do: value

  defp temporal_to_display(value, column, :instant, timezone) do
    Selecto.Temporal.to_display_temporal(column || %{}, value)
    |> maybe_shift_datetime(timezone)
  end

  defp temporal_to_display(value, column, _temporal_kind, _timezone) do
    Selecto.Temporal.to_display_temporal(column || %{}, value)
  end

  defp maybe_shift_datetime(%DateTime{} = datetime, timezone) when is_binary(timezone) do
    case DateTime.shift_zone(datetime, timezone) do
      {:ok, shifted} -> shifted
      _ -> datetime
    end
  end

  defp maybe_shift_datetime(value, _timezone), do: value

  defp timezone_label(%DateTime{} = datetime), do: datetime.time_zone || "UTC"

  defp format_number(value, presentation, context) do
    digits =
      presentation
      |> Map.get(:format, %{})
      |> Map.get(:maximum_fraction_digits, default_digits(value))

    case format_number_with_adapter(value, context, digits, presentation) do
      {:ok, formatted} when is_binary(formatted) ->
        formatted

      _ ->
        case to_float(value) do
          nil -> value_to_string(value)
          float when digits <= 0 -> float |> Float.round(0) |> trunc() |> Integer.to_string()
          float -> :erlang.float_to_binary(float, decimals: digits)
        end
    end
  end

  defp parse_number_with_adapter(value, context) do
    case Map.get(context, :locale_adapter) do
      adapter when is_atom(adapter) ->
        if function_exported?(adapter, :parse_number, 2) do
          adapter.parse_number(value, context)
        else
          :error
        end

      _ ->
        :error
    end
  rescue
    _ -> :error
  end

  defp format_number_with_adapter(value, context, digits, presentation) do
    case Map.get(context, :locale_adapter) do
      adapter when is_atom(adapter) ->
        if function_exported?(adapter, :format_number, 3) do
          adapter.format_number(value, context,
            digits: digits,
            presentation: presentation,
            locale_adapter_options: Map.get(context, :locale_adapter_options, %{})
          )
        else
          :error
        end

      _ ->
        :error
    end
  rescue
    _ -> :error
  end

  defp normalize_number_string(value, context) when is_binary(value) do
    trimmed =
      value
      |> String.trim()
      |> String.replace(~r/[−–—]/u, "-")

    if trimmed == "" do
      nil
    else
      conventions = number_conventions(context)
      decimal_separator = Map.get(conventions, :decimal_separator, ".")
      grouping_separators = Map.get(conventions, :grouping_separators, [])

      normalized =
        trimmed
        |> remove_grouping_separators(grouping_separators)
        |> normalize_decimal_separator(decimal_separator)

      if Regex.match?(~r/^[-+]?(?:\d+|\d*\.\d+)$/u, normalized), do: normalized, else: nil
    end
  end

  defp number_conventions(context) do
    conventions = Map.get(context, :conventions, %{}) || %{}
    locale = Map.get(context, :locale)
    decimal_separator = convention_decimal_separator(conventions, locale)
    grouping_separators = convention_grouping_separators(conventions, decimal_separator)

    %{
      decimal_separator: decimal_separator,
      grouping_separators: grouping_separators
    }
  end

  defp convention_decimal_separator(conventions, locale) do
    case Map.get(conventions, :decimal_separator) || Map.get(conventions, "decimal_separator") do
      separator when separator in [".", ","] -> separator
      _ -> default_decimal_separator(locale)
    end
  end

  defp convention_grouping_separators(conventions, decimal_separator) do
    explicit =
      Map.get(conventions, :grouping_separators) ||
        Map.get(conventions, "grouping_separators") ||
        Map.get(conventions, :grouping_separator) ||
        Map.get(conventions, "grouping_separator") ||
        Map.get(conventions, :group_separator) ||
        Map.get(conventions, "group_separator")

    separators =
      case explicit do
        values when is_list(values) -> values
        value when is_binary(value) -> [value]
        _ -> default_grouping_separators(decimal_separator)
      end

    separators
    |> Enum.map(&to_string/1)
    |> Enum.reject(&(&1 in [nil, "", decimal_separator]))
    |> Enum.uniq()
  end

  defp default_decimal_separator(locale) when is_binary(locale) do
    locale_prefix = locale |> String.downcase() |> String.split(~r/[-_]/u, parts: 2) |> hd()
    if locale_prefix in @comma_decimal_locales, do: ",", else: "."
  end

  defp default_decimal_separator(_locale), do: "."

  defp default_grouping_separators("."), do: [",", " ", <<194, 160>>, <<226, 128, 175>>, "'", "’"]
  defp default_grouping_separators(","), do: [".", " ", <<194, 160>>, <<226, 128, 175>>, "'", "’"]
  defp default_grouping_separators(_), do: [",", ".", " "]

  defp remove_grouping_separators(value, separators) do
    Enum.reduce(separators, value, fn separator, acc -> String.replace(acc, separator, "") end)
  end

  defp normalize_decimal_separator(value, "."), do: value
  defp normalize_decimal_separator(value, ","), do: String.replace(value, ",", ".")
  defp normalize_decimal_separator(value, separator), do: String.replace(value, separator, ".")

  defp default_digits(value) when is_integer(value), do: 0
  defp default_digits(%D{}), do: 2
  defp default_digits(_value), do: 2

  defp convert_measurement(value, canonical_unit, target_unit)
       when canonical_unit in [nil, target_unit] or target_unit == nil do
    value
  end

  defp convert_measurement(value, :celsius, :fahrenheit),
    do: numeric_transform(value, &(&1 * 9 / 5 + 32))

  defp convert_measurement(value, :fahrenheit, :celsius),
    do: numeric_transform(value, &((&1 - 32) * 5 / 9))

  defp convert_measurement(value, :celsius, :kelvin), do: numeric_transform(value, &(&1 + 273.15))
  defp convert_measurement(value, :kelvin, :celsius), do: numeric_transform(value, &(&1 - 273.15))

  defp convert_measurement(value, :fahrenheit, :kelvin),
    do: numeric_transform(value, &((&1 - 32) * 5 / 9 + 273.15))

  defp convert_measurement(value, :kelvin, :fahrenheit),
    do: numeric_transform(value, &((&1 - 273.15) * 9 / 5 + 32))

  defp convert_measurement(value, source_unit, target_unit) do
    with {:ok, source_factor} <- factor(source_unit),
         {:ok, target_factor} <- factor(target_unit),
         float when is_float(float) <- to_float(value) do
      float * source_factor / target_factor
    else
      _ -> value
    end
  end

  defp factor(:millimeter), do: {:ok, 0.001}
  defp factor(:centimeter), do: {:ok, 0.01}
  defp factor(:meter), do: {:ok, 1.0}
  defp factor(:kilometer), do: {:ok, 1000.0}
  defp factor(:inch), do: {:ok, 0.0254}
  defp factor(:foot), do: {:ok, 0.3048}
  defp factor(:yard), do: {:ok, 0.9144}
  defp factor(:mile), do: {:ok, 1609.344}
  defp factor(:gram), do: {:ok, 1.0}
  defp factor(:kilogram), do: {:ok, 1000.0}
  defp factor(:ounce), do: {:ok, 28.349523125}
  defp factor(:pound), do: {:ok, 453.59237}
  defp factor(:milliliter), do: {:ok, 0.001}
  defp factor(:liter), do: {:ok, 1.0}
  defp factor(:fluid_ounce), do: {:ok, 0.0295735295625}
  defp factor(:gallon), do: {:ok, 3.785411784}
  defp factor(:square_meter), do: {:ok, 1.0}
  defp factor(:square_foot), do: {:ok, 0.09290304}
  defp factor(:acre), do: {:ok, 4046.8564224}
  defp factor(:hectare), do: {:ok, 10000.0}
  defp factor(:meter_per_second), do: {:ok, 1.0}
  defp factor(:kilometer_per_hour), do: {:ok, 0.2777777778}
  defp factor(:mile_per_hour), do: {:ok, 0.44704}
  defp factor(_unit), do: :error

  defp numeric_transform(value, fun) do
    case to_float(value) do
      nil -> value
      float -> fun.(float)
    end
  end

  defp to_float(value) when is_float(value), do: value
  defp to_float(value) when is_integer(value), do: value * 1.0
  defp to_float(%D{} = value), do: D.to_float(value)

  defp to_float(value) when is_binary(value) do
    parse_number(value, nil)
  end

  defp to_float(_value), do: nil

  defp value_to_string(nil), do: ""
  defp value_to_string(value) when is_binary(value), do: value
  defp value_to_string(value) when is_atom(value), do: Atom.to_string(value)
  defp value_to_string(value) when is_integer(value), do: Integer.to_string(value)

  defp value_to_string(value) when is_float(value),
    do: :erlang.float_to_binary(value, decimals: 2)

  defp value_to_string(%Date{} = value), do: Date.to_iso8601(value)
  defp value_to_string(%NaiveDateTime{} = value), do: Calendar.strftime(value, "%Y-%m-%d %H:%M")
  defp value_to_string(%DateTime{} = value), do: Calendar.strftime(value, "%Y-%m-%d %H:%M")
  defp value_to_string(%D{} = value), do: D.to_string(value, :normal)
  defp value_to_string(value), do: inspect(value)

  defp safe_existing_atom_or_string(value) do
    try do
      String.to_existing_atom(value)
    rescue
      ArgumentError -> value
    end
  end
end
