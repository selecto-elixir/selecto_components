defmodule SelectoComponents.Form.ParamsState do
  @moduledoc """
  Handles bidirectional conversion between URL parameters and application state for SelectoComponents forms.

  This module manages:
  - Converting view configuration to URL parameters
  - Parsing URL parameters back to view state
  - Processing filters and view-specific parameters
  - Executing queries with error handling
  - Managing URL state updates
  """

  import SelectoComponents.Helpers.Filters, only: [filter_recurse: 3]
  alias Selecto.Executor
  alias SelectoComponents.Performance.MetricsCollector
  alias SelectoComponents.SubselectBuilder
  alias SelectoComponents.EnhancedTable.Sorting
  alias SelectoComponents.SafeAtom
  alias SelectoComponents.Views.Runtime, as: ViewRuntime
  require Logger

  @detail_initial_cached_pages 3
  @detail_chunk_pages 2

  @doc """
  Convert view_config structure to URL parameters format.
  """
  def view_config_to_params(view_config) do
    params = %{
      "view_mode" => view_config.view_mode,
      "filters" => filters_to_params(view_config.filters)
    }

    # Add view-specific parameters
    view_params =
      case view_config.views[SafeAtom.to_view_mode(view_config.view_mode)] do
        nil ->
          %{}

        view_data ->
          # Convert each list (group_by, aggregate, etc.) to params format
          Enum.reduce(view_data, %{}, fn {list_name, items}, acc ->
            items_params =
              items
              |> Enum.with_index()
              |> Enum.reduce(%{}, fn
                {{id, field, config}, index}, item_acc ->
                  Map.put(
                    item_acc,
                    id,
                    Map.merge(config, %{
                      "field" => field,
                      "index" => to_string(index)
                    })
                  )

                {[id, field, config], index}, item_acc ->
                  Map.put(
                    item_acc,
                    id,
                    Map.merge(config, %{
                      "field" => field,
                      "index" => to_string(index)
                    })
                  )
              end)

            Map.put(acc, to_string(list_name), items_params)
          end)
      end

    Map.merge(params, view_params)
  end

  @doc """
  Convert filters back to params format.
  """
  def filters_to_params(filters) do
    filters
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {{uuid, section, filter_data}, index}, acc ->
      filter_params =
        case filter_data do
          conj when is_binary(conj) ->
            %{"conjunction" => conj, "section" => section, "index" => to_string(index)}

          filter_map when is_map(filter_map) ->
            Map.merge(filter_map, %{"section" => section, "index" => to_string(index)})
        end

      Map.put(acc, uuid, filter_params)
    end)
  end

  @doc """
  Process filters from params, extracting and sorting them.
  """
  def view_filter_process(params, item_name) do
    Map.get(params, item_name, %{})
    |> Enum.filter(fn {_uuid, f} ->
      # Only include actual filters, not aggregate/group_by configurations
      # Standard filters should have: filter + comp
      # Custom component filters only need: filter (no comp required)
      is_map(f) && Map.has_key?(f, "filter")
    end)
    |> Enum.map(fn {uuid, f} ->
      # Convert selected_ids array to comma-separated value for IN/NOT IN operators
      f =
        if Map.has_key?(f, "selected_ids") && Map.get(f, "comp") in ["IN", "NOT IN"] do
          selected_ids =
            case Map.get(f, "selected_ids") do
              ids when is_list(ids) -> ids
              ids when is_binary(ids) -> String.split(ids, ",")
              _ -> []
            end

          value = Enum.join(selected_ids, ",")

          f
          |> Map.put("value", value)
          |> Map.delete("selected_ids")
        else
          f
        end

      {uuid, f}
    end)
    |> Enum.sort(fn {_, f1}, {_, f2} ->
      String.to_integer(Map.get(f1, "index", "0")) <= String.to_integer(Map.get(f2, "index", "0"))
    end)
    |> Enum.reduce([], fn
      {u, %{"conjunction" => conj} = f}, acc -> acc ++ [{u, Map.get(f, "section"), conj}]
      {u, f}, acc -> acc ++ [{u, Map.get(f, "section"), f}]
    end)
  end

  @doc """
  Version of view_from_params that applies sorting.
  """
  def view_from_params_with_sort(params, socket, sort_by) do
    # Store the sort_by in socket so the modified view_from_params can use it
    socket = Phoenix.Component.assign(socket, sort_by: sort_by)
    {:noreply, view_from_params(params, socket)}
  end

  @doc """
  Execute view from URL parameters, handling query execution and error cases.

  This is the core function that:
  1. Parses URL parameters into a view configuration
  2. Applies filters to the Selecto structure
  3. Executes the query
  4. Handles errors gracefully
  5. Updates socket state with results or errors
  """
  def view_from_params(params, socket) do
    try do
      # First, clear any existing query results to prevent stale data display
      socket =
        Phoenix.Component.assign(socket,
          query_results: nil,
          executed: false,
          execution_error: nil
        )

      # Create a fresh Selecto structure instead of reusing the cached one
      # This ensures any internal state is properly reset for the new view
      old_selecto = socket.assigns.selecto
      selecto = Selecto.configure(old_selecto.domain, old_selecto.postgrex_opts)
      raw_columns = Selecto.columns(selecto)

      # Convert columns to the format expected by ListPicker components
      # ListPicker expects a list of {id, name, format} tuples
      columns_list =
        raw_columns
        |> Enum.map(fn {key, col} ->
          {key, col.name, col.type}
        end)

      # Create columns lookup map for the process functions
      # This map has both column IDs and field names as keys pointing to column structs
      columns_map =
        raw_columns
        |> Enum.into(%{}, fn {key, col} ->
          # Preserve the original field identifier as colid
          col_with_metadata =
            col
            |> Map.put(:field, col.name)
            # Store the actual field identifier
            |> Map.put(:colid, key)

          {key, col_with_metadata}
        end)
        |> then(fn cols ->
          # Also add entries by display name for lookup convenience
          Enum.reduce(cols, cols, fn {_colid, col}, acc ->
            Map.put(acc, col.name, col)
          end)
        end)

      filters_by_section =
        Map.get(params, "filters", %{})
        |> Map.values()
        |> Enum.filter(fn f ->
          # Only include actual filters with required fields
          # Custom component filters don't have "comp" - they only need "filter" and "section"
          is_map(f) && Map.has_key?(f, "filter") && Map.has_key?(f, "section")
        end)
        |> Enum.reduce(%{}, fn f, acc ->
          Map.put(acc, Map.get(f, "section"), Map.get(acc, Map.get(f, "section"), []) ++ [f])
        end)

      filtered = filter_recurse(selecto, filters_by_section, "filters")

      selected_view = SafeAtom.to_view_mode(get_map_value(params, :view_mode))

      # Include the current detail page if we're in detail view
      params =
        if selected_view == :detail && Map.has_key?(socket.assigns, :current_detail_page) do
          Map.put(params, "detail_page", to_string(socket.assigns.current_detail_page))
        else
          params
        end

      # Handle case where view might not be found
      view_tuple = Enum.find(socket.assigns.views, fn {id, _, _, _} -> id == selected_view end)

      {view_set, view_meta} =
        case view_tuple do
          {_id, _module, _name, _opt} = tuple ->
            ViewRuntime.view(
              tuple,
              params,
              columns_map,
              filtered,
              selecto
            )

          nil ->
            # View not found - raise error that will be caught
            raise "View mode '#{selected_view}' not found in configured views"
        end

      selecto = Map.put(selecto, :set, view_set)

      # Apply automatic pivot if needed
      view_mode = Map.get(params, "view_mode", "detail")
      selected_columns = SelectoComponents.Form.get_selected_columns_from_params(params)

      selecto =
        Selecto.AutoPivot.maybe_apply(selecto,
          view_mode: view_mode,
          selected: selected_columns
        )

      # Apply subselects if denorm_groups were configured
      selecto =
        if Map.has_key?(selecto.set, :denorm_groups) and is_map(selecto.set.denorm_groups) and
             map_size(selecto.set.denorm_groups) > 0 do
          denorm_groups = selecto.set.denorm_groups

          # The selecto already has the selected columns set, we just need to add subselects
          # Use SubselectBuilder to add subselects for denormalizing columns
          try do
            # Add subselects for each denormalizing group
            result =
              Enum.reduce(denorm_groups, selecto, fn {relationship_path, columns}, acc ->
                # Add subselect for #{relationship_path} with columns: #{inspect(columns)}
                SubselectBuilder.add_subselect_for_group(acc, relationship_path, columns)
              end)

            result
          rescue
            _e ->
              # Failed to apply subselects: #{inspect(e)}
              # Fall back to original selecto if subselects fail
              selecto
          end
        else
          # No denorm_groups to process
          selecto
        end

      # Apply sorting if provided
      selecto =
        if socket.assigns[:sort_by] do
          Sorting.apply_sort_to_query(selecto, socket.assigns.sort_by)
        else
          selecto
        end

      {query_result, view_meta, detail_page_cache} =
        execute_query_with_detail_pagination(selecto, params, view_meta, socket)

      case query_result do
        {:ok, {rows, columns, aliases}, metadata} ->
          # Extract metadata from the new execute function
          query_sql = Map.get(metadata, :sql)
          query_params = Map.get(metadata, :params, [])
          execution_time = Map.get(metadata, :execution_time, 0)

          # Record query metrics only when we executed SQL this cycle
          if is_binary(query_sql) and query_sql != "" do
            MetricsCollector.record_query(
              query_sql,
              execution_time,
              %{
                rows_returned: length(rows),
                total_rows: Map.get(view_meta, :total_rows, length(rows)),
                columns_count: length(columns),
                view_mode: socket.assigns.view_config.view_mode,
                has_filters: length(selecto.set.filtered) > 0,
                has_grouping: length(selecto.set.group_by) > 0,
                params: query_params
              }
            )
          end

          normalized_rows =
            normalize_rows_for_view(rows, columns, socket.assigns.view_config.view_mode)

          # Check if any rows have subselect data
          # Debug inspection removed - data structure validated elsewhere

          view_meta = Map.merge(view_meta, %{exe_id: UUID.uuid4()})

          detail_cache_assignment = if detail_view_mode?(params), do: detail_page_cache, else: nil
          cache_debug_info = build_page_cache_debug_info(detail_cache_assignment)
          previous_last_query_info = socket.assigns[:last_query_info] || %{}

          executed_sql? = is_binary(query_sql) and query_sql != ""

          effective_sql =
            if executed_sql? do
              query_sql
            else
              Map.get(previous_last_query_info, :sql)
            end

          effective_params =
            if executed_sql? do
              query_params
            else
              Map.get(previous_last_query_info, :params, query_params)
            end

          effective_timing =
            if executed_sql? do
              execution_time
            else
              Map.get(previous_last_query_info, :timing)
            end

          last_query_info = %{
            sql: effective_sql,
            params: effective_params,
            timing: effective_timing,
            page_cache_memory_bytes: cache_debug_info.bytes,
            page_cache_pages: cache_debug_info.pages,
            page_cache_rows: cache_debug_info.rows
          }

          # Store query info in component state
          socket =
            Phoenix.Component.assign(socket,
              selecto: selecto,
              columns: columns_list,
              field_filters: Selecto.filters(selecto),
              query_results: {normalized_rows, columns, aliases},
              used_params: params,
              applied_view: get_map_value(params, :view_mode),
              view_meta: view_meta,
              detail_page_cache: detail_cache_assignment,
              executed: true,
              execution_error: nil,
              last_query_info: last_query_info
            )

          # Send query info to parent LiveView so it can pass to Results component
          send(
            self(),
            {:query_executed,
             %{
               query_results: {normalized_rows, columns, aliases},
               last_query_info: last_query_info,
               view_meta: view_meta,
               applied_view: get_map_value(params, :view_mode),
               detail_page_cache: detail_cache_assignment
             }}
          )

          socket

        {:error, %{__struct__: module} = error} when module == Selecto.Error ->
          sanitized_error = SelectoComponents.Form.sanitize_error_for_environment(error)

          if SelectoComponents.Form.dev_mode?() do
            # Selecto.Error occurred
          end

          # Try to extract SQL even in error case for debugging
          {error_sql, error_params} =
            try do
              case Selecto.to_sql(selecto) do
                {sql, params} -> {sql, params}
                _ -> {nil, []}
              end
            rescue
              _ -> {nil, []}
            end

          Phoenix.Component.assign(socket,
            selecto: selecto,
            columns: columns_list,
            field_filters: Selecto.filters(selecto),
            query_results: nil,
            used_params: params,
            applied_view: get_map_value(params, :view_mode),
            view_meta: view_meta,
            detail_page_cache: detail_page_cache,
            executed: false,
            execution_error: sanitized_error,
            last_query_info: %{
              sql: error_sql,
              params: error_params,
              timing: nil
            }
          )

        {:error, error} ->
          sanitized_error =
            SelectoComponents.Form.build_selecto_error(
              :query_error,
              inspect(error),
              %{original_error: error}
            )
            |> SelectoComponents.Form.sanitize_error_for_environment()

          if SelectoComponents.Form.dev_mode?() do
            # Generic error occurred
          end

          # Try to extract SQL even in error case for debugging
          {error_sql, error_params} =
            try do
              case Selecto.to_sql(selecto) do
                {sql, params} -> {sql, params}
                _ -> {nil, []}
              end
            rescue
              _ -> {nil, []}
            end

          Phoenix.Component.assign(socket,
            selecto: selecto,
            columns: columns_list,
            field_filters: Selecto.filters(selecto),
            query_results: nil,
            used_params: params,
            applied_view: get_map_value(params, :view_mode),
            view_meta: view_meta,
            detail_page_cache: detail_page_cache,
            executed: false,
            execution_error: sanitized_error,
            last_query_info: %{
              sql: error_sql,
              params: error_params,
              timing: nil
            }
          )
      end
    rescue
      error ->
        # Handle any errors that occur during view processing
        sanitized_error =
          build_view_processing_error(
            :query_error,
            "View processing failed",
            error,
            __STACKTRACE__,
            params
          )
          |> SelectoComponents.Form.sanitize_error_for_environment()

        if SelectoComponents.Form.dev_mode?() do
          # View error occurred
        end

        Phoenix.Component.assign(socket,
          query_results: nil,
          used_params: params,
          applied_view: view_mode_value(params, socket.assigns[:applied_view]),
          executed: false,
          execution_error: sanitized_error,
          view_meta: %{},
          detail_page_cache: nil,
          last_query_info: %{}
        )
    catch
      :exit, reason ->
        # Handle exits (like process crashes)
        if SelectoComponents.Form.dev_mode?() do
          # View exit: #{inspect(reason)}
        end

        Phoenix.Component.assign(socket,
          query_results: nil,
          used_params: params,
          applied_view: view_mode_value(params, socket.assigns[:applied_view]),
          executed: false,
          execution_error:
            SelectoComponents.Form.build_selecto_error(
              :system_error,
              "System error occurred while processing view",
              %{
                exit_reason: inspect(reason),
                view_mode: view_mode_value(params, socket.assigns[:applied_view])
              }
            )
            |> SelectoComponents.Form.sanitize_error_for_environment(),
          view_meta: %{},
          detail_page_cache: nil,
          last_query_info: %{}
        )
    end
  end

  defp execute_query_with_detail_pagination(selecto, params, view_meta, socket) do
    if detail_view_mode?(params) do
      execute_detail_query_with_cache(selecto, params, view_meta, socket)
    else
      {execute_query_with_metadata(selecto), view_meta, nil}
    end
  end

  defp detail_view_mode?(params) do
    case get_map_value(params, :view_mode) do
      :detail -> true
      "detail" -> true
      other when is_atom(other) -> Atom.to_string(other) == "detail"
      _ -> false
    end
  end

  defp view_mode_value(params, fallback \\ nil) do
    get_map_value(params, :view_mode, fallback)
  end

  defp build_view_processing_error(type, message, error, stacktrace, params) do
    details = %{
      exception: inspect(error.__struct__),
      error: Exception.message(error),
      view_mode: view_mode_value(params),
      params_keys: if(is_map(params), do: Map.keys(params), else: []),
      stacktrace: format_stacktrace(stacktrace)
    }

    SelectoComponents.Form.build_selecto_error(type, message, details)
  end

  defp format_stacktrace(stacktrace) when is_list(stacktrace) do
    stacktrace
    |> Exception.format_stacktrace()
    |> IO.iodata_to_binary()
  rescue
    _ -> inspect(stacktrace, limit: 30)
  end

  defp format_stacktrace(stacktrace), do: inspect(stacktrace, limit: 30)

  defp build_page_cache_debug_info(nil), do: %{bytes: nil, pages: nil, rows: nil}

  defp build_page_cache_debug_info(cache) when is_map(cache) do
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

  defp build_page_cache_debug_info(_), do: %{bytes: nil, pages: nil, rows: nil}

  defp term_size_bytes(term) do
    :erts_debug.size(term) * :erlang.system_info(:wordsize)
  rescue
    _ -> nil
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

  defp execute_detail_query_with_cache(selecto, params, view_meta, socket) do
    per_page = max(Map.get(view_meta, :per_page, 30), 1)
    requested_page = max(Map.get(view_meta, :page, 0), 0)
    cache_key = detail_cache_signature(params, socket.assigns[:sort_by])

    cache =
      socket.assigns[:detail_page_cache]
      |> init_or_reset_detail_cache(cache_key, per_page)

    with {:ok, {cache, count_metadata}} <- maybe_fetch_detail_total_rows(cache, selecto),
         safe_page <- clamp_detail_page(requested_page, cache.total_rows, per_page),
         {:ok, {cache, data_metadata}} <-
           maybe_fetch_detail_pages(cache, selecto, safe_page, per_page) do
      rows = Map.get(cache.pages, safe_page, [])
      columns = cache.columns || []
      aliases = cache.aliases || []

      metadata = data_metadata || count_metadata || %{sql: nil, params: [], execution_time: 0}

      updated_view_meta =
        view_meta
        |> Map.put(:page, safe_page)
        |> Map.put(:per_page, per_page)
        |> Map.put(:total_rows, cache.total_rows)

      {{:ok, {rows, columns, aliases}, metadata}, updated_view_meta, cache}
    else
      {:error, error} ->
        {{:error, error}, view_meta, cache}
    end
  end

  defp init_or_reset_detail_cache(
         %{signature: signature, per_page: per_page} = cache,
         signature,
         per_page
       ) do
    cache
  end

  defp init_or_reset_detail_cache(_, signature, per_page) do
    %{
      signature: signature,
      per_page: per_page,
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

  defp maybe_fetch_detail_total_rows(%{total_rows: total_rows} = cache, _selecto)
       when is_integer(total_rows) do
    {:ok, {cache, nil}}
  end

  defp maybe_fetch_detail_total_rows(cache, selecto) do
    case execute_detail_count_query(selecto) do
      {:ok, total_rows, metadata} ->
        {:ok, {Map.put(cache, :total_rows, total_rows), metadata}}

      {:error, error} ->
        {:error, error}
    end
  end

  defp execute_detail_count_query(selecto) do
    selecto_without_paging =
      update_in(selecto.set, fn set ->
        set
        |> Map.delete(:limit)
        |> Map.delete(:offset)
        |> Map.put(:order_by, [])
      end)

    {base_sql, base_params} = Selecto.to_sql(selecto_without_paging)
    count_sql = "SELECT count(*) AS total_rows FROM (#{base_sql}) AS selecto_detail_count"

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

  defp maybe_fetch_detail_pages(cache, selecto, requested_page, per_page) do
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
      row_limit = max(window_page_count * per_page, per_page)

      paged_selecto =
        selecto
        |> Selecto.limit(row_limit)
        |> Selecto.offset(row_offset)

      case execute_query_with_metadata(paged_selecto) do
        {:ok, {rows, columns, aliases}, metadata} ->
          normalized_rows = normalize_rows_for_view(rows, columns, "detail")

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

  defp detail_page_window(requested_page, max_page) do
    {window_start, window_end} =
      if requested_page < @detail_initial_cached_pages do
        {0, @detail_initial_cached_pages - 1}
      else
        {requested_page, requested_page + @detail_chunk_pages - 1}
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

  defp ecto_repo?(repo) when is_atom(repo) do
    Code.ensure_loaded?(repo) and function_exported?(repo, :__adapter__, 0)
  end

  defp ecto_repo?(_), do: false

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

  defp normalize_rows_for_view(rows, columns, "detail")
       when is_list(rows) and rows != [] and (is_list(hd(rows)) or is_tuple(hd(rows))) do
    Enum.map(rows, fn row ->
      row_values = if is_tuple(row), do: Tuple.to_list(row), else: row
      Enum.zip(columns, row_values) |> Map.new()
    end)
  end

  defp normalize_rows_for_view(rows, _columns, _view_mode), do: rows

  @doc """
  Build view_config from URL params, updating only filter state.
  """
  def filter_params_to_state(params, socket) do
    filters = view_filter_process(params, "filters")

    Phoenix.Component.assign(socket,
      view_config: %{
        socket.assigns.view_config
        | filters: filters
      }
    )
  end

  @doc """
  Build view_config from URL params, updating full state including view-specific configs.
  """
  def params_to_state(params, socket) do
    filters = view_filter_process(params, "filters")

    view_configs =
      Enum.reduce(socket.assigns.views, %{}, fn {view, _module, _name, _opt} = view_tuple, acc ->
        Map.merge(acc, %{
          view => ViewRuntime.param_to_state(view_tuple, params)
        })
      end)

    # Preserve existing view_config and only update what's in params
    existing_config = socket.assigns[:view_config] || %{}

    Phoenix.Component.assign(socket,
      view_config:
        Map.merge(existing_config, %{
          filters: filters,
          views: view_configs,
          view_mode: Map.get(params, "view_mode", existing_config[:view_mode] || "aggregate")
        })
    )
  end

  @doc """
  Convert saved view configuration to full params format.
  """
  def convert_saved_config_to_full_params(saved_params, view_type) do
    # The saved params look like: %{"detail" => %{selected: [...], order_by: [...], ...}}
    # We need to convert to params format that params_to_state expects

    view_config =
      saved_params
      |> get_map_value(view_type, %{})

    # Convert the view-specific lists to params format
    params = %{
      "view_mode" => view_type
    }

    # Convert selected items
    params =
      if selected = get_map_value(view_config, :selected) do
        selected_params =
          selected
          |> Enum.with_index()
          |> Enum.reduce(%{}, fn
            {[uuid, field, config], index}, acc ->
              Map.put(
                acc,
                uuid,
                Map.merge(config, %{
                  "field" => field,
                  "index" => to_string(index)
                })
              )

            {{uuid, field, config}, index}, acc ->
              Map.put(
                acc,
                uuid,
                Map.merge(config, %{
                  "field" => field,
                  "index" => to_string(index)
                })
              )
          end)

        Map.put(params, "selected", selected_params)
      else
        params
      end

    # Convert order_by items - always set this to ensure replacement
    order_by = get_map_value(view_config, :order_by, [])

    order_by_params =
      order_by
      |> Enum.with_index()
      |> Enum.reduce(%{}, fn
        {[uuid, field, config], index}, acc ->
          # Ensure all keys and values in config are strings
          string_config =
            case config do
              nil ->
                %{}

              map when is_map(map) ->
                Map.new(map, fn {k, v} -> {to_string(k), to_string(v)} end)

              _ ->
                %{}
            end

          Map.put(
            acc,
            uuid,
            Map.merge(string_config, %{
              "field" => field,
              "index" => to_string(index)
            })
          )

        {{uuid, field, config}, index}, acc ->
          # Ensure all keys and values in config are strings
          string_config =
            case config do
              nil ->
                %{}

              map when is_map(map) ->
                Map.new(map, fn {k, v} -> {to_string(k), to_string(v)} end)

              _ ->
                %{}
            end

          Map.put(
            acc,
            uuid,
            Map.merge(string_config, %{
              "field" => field,
              "index" => to_string(index)
            })
          )
      end)

    params = Map.put(params, "order_by", order_by_params)

    # Add other view-specific params
    params
    |> Map.put("per_page", to_string(get_map_value(view_config, :per_page, "30")))
    |> Map.put(
      "prevent_denormalization",
      to_string(get_map_value(view_config, :prevent_denormalization, true))
    )
  end

  @doc """
  Check if view parameters have changed significantly enough to require a view reset.
  """
  def view_params_changed?(params, socket) do
    used_params = socket.assigns[:used_params] || %{}

    # Key parameters that should trigger a view reset
    significant_changes = [
      # View mode change (aggregate vs detail vs graph)
      Map.get(params, "view_mode") != Map.get(used_params, "view_mode"),

      # Group by changes in aggregate view
      view_specific_params_changed?(params, used_params, "group_by"),

      # Aggregate fields changes in aggregate view
      view_specific_params_changed?(params, used_params, "aggregate"),

      # Column selection changes in detail view
      view_specific_params_changed?(params, used_params, "columns"),

      # Order by changes
      view_specific_params_changed?(params, used_params, "order_by"),

      # Filter changes that affect the query structure
      filter_structure_changed?(params, used_params)
    ]

    Enum.any?(significant_changes)
  end

  @doc """
  Check if view-specific parameters changed.
  """
  def view_specific_params_changed?(params, used_params, param_key) do
    current = normalize_param_map(Map.get(params, param_key, %{}))
    previous = normalize_param_map(Map.get(used_params, param_key, %{}))
    current != previous
  end

  @doc """
  Normalize parameter maps for comparison.
  """
  def normalize_param_map(param_map) when is_map(param_map) do
    param_map
    |> Enum.map(fn {k, v} ->
      {k, Map.take(v, ["field", "format", "alias", "index"])}
    end)
    |> Enum.sort()
  end

  def normalize_param_map(_), do: []

  @doc """
  Check if filter structure changed (not just values).
  """
  def filter_structure_changed?(params, used_params) do
    current_filters = Map.get(params, "filters", %{}) |> Map.keys() |> Enum.sort()
    previous_filters = Map.get(used_params, "filters", %{}) |> Map.keys() |> Enum.sort()
    current_filters != previous_filters
  end

  @doc """
  Update the URL to include the configured view parameters.
  """
  def state_to_url(params, socket) do
    params = merge_special_debug_params(params, socket)
    params_encoded = Plug.Conn.Query.encode(params)
    my_path = socket.assigns.my_path
    full_path = "#{my_path}?#{params_encoded}"

    Phoenix.LiveView.push_patch(socket, to: full_path)
  end

  defp merge_special_debug_params(params, socket) do
    existing_params = Map.get(socket.assigns, :params, %{})

    debug_params =
      %{
        "selecto_debug" => get_map_value(existing_params, :selecto_debug),
        "debug" => get_map_value(existing_params, :debug),
        "debug_token" => get_map_value(existing_params, :debug_token)
      }
      |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
      |> Map.new()

    Map.merge(debug_params, params)
  end

  defp get_map_value(map, key, default \\ nil)

  defp get_map_value(map, key, default) when is_map(map) do
    Map.get(map, key, Map.get(map, to_string(key), default))
  end

  defp get_map_value(_map, _key, default), do: default
end
