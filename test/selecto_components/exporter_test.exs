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

  test "returns no_results error for invalid query_results" do
    assert {:error, :no_results} = Exporter.build("csv", nil)
  end

  test "returns unsupported_format for unsupported format" do
    query_results = {[], [], []}
    assert {:error, :unsupported_format} = Exporter.build("xml", query_results)
  end
end
