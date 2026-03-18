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
  alias SelectoComponents.Performance.MetricsCollector
  alias SelectoComponents.DBSupport
  alias SelectoComponents.Views.Aggregate.Options, as: AggregateOptions
  alias SelectoComponents.Views.Detail.Options, as: DetailOptions
  alias SelectoComponents.Views.Detail.QueryPagination
  alias SelectoComponents.SubselectBuilder
  alias SelectoComponents.EnhancedTable.Sorting
  alias SelectoComponents.SafeAtom
  alias SelectoComponents.Views.Runtime, as: ViewRuntime
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
    filters = get_map_value(view_config, :filters, [])
    views = get_map_value(view_config, :views, %{})

    params = %{
      "view_mode" => view_mode,
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
  def view_config_to_saved_params(view_config) when is_map(view_config) do
    %{
      "view_mode" => get_map_value(view_config, :view_mode, "aggregate"),
      "filters" => normalize_saved_filters_for_storage(get_map_value(view_config, :filters, [])),
      "views" => normalize_saved_views_for_storage(get_map_value(view_config, :views, %{}))
    }
  end

  def view_config_to_saved_params(view_config), do: view_config

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
          "section" => section,
          "index" => to_string(index)
        }

      filter_map when is_map(filter_map) ->
        Map.merge(filter_map, %{
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

      f = normalize_filter_form_state(f)

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

  defp normalize_filter_form_state(filter) when is_map(filter) do
    comp = Map.get(filter, "comp") || Map.get(filter, :comp)
    value = Map.get(filter, "value") || Map.get(filter, :value)

    case comp do
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

      _ ->
        filter
    end
  end

  defp normalize_filter_form_state(filter), do: filter

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
    try do
      params = canonicalize_form_params(params)

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

      selecto =
        Selecto.configure(
          old_selecto.domain,
          old_selecto.postgrex_opts,
          adapter: old_selecto.adapter,
          validate: false
        )

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

      # Apply automatic retarget if needed
      view_mode = Map.get(params, "view_mode", "detail")
      selected_columns = SelectoComponents.Form.get_selected_columns_from_params(params)

      selecto =
        Selecto.AutoRetarget.maybe_apply(selecto,
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

      {query_result, view_meta, page_query_cache} =
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
                total_rows:
                  Map.get(
                    view_meta,
                    :total_rows,
                    Map.get(view_meta, :aggregate_total_rows, length(rows))
                  ),
                columns_count: length(columns),
                view_mode: socket.assigns.view_config.view_mode,
                has_filters: length(list_field(selecto.set, :filtered)) > 0,
                has_grouping: length(list_field(selecto.set, :group_by)) > 0,
                params: query_params
              }
            )
          end

          {rows_for_display, view_meta} = maybe_cap_aggregate_rows(rows, view_meta, params)

          normalized_rows =
            normalize_rows_for_view(
              rows_for_display,
              columns,
              socket.assigns.view_config.view_mode
            )

          # Check if any rows have subselect data
          # Debug inspection removed - data structure validated elsewhere

          view_meta = Map.merge(view_meta, %{exe_id: UUID.uuid4()})

          detail_cache_assignment =
            if DetailOptions.detail_view_mode?(params), do: page_query_cache, else: nil

          aggregate_cache_assignment =
            if AggregateOptions.aggregate_view_mode?(params), do: page_query_cache, else: nil

          cache_debug_info =
            build_query_cache_debug_info(
              detail_cache_assignment,
              params,
              normalized_rows,
              columns,
              aliases
            )

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
              aggregate_page_cache: aggregate_cache_assignment,
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
               detail_page_cache: detail_cache_assignment,
               aggregate_page_cache: aggregate_cache_assignment
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
            detail_page_cache:
              if(DetailOptions.detail_view_mode?(params), do: page_query_cache, else: nil),
            aggregate_page_cache:
              if(AggregateOptions.aggregate_view_mode?(params), do: page_query_cache, else: nil),
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
            detail_page_cache:
              if(DetailOptions.detail_view_mode?(params), do: page_query_cache, else: nil),
            aggregate_page_cache:
              if(AggregateOptions.aggregate_view_mode?(params), do: page_query_cache, else: nil),
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
          aggregate_page_cache: nil,
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
          aggregate_page_cache: nil,
          last_query_info: %{}
        )
    end
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

    if per_page_setting == "all" do
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
    {:ok, {cache, total_rows, %{sql: nil, params: [], execution_time: 0, cache_hit: true}}}
  end

  defp maybe_fetch_aggregate_total_rows(selecto, cache) do
    case execute_aggregate_total_rows(selecto) do
      {:ok, total_rows, count_metadata} ->
        {:ok, {Map.put(cache, :total_rows, total_rows), total_rows, count_metadata}}

      {:error, error} ->
        {:error, error}
    end
  end

  defp maybe_fetch_aggregate_page(selecto, cache, page, per_page) do
    case get_in(cache, [:pages, page]) do
      %{rows: rows, columns: columns, aliases: aliases} ->
        {:ok,
         {cache, rows, columns, aliases,
          %{sql: nil, params: [], execution_time: 0, cache_hit: true, pagination_mode: :cache}}}

      _ ->
        row_offset = page * per_page

        paged_selecto =
          selecto
          |> Selecto.limit(per_page)
          |> Selecto.offset(row_offset)

        case execute_query_with_metadata(paged_selecto) do
          {:ok, {rows, columns, aliases}, metadata} ->
            pages =
              cache
              |> Map.get(:pages, %{})
              |> Map.put(page, %{rows: rows, columns: columns, aliases: aliases})

            updated_cache = Map.put(cache, :pages, pages)

            {:ok,
             {updated_cache, rows, columns, aliases,
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
    Enum.map(rows, fn row ->
      if is_tuple(row), do: Tuple.to_list(row), else: row
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
    params = canonicalize_form_params(params)
    filters = view_filter_process(params, "filters")
    existing_config = socket.assigns[:view_config] || %{}

    selected_view =
      SafeAtom.to_view_mode(
        Map.get(params, "view_mode", existing_config[:view_mode] || "aggregate")
      )

    view_configs =
      Enum.reduce(socket.assigns.views, %{}, fn {view, _module, _name, _opt} = view_tuple, acc ->
        Map.merge(acc, %{
          view =>
            updated_view_state(view, selected_view, view_tuple, params, existing_config, socket)
        })
      end)
      |> preserve_missing_detail_view_params(existing_config, params)

    # Preserve existing view_config and only update what's in params
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
  Build view_config from a submitted form payload.

  Unlike URL params, the form payload contains inputs for all rendered view tabs,
  so every view can be reconstructed from the browser state in one pass.
  """
  def form_params_to_state(params, socket) do
    params = canonicalize_form_params(params)
    filters = view_filter_process(params, "filters")
    existing_config = socket.assigns[:view_config] || %{}

    view_configs =
      Enum.reduce(socket.assigns.views, %{}, fn {view, _module, _name, _opt} = view_tuple, acc ->
        Map.put(
          acc,
          view,
          submitted_view_state(view, view_tuple, params, existing_config, socket)
        )
      end)

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
  Restore a saved-view payload into socket state.
  """
  def saved_params_to_state(saved_params, socket) when is_map(saved_params) do
    if Map.has_key?(saved_params, "views") or Map.has_key?(saved_params, :views) do
      existing_config = socket.assigns[:view_config] || %{}

      restored_config = %{
        view_mode:
          get_map_value(
            saved_params,
            :view_mode,
            get_map_value(existing_config, :view_mode, "aggregate")
          ),
        filters: normalize_saved_filters_from_storage(get_map_value(saved_params, :filters, [])),
        views: restore_saved_views(saved_params, existing_config, socket)
      }

      Phoenix.Component.assign(socket, view_config: Map.merge(existing_config, restored_config))
    else
      params_to_state(saved_params, socket)
    end
  end

  def saved_params_to_state(saved_params, socket), do: params_to_state(saved_params, socket)

  defp submitted_view_state(view, view_tuple, params, existing_config, socket) do
    cond do
      view_params_present?(view, params) ->
        ViewRuntime.param_to_state(view_tuple, params)

      existing_view = get_in(existing_config, [:views, view]) ->
        existing_view

      selecto = socket.assigns[:selecto] ->
        ViewRuntime.initial_state(view_tuple, selecto)

      true ->
        %{}
    end
  end

  defp view_params_present?(view, params) when is_map(params) do
    view_param_keys(view)
    |> Enum.any?(fn key -> Map.has_key?(params, key) end)
  end

  defp view_params_present?(_view, _params), do: false

  defp view_param_keys(:detail),
    do: [
      "selected",
      "order_by",
      "per_page",
      "max_rows",
      "count_mode",
      "row_click_action",
      "prevent_denormalization"
    ]

  defp view_param_keys(:aggregate),
    do: [
      "group_by",
      "aggregate",
      "aggregate_per_page",
      "aggregate_grid",
      "aggregate_grid_colorize",
      "aggregate_grid_color_scale"
    ]

  defp view_param_keys(:graph), do: ["x_axis", "y_axis", "series", "chart_type", "options"]

  defp view_param_keys(:map), do: ["map_layers" | @map_param_keys]

  defp view_param_keys(_view), do: []

  defp updated_view_state(view, selected_view, view_tuple, params, existing_config, socket) do
    cond do
      view == selected_view ->
        ViewRuntime.param_to_state(view_tuple, params)

      existing_view = get_in(existing_config, [:views, view]) ->
        existing_view

      selecto = socket.assigns[:selecto] ->
        ViewRuntime.initial_state(view_tuple, selecto)

      true ->
        %{}
    end
  end

  defp normalize_saved_views_for_storage(views) when is_map(views) do
    Map.new(views, fn {key, value} -> {to_string(key), normalize_saved_term(value)} end)
  end

  defp normalize_saved_views_for_storage(_views), do: %{}

  defp normalize_saved_filters_for_storage(filters) when is_list(filters) do
    Enum.map(filters, &normalize_saved_term/1)
  end

  defp normalize_saved_filters_for_storage(_filters), do: []

  defp normalize_saved_term(term) when is_map(term) do
    Map.new(term, fn {key, value} -> {to_string(key), normalize_saved_term(value)} end)
  end

  defp normalize_saved_term(term) when is_list(term), do: Enum.map(term, &normalize_saved_term/1)

  defp normalize_saved_term(term) when is_tuple(term),
    do: term |> Tuple.to_list() |> normalize_saved_term()

  defp normalize_saved_term(term), do: term

  defp normalize_saved_filters_from_storage(filters) when is_list(filters) do
    Enum.map(filters, fn
      [uuid, section, filter_data] -> {uuid, section, filter_data}
      {uuid, section, filter_data} -> {uuid, section, filter_data}
      other -> other
    end)
  end

  defp normalize_saved_filters_from_storage(_filters), do: []

  defp restore_saved_views(saved_params, existing_config, socket) do
    Enum.reduce(socket.assigns.views, %{}, fn {view, _module, _name, _opt} = view_tuple, acc ->
      restored_view =
        case get_in(saved_params, ["views", Atom.to_string(view)]) ||
               get_in(saved_params, [:views, view]) do
          nil ->
            get_in(existing_config, [:views, view]) ||
              if(socket.assigns[:selecto],
                do: ViewRuntime.initial_state(view_tuple, socket.assigns.selecto),
                else: %{}
              )

          saved_view ->
            normalize_saved_term(saved_view)
        end

      Map.put(acc, view, restored_view)
    end)
  end

  defp preserve_missing_detail_view_params(view_configs, existing_config, params) do
    existing_detail = get_in(existing_config, [:views, :detail]) || %{}
    detail_config = Map.get(view_configs, :detail, %{})

    detail_config =
      detail_config
      |> preserve_scalar_when_missing(existing_detail, params, "row_click_action")
      |> preserve_scalar_when_missing(existing_detail, params, "per_page")
      |> preserve_scalar_when_missing(existing_detail, params, "max_rows")
      |> preserve_scalar_when_missing(existing_detail, params, "count_mode")
      |> preserve_scalar_when_missing(existing_detail, params, "prevent_denormalization")

    Map.put(view_configs, :detail, detail_config)
  end

  defp preserve_scalar_when_missing(detail_config, existing_detail, params, param_key) do
    if is_map(params) and Map.has_key?(params, param_key) do
      detail_config
    else
      preserve_scalar_from_existing(detail_config, existing_detail, param_key)
    end
  end

  defp preserve_scalar_from_existing(detail_config, existing_detail, param_key) do
    param_atom = detail_param_atom(param_key)
    existing_value = Map.get(existing_detail, param_atom, Map.get(existing_detail, param_key))

    if is_nil(existing_value) do
      detail_config
    else
      Map.put(detail_config, param_atom, existing_value)
    end
  end

  defp detail_param_atom("row_click_action"), do: :row_click_action
  defp detail_param_atom("per_page"), do: :per_page
  defp detail_param_atom("max_rows"), do: :max_rows
  defp detail_param_atom("count_mode"), do: :count_mode
  defp detail_param_atom("prevent_denormalization"), do: :prevent_denormalization

  def canonicalize_form_params(params) when is_map(params) do
    row_click_action =
      normalize_optional_scalar(get_map_value(params, "row_click_action_ui")) ||
        normalize_optional_scalar(get_map_value(params, "row_click_action"))

    if is_nil(row_click_action) do
      params
    else
      Map.put(params, "row_click_action", row_click_action)
    end
  end

  def canonicalize_form_params(params), do: params

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

  defp list_field(map, key) when is_map(map) and is_atom(key) do
    case Map.get(map, key, []) do
      list when is_list(list) -> list
      _ -> []
    end
  end

  defp list_field(_map, _key), do: []

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
    params =
      params
      |> compact_url_params()
      |> merge_special_debug_params(socket)

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
    ["filters", "selected", "order_by", "group_by", "aggregate", "x_axis", "y_axis", "series"]
  end

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

  defp drop_unused_form_params(params) when is_map(params) do
    params
    |> Enum.reject(fn {key, _value} ->
      key_str = to_string(key)
      String.starts_with?(key_str, "_unused_") or key_str in ["_target", "save_as"]
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
