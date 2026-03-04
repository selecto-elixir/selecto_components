defmodule SelectoComponents.Performance.MetricsCollectorTest do
  use ExUnit.Case, async: false

  alias SelectoComponents.Performance.MetricsCollector

  @queries_table :selecto_components_perf_queries
  @errors_table :selecto_components_perf_errors

  setup do
    case Process.whereis(MetricsCollector) do
      nil -> :ok
      pid -> GenServer.stop(pid)
    end

    assert {:ok, _pid} =
             MetricsCollector.start_link(
               max_queries: 3,
               max_errors: 2,
               retention_period: 1
             )

    MetricsCollector.clear_metrics()
    _ = MetricsCollector.get_metrics("1h")
    :ok
  end

  test "start_link is idempotent" do
    pid = Process.whereis(MetricsCollector)
    assert is_pid(pid)

    assert {:ok, same_pid} = MetricsCollector.start_link()
    assert same_pid == pid
  end

  test "records query metrics and aggregates totals" do
    MetricsCollector.record_query("select 1", 120, %{row_count: 3, memory_usage: 10})
    MetricsCollector.record_query("select 2", 180, %{row_count: 2, memory_usage: 20})

    metrics = MetricsCollector.get_metrics("1h")

    assert metrics.total_queries == 2
    assert metrics.avg_response_time == 150
    assert metrics.total_memory == 30
    assert metrics.slow_query_count == 0
    assert metrics.percentiles.p50 >= 120
  end

  test "enforces max query retention and returns sorted slow queries" do
    MetricsCollector.record_query("q1", 100)
    MetricsCollector.record_query("q2", 600)
    MetricsCollector.record_query("q3", 700)
    MetricsCollector.record_query("q4", 800)
    MetricsCollector.record_query("q5", 900)

    metrics = MetricsCollector.get_metrics("1h")
    assert metrics.total_queries == 3

    slow = MetricsCollector.get_slow_queries(500, 10)
    assert Enum.map(slow, & &1.execution_time) == [900, 800, 700]
  end

  test "tracks cache hit rate and clear resets counters" do
    MetricsCollector.record_cache(true)
    MetricsCollector.record_cache(false)
    MetricsCollector.record_cache(false)

    metrics = MetricsCollector.get_metrics("1h")
    assert metrics.cache_hit_rate == 33

    MetricsCollector.clear_metrics()
    reset = MetricsCollector.get_metrics("1h")

    assert reset.total_queries == 0
    assert reset.error_count == 0
    assert reset.cache_hit_rate == 0
  end

  test "enforces max error retention" do
    MetricsCollector.record_error("q1", "err1")
    MetricsCollector.record_error("q2", "err2")
    MetricsCollector.record_error("q3", "err3")

    metrics = MetricsCollector.get_metrics("1h")
    assert metrics.error_count == 2
  end

  test "cleanup drops stale records from ETS" do
    old_ms = System.system_time(:millisecond) - 5_000
    old_dt = DateTime.from_unix!(div(old_ms, 1000))

    stale_query = %{
      id: "old-query",
      query: "old",
      execution_time: 50,
      timestamp: old_dt,
      row_count: 0,
      table_scans: 0,
      index_scans: 0,
      memory_usage: 0
    }

    stale_error = %{
      id: "old-error",
      query: "old",
      error: "old",
      timestamp: old_dt
    }

    :ets.insert(@queries_table, {{old_ms, "old-query"}, stale_query})
    :ets.insert(@errors_table, {{old_ms, "old-error"}, stale_error})

    MetricsCollector.record_query("fresh", 75)
    MetricsCollector.record_error("fresh", "boom")

    send(Process.whereis(MetricsCollector), :cleanup)

    metrics = MetricsCollector.get_metrics("1h")

    assert metrics.total_queries == 1
    assert metrics.error_count == 1
  end

  test "builds timeline buckets" do
    MetricsCollector.record_query("q1", 80)
    MetricsCollector.record_query("q2", 120)

    timeline = MetricsCollector.get_timeline("1h")

    assert is_list(timeline)
    assert timeline != []
    assert Enum.all?(timeline, &Map.has_key?(&1, :timestamp))
    assert Enum.all?(timeline, &Map.has_key?(&1, :count))
    assert Enum.all?(timeline, &Map.has_key?(&1, :avg_time))
  end
end
