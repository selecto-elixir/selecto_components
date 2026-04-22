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

  alias SelectoComponents.DBSupport
  alias SelectoComponents.Execution.Executor
  alias SelectoComponents.Execution.Plan
  alias SelectoComponents.Execution.Result
  alias SelectoComponents.Views.Aggregate.Options, as: AggregateOptions
  alias SelectoComponents.Views.Detail.Options, as: DetailOptions
  alias SelectoComponents.Views.Detail.QueryPagination
  alias SelectoComponents.SafeAtom
  alias SelectoComponents.QueryResults
  alias SelectoComponents.Presentation
  alias SelectoComponents.Session.Codec
  alias SelectoComponents.Session.Store, as: SessionStore
  require Logger

  @map_param_keys ~w(
    geometry_field
    popup_field
    color_field
    tile_url
    attribution
    background_mode
    coordinate_mode
    image_overlay_url
    image_overlay_bounds
    image_overlay_opacity
    image_overlay_rotation
    default_zoom
    center_lat
    center_lng
    fit_bounds
    max_points
    cluster
  )

  @map_boolean_param_keys ~w(fit_bounds cluster)

  @doc """
  Convert view_config structure to URL parameters format.
  """
  def view_config_to_params(view_config) do
    view_mode = get_map_value(view_config, :view_mode, "aggregate")
    ctes = get_map_value(view_config, :ctes, [])
    filters = get_map_value(view_config, :filters, [])
    views = get_map_value(view_config, :views, %{})

    params = %{
      "view_mode" => view_mode,
      "ctes" => ctes_to_params(ctes),
      "filters" => filters_to_params(filters)
    }

    view_params =
      views
      |> Enum.reduce(%{}, fn {view_key, view_data}, acc ->
        view = SafeAtom.to_view_mode(view_key)
        Map.merge(acc, view_data_to_params(view, view_data))
      end)

    Map.merge(params, view_params)
  end

  defp view_data_to_params(_view, nil), do: %{}

  defp view_data_to_params(view, view_data) when is_map(view_data) do
    Enum.reduce(view_data, %{}, fn {list_name, items}, acc ->
      cond do
        view == :map and list_name in [:map_layers, "map_layers"] ->
          merge_scalar_view_param(acc, view, list_name, items)

        view == :map ->
          merge_scalar_view_param(acc, view, list_name, items)

        is_list(items) ->
          Map.put(acc, to_string(list_name), view_items_to_params(items))

        true ->
          merge_scalar_view_param(acc, view, list_name, items)
      end
    end)
  end

  defp view_data_to_params(_view, _view_data), do: %{}

  @doc """
  Convert full view_config structure to saved-view persistence format.
  """
  def view_config_to_saved_params(view_config), do: Codec.view_config_to_saved_params(view_config)

  defp view_items_to_params(items) do
    items
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn
      {{id, field, config}, index}, item_acc ->
        Map.put(
          item_acc,
          compact_param_key(index),
          Map.merge(config, %{
            "uuid" => id,
            "field" => field,
            "index" => to_string(index)
          })
        )

      {[id, field, config], index}, item_acc ->
        Map.put(
          item_acc,
          compact_param_key(index),
          Map.merge(config, %{
            "uuid" => id,
            "field" => field,
            "index" => to_string(index)
          })
        )

      {_unknown_item, _index}, item_acc ->
        item_acc
    end)
  end

  defp ctes_to_params(ctes) when is_list(ctes) do
    ctes
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn
      {{uuid, name, config}, index}, acc ->
        Map.put(
          acc,
          compact_param_key(index),
          Map.merge(stringify_map_keys(config), %{
            "uuid" => uuid,
            "name" => name,
            "index" => to_string(index)
          })
        )

      {[uuid, name, config], index}, acc ->
        Map.put(
          acc,
          compact_param_key(index),
          Map.merge(stringify_map_keys(config), %{
            "uuid" => uuid,
            "name" => name,
            "index" => to_string(index)
          })
        )

      {_unknown_item, _index}, acc ->
        acc
    end)
  end

  defp ctes_to_params(_ctes), do: %{}

  defp merge_scalar_view_param(acc, :aggregate, key, value)
       when key in [:per_page, "per_page"] do
    Map.put(acc, "aggregate_per_page", AggregateOptions.normalize_per_page_param(value))
  end

  defp merge_scalar_view_param(acc, :aggregate, key, value)
       when key in [:grid, "grid"] do
    Map.put(acc, "aggregate_grid", to_string(value))
  end

  defp merge_scalar_view_param(acc, :aggregate, key, value)
       when key in [:grid_colorize, "grid_colorize"] do
    Map.put(acc, "aggregate_grid_colorize", to_string(value))
  end

  defp merge_scalar_view_param(acc, :aggregate, key, value)
       when key in [:grid_color_scale, "grid_color_scale"] do
    Map.put(
      acc,
      "aggregate_grid_color_scale",
      AggregateOptions.normalize_grid_color_scale_mode(value)
    )
  end

  defp merge_scalar_view_param(acc, :detail, key, value)
       when key in [:max_rows, "max_rows"] do
    Map.put(acc, "max_rows", DetailOptions.normalize_max_rows_param(value))
  end

  defp merge_scalar_view_param(acc, :detail, key, value)
       when key in [:count_mode, "count_mode"] do
    Map.put(acc, "count_mode", DetailOptions.normalize_count_mode_param(value))
  end

  defp merge_scalar_view_param(acc, :detail, key, value)
       when key in [:row_click_action, "row_click_action"] do
    maybe_put_param(acc, "row_click_action", normalize_optional_scalar(value))
  end

  defp merge_scalar_view_param(acc, :map, key, value)
       when key in [:center, "center"] do
    maybe_put_center_params(acc, value)
  end

  defp merge_scalar_view_param(acc, :map, key, value)
       when key in [:map_layers, "map_layers"] do
    maybe_put_param(acc, "map_layers", normalize_map_layers_param(value))
  end

  defp merge_scalar_view_param(acc, :map, key, value) do
    case map_param_key(key) do
      nil ->
        acc

      param_key ->
        maybe_put_param(acc, param_key, normalize_map_param_value(param_key, value))
    end
  end

  defp merge_scalar_view_param(acc, _selected_view, key, value)
       when key in [:per_page, "per_page"] do
    Map.put(acc, "per_page", normalize_per_page_param(value, "30"))
  end

  defp merge_scalar_view_param(acc, _selected_view, key, value)
       when key in [:prevent_denormalization, "prevent_denormalization"] do
    Map.put(acc, "prevent_denormalization", to_string(value))
  end

  defp merge_scalar_view_param(acc, _selected_view, _key, _value), do: acc

  defp normalize_per_page_param(nil, default), do: default

  defp normalize_per_page_param(value, default) when is_binary(value) do
    trimmed = String.trim(value)
    if byte_size(trimmed) > 0, do: trimmed, else: default
  end

  defp normalize_per_page_param(value, _default) when is_integer(value), do: to_string(value)
  defp normalize_per_page_param(value, _default) when is_atom(value), do: Atom.to_string(value)

  defp normalize_per_page_param(_value, default), do: default

  defp normalize_optional_scalar(nil), do: nil

  defp normalize_optional_scalar(value) when is_binary(value) do
    trimmed = String.trim(value)
    if trimmed == "", do: nil, else: trimmed
  end

  defp normalize_optional_scalar(value) when is_atom(value),
    do: value |> Atom.to_string() |> normalize_optional_scalar()

  defp normalize_optional_scalar(value) when is_integer(value), do: Integer.to_string(value)
  defp normalize_optional_scalar(value) when is_float(value), do: to_string(value)
  defp normalize_optional_scalar(_value), do: nil

  @doc """
  Convert filters back to params format.
  """
  def filters_to_params(filters) do
    filters
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn
      {{uuid, section, filter_data}, index}, acc ->
        Map.put(
          acc,
          compact_param_key(index),
          build_filter_params(uuid, section, filter_data, index)
        )

      {[uuid, section, filter_data], index}, acc ->
        Map.put(
          acc,
          compact_param_key(index),
          build_filter_params(uuid, section, filter_data, index)
        )
    end)
  end

  defp build_filter_params(uuid, section, filter_data, index) do
    case filter_data do
      conj when is_binary(conj) ->
        %{
          "uuid" => uuid,
          "conjunction" => conj,
          "is_section" => "Y",
          "section" => section,
          "index" => to_string(index)
        }

      filter_map when is_map(filter_map) ->
        Map.merge(normalize_filter_storage_state(filter_map), %{
          "uuid" => uuid,
          "section" => section,
          "index" => to_string(index)
        })
    end
  end

  defp compact_param_key(index) when is_integer(index), do: "k" <> Integer.to_string(index, 36)

  @doc """
  Process filters from params, extracting and sorting them.
  """
  def view_filter_process(params, item_name) do
    Map.get(params, item_name, %{})
    |> Enum.filter(fn {_uuid, f} ->
      # Filter form payloads can include both real filters and logical section rows.
      # Preserve section rows so editing a child filter does not collapse its OR/AND group.
      is_map(f) && (Map.has_key?(f, "filter") || Map.get(f, "is_section") in ["Y", true, "true"])
    end)
    |> Enum.map(fn {param_key, f} ->
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

      f = normalize_filter_form_state(f)

      {param_key, f}
    end)
    |> Enum.sort(fn {_, f1}, {_, f2} ->
      String.to_integer(Map.get(f1, "index", "0")) <= String.to_integer(Map.get(f2, "index", "0"))
    end)
    |> Enum.reduce([], fn
      {param_key, %{"conjunction" => conj} = f}, acc ->
        uuid = get_map_value(f, :uuid, param_key)
        acc ++ [{uuid, Map.get(f, "section"), conj}]

      {param_key, f}, acc ->
        uuid = get_map_value(f, :uuid, param_key)
        acc ++ [{uuid, Map.get(f, "section"), f}]
    end)
  end

  defp normalize_filter_form_state(filter) when is_map(filter) do
    comp = Map.get(filter, "comp") || Map.get(filter, :comp)
    value = Map.get(filter, "value") || Map.get(filter, :value)

    case comp do
      comp when comp in ["IN", "NOT IN"] ->
        normalize_in_filter_state(filter, value)

      "SHORTCUT" ->
        shortcut =
          if SelectoComponents.Form.FilterRendering.is_date_shortcut(value),
            do: value,
            else: "today"

        filter
        |> Map.put("value", shortcut)
        |> Map.delete("value_start")
        |> Map.delete("value_end")
        |> Map.delete("value2")

      "RELATIVE" ->
        filter
        |> Map.put("value", value || "")
        |> Map.delete("value_start")
        |> Map.delete("value_end")
        |> Map.delete("value2")

      comp when comp in ["IS NULL", "IS NOT NULL", "IS_EMPTY", "NOT_EMPTY"] ->
        filter
        |> Map.put("value", "")
        |> Map.delete("value_start")
        |> Map.delete("value_end")
        |> Map.delete("value2")

      "WEEKDAY_SUN1" ->
        Map.put(filter, "value", normalize_numeric_choice(value, 1, 7, "1"))

      "WEEKDAY" ->
        Map.put(filter, "value", normalize_numeric_choice(value, 1, 7, "1"))

      "MONTH_OF_YEAR" ->
        Map.put(filter, "value", normalize_numeric_choice(value, 1, 12, "1"))

      "DAY_OF_MONTH" ->
        Map.put(filter, "value", normalize_numeric_choice(value, 1, 31, "1"))

      "HOUR_OF_DAY" ->
        Map.put(filter, "value", normalize_numeric_choice(value, 0, 23, "0"))

      "WEEK_OF_YEAR" ->
        week_value = to_string(value || "")

        if String.match?(week_value, ~r/^\d{4}-\d{2}$/),
          do: Map.put(filter, "value", week_value),
          else: filter

      comp when comp in ["BETWEEN", "DATE_BETWEEN"] ->
        start_value = Map.get(filter, "value_start") || Map.get(filter, "value") || ""
        end_value = Map.get(filter, "value_end") || Map.get(filter, "value2") || ""

        filter
        |> Map.put("value_start", start_value)
        |> Map.put("value_end", end_value)
        |> Map.delete("selected_values")
        |> Map.delete("pending_values")

      _ ->
        filter
        |> Map.delete("selected_values")
        |> Map.delete("pending_values")
    end
  end

  defp normalize_filter_form_state(filter), do: filter

  defp normalize_in_filter_state(filter, value) do
    {selected_values, pending_values} =
      filter
      |> selected_filter_values_from_state(value)
      |> merge_pending_filter_values(
        Map.get(filter, "pending_values") || Map.get(filter, :pending_values)
      )

    filter
    |> Map.put("selected_values", selected_values)
    |> Map.put("value", Enum.join(selected_values, ","))
    |> Map.delete("selected_ids")
    |> maybe_put_pending_values(pending_values)
  end

  defp selected_filter_values_from_state(filter, fallback_value) do
    cond do
      is_list(Map.get(filter, "selected_values")) ->
        Map.get(filter, "selected_values")

      is_list(Map.get(filter, :selected_values)) ->
        Map.get(filter, :selected_values)

      is_list(Map.get(filter, "selected_ids")) ->
        Map.get(filter, "selected_ids")

      is_list(Map.get(filter, :selected_ids)) ->
        Map.get(filter, :selected_ids)

      true ->
        fallback_value
    end
    |> parse_filter_values()
  end

  defp merge_pending_filter_values(selected_values, pending_values) do
    {committed_values, remaining_pending_values} = parse_pending_filter_values(pending_values)

    {
      selected_values ++
        Enum.reduce(committed_values, [], fn value, acc ->
          if value in selected_values or value in acc, do: acc, else: acc ++ [value]
        end),
      remaining_pending_values
    }
  end

  defp parse_pending_filter_values(value) when is_binary(value) do
    normalized_value = String.replace(value, ~r/\r\n|\r/, "\n")

    cond do
      normalized_value == "" ->
        {[], ""}

      String.contains?(normalized_value, "\n") ->
        commit_pending_lines(normalized_value)

      true ->
        {[], normalized_value}
    end
  end

  defp parse_pending_filter_values(_value), do: {[], ""}

  defp commit_pending_lines(normalized_value) do
    committed_values =
      normalized_value
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    {committed_values, ""}
  end

  defp maybe_put_pending_values(filter, pending_values) when pending_values in [nil, ""],
    do: Map.delete(filter, "pending_values")

  defp maybe_put_pending_values(filter, pending_values),
    do: Map.put(filter, "pending_values", pending_values)

  defp parse_filter_values(values) when is_list(values) do
    values
    |> Enum.map(&to_string/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp parse_filter_values(values) when is_binary(values) do
    values
    |> String.split(~r/\r\n|\n|\r|,/, trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp parse_filter_values(_values), do: []

  defp normalize_filter_storage_state(filter) when is_map(filter) do
    filter
    |> normalize_filter_form_state()
    |> Map.delete("selected_values")
    |> Map.delete("pending_values")
  end

  defp normalize_filter_storage_state(filter), do: filter

  defp normalize_numeric_choice(value, min_value, max_value, default) do
    case Integer.parse(to_string(value || "")) do
      {int_val, ""} when int_val >= min_value and int_val <= max_value ->
        Integer.to_string(int_val)

      _ ->
        default
    end
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
  Clears cached query pagination state.

  This is used when a user explicitly re-submits or reloads a view so results
  are recomputed from fresh execution instead of page-cache reuse.
  """
  def clear_query_caches(socket) do
    Phoenix.Component.assign(socket,
      detail_page_cache: nil,
      aggregate_page_cache: nil
    )
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
    Logger.debug(fn ->
      "[selecto_components] view_from_params start view_mode=#{Map.get(params, "view_mode") || Map.get(params, :view_mode)} connected=#{Phoenix.LiveView.connected?(socket)} pid=#{inspect(self())}"
    end)

    result_socket =
      try do
        socket =
          Phoenix.Component.assign(socket,
            query_results: nil,
            executed: false,
            execution_error: nil
          )

        plan = Plan.build(params, socket)
        result = Executor.run(plan, socket)
        socket = Phoenix.Component.assign(socket, Result.to_assigns(result))

        if result.executed do
          send(
            self(),
            {:query_executed,
             %{
               selecto: result.selecto,
               query_results: result.query_results,
               last_query_info: result.last_query_info,
               view_meta: result.view_meta,
               applied_view: result.applied_view,
               detail_page_cache: result.detail_page_cache,
               aggregate_page_cache: result.aggregate_page_cache
             }}
          )

          row_count =
            case result.query_results do
              {rows, _columns, _aliases} when is_list(rows) -> length(rows)
              _ -> 0
            end

          Logger.debug(fn ->
            "[selecto_components] view_from_params success view_mode=#{result.applied_view} rows=#{row_count} sql?=#{is_binary(result.last_query_info[:sql]) and result.last_query_info[:sql] != ""} pid=#{inspect(self())}"
          end)

          socket
        else
          socket
        end
      rescue
        error ->
          sanitized_error =
            build_view_processing_error(
              :query_error,
              "View processing failed",
              error,
              __STACKTRACE__,
              params
            )
            |> SelectoComponents.Form.sanitize_error_for_environment(
              stage: :result_process,
              category: :processing,
              code: :view_processing_failed,
              operation: "view-apply",
              view_mode: view_mode_value(params)
            )

          Phoenix.Component.assign(socket,
            query_results: nil,
            used_params: drop_runtime_only_params(params),
            applied_view: view_mode_value(params, socket.assigns[:applied_view]),
            executed: false,
            execution_error: sanitized_error,
            view_meta: %{},
            detail_page_cache: nil,
            aggregate_page_cache: nil,
            last_query_info: %{}
          )
      catch
        :exit, reason ->
          Phoenix.Component.assign(socket,
            query_results: nil,
            used_params: drop_runtime_only_params(params),
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
              |> SelectoComponents.Form.sanitize_error_for_environment(
                stage: if(reason == :timeout, do: :timeout, else: :lifecycle),
                category: if(reason == :timeout, do: :timeout, else: :runtime),
                code: if(reason == :timeout, do: :query_timed_out, else: :system_exit),
                operation: "view-apply",
                view_mode: view_mode_value(params, socket.assigns[:applied_view])
              ),
            view_meta: %{},
            detail_page_cache: nil,
            aggregate_page_cache: nil,
            last_query_info: %{}
          )
      end

    mark_form_state_applied(result_socket)
  end

  defp execute_query_with_detail_pagination(selecto, params, view_meta, socket) do
    cond do
      DetailOptions.detail_view_mode?(params) ->
        QueryPagination.execute(selecto, params, view_meta, socket)

      AggregateOptions.aggregate_view_mode?(params) ->
        execute_aggregate_query_with_pagination(selecto, params, view_meta, socket)

      true ->
        {execute_query_with_metadata(selecto), view_meta, nil}
    end
  end

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
       ) do
    cache
  end

  defp init_or_reset_aggregate_cache(_cache, signature, per_page_setting) do
    %{
      signature: signature,
      per_page_setting: per_page_setting,
      total_rows: nil,
      pages: %{}
    }
  end

  defp aggregate_cache_signature(params, sort_by) do
    %{
      params: Map.drop(params, ["aggregate_page", "detail_page"]),
      sort_by: sort_by || []
    }
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
        set
        |> Map.delete(:limit)
        |> Map.delete(:offset)
        |> Map.put(:order_by, [])
      end)

    {base_sql, aliases, base_params} = Selecto.gen_sql(count_selecto, [])
    count_sql = build_aggregate_count_sql(base_sql, aliases, selecto)
    started_at = System.monotonic_time(:millisecond)

    case execute_raw_query(selecto, count_sql, base_params) do
      {:ok, {[[count_value]], _columns, _aliases}} ->
        execution_time = System.monotonic_time(:millisecond) - started_at

        {:ok, normalize_count(count_value),
         %{
           sql: count_sql,
           params: base_params,
           execution_time: execution_time
         }}

      {:ok, {rows, _columns, _aliases}} ->
        {:error,
         Selecto.Error.query_error(
           "Unexpected aggregate count query result",
           count_sql,
           base_params,
           %{
             rows: rows
           }
         )}

      {:error, error} ->
        {:error, error}
    end
  end

  defp build_aggregate_count_sql(base_sql, aliases, selecto) do
    if DBSupport.requires_derived_table_column_aliases?(selecto) do
      column_list =
        aliases
        |> aggregate_count_column_aliases()
        |> Enum.join(", ")

      "SELECT count(*) AS total_rows FROM (#{base_sql}) AS selecto_aggregate_count (#{column_list})"
    else
      "SELECT count(*) AS total_rows FROM (#{base_sql}) AS selecto_aggregate_count"
    end
  end

  defp aggregate_count_column_aliases(aliases) when is_list(aliases) and aliases != [] do
    aliases
    |> Enum.with_index(1)
    |> Enum.map(fn {_alias, index} -> "agg_col_#{index}" end)
  end

  defp aggregate_count_column_aliases(_aliases), do: ["agg_col_1"]

  defp clear_limit_offset(selecto) do
    update_in(selecto.set, fn set ->
      set
      |> Map.delete(:limit)
      |> Map.delete(:offset)
    end)
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

  defp execution_error_opts(error, params, extra_opts) do
    view_mode = view_mode_value(params)

    Keyword.merge(
      [
        stage: execution_error_stage(error),
        category: execution_error_category(error),
        code: execution_error_code(error),
        view_mode: view_mode
      ],
      extra_opts
    )
  end

  defp execution_error_stage(%{__struct__: module} = error) when module == Selecto.Error do
    case Map.get(error, :type, :query_error) do
      :validation_error -> :input
      :configuration_error -> :configuration
      :field_resolution_error -> :configuration
      :timeout_error -> :timeout
      :connection_error -> :db_execute
      :transformation_error -> :result_process
      :query_error -> if(Map.get(error, :query), do: :db_execute, else: :query_build)
      _ -> :unknown
    end
  end

  defp execution_error_stage(:timeout), do: :timeout
  defp execution_error_stage({:error, :timeout}), do: :timeout
  defp execution_error_stage(_), do: :db_execute

  defp execution_error_category(%{__struct__: module} = error) when module == Selecto.Error do
    case Map.get(error, :type, :query_error) do
      :validation_error -> :validation
      :configuration_error -> :configuration
      :field_resolution_error -> :configuration
      :timeout_error -> :timeout
      :connection_error -> :connection
      :transformation_error -> :processing
      :permission_error -> :authorization
      :query_error -> :query
      _ -> :runtime
    end
  end

  defp execution_error_category(:timeout), do: :timeout
  defp execution_error_category({:error, :timeout}), do: :timeout
  defp execution_error_category(_), do: :query

  defp execution_error_code(%{__struct__: module} = error) when module == Selecto.Error do
    case Map.get(error, :type, :query_error) do
      :validation_error -> :validation_error
      :configuration_error -> :invalid_view_config
      :field_resolution_error -> :unknown_field
      :timeout_error -> :query_timed_out
      :connection_error -> :connection_error
      :transformation_error -> :result_processing_failed
      :permission_error -> :permission_error
      :query_error -> if(Map.get(error, :query), do: :db_query_failed, else: :query_build_failed)
      type -> type
    end
  end

  defp execution_error_code(:timeout), do: :query_timed_out
  defp execution_error_code({:error, :timeout}), do: :query_timed_out
  defp execution_error_code(_), do: :db_query_failed

  defp format_stacktrace(stacktrace) when is_list(stacktrace) do
    stacktrace
    |> Exception.format_stacktrace()
    |> IO.iodata_to_binary()
  rescue
    _ -> inspect(stacktrace, limit: 30)
  end

  defp format_stacktrace(stacktrace), do: inspect(stacktrace, limit: 30)

  defp build_query_cache_debug_info(detail_cache, params, rows, columns, aliases) do
    cond do
      is_map(detail_cache) ->
        QueryPagination.cache_debug_info(detail_cache)

      AggregateOptions.aggregate_view_mode?(params) ->
        %{
          bytes: term_size_bytes({rows, columns, aliases}),
          pages: 1,
          rows: length(rows)
        }

      true ->
        %{bytes: nil, pages: nil, rows: nil}
    end
  end

  defp maybe_cap_aggregate_rows(rows, view_meta, params) when is_list(rows) do
    if AggregateOptions.aggregate_view_mode?(params) do
      total_rows = length(rows)

      case AggregateOptions.max_client_rows() do
        :infinity ->
          {
            rows,
            Map.merge(view_meta, %{
              aggregate_rows_capped?: false,
              aggregate_total_rows_before_cap: total_rows,
              aggregate_max_client_rows: :infinity
            })
          }

        max_client_rows when is_integer(max_client_rows) and total_rows > max_client_rows ->
          {
            Enum.take(rows, max_client_rows),
            Map.merge(view_meta, %{
              aggregate_rows_capped?: true,
              aggregate_total_rows_before_cap: total_rows,
              aggregate_max_client_rows: max_client_rows
            })
          }

        max_client_rows when is_integer(max_client_rows) ->
          {
            rows,
            Map.merge(view_meta, %{
              aggregate_rows_capped?: false,
              aggregate_total_rows_before_cap: total_rows,
              aggregate_max_client_rows: max_client_rows
            })
          }

        _other ->
          {rows, view_meta}
      end
    else
      {rows, view_meta}
    end
  end

  defp maybe_cap_aggregate_rows(rows, view_meta, _params), do: {rows, view_meta}

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

  defp execute_raw_query(selecto, query, params) do
    DBSupport.execute_raw_query(selecto, query, params)
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

  defp normalize_rows_for_view(rows, _columns, "detail")
       when is_list(rows) and rows != [] and (is_list(hd(rows)) or is_tuple(hd(rows))) do
    rows
    |> Enum.map(fn row ->
      if is_tuple(row), do: Tuple.to_list(row), else: row
    end)
    |> QueryResults.normalize_rows()
  end

  defp normalize_rows_for_view(rows, _columns, _view_mode), do: QueryResults.normalize_rows(rows)

  @doc """
  Build view_config from URL params, updating only filter state.
  """
  def filter_params_to_state(params, socket) do
    params
    |> Codec.filter_params_to_view_config(socket)
    |> then(&assign_view_config(socket, &1))
  end

  @doc """
  Build view_config from URL params, updating full state including view-specific configs.
  """
  def params_to_state(params, socket) do
    params
    |> Codec.params_to_view_config(socket)
    |> then(&assign_view_config(socket, &1))
  end

  @doc """
  Build view_config from a submitted form payload.

  Unlike URL params, the form payload contains inputs for all rendered view tabs,
  so every view can be reconstructed from the browser state in one pass.
  """
  def form_params_to_state(params, socket) do
    params
    |> Codec.form_params_to_view_config(socket)
    |> then(&assign_view_config(socket, &1))
  end

  @doc """
  Restore a saved-view payload into socket state.
  """
  def saved_params_to_state(saved_params, socket) do
    saved_params
    |> Codec.saved_params_to_view_config(socket)
    |> then(&assign_view_config(socket, &1))
  end

  def sync_view_config_ctes(view_config, %Selecto{} = selecto) when is_map(view_config) do
    derived_names = derived_cte_names_from_view_config(view_config, selecto)
    existing_ctes = get_map_value(view_config, :ctes, [])
    synced_ctes = build_cte_entries(derived_names, existing_ctes)

    Map.put(view_config, :ctes, synced_ctes)
  end

  def sync_view_config_ctes(view_config, _selecto), do: view_config

  def apply_ctes_for_params(selecto, params), do: maybe_apply_ctes(selecto, params)

  def execute_query_for_plan(selecto, params, view_meta, socket),
    do: execute_query_with_detail_pagination(selecto, params, view_meta, socket)

  def cap_aggregate_rows_for_result(rows, view_meta, params),
    do: maybe_cap_aggregate_rows(rows, view_meta, params)

  def normalize_rows_for_result(rows, columns, view_mode),
    do: normalize_rows_for_view(rows, columns, view_mode)

  def build_query_cache_debug_info_for_result(detail_cache, params, rows, columns, aliases),
    do: build_query_cache_debug_info(detail_cache, params, rows, columns, aliases)

  def drop_runtime_only_params_public(params), do: drop_runtime_only_params(params)

  def execution_error_opts_public(error, params, extra_opts),
    do: execution_error_opts(error, params, extra_opts)

  def get_map_value_public(map, key, default \\ nil), do: get_map_value(map, key, default)

  def assign_view_config(socket, view_config) do
    SessionStore.assign_view_config(socket, view_config)
  end

  def mark_form_state_applied(socket) do
    SessionStore.mark_form_state_applied(socket)
  end

  def canonicalize_form_params(params, selecto \\ nil, presentation_context \\ %{})

  def canonicalize_form_params(params, selecto, presentation_context) when is_map(params) do
    params =
      params
      |> merge_promoted_filter_params(selecto, presentation_context)
      |> canonicalize_filter_params(selecto, presentation_context)

    row_click_action =
      normalize_optional_scalar(get_map_value(params, "row_click_action_ui")) ||
        normalize_optional_scalar(get_map_value(params, "row_click_action"))

    if is_nil(row_click_action) do
      params
    else
      Map.put(params, "row_click_action", row_click_action)
    end
  end

  def canonicalize_form_params(params, _selecto, _presentation_context), do: params

  defp merge_promoted_filter_params(params, _selecto, _presentation_context)
       when not is_map(params),
       do: params

  defp merge_promoted_filter_params(params, selecto, presentation_context) do
    case {Map.get(params, "filters"), Map.get(params, "promoted_filters")} do
      {filters, promoted_filters} when is_map(filters) and is_map(promoted_filters) ->
        merged_filters =
          Enum.reduce(promoted_filters, filters, fn
            {uuid, promoted_values}, acc when is_binary(uuid) and is_map(promoted_values) ->
              current_filter = Map.get(acc, uuid, %{})

              normalized_values =
                normalize_promoted_filter_values(
                  current_filter,
                  promoted_values,
                  selecto,
                  presentation_context
                )

              Map.put(
                acc,
                uuid,
                Map.merge(
                  current_filter,
                  Map.take(normalized_values, [
                    "value",
                    "display_value",
                    "value_start",
                    "display_value_start",
                    "value_end",
                    "display_value_end",
                    "value2",
                    "display_value2",
                    "mode"
                  ])
                )
              )

            _, acc ->
              acc
          end)

        params
        |> Map.put("filters", merged_filters)
        |> Map.delete("promoted_filters")

      _ ->
        params
    end
  end

  defp normalize_promoted_filter_values(
         current_filter,
         promoted_values,
         selecto,
         _presentation_context
       ) do
    comp =
      current_filter
      |> get_map_value("comp", "=")
      |> to_string()
      |> String.trim()
      |> String.upcase()

    filter_id = get_map_value(current_filter, "filter")
    column = resolve_filter_column(selecto, filter_id)

    cond do
      comp in ["IN", "NOT IN"] and locale_sensitive_in_filter_column?(column) ->
        normalized_display_value =
          normalize_locale_sensitive_multi_value_input(Map.get(promoted_values, "value"))

        promoted_values
        |> Map.put("value", normalized_display_value)
        |> Map.put("display_value", normalized_display_value)

      comp in ["IN", "NOT IN"] ->
        Map.put(
          promoted_values,
          "value",
          normalize_promoted_multi_value(Map.get(promoted_values, "value"))
        )

      true ->
        promoted_values
    end
  end

  defp canonicalize_filter_params(params, nil, _presentation_context), do: params

  defp canonicalize_filter_params(params, selecto, presentation_context) when is_map(params) do
    if valid_selecto_for_filter_canonicalization?(selecto) do
      case Map.get(params, "filters") do
        filters when is_map(filters) ->
          normalized_filters =
            Enum.into(filters, %{}, fn {uuid, filter} ->
              {uuid, canonicalize_filter_map(filter, selecto, presentation_context)}
            end)

          Map.put(params, "filters", normalized_filters)

        _ ->
          params
      end
    else
      params
    end
  end

  defp valid_selecto_for_filter_canonicalization?(%Selecto{config: config}) when is_map(config),
    do: true

  defp valid_selecto_for_filter_canonicalization?(_), do: false

  defp canonicalize_filter_map(filter, _selecto, _presentation_context) when not is_map(filter),
    do: filter

  defp canonicalize_filter_map(filter, selecto, presentation_context) do
    filter_id = get_map_value(filter, "filter")
    column = resolve_filter_column(selecto, filter_id)

    cond do
      is_nil(column) ->
        filter

      Selecto.Presentation.measurement?(column) ->
        canonicalize_measurement_filter(filter, column, presentation_context)

      Selecto.Presentation.temporal?(column) or Selecto.Temporal.date_like?(column) ->
        canonicalize_temporal_filter(filter, column, presentation_context)

      locale_numeric_column?(column) ->
        canonicalize_numeric_filter(filter, presentation_context)

      true ->
        filter
    end
  end

  defp resolve_filter_column(nil, _filter_id), do: nil
  defp resolve_filter_column(_selecto, nil), do: nil

  defp resolve_filter_column(selecto, filter_id) do
    Selecto.columns(selecto)[filter_id] ||
      Enum.find_value(Selecto.columns(selecto), fn {_key, col} ->
        if col.colid == filter_id or to_string(col.colid) == filter_id or col.name == filter_id,
          do: col,
          else: nil
      end) || Selecto.field(selecto, filter_id)
  end

  defp canonicalize_measurement_filter(filter, column, presentation_context) do
    display_unit = Presentation.display_unit(column, presentation_context)
    canonical_unit = Selecto.Presentation.canonical_unit(column)
    comp = normalize_filter_comp(filter)

    if comp in ["IN", "NOT IN"] do
      canonicalize_measurement_multi_value_filter(
        filter,
        display_unit,
        canonical_unit,
        presentation_context
      )
    else
      filter
      |> maybe_put_display_value("value")
      |> maybe_put_display_value("value_start")
      |> maybe_put_display_value("value_end")
      |> maybe_put_display_value("value2")
      |> maybe_canonicalize_measurement_key(
        "value",
        comp,
        display_unit,
        canonical_unit,
        presentation_context
      )
      |> maybe_canonicalize_measurement_key(
        "value_start",
        comp,
        display_unit,
        canonical_unit,
        presentation_context
      )
      |> maybe_canonicalize_measurement_key(
        "value_end",
        comp,
        display_unit,
        canonical_unit,
        presentation_context
      )
      |> maybe_canonicalize_measurement_key(
        "value2",
        comp,
        display_unit,
        canonical_unit,
        presentation_context
      )
    end
  end

  defp maybe_canonicalize_measurement_key(
         filter,
         _key,
         comp,
         _display_unit,
         _canonical_unit,
         _presentation_context
       )
       when comp in [
              "SHORTCUT",
              "RELATIVE",
              "IS NULL",
              "IS NOT NULL",
              "WEEKDAY",
              "WEEKDAY_SUN1",
              "WEEK_OF_YEAR",
              "MONTH_OF_YEAR",
              "DAY_OF_MONTH",
              "HOUR_OF_DAY"
            ] do
    filter
  end

  defp maybe_canonicalize_measurement_key(
         filter,
         key,
         _comp,
         display_unit,
         canonical_unit,
         presentation_context
       ) do
    case convert_measurement_filter_value(
           canonicalization_source_value(filter, key),
           display_unit,
           canonical_unit,
           presentation_context
         ) do
      {:ok, converted} -> Map.put(filter, key, converted)
      :skip -> filter
    end
  end

  defp convert_measurement_filter_value(
         value,
         _display_unit,
         _canonical_unit,
         _presentation_context
       )
       when value in [nil, ""],
       do: :skip

  defp convert_measurement_filter_value(value, display_unit, canonical_unit, presentation_context) do
    case split_measurement_value(value) do
      {numeric, suffix} ->
        with number when not is_nil(number) <-
               Presentation.parse_number(numeric, presentation_context),
             true <- suffix in [nil, "", measurement_unit_label(display_unit)],
             converted when not is_nil(converted) <-
               maybe_convert_measurement_to_canonical(number, display_unit, canonical_unit) do
          {:ok, float_to_filter_string(converted)}
        else
          _ -> :skip
        end
    end
  end

  defp split_measurement_value(value) when is_binary(value) do
    case Regex.run(~r/^\s*([-+]?[0-9][0-9\s.,'’  ]*[0-9]|[-+]?[0-9])\s*([^0-9\s].*)?\s*$/u, value) do
      [_, number] -> {number, nil}
      [_, number, suffix] -> {number, String.trim(suffix)}
      _ -> {String.trim(value), nil}
    end
  end

  defp split_measurement_value(value), do: {to_string(value), nil}

  defp float_to_filter_string(value) when is_float(value) do
    value
    |> Float.round(12)
    |> :erlang.float_to_binary(decimals: 12)
    |> String.trim_trailing("0")
    |> String.trim_trailing(".")
  end

  defp measurement_unit_label(unit) do
    case Presentation.display_unit_label(
           %{presentation: %{default_unit: unit, canonical_unit: unit}},
           %{}
         ) do
      nil -> nil
      label -> String.trim(label)
    end
  end

  defp measurement_to_canonical(value, :fahrenheit, :celsius), do: (value - 32) * 5 / 9
  defp measurement_to_canonical(value, :kelvin, :celsius), do: value - 273.15
  defp measurement_to_canonical(value, :celsius, :fahrenheit), do: value * 9 / 5 + 32
  defp measurement_to_canonical(value, :celsius, :kelvin), do: value + 273.15

  defp measurement_to_canonical(value, display_unit, canonical_unit)
       when display_unit == canonical_unit, do: value

  defp measurement_to_canonical(value, display_unit, canonical_unit) do
    with {:ok, display_factor} <- measurement_factor(display_unit),
         {:ok, canonical_factor} <- measurement_factor(canonical_unit) do
      value * display_factor / canonical_factor
    else
      _ -> nil
    end
  end

  defp measurement_factor(:millimeter), do: {:ok, 0.001}
  defp measurement_factor(:centimeter), do: {:ok, 0.01}
  defp measurement_factor(:meter), do: {:ok, 1.0}
  defp measurement_factor(:kilometer), do: {:ok, 1000.0}
  defp measurement_factor(:inch), do: {:ok, 0.0254}
  defp measurement_factor(:foot), do: {:ok, 0.3048}
  defp measurement_factor(:yard), do: {:ok, 0.9144}
  defp measurement_factor(:mile), do: {:ok, 1609.344}
  defp measurement_factor(:gram), do: {:ok, 1.0}
  defp measurement_factor(:kilogram), do: {:ok, 1000.0}
  defp measurement_factor(:ounce), do: {:ok, 28.349523125}
  defp measurement_factor(:pound), do: {:ok, 453.59237}
  defp measurement_factor(:milliliter), do: {:ok, 0.001}
  defp measurement_factor(:liter), do: {:ok, 1.0}
  defp measurement_factor(:fluid_ounce), do: {:ok, 0.0295735295625}
  defp measurement_factor(:gallon), do: {:ok, 3.785411784}
  defp measurement_factor(:square_meter), do: {:ok, 1.0}
  defp measurement_factor(:square_foot), do: {:ok, 0.09290304}
  defp measurement_factor(:acre), do: {:ok, 4046.8564224}
  defp measurement_factor(:hectare), do: {:ok, 10000.0}
  defp measurement_factor(:meter_per_second), do: {:ok, 1.0}
  defp measurement_factor(:kilometer_per_hour), do: {:ok, 0.2777777778}
  defp measurement_factor(:mile_per_hour), do: {:ok, 0.44704}
  defp measurement_factor(_unit), do: :error

  defp maybe_convert_measurement_to_canonical(value, display_unit, canonical_unit)
       when is_nil(display_unit) or is_nil(canonical_unit) or display_unit == canonical_unit,
       do: value

  defp maybe_convert_measurement_to_canonical(value, display_unit, canonical_unit),
    do: measurement_to_canonical(value, display_unit, canonical_unit)

  defp canonicalize_numeric_filter(filter, presentation_context) do
    comp = normalize_filter_comp(filter)

    if comp in ["IN", "NOT IN"] do
      canonicalize_numeric_multi_value_filter(filter, presentation_context)
    else
      filter
      |> maybe_put_display_value("value")
      |> maybe_put_display_value("value_start")
      |> maybe_put_display_value("value_end")
      |> maybe_put_display_value("value2")
      |> maybe_canonicalize_numeric_key("value", comp, presentation_context)
      |> maybe_canonicalize_numeric_key("value_start", comp, presentation_context)
      |> maybe_canonicalize_numeric_key("value_end", comp, presentation_context)
      |> maybe_canonicalize_numeric_key("value2", comp, presentation_context)
    end
  end

  defp maybe_canonicalize_numeric_key(filter, _key, comp, _presentation_context)
       when comp in [
              "SHORTCUT",
              "RELATIVE",
              "IS NULL",
              "IS NOT NULL",
              "WEEKDAY",
              "WEEKDAY_SUN1",
              "WEEK_OF_YEAR",
              "MONTH_OF_YEAR",
              "DAY_OF_MONTH",
              "HOUR_OF_DAY"
            ] do
    filter
  end

  defp maybe_canonicalize_numeric_key(filter, key, _comp, presentation_context) do
    case canonicalization_source_value(filter, key) do
      value when value in [nil, ""] ->
        filter

      value ->
        case Presentation.parse_number(value, presentation_context) do
          number when is_float(number) -> Map.put(filter, key, float_to_filter_string(number))
          _ -> filter
        end
    end
  end

  defp locale_numeric_column?(column) when is_map(column) do
    normalized_type = Selecto.Temporal.date_like_type(column) || Map.get(column, :type)
    normalized_type in [:integer, :float, :decimal]
  end

  defp locale_numeric_column?(_column), do: false

  defp locale_sensitive_in_filter_column?(column) when is_map(column) do
    Selecto.Presentation.measurement?(column) or locale_numeric_column?(column)
  end

  defp locale_sensitive_in_filter_column?(_column), do: false

  defp canonicalize_measurement_multi_value_filter(
         filter,
         display_unit,
         canonical_unit,
         presentation_context
       ) do
    with {display_tokens, source} when display_tokens != [] <-
           multi_value_tokens_for_locale_aware_filter(filter),
         canonical_tokens when canonical_tokens != :error <-
           map_multi_value_tokens_while(display_tokens, fn token ->
             case convert_measurement_filter_value(
                    token,
                    display_unit,
                    canonical_unit,
                    presentation_context
                  ) do
               {:ok, converted} -> {:cont, converted}
               :skip -> {:halt, :error}
             end
           end) do
      filter
      |> Map.put("value", Enum.join(canonical_tokens, ","))
      |> maybe_put_multi_value_display(source, display_tokens)
    else
      _ -> filter
    end
  end

  defp canonicalize_numeric_multi_value_filter(filter, presentation_context) do
    with {display_tokens, source} when display_tokens != [] <-
           multi_value_tokens_for_locale_aware_filter(filter),
         canonical_tokens when canonical_tokens != :error <-
           map_multi_value_tokens_while(display_tokens, fn token ->
             case Presentation.parse_number(token, presentation_context) do
               number when is_float(number) -> {:cont, float_to_filter_string(number)}
               _ -> {:halt, :error}
             end
           end) do
      filter
      |> Map.put("value", Enum.join(canonical_tokens, ","))
      |> maybe_put_multi_value_display(source, display_tokens)
    else
      _ -> filter
    end
  end

  defp multi_value_tokens_for_locale_aware_filter(filter) when is_map(filter) do
    cond do
      is_binary(Map.get(filter, "display_value")) ->
        {multi_value_display_tokens(Map.get(filter, "display_value"), true), :display}

      is_binary(Map.get(filter, :display_value)) ->
        {multi_value_display_tokens(Map.get(filter, :display_value), true), :display}

      true ->
        {multi_value_display_tokens(Map.get(filter, "value") || Map.get(filter, :value), false),
         :value}
    end
  end

  defp multi_value_tokens_for_locale_aware_filter(_filter), do: {[], :value}

  defp multi_value_display_tokens(values, _preserve_commas?) when is_list(values) do
    values
    |> Enum.map(&to_string/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp multi_value_display_tokens(values, preserve_commas?) when is_binary(values) do
    normalized = String.replace(values, ~r/\r\n|\r/, "\n")

    cond do
      normalized == "" ->
        []

      String.contains?(normalized, "\n") ->
        normalized
        |> String.split("\n")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))

      String.contains?(normalized, ";") ->
        normalized
        |> String.split(";")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))

      preserve_commas? ->
        [String.trim(normalized)]
        |> Enum.reject(&(&1 == ""))

      true ->
        normalized
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
    end
  end

  defp multi_value_display_tokens(_values, _preserve_commas?), do: []

  defp maybe_put_multi_value_display(filter, :display, display_tokens) do
    Map.put(filter, "display_value", Enum.join(display_tokens, "\n"))
  end

  defp maybe_put_multi_value_display(filter, _source, _display_tokens), do: filter

  defp map_multi_value_tokens_while(tokens, mapper)
       when is_list(tokens) and is_function(mapper, 1) do
    Enum.reduce_while(tokens, [], fn token, acc ->
      case mapper.(token) do
        {:cont, value} -> {:cont, [value | acc]}
        {:halt, value} -> {:halt, value}
      end
    end)
    |> case do
      :error -> :error
      values when is_list(values) -> Enum.reverse(values)
    end
  end

  defp canonicalize_temporal_filter(filter, column, presentation_context) do
    comp = normalize_filter_comp(filter)
    timezone = presentation_timezone(presentation_context)

    filter
    |> maybe_put_display_value("value")
    |> maybe_put_display_value("value_start")
    |> maybe_put_display_value("value_end")
    |> maybe_put_display_value("value2")
    |> maybe_canonicalize_temporal_key("value", comp, column, timezone)
    |> maybe_canonicalize_temporal_key("value_start", comp, column, timezone)
    |> maybe_canonicalize_temporal_key("value_end", comp, column, timezone)
    |> maybe_canonicalize_temporal_key("value2", comp, column, timezone)
  end

  defp maybe_canonicalize_temporal_key(filter, _key, comp, _column, _timezone)
       when comp in [
              "SHORTCUT",
              "RELATIVE",
              "WEEKDAY",
              "WEEKDAY_SUN1",
              "WEEK_OF_YEAR",
              "MONTH_OF_YEAR",
              "DAY_OF_MONTH",
              "HOUR_OF_DAY",
              "DATE=",
              "DATE!=",
              "DATE_BETWEEN"
            ] do
    filter
  end

  defp maybe_canonicalize_temporal_key(filter, key, _comp, column, timezone) do
    case local_input_to_utc_string(canonicalization_source_value(filter, key), column, timezone) do
      nil -> filter
      converted -> Map.put(filter, key, converted)
    end
  end

  defp local_input_to_utc_string(value, column, timezone) when is_binary(value) do
    if Selecto.Presentation.temporal_kind(column) == :instant do
      trimmed = String.trim(value)

      cond do
        trimmed == "" ->
          nil

        match?({:ok, _}, NaiveDateTime.from_iso8601(trimmed)) ->
          {:ok, naive} = NaiveDateTime.from_iso8601(trimmed)
          timezone_naive_to_utc_string(naive, timezone)

        match?({:ok, _}, NaiveDateTime.from_iso8601(trimmed <> ":00")) ->
          {:ok, naive} = NaiveDateTime.from_iso8601(trimmed <> ":00")
          timezone_naive_to_utc_string(naive, timezone)

        String.contains?(trimmed, " ") and
            match?({:ok, _}, NaiveDateTime.from_iso8601(String.replace(trimmed, " ", "T"))) ->
          {:ok, naive} = trimmed |> String.replace(" ", "T") |> NaiveDateTime.from_iso8601()
          timezone_naive_to_utc_string(naive, timezone)

        String.contains?(trimmed, " ") and
            match?(
              {:ok, _},
              NaiveDateTime.from_iso8601(String.replace(trimmed, " ", "T") <> ":00")
            ) ->
          {:ok, naive} =
            trimmed
            |> String.replace(" ", "T")
            |> Kernel.<>(":00")
            |> NaiveDateTime.from_iso8601()

          timezone_naive_to_utc_string(naive, timezone)

        true ->
          nil
      end
    end
  end

  defp local_input_to_utc_string(_value, _column, _timezone), do: nil

  defp timezone_naive_to_utc_string(naive, timezone) do
    case DateTime.from_naive(naive, timezone) do
      {:ok, datetime} ->
        datetime
        |> DateTime.shift_zone!("Etc/UTC")
        |> DateTime.to_iso8601()

      {:ambiguous, datetime, _other} ->
        datetime
        |> DateTime.shift_zone!("Etc/UTC")
        |> DateTime.to_iso8601()

      _ ->
        nil
    end
  end

  defp presentation_timezone(context) do
    context
    |> Presentation.resolve_context()
    |> Map.get(:timezone, "Etc/UTC")
  end

  defp normalize_filter_comp(filter) do
    filter
    |> get_map_value("comp", "=")
    |> to_string()
    |> String.trim()
    |> String.upcase()
  end

  defp maybe_put_display_value(filter, key) do
    case Map.get(filter, key) do
      nil -> filter
      value -> Map.put_new(filter, "display_#{key}", value)
    end
  end

  defp canonicalization_source_value(filter, key) when is_map(filter) do
    Map.get(filter, "display_#{key}") || Map.get(filter, key)
  end

  defp normalize_locale_sensitive_multi_value_input(value) when is_binary(value) do
    normalized = String.replace(value, ~r/\r\n|\r/, "\n")

    cond do
      String.contains?(normalized, "\n") ->
        normalized
        |> String.split("\n")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.join("\n")

      String.contains?(normalized, ";") ->
        normalized
        |> String.split(";")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.join("\n")

      true ->
        String.trim(normalized)
    end
  end

  defp normalize_locale_sensitive_multi_value_input(value), do: value

  defp normalize_promoted_multi_value(value) when is_binary(value) do
    value
    |> String.split(~r/[\r\n,]+/)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(",")
  end

  defp normalize_promoted_multi_value(value) when is_list(value) do
    value
    |> Enum.map(&to_string/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(",")
  end

  defp normalize_promoted_multi_value(value), do: value

  @doc """
  Normalize submitted form params so submit uses the browser form state as truth.
  """
  def submitted_form_params(params) when is_map(params) do
    params
    |> canonicalize_form_params()
    |> drop_unused_form_params()
    |> normalize_submitted_boolean_param("prevent_denormalization")
  end

  def submitted_form_params(params), do: params

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
      "view_mode" => view_type,
      "ctes" => ctes_to_params(get_map_value(saved_params, :ctes, []))
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
    view_type_str = to_string(view_type)

    params =
      if view_type_str == "aggregate" do
        params
        |> Map.put(
          "aggregate_per_page",
          AggregateOptions.normalize_per_page_param(get_map_value(view_config, :per_page, "100"))
        )
        |> Map.put("aggregate_grid", to_string(get_map_value(view_config, :grid, false)))
        |> Map.put(
          "aggregate_grid_colorize",
          to_string(get_map_value(view_config, :grid_colorize, false))
        )
        |> Map.put(
          "aggregate_grid_color_scale",
          AggregateOptions.normalize_grid_color_scale_mode(
            get_map_value(
              view_config,
              :grid_color_scale,
              AggregateOptions.default_grid_color_scale_mode()
            )
          )
        )
      else
        Map.put(params, "per_page", to_string(get_map_value(view_config, :per_page, "30")))
      end

    params =
      if view_type_str == "detail" do
        params
        |> Map.put(
          "max_rows",
          DetailOptions.normalize_max_rows_param(get_map_value(view_config, :max_rows, "1000"))
        )
        |> Map.put(
          "count_mode",
          DetailOptions.normalize_count_mode_param(
            get_map_value(view_config, :count_mode, DetailOptions.default_count_mode())
          )
        )
        |> maybe_put_param(
          "row_click_action",
          normalize_optional_scalar(get_map_value(view_config, :row_click_action))
        )
      else
        params
      end

    params =
      if view_type_str == "map" do
        map_config =
          view_config
          |> get_map_value(:map_view, %{})
          |> Map.merge(view_config)

        merge_saved_map_params(params, map_config)
      else
        params
      end

    Map.put(
      params,
      "prevent_denormalization",
      to_string(get_map_value(view_config, :prevent_denormalization, true))
    )
  end

  defp merge_saved_map_params(params, map_config) do
    params_with_center = maybe_put_center_params(params, get_map_value(map_config, :center))

    params_with_layers =
      maybe_put_param(
        params_with_center,
        "map_layers",
        normalize_map_layers_param(get_map_value(map_config, :map_layers))
      )

    Enum.reduce(@map_param_keys, params_with_layers, fn param_key, acc ->
      maybe_put_param(
        acc,
        param_key,
        normalize_map_param_value(param_key, get_map_value(map_config, param_key))
      )
    end)
  end

  defp normalize_map_layers_param(nil), do: nil

  defp normalize_map_layers_param(layers) when is_list(layers) do
    layers
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {layer, index}, acc ->
      Map.put(acc, Integer.to_string(index), normalize_map_layer_param(layer))
    end)
  end

  defp normalize_map_layers_param(layers) when is_map(layers) do
    layers
    |> Enum.sort_by(fn {key, _value} ->
      case Integer.parse(to_string(key)) do
        {parsed, ""} -> parsed
        _ -> 999
      end
    end)
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {{_key, layer}, index}, acc ->
      Map.put(acc, Integer.to_string(index), normalize_map_layer_param(layer))
    end)
  end

  defp normalize_map_layers_param(_), do: nil

  defp normalize_map_layer_param(layer) when is_map(layer) do
    %{}
    |> maybe_put_param("label", normalize_map_scalar(get_map_value(layer, :label)))
    |> maybe_put_param(
      "geometry_field",
      normalize_map_scalar(get_map_value(layer, :geometry_field))
    )
    |> maybe_put_param(
      "geometry_kind",
      normalize_map_scalar(get_map_value(layer, :geometry_kind))
    )
    |> maybe_put_param("popup_field", normalize_map_scalar(get_map_value(layer, :popup_field)))
    |> maybe_put_param("color_field", normalize_map_scalar(get_map_value(layer, :color_field)))
    |> maybe_put_param("scale_type", normalize_map_scalar(get_map_value(layer, :scale_type)))
    |> maybe_put_param(
      "scale_palette",
      normalize_map_scalar(get_map_value(layer, :scale_palette))
    )
    |> maybe_put_param("scale_steps", normalize_map_scalar(get_map_value(layer, :scale_steps)))
    |> maybe_put_param(
      "scale_categories",
      normalize_map_scalar(get_map_value(layer, :scale_categories))
    )
    |> maybe_put_param("track_by", normalize_map_scalar(get_map_value(layer, :track_by)))
    |> maybe_put_param(
      "track_order_field",
      normalize_map_scalar(get_map_value(layer, :track_order_field))
    )
    |> maybe_put_param("point_radius", normalize_map_scalar(get_map_value(layer, :point_radius)))
    |> maybe_put_param("line_weight", normalize_map_scalar(get_map_value(layer, :line_weight)))
    |> maybe_put_param(
      "line_dash_array",
      normalize_map_scalar(get_map_value(layer, :line_dash_array))
    )
    |> maybe_put_param("fill_opacity", normalize_map_scalar(get_map_value(layer, :fill_opacity)))
    |> maybe_put_param(
      "stroke_opacity",
      normalize_map_scalar(get_map_value(layer, :stroke_opacity))
    )
    |> maybe_put_param("visible", normalize_map_boolean(get_map_value(layer, :visible)))
  end

  defp normalize_map_layer_param(_), do: %{}

  defp maybe_put_center_params(params, center_value) do
    case parse_center_value(center_value) do
      {lat, lng} ->
        params
        |> maybe_put_param("center_lat", normalize_map_param_value("center_lat", lat), false)
        |> maybe_put_param("center_lng", normalize_map_param_value("center_lng", lng), false)

      _ ->
        params
    end
  end

  defp parse_center_value({lat, lng}), do: {lat, lng}
  defp parse_center_value([lat, lng]), do: {lat, lng}

  defp parse_center_value(center_value) when is_map(center_value) do
    {get_map_value(center_value, :lat), get_map_value(center_value, :lng)}
  end

  defp parse_center_value(center_value) when is_binary(center_value) do
    case String.split(center_value, ",", parts: 2) do
      [lat, lng] -> {lat, lng}
      _ -> nil
    end
  end

  defp parse_center_value(_), do: nil

  defp maybe_put_param(params, _key, nil, _replace?), do: params

  defp maybe_put_param(params, key, value, true), do: Map.put(params, key, value)

  defp maybe_put_param(params, key, value, false) do
    if Map.has_key?(params, key), do: params, else: Map.put(params, key, value)
  end

  defp maybe_put_param(params, key, value), do: maybe_put_param(params, key, value, true)

  defp map_param_key(key) when is_atom(key), do: map_param_key(Atom.to_string(key))

  defp map_param_key(key) when is_binary(key) do
    if key in @map_param_keys, do: key, else: nil
  end

  defp map_param_key(_), do: nil

  defp normalize_map_param_value(key, value) when key in @map_boolean_param_keys do
    normalize_map_boolean(value)
  end

  defp normalize_map_param_value("image_overlay_bounds", value) do
    normalize_map_bounds(value)
  end

  defp normalize_map_param_value(_key, value), do: normalize_map_scalar(value)

  defp normalize_map_bounds(nil), do: nil

  defp normalize_map_bounds([[south, west], [north, east]]) do
    values = [south, west, north, east] |> Enum.map(&normalize_map_scalar/1)

    if Enum.any?(values, &is_nil/1), do: nil, else: Enum.join(values, ",")
  end

  defp normalize_map_bounds([south, west, north, east]) do
    values = [south, west, north, east] |> Enum.map(&normalize_map_scalar/1)

    if Enum.any?(values, &is_nil/1), do: nil, else: Enum.join(values, ",")
  end

  defp normalize_map_bounds(value) when is_binary(value) do
    normalize_map_scalar(value)
  end

  defp normalize_map_bounds(_value), do: nil

  defp normalize_map_boolean(value) when value in [true, "true", "on", "1", 1], do: "true"
  defp normalize_map_boolean(value) when value in [false, "false", "off", "0", 0], do: "false"
  defp normalize_map_boolean(_value), do: nil

  defp normalize_map_scalar(nil), do: nil

  defp normalize_map_scalar(value) when is_binary(value) do
    trimmed = String.trim(value)
    if trimmed == "", do: nil, else: trimmed
  end

  defp normalize_map_scalar(value) when is_atom(value),
    do: value |> Atom.to_string() |> normalize_map_scalar()

  defp normalize_map_scalar(value) when is_integer(value), do: Integer.to_string(value)

  defp normalize_map_scalar(value) when is_float(value),
    do: value |> Float.round(6) |> to_string()

  defp normalize_map_scalar(value) when is_boolean(value), do: to_string(value)
  defp normalize_map_scalar(_value), do: nil

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
  def state_to_url(params, socket, opts \\ []) do
    params =
      params
      |> compact_url_params()
      |> merge_passthrough_url_params(socket)

    params_encoded = Plug.Conn.Query.encode(params)
    my_path = socket.assigns.my_path
    full_path = "#{my_path}?#{params_encoded}"

    Phoenix.LiveView.push_patch(socket, Keyword.merge([to: full_path], opts))
  end

  defp merge_passthrough_url_params(params, socket) do
    existing_params = Map.get(socket.assigns, :params, %{})

    passthrough_keys =
      ["selecto_theme", "selecto_debug", "debug", "debug_token"] ++
        normalize_passthrough_keys(Map.get(socket.assigns, :url_passthrough_params, []))

    passthrough_params =
      passthrough_keys
      |> Enum.uniq()
      |> Enum.reduce(%{}, fn key, acc ->
        case get_map_value(existing_params, key) do
          nil -> acc
          "" -> acc
          value -> Map.put(acc, to_string(key), value)
        end
      end)

    Map.merge(passthrough_params, params)
  end

  defp normalize_passthrough_keys(keys) when is_list(keys), do: Enum.map(keys, &to_string/1)
  defp normalize_passthrough_keys(_keys), do: []

  defp get_map_value(map, key, default \\ nil)

  defp get_map_value(map, key, default) when is_map(map) do
    Map.get(map, key, Map.get(map, to_string(key), default))
  end

  defp get_map_value(_map, _key, default), do: default

  @doc false
  def compact_url_params(params) when is_map(params) do
    Enum.reduce(url_compactable_keys(), params, fn key, acc ->
      case Map.get(acc, key) do
        section when is_map(section) -> Map.put(acc, key, compact_param_section(section))
        _ -> acc
      end
    end)
  end

  def compact_url_params(params), do: params

  defp compact_param_section(section) when is_map(section) do
    section
    |> Enum.sort_by(fn {_k, v} -> sort_index_for_compaction(v) end)
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {{original_key, value}, index}, acc ->
      compacted_value =
        case value do
          map when is_map(map) -> Map.put_new(map, "uuid", original_key)
          other -> other
        end

      Map.put(acc, compact_param_key(index), compacted_value)
    end)
  end

  defp url_compactable_keys do
    [
      "ctes",
      "filters",
      "selected",
      "order_by",
      "group_by",
      "aggregate",
      "x_axis",
      "y_axis",
      "series"
    ]
  end

  defp maybe_apply_ctes(selecto, params) when is_map(params) do
    explicit_names =
      params
      |> ctes_from_params([])
      |> Enum.map(&cte_entry_name/1)
      |> Enum.reject(&is_nil/1)

    derived_names = derived_cte_names_from_params(params, selecto)

    Enum.reduce(explicit_names ++ derived_names, selecto, fn
      name, acc when is_binary(name) and name != "" ->
        if name in SelectoComponents.Form.ColumnCatalog.available_cte_names(acc) and
             not cte_already_applied?(acc, name) do
          Selecto.with_cte(acc, name)
        else
          acc
        end

      _name, acc ->
        acc
    end)
  end

  defp maybe_apply_ctes(selecto, _params), do: selecto

  defp ctes_from_params(params, default) when is_map(params) do
    case Map.get(params, "ctes") do
      section when is_map(section) ->
        section
        |> Enum.sort_by(fn {_uuid, value} -> sort_index_for_compaction(value) end)
        |> Enum.map(fn {uuid, value} ->
          cte_uuid = get_map_value(value, :uuid, uuid)
          name = get_map_value(value, :name)

          {cte_uuid, name, Map.drop(stringify_map_keys(value), ["uuid", "name", "index"])}
        end)
        |> Enum.reject(fn {_uuid, name, _config} -> is_nil(name) or to_string(name) == "" end)

      _ ->
        default
    end
  end

  defp ctes_from_params(_params, default), do: default

  defp derived_cte_names_from_params(params, %Selecto{} = selecto) when is_map(params) do
    field_ids =
      params
      |> field_ids_from_params()
      |> Kernel.++(filter_ids_from_params(params))

    SelectoComponents.Form.ColumnCatalog.required_cte_names_for_fields(selecto, field_ids)
  end

  defp derived_cte_names_from_params(_params, _selecto), do: []

  defp derived_cte_names_from_view_config(view_config, %Selecto{} = selecto)
       when is_map(view_config) do
    field_ids =
      view_config
      |> field_ids_from_view_config()
      |> Kernel.++(filter_ids_from_view_config(view_config))

    SelectoComponents.Form.ColumnCatalog.required_cte_names_for_fields(selecto, field_ids)
  end

  defp derived_cte_names_from_view_config(_view_config, _selecto), do: []

  defp field_ids_from_params(params) when is_map(params) do
    ["selected", "order_by", "group_by", "aggregate", "x_axis", "y_axis", "series"]
    |> Enum.flat_map(fn section ->
      params
      |> Map.get(section, %{})
      |> list_field_ids_from_param_section()
    end)
  end

  defp field_ids_from_params(_params), do: []

  defp list_field_ids_from_param_section(section) when is_map(section) do
    section
    |> Map.values()
    |> Enum.map(&get_map_value(&1, :field))
    |> Enum.reject(&is_nil/1)
  end

  defp list_field_ids_from_param_section(_section), do: []

  defp filter_ids_from_params(params) when is_map(params) do
    params
    |> Map.get("filters", %{})
    |> Map.values()
    |> Enum.map(&get_map_value(&1, :filter))
    |> Enum.reject(&is_nil/1)
  end

  defp filter_ids_from_params(_params), do: []

  defp field_ids_from_view_config(view_config) when is_map(view_config) do
    view_config
    |> get_map_value(:views, %{})
    |> Map.values()
    |> Enum.flat_map(&field_ids_from_view_state/1)
  end

  defp field_ids_from_view_config(_view_config), do: []

  defp field_ids_from_view_state(view_state) when is_map(view_state) do
    [:selected, :order_by, :group_by, :aggregate, :x_axis, :y_axis, :series]
    |> Enum.flat_map(fn key ->
      view_state
      |> get_map_value(key, [])
      |> list_field_ids_from_items()
    end)
  end

  defp field_ids_from_view_state(_view_state), do: []

  defp list_field_ids_from_items(items) when is_list(items) do
    Enum.map(items, fn
      {_uuid, field, _config} -> field
      [_, field, _config] -> field
      _other -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp list_field_ids_from_items(_items), do: []

  defp filter_ids_from_view_config(view_config) when is_map(view_config) do
    view_config
    |> get_map_value(:filters, [])
    |> Enum.map(fn
      {_uuid, _section, filter_value} -> get_map_value(filter_value, :filter)
      [_, _, filter_value] -> get_map_value(filter_value, :filter)
      _other -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp filter_ids_from_view_config(_view_config), do: []

  defp build_cte_entries(names, existing_ctes) when is_list(names) do
    existing_by_name =
      Map.new(existing_ctes, fn entry ->
        case normalize_cte_entry(entry) do
          {uuid, name, config} -> {name, {uuid, name, config}}
          nil -> {nil, nil}
        end
      end)

    names
    |> Enum.uniq()
    |> Enum.map(fn name ->
      Map.get(existing_by_name, name, {"auto-cte-#{name}", name, %{}})
    end)
  end

  defp build_cte_entries(_names, _existing_ctes), do: []

  defp normalize_cte_entry({uuid, name, config}),
    do: {to_string(uuid), to_string(name), config || %{}}

  defp normalize_cte_entry([uuid, name, config]),
    do: {to_string(uuid), to_string(name), config || %{}}

  defp normalize_cte_entry(_entry), do: nil

  defp cte_entry_name({_, name, _}) when is_binary(name), do: name
  defp cte_entry_name([_, name, _]) when is_binary(name), do: name
  defp cte_entry_name(_entry), do: nil

  defp cte_already_applied?(%Selecto{} = selecto, name) do
    selecto
    |> get_in([Access.key(:set, %{}), Access.key(:ctes, [])])
    |> Enum.any?(fn spec ->
      spec_name =
        Map.get(spec, :name) ||
          Map.get(spec, :as) ||
          Map.get(spec, "name") ||
          Map.get(spec, "as")

      to_string(spec_name || "") == name
    end)
  end

  defp cte_already_applied?(_selecto, _name), do: false

  defp stringify_map_keys(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {to_string(key), value} end)
  end

  defp stringify_map_keys(_value), do: %{}

  defp sort_index_for_compaction(value) when is_map(value) do
    case Map.get(value, "index") do
      idx when is_binary(idx) ->
        case Integer.parse(idx) do
          {num, ""} -> num
          _ -> 0
        end

      idx when is_integer(idx) ->
        idx

      _ ->
        0
    end
  end

  defp sort_index_for_compaction(_value), do: 0

  defp drop_runtime_only_params(params) when is_map(params) do
    Map.delete(params, "_presentation_context")
  end

  defp drop_runtime_only_params(params), do: params

  defp drop_unused_form_params(params) when is_map(params) do
    params
    |> Enum.reject(fn {key, _value} ->
      key_str = to_string(key)

      String.starts_with?(key_str, "_unused_") or
        key_str in ["_target", "save_as", "_presentation_context"]
    end)
    |> Enum.into(%{}, fn {key, value} -> {key, drop_unused_form_params(value)} end)
  end

  defp drop_unused_form_params(params) when is_list(params) do
    Enum.map(params, &drop_unused_form_params/1)
  end

  defp drop_unused_form_params(params), do: params

  defp normalize_submitted_boolean_param(params, key) when is_map(params) do
    case Map.get(params, key) do
      value when value in ["on", "true", true] ->
        Map.put(params, key, "true")

      value when value in ["false", false] ->
        Map.put(params, key, "false")

      nil ->
        Map.delete(params, key)

      _other ->
        params
    end
  end
end
