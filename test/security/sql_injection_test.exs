defmodule SelectoComponents.Security.SqlInjectionTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.Helpers.Filters
  alias SelectoComponents.SqlSafety
  alias SelectoComponents.Views.Aggregate.Process, as: AggregateProcess
  alias SelectoComponents.Views.Graph.Process, as: GraphProcess

  defp selecto do
    Selecto.configure(
      %{
        name: "SqlInjectionTest",
        source: %{
          source_table: "records",
          primary_key: :id,
          fields: [:id, :title],
          redact_fields: [],
          columns: %{
            id: %{type: :integer},
            title: %{type: :string}
          },
          associations: %{}
        },
        schemas: %{},
        joins: %{}
      },
      nil
    )
  end

  defp instant_column(storage_timezone \\ "Etc/UTC") do
    %{
      name: "Occurred At",
      colid: :occurred_at,
      type: :utc_datetime,
      presentation: %{
        semantic_type: :temporal,
        temporal_kind: :instant,
        storage_timezone: storage_timezone,
        display_timezone: :viewer
      }
    }
  end

  test "filter values are bound as query parameters" do
    malicious_value = "'; DROP TABLE records; --"

    filters = %{
      "filters" => [
        %{
          "uuid" => "f1",
          "section" => "filters",
          "filter" => "title",
          "comp" => "=",
          "value" => malicious_value
        }
      ]
    }

    built_filters = Filters.filter_recurse(selecto(), filters, "filters")

    {sql, params} =
      selecto()
      |> Selecto.select(["id"])
      |> Selecto.filter(built_filters)
      |> Selecto.to_sql()

    refute sql =~ malicious_value
    assert malicious_value in params
  end

  test "datetime grouping formats are restricted to known values" do
    assert SqlSafety.datetime_grouping_format("YYYY-MM") == "YYYY-MM"

    assert SqlSafety.datetime_grouping_format("YYYY-MM-DD'); DROP TABLE records; --") ==
             "YYYY-MM-DD"
  end

  test "timezones require a valid safe timezone name" do
    assert SqlSafety.timezone("America/New_York") == "America/New_York"
    assert SqlSafety.timezone("Etc/UTC'; DROP TABLE records; --", nil) == nil
    assert SqlSafety.timezone("Not/A_Real_Zone", nil) == nil
  end

  test "aggregate raw SQL rejects injected format and storage timezone values" do
    columns = %{
      "occurred_at" => instant_column("Etc/UTC'; DROP TABLE records; --")
    }

    [{_column, {:field, {:raw_sql, sql}, "Occurred At"}}] =
      AggregateProcess.group_by(
        %{
          "g1" => %{
            "field" => "occurred_at",
            "format" => "YYYY-MM-DD'); DROP TABLE records; --",
            "index" => "not-an-integer"
          }
        },
        columns,
        nil,
        %{timezone: "America/New_York"}
      )

    assert sql =~ "AT TIME ZONE 'Etc/UTC'"
    assert sql =~ "'YYYY-MM-DD'"
    refute sql =~ "DROP TABLE"
  end

  test "aggregate grouping ignores an injected runtime timezone" do
    columns = %{"occurred_at" => instant_column()}

    [{_column, selector}] =
      AggregateProcess.group_by(
        %{
          "g1" => %{
            "field" => "occurred_at",
            "format" => "YYYY-MM",
            "index" => "0"
          }
        },
        columns,
        nil,
        %{timezone: "Etc/UTC'; DROP TABLE records; --"}
      )

    assert {:field, {:to_char, {:occurred_at, "YYYY-MM"}}, "Occurred At"} = selector
  end

  test "graph raw SQL rejects injected format values" do
    columns = %{"occurred_at" => instant_column()}

    [{_column, {:field, {:raw_sql, sql}, _alias}}] =
      GraphProcess.group_by_fields(
        %{
          "g1" => %{
            "field" => "occurred_at",
            "format" => "YYYY'); DELETE FROM records; --",
            "index" => "invalid"
          }
        },
        columns,
        %{timezone: "Europe/Berlin"}
      )

    assert sql =~ "'YYYY-MM-DD'"
    refute sql =~ "DELETE FROM"
  end
end
