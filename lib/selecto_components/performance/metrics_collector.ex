defmodule SelectoComponents.Performance.MetricsCollector do
  @moduledoc """
  Collects and stores performance metrics for Selecto queries.
  """

  use GenServer
  require Logger

  # Client API

  @doc """
  Starts the metrics collector.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
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
    # Schedule periodic cleanup
    schedule_cleanup()
    
    state = %{
      queries: [],
      errors: [],
      cache_hits: 0,
      cache_misses: 0,
      retention_period: Keyword.get(opts, :retention_period, 24 * 60 * 60), # 24 hours
      max_queries: Keyword.get(opts, :max_queries, 10000)
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
    
    queries = [query_record | state.queries] |> limit_queries(state.max_queries)
    
    {:noreply, %{state | queries: queries}}
  end

  def handle_cast({:record_error, query, error}, state) do
    error_record = %{
      id: Ecto.UUID.generate(),
      query: query,
      error: error,
      timestamp: DateTime.utc_now()
    }
    
    errors = [error_record | state.errors] |> Enum.take(1000)
    
    {:noreply, %{state | errors: errors}}
  end

  def handle_cast({:record_cache, hit?}, state) do
    state = if hit? do
      %{state | cache_hits: state.cache_hits + 1}
    else
      %{state | cache_misses: state.cache_misses + 1}
    end
    
    {:noreply, state}
  end

  def handle_cast(:clear_metrics, state) do
    {:noreply, %{state | 
      queries: [],
      errors: [],
      cache_hits: 0,
      cache_misses: 0
    }}
  end

  def handle_call({:get_metrics, time_range}, _from, state) do
    cutoff = get_cutoff_time(time_range)
    recent_queries = filter_by_time(state.queries, cutoff)
    recent_errors = filter_by_time(state.errors, cutoff)
    
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
      state.queries
      |> Enum.filter(&(&1.execution_time >= threshold))
      |> Enum.sort_by(&(&1.execution_time), :desc)
      |> Enum.take(limit)
    
    {:reply, slow_queries, state}
  end

  def handle_call({:get_timeline, time_range}, _from, state) do
    cutoff = get_cutoff_time(time_range)
    recent_queries = filter_by_time(state.queries, cutoff)
    
    timeline = build_timeline(recent_queries, time_range)
    
    {:reply, timeline, state}
  end

  def handle_info(:cleanup, state) do
    cutoff = DateTime.add(DateTime.utc_now(), -state.retention_period, :second)
    
    queries = filter_by_time(state.queries, cutoff)
    errors = filter_by_time(state.errors, cutoff)
    
    # Schedule next cleanup
    schedule_cleanup()
    
    {:noreply, %{state | queries: queries, errors: errors}}
  end

  # Helper Functions

  defp schedule_cleanup do
    # Cleanup every hour
    Process.send_after(self(), :cleanup, 60 * 60 * 1000)
  end

  defp limit_queries(queries, max) when length(queries) > max do
    Enum.take(queries, max)
  end
  defp limit_queries(queries, _max), do: queries

  defp get_cutoff_time(time_range) do
    seconds = case time_range do
      "1h" -> 3600
      "6h" -> 6 * 3600
      "24h" -> 24 * 3600
      "7d" -> 7 * 24 * 3600
      _ -> 3600
    end
    
    DateTime.add(DateTime.utc_now(), -seconds, :second)
  end

  defp filter_by_time(records, cutoff) do
    Enum.filter(records, &(DateTime.compare(&1.timestamp, cutoff) == :gt))
  end

  defp calculate_avg_response_time([]), do: 0
  defp calculate_avg_response_time(queries) do
    total = Enum.sum(Enum.map(queries, & &1.execution_time))
    round(total / length(queries))
  end

  defp calculate_qpm([]), do: 0
  defp calculate_qpm(queries) do
    if queries == [] do
      0
    else
      first = List.last(queries).timestamp
      last = List.first(queries).timestamp
      minutes = DateTime.diff(last, first) / 60
      
      if minutes > 0 do
        round(length(queries) / minutes)
      else
        length(queries)
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
    total = state.cache_hits + state.cache_misses
    if total > 0 do
      round(state.cache_hits / total * 100)
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
    # Group queries by time bucket
    bucket_size = get_bucket_size(time_range)
    
    queries
    |> Enum.group_by(&time_bucket(&1.timestamp, bucket_size))
    |> Enum.map(fn {bucket, bucket_queries} ->
      %{
        timestamp: bucket,
        count: length(bucket_queries),
        avg_time: calculate_avg_response_time(bucket_queries),
        errors: 0  # Would need to track errors with timestamps
      }
    end)
    |> Enum.sort_by(& &1.timestamp)
  end

  defp get_bucket_size(time_range) do
    case time_range do
      "1h" -> 60      # 1 minute buckets
      "6h" -> 300     # 5 minute buckets
      "24h" -> 900    # 15 minute buckets
      "7d" -> 3600    # 1 hour buckets
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