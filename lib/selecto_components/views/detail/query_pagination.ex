defmodule SelectoComponents.Views.Detail.QueryPagination do
  @moduledoc false

  alias Selecto.Executor
  alias SelectoComponents.Views.Detail.Options

  @initial_cached_pages 3
  @chunk_pages 2

  def execute(selecto, params, view_meta, socket) do
    per_page = max(Map.get(view_meta, :per_page, 30), 1)
    requested_page = max(Map.get(view_meta, :page, 0), 0)

    max_rows_limit =
      Options.normalize_max_rows_limit(Map.get(view_meta, :max_rows, Options.default_max_rows()))

    cache_key = detail_cache_signature(params, socket.assigns[:sort_by])

    cache =
      socket.assigns[:detail_page_cache]
      |> init_or_reset_detail_cache(cache_key, per_page, max_rows_limit)

    with {:ok, {cache, count_metadata}} <-
           maybe_fetch_detail_total_rows(cache, selecto, max_rows_limit),
         safe_page <- clamp_detail_page(requested_page, cache.total_rows, per_page),
         {:ok, {cache, data_metadata}} <-
           maybe_fetch_detail_pages(cache, selecto, safe_page, per_page, max_rows_limit) do
      rows = Map.get(cache.pages, safe_page, [])
      columns = cache.columns || []
      aliases = cache.aliases || []

      metadata = data_metadata || count_metadata || %{sql: nil, params: [], execution_time: 0}

      updated_view_meta =
        view_meta
        |> Map.put(:page, safe_page)
        |> Map.put(:per_page, per_page)
        |> Map.put(:total_rows, cache.total_rows)
        |> Map.put(:max_rows_limit, max_rows_limit)

      {{:ok, {rows, columns, aliases}, metadata}, updated_view_meta, cache}
    else
      {:error, error} ->
        {{:error, error}, view_meta, cache}
    end
  end

  def cache_debug_info(nil), do: %{bytes: nil, pages: nil, rows: nil}

  def cache_debug_info(cache) when is_map(cache) do
    pages = Map.get(cache, :pages, %{})
    page_count = map_size(pages)

    row_count =
      pages
      |> Map.values()
      |> Enum.reduce(0, fn
        page_rows, acc when is_list(page_rows) -> acc + length(page_rows)
        _page_rows, acc -> acc
      end)

    %{
      bytes: term_size_bytes(cache),
      pages: page_count,
      rows: row_count
    }
  end

  def cache_debug_info(_cache), do: %{bytes: nil, pages: nil, rows: nil}

  defp init_or_reset_detail_cache(
         %{signature: signature, per_page: per_page, max_rows_limit: max_rows_limit} = cache,
         signature,
         per_page,
         max_rows_limit
       ) do
    cache
  end

  defp init_or_reset_detail_cache(_, signature, per_page, max_rows_limit) do
    %{
      signature: signature,
      per_page: per_page,
      max_rows_limit: max_rows_limit,
      total_rows: nil,
      columns: nil,
      aliases: nil,
      pages: %{}
    }
  end

  defp detail_cache_signature(params, sort_by) do
    %{
      params: Map.drop(params, ["detail_page"]),
      sort_by: sort_by || []
    }
  end

  defp maybe_fetch_detail_total_rows(
         %{total_rows: total_rows, max_rows_limit: max_rows_limit} = cache,
         _selecto,
         max_rows_limit
       )
       when is_integer(total_rows) do
    {:ok, {cache, nil}}
  end

  defp maybe_fetch_detail_total_rows(cache, selecto, max_rows_limit) do
    case execute_detail_count_query(selecto, max_rows_limit) do
      {:ok, total_rows, metadata} ->
        updated_cache =
          cache
          |> Map.put(:total_rows, total_rows)
          |> Map.put(:max_rows_limit, max_rows_limit)

        {:ok, {updated_cache, metadata}}

      {:error, error} ->
        {:error, error}
    end
  end

  defp execute_detail_count_query(selecto, max_rows_limit) do
    selecto_without_paging =
      update_in(selecto.set, fn set ->
        set
        |> Map.delete(:limit)
        |> Map.delete(:offset)
        |> Map.put(:order_by, [])
      end)

    {base_sql, base_params} = Selecto.to_sql(selecto_without_paging)

    count_sql =
      if is_integer(max_rows_limit) and max_rows_limit > 0 do
        "SELECT count(*) AS total_rows FROM (#{base_sql} LIMIT #{max_rows_limit}) AS selecto_detail_count"
      else
        "SELECT count(*) AS total_rows FROM (#{base_sql}) AS selecto_detail_count"
      end

    started_at = System.monotonic_time(:millisecond)

    case execute_raw_query(selecto, count_sql, base_params) do
      {:ok, {[[count_value]], _columns, _aliases}} ->
        execution_time = System.monotonic_time(:millisecond) - started_at

        {:ok, normalize_count(count_value),
         %{sql: count_sql, params: base_params, execution_time: execution_time}}

      {:ok, {rows, _columns, _aliases}} ->
        {:error,
         Selecto.Error.query_error("Unexpected count query result", count_sql, base_params, %{
           rows: rows
         })}

      {:error, error} ->
        {:error, error}
    end
  end

  defp maybe_fetch_detail_pages(cache, selecto, requested_page, per_page, max_rows_limit) do
    max_page = max_page(cache.total_rows, per_page)
    {window_start_page, window_end_page} = detail_page_window(requested_page, max_page)

    pages_in_window = Enum.to_list(window_start_page..window_end_page)

    has_full_window? =
      cache.columns != nil and cache.aliases != nil and
        Enum.all?(pages_in_window, &Map.has_key?(cache.pages, &1))

    if has_full_window? do
      {:ok, {cache, nil}}
    else
      window_page_count = window_end_page - window_start_page + 1
      row_offset = window_start_page * per_page

      row_limit =
        max(window_page_count * per_page, per_page)
        |> apply_max_rows_limit(row_offset, max_rows_limit)

      if row_limit <= 0 do
        updated_cache =
          pages_in_window
          |> Enum.reduce(cache.pages, fn page_number, acc -> Map.put_new(acc, page_number, []) end)
          |> then(&Map.put(cache, :pages, &1))

        {:ok, {updated_cache, nil}}
      else
        paged_selecto =
          selecto
          |> Selecto.limit(row_limit)
          |> Selecto.offset(row_offset)

        case execute_query_with_metadata(paged_selecto) do
          {:ok, {rows, columns, aliases}, metadata} ->
            normalized_rows = normalize_detail_rows(rows, columns)

            chunked_pages =
              normalized_rows
              |> Enum.chunk_every(per_page)
              |> Enum.with_index(window_start_page)
              |> Enum.into(%{}, fn {chunk, page_number} ->
                {page_number, chunk}
              end)

            merged_pages =
              pages_in_window
              |> Enum.reduce(Map.merge(cache.pages, chunked_pages), fn page_number, acc ->
                Map.put_new(acc, page_number, [])
              end)

            updated_cache =
              cache
              |> Map.put(:pages, merged_pages)
              |> Map.put(:columns, columns)
              |> Map.put(:aliases, aliases)

            {:ok, {updated_cache, metadata}}

          {:error, error} ->
            {:error, error}
        end
      end
    end
  end

  defp apply_max_rows_limit(row_limit, _row_offset, nil), do: row_limit

  defp apply_max_rows_limit(row_limit, row_offset, max_rows_limit)
       when is_integer(max_rows_limit) and max_rows_limit > 0 do
    remaining_rows = max(max_rows_limit - row_offset, 0)
    min(row_limit, remaining_rows)
  end

  defp apply_max_rows_limit(row_limit, _row_offset, _max_rows_limit), do: row_limit

  defp detail_page_window(requested_page, max_page) do
    {window_start, window_end} =
      if requested_page < @initial_cached_pages do
        {0, @initial_cached_pages - 1}
      else
        {requested_page, requested_page + @chunk_pages - 1}
      end

    clamped_end = min(window_end, max_page)
    {window_start, max(window_start, clamped_end)}
  end

  defp max_page(total_rows, per_page) when is_integer(total_rows) and total_rows > 0,
    do: div(total_rows - 1, per_page)

  defp max_page(_total_rows, _per_page), do: 0

  defp clamp_detail_page(requested_page, total_rows, per_page) do
    requested_page
    |> max(0)
    |> min(max_page(total_rows, per_page))
  end

  defp execute_raw_query(selecto, query, params) do
    cond do
      selecto.adapter && selecto.adapter != Selecto.DB.PostgreSQL ->
        Executor.execute_with_adapter(selecto.adapter, selecto.connection, query, params, [])

      ecto_repo?(selecto.postgrex_opts) ->
        Executor.execute_with_ecto_repo(selecto.postgrex_opts, query, params, [])

      true ->
        Executor.execute_with_postgrex(selecto.postgrex_opts, query, params, [])
    end
  end

  defp execute_query_with_metadata(selecto) do
    try do
      Selecto.execute_with_metadata(selecto)
    rescue
      error ->
        {:error, Selecto.Error.from_reason(error)}
    catch
      :exit, reason ->
        {:error,
         Selecto.Error.connection_error("Database connection failed", %{exit_reason: reason})}
    end
  end

  defp ecto_repo?(repo) when is_atom(repo) do
    Code.ensure_loaded?(repo) and function_exported?(repo, :__adapter__, 0)
  end

  defp ecto_repo?(_repo), do: false

  defp normalize_count(value) when is_integer(value), do: value
  defp normalize_count(value) when is_float(value), do: trunc(value)

  defp normalize_count(value) when is_binary(value) do
    case Integer.parse(value) do
      {count, _} -> count
      :error -> 0
    end
  end

  defp normalize_count(value) do
    value
    |> to_string()
    |> normalize_count()
  rescue
    _ -> 0
  end

  defp normalize_detail_rows(rows, columns)
       when is_list(rows) and rows != [] and (is_list(hd(rows)) or is_tuple(hd(rows))) do
    Enum.map(rows, fn row ->
      row_values = if is_tuple(row), do: Tuple.to_list(row), else: row
      Enum.zip(columns, row_values) |> Map.new()
    end)
  end

  defp normalize_detail_rows(rows, _columns), do: rows

  defp term_size_bytes(term) do
    :erts_debug.size(term) * :erlang.system_info(:wordsize)
  rescue
    _ -> nil
  end
end
