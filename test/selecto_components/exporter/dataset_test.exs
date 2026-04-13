defmodule SelectoComponents.Exporter.DatasetTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.Exporter.Dataset

  test "builds table dataset from tabular query results" do
    query_results =
      {
        [
          ["Film A", 1901],
          ["Film B", 1902]
        ],
        ["title", "release_year"],
        []
      }

    assert {:ok, dataset} = Dataset.from_query_results(query_results, view_mode: "detail")

    assert dataset.kind == :table
    assert dataset.headers == ["title", "release_year"]
    assert dataset.row_keys == ["__col_0", "__col_1"]

    assert dataset.rows == [
             %{"__col_0" => "Film A", "__col_1" => 1901},
             %{"__col_0" => "Film B", "__col_1" => 1902}
           ]

    assert dataset.metadata.row_count == 2
  end

  test "builds grid dataset from aggregate grid query results" do
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

    assert {:ok, dataset} =
             Dataset.from_query_results(query_results,
               view_mode: "aggregate",
               view_config: view_config
             )

    assert dataset.kind == :grid
    assert dataset.headers == ["Year", "A", "B"]

    assert dataset.rows == [
             %{"Year" => 2001, "A" => 3, "B" => 5},
             %{"Year" => 2002, "A" => 2, "B" => nil}
           ]

    assert dataset.metadata.row_count == 2
    assert dataset.metadata.row_header == "Year"
  end
end
