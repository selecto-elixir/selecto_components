defmodule SelectoComponents.PresentationTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.Presentation

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
end
