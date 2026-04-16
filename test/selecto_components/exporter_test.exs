defmodule SelectoComponents.ExporterTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.Exporter

  @exported_at ~U[2026-02-25 12:00:00Z]

  test "builds CSV export with escaped values" do
    query_results =
      {
        [
          ["Simple", 1901],
          ["Has,Comma", 1902],
          ["Has \"Quote\"", 1903],
          ["Line\nBreak", 1904]
        ],
        ["title", "release_year"],
        ["Title", "Release Year"]
      }

    assert {:ok, export} =
             Exporter.build("csv", query_results,
               view_mode: "detail",
               exported_at: @exported_at
             )

    assert export.filename == "selecto_detail_20260225_120000.csv"
    assert export.mime_type == "text/csv;charset=utf-8"

    assert export.content =~ "title,release_year"
    assert export.content =~ "\"Has,Comma\",1902"
    assert export.content =~ "\"Has \"\"Quote\"\"\",1903"
    assert export.content =~ "\"Line\nBreak\",1904"
  end

  test "neutralizes spreadsheet formulas in CSV export" do
    query_results =
      {
        [
          ["=2+2"],
          [" +SUM(A1:A2)"],
          ["-10"],
          ["@cmd"],
          ["safe value"]
        ],
        ["value"],
        ["Value"]
      }

    assert {:ok, export} =
             Exporter.build("csv", query_results,
               view_mode: "detail",
               exported_at: @exported_at
             )

    assert export.content =~ "'=2+2"
    assert export.content =~ "' +SUM(A1:A2)"
    assert export.content =~ "'-10"
    assert export.content =~ "'@cmd"
    assert export.content =~ "safe value"
  end

  test "builds TSV export with escaped values" do
    query_results =
      {
        [
          ["Simple", 1901],
          ["Has\tTab", 1902],
          ["Has \"Quote\"", 1903]
        ],
        ["title", "release_year"],
        ["Title", "Release Year"]
      }

    assert {:ok, export} =
             Exporter.build("tsv", query_results,
               view_mode: "detail",
               exported_at: @exported_at
             )

    assert export.filename == "selecto_detail_20260225_120000.tsv"
    assert export.mime_type == "text/tab-separated-values;charset=utf-8"
    assert export.browser_content_encoding == "utf8"
    assert export.content =~ "title\trelease_year"
    assert export.content =~ "\"Has\tTab\"\t1902"
    assert export.content =~ "\"Has \"\"Quote\"\"\"\t1903"
  end

  test "builds JSON export from map rows" do
    query_results =
      {
        [
          %{"title" => "Film A", "release_year" => 1901},
          %{"title" => "Film B", "release_year" => 1902}
        ],
        ["title", "release_year"],
        []
      }

    assert {:ok, export} =
             Exporter.build("json", query_results,
               view_mode: :detail,
               exported_at: @exported_at
             )

    assert export.filename == "selecto_detail_20260225_120000.json"
    assert export.mime_type == "application/json"

    decoded = Jason.decode!(export.content)
    assert decoded["view_mode"] == "detail"
    assert decoded["row_count"] == 2
    assert decoded["columns"] == ["title", "release_year"]
    assert [%{"title" => "Film A", "release_year" => 1901} | _] = decoded["rows"]
  end

  test "builds grid-shaped CSV export for aggregate grid view" do
    query_results =
      {
        [
          [2001, "A", 3],
          [2001, "B", 5],
          [2002, "A", 2],
          [nil, nil, 10]
        ],
        ["release_year", "title", "film_count"],
        []
      }

    view_config = %{
      views: %{
        aggregate: %{
          group_by: [
            {"g0", "release_year", %{"alias" => "Year", "index" => "0"}},
            {"g1", "title", %{"alias" => "Title", "index" => "1"}}
          ],
          aggregate: [{"a0", "film_count", %{"alias" => "Films", "index" => "0"}}],
          grid: true
        }
      }
    }

    assert {:ok, export} =
             Exporter.build("csv", query_results,
               view_mode: "aggregate",
               view_config: view_config,
               exported_at: @exported_at
             )

    assert export.filename == "selecto_aggregate_20260225_120000.csv"
    assert export.content == "Year,A,B\n2001,3,5\n2002,2,"
  end

  test "builds grid-shaped JSON export for aggregate grid view" do
    query_results =
      {
        [
          [2001, "A", 3],
          [2001, "B", 5],
          [2002, "A", 2],
          [nil, nil, 10]
        ],
        ["release_year", "title", "film_count"],
        []
      }

    view_config = %{
      views: %{
        aggregate: %{
          group_by: [
            {"g0", "release_year", %{"alias" => "Year", "index" => "0"}},
            {"g1", "title", %{"alias" => "Title", "index" => "1"}}
          ],
          aggregate: [{"a0", "film_count", %{"alias" => "Films", "index" => "0"}}],
          grid: true
        }
      }
    }

    assert {:ok, export} =
             Exporter.build("json", query_results,
               view_mode: :aggregate,
               view_config: view_config,
               exported_at: @exported_at
             )

    decoded = Jason.decode!(export.content)
    assert decoded["columns"] == ["Year", "A", "B"]

    assert decoded["rows"] == [
             %{"Year" => 2001, "A" => 3, "B" => 5},
             %{"Year" => 2002, "A" => 2, "B" => nil}
           ]
  end

  test "builds XLSX export" do
    query_results =
      {
        [
          ["Film A", 1901],
          ["Film B", 1902]
        ],
        ["title", "release_year"],
        []
      }

    assert {:ok, export} =
             Exporter.build("xlsx", query_results,
               view_mode: :detail,
               exported_at: @exported_at
             )

    assert export.filename == "selecto_detail_20260225_120000.xlsx"
    assert export.mime_type == "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    assert export.browser_content_encoding == "base64"
    assert is_binary(export.content)
    assert byte_size(export.content) > 0
    assert <<"PK", _::binary>> = export.content
    assert Base.decode64!(export.browser_content) == export.content
  end

  test "preserves distinct values when export headers repeat" do
    query_results =
      {
        [
          ["Actor Name", "Category Name", "Customer Name", "Employee Name"]
        ],
        ["Name", "Name", "Name", "Name"],
        []
      }

    assert {:ok, csv_export} =
             Exporter.build("csv", query_results,
               view_mode: :detail,
               exported_at: @exported_at
             )

    assert csv_export.content ==
             "Name,Name,Name,Name\nActor Name,Category Name,Customer Name,Employee Name"

    assert {:ok, json_export} =
             Exporter.build("json", query_results,
               view_mode: :detail,
               exported_at: @exported_at
             )

    decoded = Jason.decode!(json_export.content)

    assert decoded["columns"] == ["Name", "Name", "Name", "Name"]

    assert decoded["rows"] == [
             %{
               "Name" => "Actor Name",
               "Name (2)" => "Category Name",
               "Name (3)" => "Customer Name",
               "Name (4)" => "Employee Name"
             }
           ]
  end

  test "formats exports in display mode using presentation metadata" do
    query_results =
      {
        [[0, 1_704_067_200]],
        ["temperature_c", "recorded_at"],
        ["Temperature", "Recorded At"]
      }

    selecto =
      Selecto.configure(
        %{
          name: "ExporterPresentationTest",
          source: %{
            source_table: "measurements",
            primary_key: :id,
            fields: [:id, :temperature_c, :recorded_at],
            redact_fields: [],
            columns: %{
              id: %{type: :integer},
              temperature_c: %{
                type: :decimal,
                presentation: %{
                  semantic_type: :measurement,
                  quantity: :temperature,
                  canonical_unit: :celsius,
                  default_unit: :celsius,
                  format: %{maximum_fraction_digits: 1}
                }
              },
              recorded_at: %{
                type: :integer,
                presentation_type: :utc_datetime,
                datetime_storage: :unix_seconds,
                presentation: %{
                  semantic_type: :temporal,
                  temporal_kind: :instant,
                  display_timezone: :viewer
                }
              }
            },
            associations: %{}
          },
          schemas: %{},
          joins: %{}
        },
        nil
      )

    assert {:ok, csv_export} =
             Exporter.build("csv", query_results,
               view_mode: :detail,
               exported_at: @exported_at,
               selecto: selecto,
               export_mode: :display,
               presentation_context: %{unit_system: :us_customary, timezone: "America/New_York"}
             )

    assert csv_export.content ==
             "temperature_c,recorded_at\n32.0 F,2023-12-31 19:00"

    assert {:ok, json_export} =
             Exporter.build("json", query_results,
               view_mode: :detail,
               exported_at: @exported_at,
               selecto: selecto,
               export_mode: :display,
               presentation_context: %{unit_system: :us_customary, timezone: "America/New_York"}
             )

    decoded = Jason.decode!(json_export.content)

    assert decoded["export_mode"] == "display"

    assert decoded["presentation_context"] == %{
             "timezone" => "America/New_York",
             "unit_system" => "us_customary"
           }

    assert decoded["rows"] == [
             %{"temperature_c" => "32.0 F", "recorded_at" => "2023-12-31 19:00"}
           ]
  end

  test "returns no_results error for invalid query_results" do
    assert {:error, :no_results} = Exporter.build("csv", nil)
  end

  test "returns unsupported_format for unsupported format" do
    query_results = {[], [], []}
    assert {:error, :unsupported_format} = Exporter.build("xml", query_results)
  end
end
