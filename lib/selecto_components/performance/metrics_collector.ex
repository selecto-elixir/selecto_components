defmodule SelectoComponents.Performance.MetricsCollector do
  @moduledoc """
  Collects and stores performance metrics for Selecto queries.
  """

  use GenServer

  @queries_table :selecto_components_perf_queries
  @errors_table :selecto_components_perf_errors
  @cleanup_interval_ms 60 * 60 * 1000
  @default_retention_seconds 24 * 60 * 60
  @default_max_queries 10_000
  @default_max_errors 1_000

  @counter_cache_hits 1
  @counter_cache_misses 2

  # Client API

  @doc """
  Starts the metrics collector.
  """
  def start_link(opts \\ []) do
    case GenServer.start_link(__MODULE__, opts, name: __MODULE__) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      other -> other
    end
  end

  @doc """
  Records a query execution.
  """
  def record_query(query, execution_time, opts \\ %{}) do
    GenServer.cast(__MODULE__, {:record_query, query, execution_time, opts})
  end

  @doc """
  Records an error.
  """
  def record_error(query, error) do
    GenServer.cast(__MODULE__, {:record_error, query, error})
  end

  @doc """
  Records cache hit/miss.
  """
  def record_cache(hit?) do
    GenServer.cast(__MODULE__, {:record_cache, hit?})
  end

  @doc """
  Gets current metrics.
  """
  def get_metrics(time_range \\ "1h") do
    GenServer.call(__MODULE__, {:get_metrics, time_range})
  end

  @doc """
  Gets slow queries.
  """
  def get_slow_queries(threshold \\ 500, limit \\ 10) do
    GenServer.call(__MODULE__, {:get_slow_queries, threshold, limit})
  end

  @doc """
  Gets query timeline data.
  """
  def get_timeline(time_range \\ "1h") do
    GenServer.call(__MODULE__, {:get_timeline, time_range})
  end

  @doc """
  Clears all metrics.
  """
  def clear_metrics do
    GenServer.cast(__MODULE__, :clear_metrics)
  end

  # Server Callbacks

  def init(opts) do
    schedule_cleanup()

    state = %{
      queries_table: ensure_table(@queries_table),
      errors_table: ensure_table(@errors_table),
      cache_counter: :counters.new(2, [:write_concurrency]),
      retention_period: Keyword.get(opts, :retention_period, @default_retention_seconds),
      max_queries: Keyword.get(opts, :max_queries, @default_max_queries),
      max_errors: Keyword.get(opts, :max_errors, @default_max_errors)
    }

    {:ok, state}
  end

  def handle_cast({:record_query, query, execution_time, opts}, state) do
    query_record = %{
      id: Ecto.UUID.generate(),
      query: query,
      execution_time: execution_time,
      timestamp: DateTime.utc_now(),
      row_count: Map.get(opts, :row_count, 0),
      table_scans: Map.get(opts, :table_scans, 0),
      index_scans: Map.get(opts, :index_scans, 0),
      memory_usage: Map.get(opts, :memory_usage, 0)
    }

    insert_record(state.queries_table, query_record)
    prune_table_to_limit(state.queries_table, state.max_queries)

    {:noreply, state}
  end

  def handle_cast({:record_error, query, error}, state) do
    error_record = %{
      id: Ecto.UUID.generate(),
      query: query,
      error: error,
      timestamp: DateTime.utc_now()
    }

    insert_record(state.errors_table, error_record)
    prune_table_to_limit(state.errors_table, state.max_errors)

    {:noreply, state}
  end

  def handle_cast({:record_cache, hit?}, state) do
    if hit? do
      :counters.add(state.cache_counter, @counter_cache_hits, 1)
    else
      :counters.add(state.cache_counter, @counter_cache_misses, 1)
    end

    {:noreply, state}
  end

  def handle_cast(:clear_metrics, state) do
    :ets.delete_all_objects(state.queries_table)
    :ets.delete_all_objects(state.errors_table)

    :counters.put(state.cache_counter, @counter_cache_hits, 0)
    :counters.put(state.cache_counter, @counter_cache_misses, 0)

    {:noreply, state}
  end

  def handle_call({:get_metrics, time_range}, _from, state) do
    cutoff = get_cutoff_timestamp(time_range)
    recent_queries = records_since(state.queries_table, cutoff)
    recent_errors = records_since(state.errors_table, cutoff)

    metrics = %{
      total_queries: length(recent_queries),
      avg_response_time: calculate_avg_response_time(recent_queries),
      queries_per_minute: calculate_qpm(recent_queries),
      error_count: length(recent_errors),
      error_rate: calculate_error_rate(recent_queries, recent_errors),
      cache_hit_rate: calculate_cache_hit_rate(state),
      slow_query_count: count_slow_queries(recent_queries),
      total_memory: calculate_total_memory(recent_queries),
      percentiles: calculate_percentiles(recent_queries)
    }

    {:reply, metrics, state}
  end

  def handle_call({:get_slow_queries, threshold, limit}, _from, state) do
    slow_queries =
      all_records(state.queries_table)
      |> Enum.filter(&(&1.execution_time >= threshold))
      |> Enum.sort_by(& &1.execution_time, :desc)
      |> Enum.take(limit)

    {:reply, slow_queries, state}
  end

  def handle_call({:get_timeline, time_range}, _from, state) do
    cutoff = get_cutoff_timestamp(time_range)
    recent_queries = records_since(state.queries_table, cutoff)

    timeline = build_timeline(recent_queries, time_range)

    {:reply, timeline, state}
  end

  def handle_info(:cleanup, state) do
    cutoff = cutoff_for_retention(state.retention_period)

    delete_older_than(state.queries_table, cutoff)
    delete_older_than(state.errors_table, cutoff)

    schedule_cleanup()

    {:noreply, state}
  end

  # Helper Functions

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval_ms)
  end

  defp ensure_table(name) do
    case :ets.whereis(name) do
      :undefined ->
        try do
          :ets.new(name, [
            :ordered_set,
            :public,
            :named_table,
            read_concurrency: true,
            write_concurrency: true
          ])
        rescue
          ArgumentError -> :ets.whereis(name)
        end

      table ->
        table
    end
  end

  defp insert_record(table, %{timestamp: timestamp} = record) do
    key =
      {DateTime.to_unix(timestamp, :millisecond), System.unique_integer([:positive, :monotonic])}

    :ets.insert(table, {key, record})
  end

  defp prune_table_to_limit(table, max) do
    size = :ets.info(table, :size)
    overflow = max(size - max, 0)

    if overflow > 0 do
      Enum.each(1..overflow, fn _ ->
        case :ets.first(table) do
          :"$end_of_table" -> :ok
          key -> :ets.delete(table, key)
        end
      end)
    end
  end

  defp all_records(table) do
    :ets.foldl(fn {_key, record}, acc -> [record | acc] end, [], table)
  end

  defp records_since(table, cutoff_ms) do
    :ets.select(table, [
      {{{:"$1", :_}, :"$2"}, [{:>=, :"$1", cutoff_ms}], [:"$2"]}
    ])
  end

  defp delete_older_than(table, cutoff_ms) do
    :ets.select_delete(table, [
      {{{:"$1", :_}, :_}, [{:<, :"$1", cutoff_ms}], [true]}
    ])
  end

  defp get_cutoff_timestamp(time_range) do
    seconds =
      case time_range do
        "1h" -> 3600
        "6h" -> 6 * 3600
        "24h" -> 24 * 3600
        "7d" -> 7 * 24 * 3600
        _ -> 3600
      end

    System.system_time(:millisecond) - seconds * 1000
  end

  defp cutoff_for_retention(retention_seconds) do
    System.system_time(:millisecond) - retention_seconds * 1000
  end

  defp calculate_avg_response_time([]), do: 0

  defp calculate_avg_response_time(queries) do
    total = Enum.sum(Enum.map(queries, & &1.execution_time))
    round(total / length(queries))
  end

  defp calculate_qpm([]), do: 0

  defp calculate_qpm(queries) do
    sorted = Enum.sort_by(queries, &DateTime.to_unix(&1.timestamp, :millisecond))

    case sorted do
      [] ->
        0

      [_single] ->
        length(sorted)

      _ ->
        first = hd(sorted).timestamp
        last = List.last(sorted).timestamp
        minutes = DateTime.diff(last, first) / 60

        if minutes > 0 do
          round(length(sorted) / minutes)
        else
          length(sorted)
        end
    end
  end

  defp calculate_error_rate(queries, errors) do
    total = length(queries) + length(errors)

    if total > 0 do
      Float.round(length(errors) / total * 100, 1)
    else
      0
    end
  end

  defp calculate_cache_hit_rate(state) do
    hits = :counters.get(state.cache_counter, @counter_cache_hits)
    misses = :counters.get(state.cache_counter, @counter_cache_misses)
    total = hits + misses

    if total > 0 do
      round(hits / total * 100)
    else
      0
    end
  end

  defp count_slow_queries(queries, threshold \\ 500) do
    Enum.count(queries, &(&1.execution_time >= threshold))
  end

  defp calculate_total_memory(queries) do
    Enum.sum(Enum.map(queries, & &1.memory_usage))
  end

  defp calculate_percentiles(queries) do
    if queries == [] do
      %{p50: 0, p95: 0, p99: 0}
    else
      times = Enum.map(queries, & &1.execution_time) |> Enum.sort()
      count = length(times)

      %{
        p50: Enum.at(times, round(count * 0.5)) || 0,
        p95: Enum.at(times, round(count * 0.95)) || 0,
        p99: Enum.at(times, round(count * 0.99)) || 0
      }
    end
  end

  defp build_timeline(queries, time_range) do
    bucket_size = get_bucket_size(time_range)

    queries
    |> Enum.group_by(&time_bucket(&1.timestamp, bucket_size))
    |> Enum.map(fn {bucket, bucket_queries} ->
      %{
        timestamp: bucket,
        count: length(bucket_queries),
        avg_time: calculate_avg_response_time(bucket_queries),
        # Would need to track errors with timestamps
        errors: 0
      }
    end)
    |> Enum.sort_by(& &1.timestamp)
  end

  defp get_bucket_size(time_range) do
    case time_range do
      # 1 minute buckets
      "1h" -> 60
      # 5 minute buckets
      "6h" -> 300
      # 15 minute buckets
      "24h" -> 900
      # 1 hour buckets
      "7d" -> 3600
      _ -> 60
    end
  end

  defp time_bucket(datetime, bucket_size) do
    seconds = DateTime.to_unix(datetime)
    bucket = div(seconds, bucket_size) * bucket_size
    DateTime.from_unix!(bucket)
  end
end

defmodule SelectoComponents.Performance.MetricsHook do
  @moduledoc """
  Hook for automatically collecting metrics from Selecto queries.
  """

  alias SelectoComponents.Performance.MetricsCollector

  @doc """
  Wraps a Selecto query execution to collect metrics.
  """
  def track_query(fun) when is_function(fun, 0) do
    start_time = System.monotonic_time(:millisecond)

    try do
      result = fun.()

      execution_time = System.monotonic_time(:millisecond) - start_time

      # Extract query info from result if available
      opts = extract_query_info(result)

      MetricsCollector.record_query(
        inspect(fun),
        execution_time,
        opts
      )

      result
    rescue
      error ->
        MetricsCollector.record_error(inspect(fun), inspect(error))
        reraise error, __STACKTRACE__
    end
  end

  defp extract_query_info({:ok, %{rows: rows}}) do
    %{row_count: length(rows)}
  end

  defp extract_query_info(_), do: %{}
end
