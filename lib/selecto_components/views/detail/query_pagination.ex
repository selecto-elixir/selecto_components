defmodule SelectoComponents.Views.Detail.QueryPagination do
  @moduledoc false

  alias SelectoComponents.DBSupport
  alias SelectoComponents.Views.Detail.Options

  @initial_cached_pages 3
  @chunk_pages 2
  @keyset_page_threshold 50

  def execute(selecto, params, view_meta, socket) do
    per_page = max(Map.get(view_meta, :per_page, 30), 1)
    requested_page = max(Map.get(view_meta, :page, 0), 0)

    count_mode =
      Options.normalize_count_mode_param(
        Map.get(view_meta, :count_mode, Options.default_count_mode())
      )

    max_rows_limit =
      Options.normalize_max_rows_limit(Map.get(view_meta, :max_rows, Options.default_max_rows()))

    cache_key = detail_cache_signature(params, socket.assigns[:sort_by])

    cache =
      socket.assigns[:detail_page_cache]
      |> init_or_reset_detail_cache(cache_key, per_page, max_rows_limit, count_mode)

    with {:ok, {cache, count_metadata, _count_cache_hit?}} <-
           maybe_fetch_detail_total_rows(cache, selecto, max_rows_limit, count_mode),
         safe_page <- clamp_detail_page(requested_page, cache.total_rows, per_page, count_mode),
         {:ok, {cache, data_metadata, _page_cache_hit?}} <-
           maybe_fetch_detail_pages(
             cache,
             selecto,
             safe_page,
             per_page,
             max_rows_limit,
             count_mode
           ) do
      rows = Map.get(cache.pages, safe_page, [])
      columns = cache.columns || []
      aliases = cache.aliases || []

      metadata = data_metadata || count_metadata || %{sql: nil, params: [], execution_time: 0}

      emit_detail_query_telemetry(%{
        count_metadata: count_metadata,
        page_metadata: data_metadata,
        count_mode: count_mode,
        page: safe_page,
        per_page: per_page,
        total_rows: cache.total_rows,
        max_rows_limit: max_rows_limit
      })

      updated_view_meta =
        view_meta
        |> Map.put(:page, safe_page)
        |> Map.put(:per_page, per_page)
        |> Map.put(:total_rows, cache.total_rows)
        |> Map.put(:max_rows_limit, max_rows_limit)
        |> Map.put(:count_mode, count_mode)

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
         %{
           signature: signature,
           per_page: per_page,
           max_rows_limit: max_rows_limit,
           count_mode: count_mode
         } = cache,
         signature,
         per_page,
         max_rows_limit,
         count_mode
       ) do
    cache
  end

  defp init_or_reset_detail_cache(_, signature, per_page, max_rows_limit, count_mode) do
    %{
      signature: signature,
      per_page: per_page,
      max_rows_limit: max_rows_limit,
      count_mode: count_mode,
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
         max_rows_limit,
         count_mode
       )
       when is_integer(total_rows) and count_mode != "none" do
    {:ok, {cache, %{execution_time: 0, count_strategy: :cached, cache_hit: true}, true}}
  end

  defp maybe_fetch_detail_total_rows(cache, _selecto, _max_rows_limit, "none") do
    {:ok, {cache, %{execution_time: 0, count_strategy: :none, cache_hit: true}, true}}
  end

  defp maybe_fetch_detail_total_rows(cache, selecto, max_rows_limit, count_mode) do
    case execute_detail_count_query(selecto, max_rows_limit, count_mode) do
      {:ok, total_rows, metadata} ->
        updated_cache =
          cache
          |> Map.put(:total_rows, total_rows)
          |> Map.put(:max_rows_limit, max_rows_limit)

        {:ok, {updated_cache, Map.put(metadata, :cache_hit, false), false}}

      {:error, error} ->
        {:error, error}
    end
  end

  defp execute_detail_count_query(selecto, max_rows_limit, count_mode) do
    count_selecto = build_lightweight_count_selecto(selecto)

    {base_sql, base_params} = Selecto.to_sql(count_selecto)

    count_sql = build_count_sql(base_sql, max_rows_limit, count_mode, selecto)

    started_at = System.monotonic_time(:millisecond)

    case execute_raw_query(selecto, count_sql, base_params) do
      {:ok, {[[count_value]], _columns, _aliases}} ->
        execution_time = System.monotonic_time(:millisecond) - started_at

        {:ok, normalize_count(count_value),
         %{
           sql: count_sql,
           params: base_params,
           execution_time: execution_time,
           count_strategy: count_strategy(count_mode),
           count_projection: :lightweight
         }}

      {:ok, {rows, _columns, _aliases}} ->
        {:error,
         Selecto.Error.query_error("Unexpected count query result", count_sql, base_params, %{
           rows: rows
         })}

      {:error, error} ->
        {:error, error}
    end
  end

  defp build_count_sql(base_sql, max_rows_limit, "bounded", selecto)
       when is_integer(max_rows_limit) and max_rows_limit > 0 do
    if DBSupport.bounded_count_uses_top?(selecto) do
      "SELECT count(*) AS total_rows FROM (SELECT TOP (#{max_rows_limit}) * FROM (#{base_sql}) AS bounded_selecto_detail_count) AS selecto_detail_count"
    else
      "SELECT count(*) AS total_rows FROM (#{base_sql} LIMIT #{max_rows_limit}) AS selecto_detail_count"
    end
  end

  defp build_count_sql(base_sql, _max_rows_limit, _count_mode, _selecto) do
    "SELECT count(*) AS total_rows FROM (#{base_sql}) AS selecto_detail_count"
  end

  defp count_strategy("exact"), do: :exact
  defp count_strategy("bounded"), do: :bounded
  defp count_strategy("none"), do: :none
  defp count_strategy(_), do: :bounded

  defp build_lightweight_count_selecto(selecto) do
    primary_key_field = primary_key_field(selecto)

    update_in(selecto.set, fn set ->
      set
      |> Map.delete(:limit)
      |> Map.delete(:offset)
      |> Map.put(:order_by, [])
      |> Map.put(:subselects, [])
      |> Map.put(:denorm_groups, %{})
      |> Map.put(:denormalizing_columns, [])
      |> Map.put(:selected, [{:field, primary_key_field}])
    end)
  end

  defp primary_key_field(selecto) do
    source =
      selecto
      |> Map.get(:domain, %{})
      |> Map.get(:source, %{})

    source
    |> Map.get(:primary_key)
    |> resolve_primary_key(source)
    |> normalize_field_name()
  end

  defp resolve_primary_key([first | _], _source), do: first

  defp resolve_primary_key(nil, source) do
    source
    |> Map.get(:fields, [])
    |> List.first()
    |> Kernel.||(:id)
  end

  defp resolve_primary_key(primary_key, _source), do: primary_key

  defp normalize_field_name(field) when is_atom(field), do: Atom.to_string(field)
  defp normalize_field_name(field) when is_binary(field), do: field
  defp normalize_field_name(field), do: to_string(field)

  defp maybe_fetch_detail_pages(
         cache,
         selecto,
         requested_page,
         per_page,
         max_rows_limit,
         count_mode
       ) do
    {window_start_page, window_end_page} =
      detail_page_window(requested_page, cache.total_rows, per_page, count_mode)

    pages_in_window = Enum.to_list(window_start_page..window_end_page)

    has_full_window? =
      cache.columns != nil and cache.aliases != nil and
        Enum.all?(pages_in_window, &Map.has_key?(cache.pages, &1))

    if has_full_window? do
      metadata = %{execution_time: 0, pagination_mode: :cache, cache_hit: true}
      {:ok, {cache, metadata, true}}
    else
      window_page_count = window_end_page - window_start_page + 1
      row_offset = window_start_page * per_page
      probe_extra = if count_mode == "none", do: 1, else: 0
      base_row_limit = max(window_page_count * per_page, per_page)

      query_row_limit =
        (base_row_limit + probe_extra)
        |> apply_max_rows_limit(row_offset, max_rows_limit)

      if query_row_limit <= 0 do
        updated_cache =
          pages_in_window
          |> Enum.reduce(cache.pages, fn page_number, acc -> Map.put_new(acc, page_number, []) end)
          |> then(&Map.put(cache, :pages, &1))
          |> maybe_update_total_rows_for_none(count_mode, row_offset, max_rows_limit)

        metadata = %{execution_time: 0, pagination_mode: :boundary, cache_hit: true}
        {:ok, {updated_cache, metadata, true}}
      else
        {paged_selecto, pagination_mode, strategy_metadata} =
          build_detail_page_query(
            selecto,
            cache,
            requested_page,
            window_start_page,
            row_offset,
            query_row_limit
          )

        case execute_query_with_metadata(paged_selecto) do
          {:ok, {rows, columns, aliases}, metadata} ->
            cached_rows = normalize_rows_for_cache(rows)

            {rows_for_pages, has_more_window?} =
              maybe_extract_probe_row(cached_rows, base_row_limit, count_mode)

            chunked_pages =
              rows_for_pages
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
              |> maybe_update_estimated_total_rows(
                count_mode,
                window_start_page,
                per_page,
                rows_for_pages,
                has_more_window?,
                max_rows_limit
              )

            enriched_metadata =
              metadata
              |> Map.put(:pagination_mode, pagination_mode)
              |> Map.put(:cache_hit, false)
              |> Map.put(:has_more_window, has_more_window?)
              |> Map.merge(strategy_metadata)

            {:ok, {updated_cache, enriched_metadata, false}}

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

  defp maybe_update_total_rows_for_none(cache, "none", row_offset, max_rows_limit) do
    estimated_total =
      if is_integer(max_rows_limit) and max_rows_limit > 0 do
        max_rows_limit
      else
        row_offset
      end

    Map.put(cache, :total_rows, max(Map.get(cache, :total_rows) || 0, estimated_total))
  end

  defp maybe_update_total_rows_for_none(cache, _count_mode, _row_offset, _max_rows_limit),
    do: cache

  defp maybe_update_estimated_total_rows(
         cache,
         "none",
         window_start_page,
         per_page,
         rows_for_pages,
         has_more_window?,
         max_rows_limit
       ) do
    known_rows = window_start_page * per_page + length(rows_for_pages)

    estimated_total =
      if has_more_window? do
        known_rows + 1
      else
        known_rows
      end

    estimated_total =
      if is_integer(max_rows_limit) and max_rows_limit > 0 do
        min(estimated_total, max_rows_limit)
      else
        estimated_total
      end

    Map.put(cache, :total_rows, max(Map.get(cache, :total_rows) || 0, estimated_total))
  end

  defp maybe_update_estimated_total_rows(
         cache,
         _count_mode,
         _window_start_page,
         _per_page,
         _rows_for_pages,
         _has_more_window?,
         _max_rows_limit
       ),
       do: cache

  defp detail_page_window(requested_page, total_rows, _per_page, "none")
       when not is_integer(total_rows) do
    if requested_page < @initial_cached_pages do
      {0, @initial_cached_pages - 1}
    else
      {requested_page, requested_page + @chunk_pages - 1}
    end
  end

  defp detail_page_window(requested_page, total_rows, per_page, _count_mode) do
    max_page = max_page(total_rows, per_page)

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

  defp clamp_detail_page(requested_page, total_rows, _per_page, "none")
       when not is_integer(total_rows) do
    max(requested_page, 0)
  end

  defp clamp_detail_page(requested_page, total_rows, per_page, _count_mode) do
    requested_page
    |> max(0)
    |> min(max_page(total_rows, per_page))
  end

  defp build_detail_page_query(
         selecto,
         cache,
         requested_page,
         window_start_page,
         row_offset,
         row_limit
       ) do
    case build_keyset_query(selecto, cache, requested_page, window_start_page, row_limit) do
      {:ok, keyset_selecto, strategy_metadata} ->
        {keyset_selecto, :keyset, strategy_metadata}

      :error ->
        paged_selecto =
          selecto
          |> Selecto.limit(row_limit)
          |> Selecto.offset(row_offset)

        {paged_selecto, :offset, %{row_offset: row_offset}}
    end
  end

  defp build_keyset_query(selecto, cache, requested_page, window_start_page, row_limit) do
    with true <- requested_page >= @keyset_page_threshold,
         true <- window_start_page == requested_page,
         true <- requested_page > 0,
         previous_rows when is_list(previous_rows) <- Map.get(cache.pages, requested_page - 1),
         true <- previous_rows != [],
         pk_field <- primary_key_field(selecto),
         {:ok, direction} <- keyset_sort_direction(selecto, pk_field),
         {:ok, cursor_value} <- keyset_cursor_value(previous_rows, cache.columns || [], pk_field),
         keyset_filter <- {pk_field, {keyset_operator(direction), cursor_value}} do
      keyset_selecto =
        selecto
        |> replace_order_by(order_by_for_direction(pk_field, direction))
        |> Selecto.limit(row_limit)
        |> Selecto.filter([keyset_filter])

      {:ok, keyset_selecto,
       %{keyset_field: pk_field, keyset_direction: direction, keyset_cursor: cursor_value}}
    else
      _ -> :error
    end
  end

  defp keyset_sort_direction(selecto, pk_field) do
    order_by =
      selecto
      |> Map.get(:set, %{})
      |> Map.get(:order_by, [])

    case order_by do
      [] ->
        {:ok, :asc}

      [field] ->
        if normalize_field_name(field) == pk_field, do: {:ok, :asc}, else: :error

      [{:asc, field}] ->
        if normalize_field_name(field) == pk_field, do: {:ok, :asc}, else: :error

      [{:desc, field}] ->
        if normalize_field_name(field) == pk_field, do: {:ok, :desc}, else: :error

      _ ->
        :error
    end
  end

  defp keyset_cursor_value(previous_rows, columns, pk_field) do
    last_row = List.last(previous_rows)

    value =
      cond do
        is_map(last_row) ->
          map_get_flexible(last_row, pk_field)

        is_list(last_row) ->
          case Enum.find_index(columns, fn column -> normalize_field_name(column) == pk_field end) do
            nil -> nil
            index -> Enum.at(last_row, index)
          end

        is_tuple(last_row) ->
          keyset_cursor_value([Tuple.to_list(last_row)], columns, pk_field)

        true ->
          nil
      end

    if is_nil(value), do: :error, else: {:ok, value}
  end

  defp keyset_operator(:asc), do: :gt
  defp keyset_operator(:desc), do: :lt

  defp order_by_for_direction(pk_field, :asc), do: [pk_field]
  defp order_by_for_direction(pk_field, :desc), do: [{:desc, pk_field}]

  defp replace_order_by(selecto, order_by) do
    update_in(selecto.set, fn set -> Map.put(set, :order_by, order_by) end)
  end

  defp normalize_rows_for_cache(rows) when is_list(rows) do
    Enum.map(rows, fn
      row when is_tuple(row) -> Tuple.to_list(row)
      row -> row
    end)
  end

  defp normalize_rows_for_cache(rows), do: rows

  defp maybe_extract_probe_row(rows, base_row_limit, "none") when is_list(rows) do
    if length(rows) > base_row_limit do
      {Enum.take(rows, base_row_limit), true}
    else
      {rows, false}
    end
  end

  defp maybe_extract_probe_row(rows, _base_row_limit, _count_mode), do: {rows, false}

  defp map_get_flexible(map, key) when is_map(map) do
    direct_value = Map.get(map, key)

    if is_nil(direct_value) do
      case key do
        value when is_binary(value) ->
          atom_key =
            try do
              String.to_existing_atom(value)
            rescue
              ArgumentError -> nil
            end

          Map.get(map, atom_key) ||
            Enum.find_value(map, fn
              {candidate_key, candidate_value} when is_atom(candidate_key) ->
                if Atom.to_string(candidate_key) == value, do: candidate_value

              {candidate_key, candidate_value} when is_binary(candidate_key) ->
                if candidate_key == value, do: candidate_value

              _ ->
                nil
            end)

        value when is_atom(value) ->
          Map.get(map, Atom.to_string(value))

        _ ->
          nil
      end
    else
      direct_value
    end
  end

  defp map_get_flexible(_map, _key), do: nil

  defp emit_detail_query_telemetry(context) do
    count_metadata = Map.get(context, :count_metadata) || %{}
    page_metadata = Map.get(context, :page_metadata) || %{}
    page_cache_hit? = Map.get(page_metadata, :cache_hit, false)
    count_cache_hit? = Map.get(count_metadata, :cache_hit, false)
    overall_cache_hit? = page_cache_hit? and count_cache_hit?

    :telemetry.execute(
      [:selecto_components, :detail, :query],
      %{
        count_time_ms: extract_execution_time(count_metadata),
        page_fetch_time_ms: extract_execution_time(page_metadata),
        cache_hit: bool_to_int(overall_cache_hit?),
        cache_miss: bool_to_int(not overall_cache_hit?)
      },
      %{
        count_mode: Map.get(context, :count_mode),
        pagination_mode: Map.get(page_metadata, :pagination_mode, :unknown),
        page: Map.get(context, :page),
        per_page: Map.get(context, :per_page),
        total_rows: Map.get(context, :total_rows),
        max_rows_limit: Map.get(context, :max_rows_limit)
      }
    )
  end

  defp extract_execution_time(metadata) when is_map(metadata) do
    case Map.get(metadata, :execution_time, 0) do
      time when is_integer(time) and time >= 0 -> time
      _ -> 0
    end
  end

  defp extract_execution_time(_metadata), do: 0

  defp bool_to_int(true), do: 1
  defp bool_to_int(false), do: 0

  defp execute_raw_query(selecto, query, params) do
    DBSupport.execute_raw_query(selecto, query, params)
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

  defp term_size_bytes(term) do
    :erts_debug.size(term) * :erlang.system_info(:wordsize)
  rescue
    _ -> nil
  end
end
