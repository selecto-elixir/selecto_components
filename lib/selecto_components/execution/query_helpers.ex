defmodule SelectoComponents.Execution.QueryHelpers do
  @moduledoc """
  Query execution helpers shared by the execution runtime.
  """

  require Logger

  alias SelectoComponents.DBSupport
  alias SelectoComponents.QueryResults
  alias SelectoComponents.Views.Aggregate.Options, as: AggregateOptions
  alias SelectoComponents.Views.Detail.Options, as: DetailOptions
  alias SelectoComponents.Views.Detail.QueryPagination

  def execute_query_with_pagination(selecto, params, view_meta, socket) do
    cond do
      DetailOptions.detail_view_mode?(params) ->
        QueryPagination.execute(selecto, params, view_meta, socket)

      AggregateOptions.aggregate_view_mode?(params) ->
        execute_aggregate_query_with_pagination(selecto, params, view_meta, socket)

      true ->
        {execute_query_with_metadata(selecto), view_meta, nil}
    end
  end

  def build_query_cache_debug_info(detail_cache, params, rows, columns, aliases) do
    cond do
      is_map(detail_cache) ->
        QueryPagination.cache_debug_info(detail_cache)

      AggregateOptions.aggregate_view_mode?(params) ->
        %{bytes: term_size_bytes({rows, columns, aliases}), pages: 1, rows: length(rows)}

      true ->
        %{bytes: nil, pages: nil, rows: nil}
    end
  end

  def maybe_cap_aggregate_rows(rows, view_meta, params) when is_list(rows) do
    if AggregateOptions.aggregate_view_mode?(params) do
      total_rows = length(rows)

      case AggregateOptions.max_client_rows() do
        :infinity ->
          {rows,
           Map.merge(view_meta, %{
             aggregate_rows_capped?: false,
             aggregate_total_rows_before_cap: total_rows,
             aggregate_max_client_rows: :infinity
           })}

        max_client_rows when is_integer(max_client_rows) and total_rows > max_client_rows ->
          {Enum.take(rows, max_client_rows),
           Map.merge(view_meta, %{
             aggregate_rows_capped?: true,
             aggregate_total_rows_before_cap: total_rows,
             aggregate_max_client_rows: max_client_rows
           })}

        max_client_rows when is_integer(max_client_rows) ->
          {rows,
           Map.merge(view_meta, %{
             aggregate_rows_capped?: false,
             aggregate_total_rows_before_cap: total_rows,
             aggregate_max_client_rows: max_client_rows
           })}

        _other ->
          {rows, view_meta}
      end
    else
      {rows, view_meta}
    end
  end

  def maybe_cap_aggregate_rows(rows, view_meta, _params), do: {rows, view_meta}

  def normalize_rows_for_view(rows, _columns, "detail")
      when is_list(rows) and rows != [] and (is_list(hd(rows)) or is_tuple(hd(rows))) do
    rows
    |> Enum.map(fn row -> if is_tuple(row), do: Tuple.to_list(row), else: row end)
    |> QueryResults.normalize_rows()
  end

  def normalize_rows_for_view(rows, _columns, _view_mode), do: QueryResults.normalize_rows(rows)

  defp execute_aggregate_query_with_pagination(selecto, params, view_meta, socket) do
    per_page_setting =
      AggregateOptions.normalize_per_page_param(
        Map.get(view_meta, :per_page, AggregateOptions.default_per_page())
      )

    requested_page = normalize_page_param(get_map_value(params, :aggregate_page, 0))
    base_selecto = clear_limit_offset(selecto)

    cache_signature = aggregate_cache_signature(params, socket.assigns[:sort_by])

    aggregate_cache =
      init_or_reset_aggregate_cache(
        socket.assigns[:aggregate_page_cache],
        cache_signature,
        per_page_setting
      )

    if per_page_setting == "all" or aggregate_grid_enabled?(params) do
      updated_view_meta =
        view_meta
        |> Map.put(:aggregate_server_paged?, false)
        |> Map.put(:aggregate_page, 0)

      {execute_query_with_metadata(base_selecto), updated_view_meta, nil}
    else
      per_page = AggregateOptions.per_page_to_int(per_page_setting, 0)

      case maybe_fetch_aggregate_total_rows(base_selecto, aggregate_cache) do
        {:ok, {aggregate_cache, total_rows, count_metadata}} ->
          safe_page = clamp_aggregate_page(requested_page, total_rows, per_page)

          case maybe_fetch_aggregate_page(base_selecto, aggregate_cache, safe_page, per_page) do
            {:ok, {aggregate_cache, rows, columns, aliases, metadata}} ->
              merged_metadata =
                Map.merge(metadata || %{}, %{
                  aggregate_count_sql: Map.get(count_metadata, :sql),
                  aggregate_count_params: Map.get(count_metadata, :params, []),
                  aggregate_count_execution_time: Map.get(count_metadata, :execution_time)
                })

              updated_view_meta =
                view_meta
                |> Map.put(:aggregate_server_paged?, true)
                |> Map.put(:aggregate_page, safe_page)
                |> Map.put(:aggregate_total_rows, total_rows)

              {{:ok, {rows, columns, aliases}, merged_metadata}, updated_view_meta,
               aggregate_cache}

            {:error, error} ->
              {{:error, error}, view_meta, aggregate_cache}
          end

        {:error, error} ->
          {{:error, error}, view_meta, aggregate_cache}
      end
    end
  end

  defp aggregate_grid_enabled?(params) do
    get_map_value(params, :aggregate_grid, false) in [true, "true", "on", "1", 1]
  end

  defp init_or_reset_aggregate_cache(
         %{signature: signature, per_page_setting: per_page_setting} = cache,
         signature,
         per_page_setting
       ),
       do: cache

  defp init_or_reset_aggregate_cache(_cache, signature, per_page_setting) do
    %{signature: signature, per_page_setting: per_page_setting, total_rows: nil, pages: %{}}
  end

  defp aggregate_cache_signature(params, sort_by) do
    %{params: Map.drop(params, ["aggregate_page", "detail_page"]), sort_by: sort_by || []}
  end

  defp maybe_fetch_aggregate_total_rows(_selecto, %{total_rows: total_rows} = cache)
       when is_integer(total_rows) and total_rows >= 0 do
    Logger.debug(fn ->
      "[selecto_components] aggregate count cache hit total_rows=#{total_rows} pid=#{inspect(self())}"
    end)

    {:ok, {cache, total_rows, %{sql: nil, params: [], execution_time: 0, cache_hit: true}}}
  end

  defp maybe_fetch_aggregate_total_rows(selecto, cache) do
    Logger.debug(fn ->
      "[selecto_components] aggregate count query start pid=#{inspect(self())}"
    end)

    case execute_aggregate_total_rows(selecto) do
      {:ok, total_rows, count_metadata} ->
        Logger.debug(fn ->
          "[selecto_components] aggregate count query success total_rows=#{total_rows} pid=#{inspect(self())}"
        end)

        {:ok, {Map.put(cache, :total_rows, total_rows), total_rows, count_metadata}}

      {:error, error} ->
        {:error, error}
    end
  end

  defp maybe_fetch_aggregate_page(selecto, cache, page, per_page) do
    case get_in(cache, [:pages, page]) do
      %{rows: rows, columns: columns, aliases: aliases} ->
        Logger.debug(fn ->
          "[selecto_components] aggregate page cache hit page=#{page} rows=#{length(rows)} pid=#{inspect(self())}"
        end)

        {:ok,
         {cache, rows, columns, aliases,
          %{sql: nil, params: [], execution_time: 0, cache_hit: true, pagination_mode: :cache}}}

      _ ->
        Logger.debug(fn ->
          "[selecto_components] aggregate page query start page=#{page} per_page=#{per_page} pid=#{inspect(self())}"
        end)

        row_offset = page * per_page

        paged_selecto =
          selecto
          |> Selecto.limit(per_page)
          |> Selecto.offset(row_offset)

        case execute_query_with_metadata(paged_selecto) do
          {:ok, {rows, columns, aliases}, metadata} ->
            normalized_rows = QueryResults.normalize_rows(rows)

            Logger.debug(fn ->
              "[selecto_components] aggregate page query success page=#{page} rows=#{length(normalized_rows)} pid=#{inspect(self())}"
            end)

            pages =
              cache
              |> Map.get(:pages, %{})
              |> Map.put(page, %{rows: normalized_rows, columns: columns, aliases: aliases})

            updated_cache = Map.put(cache, :pages, pages)

            {:ok,
             {updated_cache, normalized_rows, columns, aliases,
              Map.put(metadata || %{}, :pagination_mode, :offset)}}

          {:error, error} ->
            {:error, error}
        end
    end
  end

  defp execute_aggregate_total_rows(selecto) do
    count_selecto =
      update_in(selecto.set, fn set ->
        set |> Map.delete(:limit) |> Map.delete(:offset) |> Map.put(:order_by, [])
      end)

    {base_sql, aliases, base_params} = Selecto.gen_sql(count_selecto, [])
    count_sql = build_aggregate_count_sql(base_sql, aliases, selecto)
    started_at = System.monotonic_time(:millisecond)

    case execute_raw_query(selecto, count_sql, base_params) do
      {:ok, {[[count_value]], _columns, _aliases}} ->
        execution_time = System.monotonic_time(:millisecond) - started_at

        {:ok, normalize_count(count_value),
         %{sql: count_sql, params: base_params, execution_time: execution_time}}

      {:ok, {rows, _columns, _aliases}} ->
        {:error,
         Selecto.Error.query_error(
           "Unexpected aggregate count query result",
           count_sql,
           base_params,
           %{rows: rows}
         )}

      {:error, error} ->
        {:error, error}
    end
  end

  defp build_aggregate_count_sql(base_sql, aliases, selecto) do
    if DBSupport.requires_derived_table_column_aliases?(selecto) do
      column_list = aliases |> aggregate_count_column_aliases() |> Enum.join(", ")

      "SELECT count(*) AS total_rows FROM (#{base_sql}) AS selecto_aggregate_count (#{column_list})"
    else
      "SELECT count(*) AS total_rows FROM (#{base_sql}) AS selecto_aggregate_count"
    end
  end

  defp aggregate_count_column_aliases(aliases) when is_list(aliases) and aliases != [] do
    aliases |> Enum.with_index(1) |> Enum.map(fn {_alias, index} -> "agg_col_#{index}" end)
  end

  defp aggregate_count_column_aliases(_aliases), do: ["agg_col_1"]

  defp clear_limit_offset(selecto) do
    update_in(selecto.set, fn set -> set |> Map.delete(:limit) |> Map.delete(:offset) end)
  end

  defp clamp_aggregate_page(page, total_rows, per_page)
       when is_integer(total_rows) and total_rows > 0 do
    max_page = div(total_rows - 1, max(per_page, 1))
    min(max(page, 0), max_page)
  end

  defp clamp_aggregate_page(page, _total_rows, _per_page), do: max(page, 0)
  defp normalize_page_param(value) when is_integer(value), do: max(value, 0)

  defp normalize_page_param(value) when is_binary(value) do
    case Integer.parse(value) do
      {page, ""} -> max(page, 0)
      _ -> 0
    end
  end

  defp normalize_page_param(_), do: 0

  defp term_size_bytes(term) do
    :erts_debug.size(term) * :erlang.system_info(:wordsize)
  rescue
    _ -> nil
  end

  defp execute_query_with_metadata(selecto) do
    try do
      Selecto.execute_with_metadata(selecto)
    rescue
      error -> {:error, Selecto.Error.from_reason(error)}
    catch
      :exit, reason ->
        {:error,
         Selecto.Error.connection_error("Database connection failed", %{exit_reason: reason})}
    end
  end

  defp execute_raw_query(selecto, query, params),
    do: DBSupport.execute_raw_query(selecto, query, params)

  defp normalize_count(value) when is_integer(value), do: value
  defp normalize_count(value) when is_float(value), do: trunc(value)

  defp normalize_count(value) when is_binary(value) do
    case Integer.parse(value) do
      {count, _} -> count
      :error -> 0
    end
  end

  defp normalize_count(value) do
    value |> to_string() |> normalize_count()
  rescue
    _ -> 0
  end

  defp get_map_value(map, key, default) when is_map(map) do
    Map.get(map, key, Map.get(map, to_string(key), default))
  end

  defp get_map_value(_map, _key, default), do: default
end
