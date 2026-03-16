defmodule SelectoComponents.Views.Detail.QueryPaginationTest do
  use ExUnit.Case, async: false

  alias SelectoComponents.Views.Detail.QueryPagination

  defmodule CaptureAdapter do
    def execute(parent, query, _params, _opts) when is_pid(parent) do
      send(parent, {:executed_sql, query})

      down = String.downcase(query)

      cond do
        String.contains?(down, "count(*) as total_rows") ->
          {:ok, %{rows: [[200]], columns: ["total_rows"]}}

        String.contains?(down, "selecto_root.id") ->
          {:ok,
           %{
             rows: [[100, "N100"], [101, "N101"], [102, "N102"], [103, "N103"], [104, "N104"]],
             columns: ["id", "name"]
           }}

        true ->
          {:ok, %{rows: [["Alpha"], ["Beta"]], columns: ["name"]}}
      end
    end
  end

  def handle_telemetry(_event, measurements, metadata, parent) do
    send(parent, {:detail_query_telemetry, measurements, metadata})
  end

  defp detail_selecto(selected) do
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
    |> Selecto.select(selected)
    |> Map.put(:adapter, CaptureAdapter)
    |> Map.put(:connection, self())
  end

  defp socket(cache \\ nil) do
    %{assigns: %{detail_page_cache: cache, sort_by: nil}}
  end

  defp view_meta(overrides) do
    Map.merge(
      %{page: 0, per_page: 2, max_rows: "1000", count_mode: "bounded", subselect_configs: []},
      overrides
    )
  end

  defp params(overrides \\ %{}) do
    Map.merge(%{"view_mode" => "detail", "selected" => %{}}, overrides)
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

  test "exact count query omits max_rows bound" do
    selecto = detail_selecto(["name"])

    {{:ok, {_rows, _columns, _aliases}, _metadata}, _updated_view_meta, _cache} =
      QueryPagination.execute(selecto, params(), view_meta(%{count_mode: "exact"}), socket())

    count_sql =
      collect_sql_messages()
      |> Enum.find(&String.contains?(String.downcase(&1), "count(*) as total_rows"))

    assert is_binary(count_sql)
    refute count_sql =~ ~r/limit\s+1000/i
  end

  test "none count mode skips count query" do
    selecto = detail_selecto(["name"])

    {{:ok, {_rows, _columns, _aliases}, _metadata}, _updated_view_meta, _cache} =
      QueryPagination.execute(
        selecto,
        params(),
        view_meta(%{count_mode: "none", max_rows: "all"}),
        socket()
      )

    assert collect_sql_messages()
           |> Enum.all?(fn sql ->
             not String.contains?(String.downcase(sql), "count(*) as total_rows")
           end)
  end

  test "deep sequential paging uses keyset strategy when cursor context is available" do
    selecto = detail_selecto(["id", "name"])
    request_params = params(%{"detail_page" => "50"})

    cache = %{
      signature: %{params: Map.drop(request_params, ["detail_page"]), sort_by: []},
      per_page: 2,
      max_rows_limit: nil,
      count_mode: "none",
      total_rows: 200,
      columns: ["id", "name"],
      aliases: ["ID", "Name"],
      pages: %{49 => [[98, "N98"], [99, "N99"]]}
    }

    {{:ok, {_rows, _columns, _aliases}, metadata}, _updated_view_meta, _cache} =
      QueryPagination.execute(
        selecto,
        request_params,
        view_meta(%{page: 50, count_mode: "none", max_rows: "all"}),
        socket(cache)
      )

    sql_statements = collect_sql_messages()

    data_sql =
      Enum.find(sql_statements, fn sql ->
        not String.contains?(String.downcase(sql), "count(*)")
      end)

    assert is_binary(data_sql)
    assert String.contains?(String.downcase(data_sql), " where ")
    assert String.contains?(String.downcase(data_sql), "id")
    refute String.contains?(String.downcase(data_sql), " offset ")
    assert metadata[:pagination_mode] == :keyset
  end

  test "emits detail query telemetry with count/page timing and cache flags" do
    handler_id = "detail-query-telemetry-#{System.unique_integer([:positive])}"
    parent = self()

    :ok =
      :telemetry.attach(
        handler_id,
        [:selecto_components, :detail, :query],
        &__MODULE__.handle_telemetry/4,
        parent
      )

    selecto = detail_selecto(["name"])

    {{:ok, {_rows, _columns, _aliases}, _metadata}, _updated_view_meta, _cache} =
      QueryPagination.execute(selecto, params(), view_meta(%{count_mode: "bounded"}), socket())

    assert_receive {:detail_query_telemetry, measurements, metadata}
    assert is_integer(measurements[:count_time_ms])
    assert is_integer(measurements[:page_fetch_time_ms])
    assert measurements[:cache_hit] in [0, 1]
    assert measurements[:cache_miss] in [0, 1]
    assert metadata[:count_mode] == "bounded"

    :telemetry.detach(handler_id)
  end
end
