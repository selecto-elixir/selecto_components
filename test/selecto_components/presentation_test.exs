defmodule SelectoComponents.PresentationTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.Presentation

  defmodule TestLocaleAdapter do
    @behaviour SelectoComponents.Presentation.LocaleAdapter

    @impl true
    def parse_number("1|234~5", _context), do: {:ok, 1234.5}
    def parse_number(_value, _context), do: :error

    @impl true
    def format_number(value, _context, opts) do
      digits = Keyword.get(opts, :digits, 2)

      formatted =
        case value do
          float when is_float(float) -> :erlang.float_to_binary(float, decimals: digits)
          integer when is_integer(integer) -> Integer.to_string(integer)
          _ -> to_string(value)
        end

      {:ok, "adapter:" <> formatted}
    end
  end

  test "formats measurements using viewer unit preferences" do
    column = %{
      presentation: %{
        semantic_type: :measurement,
        quantity: :temperature,
        canonical_unit: :celsius,
        default_unit: :celsius,
        format: %{maximum_fraction_digits: 1}
      }
    }

    context = %{unit_system: :us_customary}

    assert Presentation.display_unit(column, context) == :fahrenheit
    assert Presentation.display_unit_label(column, context) == "F"
    assert Presentation.format_cell(0, column, context) == "32.0 F"
  end

  test "formats epoch-backed temporal values in the requested timezone" do
    column = %{
      type: :integer,
      presentation_type: :utc_datetime,
      datetime_storage: :unix_seconds,
      presentation: %{
        semantic_type: :temporal,
        temporal_kind: :instant,
        display_timezone: :viewer
      }
    }

    assert Presentation.format_cell(1_704_067_200, column, %{timezone: "America/New_York"}) ==
             "2023-12-31 19:00"
  end

  test "raw mode preserves original values" do
    column = %{
      presentation: %{
        semantic_type: :measurement,
        quantity: :distance,
        canonical_unit: :kilometer
      }
    }

    assert Presentation.format_value(12.5, column, %{unit_system: :us_customary}, mode: :raw) ==
             12.5
  end

  test "parses locale-aware numeric strings using inferred locale conventions" do
    assert Presentation.parse_number("1.234,5", %{locale: "de-DE"}) == 1234.5
    assert Presentation.parse_number("1 234,5", %{locale: "fr-FR"}) == 1234.5
    assert Presentation.parse_number("1,234.5", %{locale: "en-US"}) == 1234.5
  end

  test "parses numeric strings using explicit conventions overrides" do
    context = %{
      locale: "en-US",
      conventions: %{
        decimal_separator: ",",
        grouping_separators: [".", " "]
      }
    }

    assert Presentation.parse_number("1.234,5", context) == 1234.5
  end

  test "parses numbers through a custom locale adapter when configured" do
    context = %{locale_adapter: TestLocaleAdapter}

    assert Presentation.parse_number("1|234~5", context) == 1234.5
  end

  test "formats numbers through a custom locale adapter when configured" do
    column = %{
      presentation: %{
        semantic_type: :measurement,
        quantity: :temperature,
        canonical_unit: :celsius,
        default_unit: :celsius,
        format: %{maximum_fraction_digits: 1}
      }
    }

    context = %{locale_adapter: TestLocaleAdapter}

    assert Presentation.format_cell(12.5, column, context, show_unit: false) == "adapter:12.5"
  end

  test "falls back to built-in parsing when locale adapter does not handle a value" do
    context = %{locale: "de-DE", locale_adapter: TestLocaleAdapter}

    assert Presentation.parse_number("1.234,5", context) == 1234.5
  end
end
