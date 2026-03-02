defmodule SelectoComponents.Views.Detail.QueryPaginationTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.Views.Detail.QueryPagination

  defmodule CaptureAdapter do
    def execute(parent, query, _params, _opts) when is_pid(parent) do
      send(parent, {:executed_sql, query})

      if String.contains?(String.downcase(query), "count(*) as total_rows") do
        {:ok, %{rows: [[2]], columns: ["total_rows"]}}
      else
        {:ok, %{rows: [["Alpha"], ["Beta"]], columns: ["name"]}}
      end
    end
  end

  defp detail_selecto do
    domain = %{
      name: "DetailQueryPaginationTest",
      source: %{
        source_table: "users",
        primary_key: :id,
        fields: [:id, :name],
        redact_fields: [],
        columns: %{
          id: %{type: :integer},
          name: %{type: :string}
        },
        associations: %{}
      },
      schemas: %{},
      joins: %{}
    }

    domain
    |> Selecto.configure(nil, validate: false)
    |> Selecto.select(["name"])
    |> Map.put(:adapter, CaptureAdapter)
    |> Map.put(:connection, self())
  end

  defp socket do
    %{assigns: %{detail_page_cache: nil, sort_by: nil}}
  end

  defp collect_sql_messages(acc \\ []) do
    receive do
      {:executed_sql, query} ->
        collect_sql_messages([query | acc])
    after
      100 ->
        Enum.reverse(acc)
    end
  end

  test "count query uses lightweight primary-key projection" do
    selecto = detail_selecto()
    params = %{"view_mode" => "detail", "selected" => %{}}
    view_meta = %{page: 0, per_page: 2, max_rows: "1000", subselect_configs: []}

    {{:ok, {rows, columns, _aliases}, metadata}, _updated_view_meta, _cache} =
      QueryPagination.execute(selecto, params, view_meta, socket())

    assert rows == [%{"name" => "Alpha"}, %{"name" => "Beta"}]
    assert columns == ["name"]

    sql_statements = collect_sql_messages()

    count_sql =
      Enum.find(sql_statements, &String.contains?(String.downcase(&1), "count(*) as total_rows"))

    assert is_binary(count_sql)
    assert count_sql =~ ~r/\bid\b/i
    refute count_sql =~ ~r/"name"/i
    assert is_map(metadata)
  end
end
