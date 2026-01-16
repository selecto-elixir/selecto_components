defmodule SelectoComponents.Router do
  @moduledoc """
  Event routing and business logic for SelectoComponents.

  Handles event processing, query execution, and business logic
  without concern for UI rendering or direct state manipulation.
  """

  alias SelectoComponents.State
  alias SelectoComponents.SafeAtom
  alias UUID

  @doc """
  Routes and processes events, returning updated state and any side effects.
  """
  def handle_event(event, params, state)

  def handle_event("set_active_tab", %{"tab" => tab}, state) do
    {:ok, State.set_active_tab(state, tab)}
  end

  def handle_event("view-validate", params, state) do
    updated_state = State.update_view_config(state, params)
    {:ok, updated_state}
  end

  def handle_event("view-apply", params, %{active_tab: "save"} = state) do
    # Handle save view logic
    case handle_save_view(params, state) do
      {:ok, updated_state} -> {:ok, updated_state}
    end
  end

  def handle_event("view-apply", params, state) do
    case execute_query(params, state) do
      {:ok, results, updated_selecto} ->
        updated_state =
          state
          |> State.update_view_config(params)
          |> State.update_selecto(updated_selecto)
          |> State.set_query_results(results)
          |> State.clear_execution_error()

        {:ok, updated_state}

      {:error, error} ->
        updated_state = State.set_execution_error(state, error)
        {:error, updated_state}
    end
  end

  def handle_event("treedrop", params, state) do
    case handle_tree_drop(params, state) do
      {:ok, updated_state} -> {:ok, updated_state}
    end
  end

  def handle_event("filter_remove", params, state) do
    IO.puts("Handling filter_remove event")
    case handle_filter_remove(params, state) do
      {:ok, updated_state} -> {:ok, updated_state}
    end
  end

  def handle_event("agg_add_filters", params, state) do
    {:ok, updated_state} = handle_agg_add_filters(params, state)
    {:ok, updated_state}
  end

  def handle_event(event, _params, state) do
    # Fallback for unhandled events
    {:error, State.set_execution_error(state, "Unknown event: #{event}")}
  end

  @doc """
  Routes and processes info messages.
  """
  def handle_info(message, state)

  def handle_info({:view_set, _view}, state) do
    # Handle view change logic
    {:ok, state}
  end

  def handle_info({:list_picker_remove, view, list, item}, state) do
    {:ok, updated_state} = handle_list_picker_remove(view, list, item, state)
    {:ok, updated_state}
  end

  def handle_info({:list_picker_move, view, list, uuid, direction}, state) do
    {:ok, updated_state} = handle_list_picker_move(view, list, uuid, direction, state)
    {:ok, updated_state}
  end

  def handle_info({:list_picker_add, view, list, item}, state) do
    {:ok, updated_state} = handle_list_picker_add(view, list, item, state)
    {:ok, updated_state}
  end

  def handle_info(_message, state) do
    # Fallback for unhandled messages
    {:ok, state}
  end

  # Private helper functions for business logic

  defp handle_save_view(params, state) do
    # Extract save view params
    view_name = get_in(params, ["view", "name"]) || get_in(params, ["name"])
    view_params = %{
      name: view_name,
      context: state.context,
      params: %{
        view_config: state.view_config,
        filters: Map.get(state.view_config, :filters, []),
        selected: Map.get(state.view_config, :selected, %{}),
        group_by: Map.get(state.view_config, :group_by, %{}),
        aggregate: Map.get(state.view_config, :aggregate, %{}),
        view_mode: Map.get(state.view_config, :view_mode)
      }
    }

    # Use the saved view module if configured
    case Map.get(state, :saved_view_module) do
      nil ->
        # No saved view module configured, store in state
        saved_views = Map.get(state, :saved_views, [])
        updated_saved_views = [view_params | saved_views]
        updated_state = Map.put(state, :saved_views, updated_saved_views)
        {:ok, updated_state}

      module ->
        # Call the module's save function
        case apply(module, :save_view, [view_params]) do
          {:ok, _saved_view} ->
            {:ok, state}
          {:error, reason} ->
            {:ok, State.set_execution_error(state, "Failed to save view: #{inspect(reason)}")}
        end
    end
  end

  defp execute_query(params, state) do
    require Logger

    try do
      # Process view configuration
      view_config = State.update_view_config(state, params).view_config
      selecto = state.selecto

      # Apply filters and configuration to selecto
      filters = Map.get(view_config, :filters, [])
      filtered_selecto = apply_filters(selecto, filters)

      # Apply automatic pivot if needed
      pivoted_selecto = maybe_auto_pivot(filtered_selecto, view_config)

      # Check if we have a valid connection - if not, skip execution
      # This allows tests to verify pivot logic without needing a database
      if pivoted_selecto.connection == nil do
        Logger.debug("Skipping query execution - no database connection (test mode)")
        {:ok, %{rows: [], columns: [], aliases: %{}}, pivoted_selecto}
      else
        # Log the SQL being generated for debugging
        try do
          sql_info = Selecto.to_sql(pivoted_selecto)
          Logger.debug("Executing SQL: #{inspect(sql_info, pretty: true)}")
        rescue
          e ->
            Logger.error("Failed to generate SQL: #{inspect(e)}")
            Logger.error("Stack trace: #{inspect(__STACKTRACE__)}")
        end

        # Execute the query
        case Selecto.execute(pivoted_selecto) do
          {:ok, results} ->
            {:ok, results, pivoted_selecto}

          {:error, %{message: message} = error} ->
            Logger.error("Query execution failed with error: #{message}")
            Logger.error("Full error details: #{inspect(error, pretty: true)}")
            {:error, %{error | message: "Query execution failed: #{message}"}}

          {:error, error} when is_binary(error) ->
            Logger.error("Query execution failed: #{error}")
            {:error, %{message: "Query execution failed: #{error}"}}

          {:error, error} ->
            Logger.error("Query execution failed with unknown error: #{inspect(error)}")
            {:error, %{message: "Query execution failed: #{inspect(error)}"}}
        end
      end
    rescue
      e ->
        Logger.error("Exception during query execution: #{inspect(e)}")
        Logger.error("Stack trace: #{inspect(__STACKTRACE__)}")
        {:error, %{message: "Query execution exception: #{Exception.message(e)}"}}
    end
  end

  defp handle_tree_drop(params, state) do
    # Handle drag-and-drop reordering in filter tree
    source_uuid = Map.get(params, "source_uuid")
    target_uuid = Map.get(params, "target_uuid")
    position = Map.get(params, "position", "after") # "before", "after", or "inside"

    filters = Map.get(state.view_config, :filters, [])

    # Find and remove the source item
    {source_item, remaining_filters} = extract_filter_by_uuid(filters, source_uuid)

    if source_item do
      # Insert at new position
      updated_filters = insert_filter_at_position(remaining_filters, source_item, target_uuid, position)
      updated_view_config = Map.put(state.view_config, :filters, updated_filters)
      updated_state = State.update_view_config(state, updated_view_config)
      {:ok, updated_state}
    else
      {:ok, state}
    end
  end

  defp handle_filter_remove(params, state) do
    # Remove filter from view configuration
    filter_uuid = Map.get(params, "uuid") || Map.get(params, "filter_uuid")

    filters = Map.get(state.view_config, :filters, [])
    updated_filters = remove_filter_by_uuid(filters, filter_uuid)

    updated_view_config = Map.put(state.view_config, :filters, updated_filters)
    updated_state = %{state | view_config: updated_view_config}
    {:ok, updated_state}
  end

  defp handle_agg_add_filters(params, state) do
    # Add filters when clicking aggregate view cells (drill-down)
    # Extract field values from phx-value-* params
    filter_values = params
    |> Enum.filter(fn {k, _v} -> String.starts_with?(k, "field_") end)
    |> Enum.map(fn {"field_" <> field_name, value} ->
      %{
        "uuid" => UUID.uuid4(),
        "field" => field_name,
        "value" => value,
        "comp" => "="
      }
    end)

    if length(filter_values) > 0 do
      # Add new filters
      existing_filters = Map.get(state.view_config, :filters, [])
      updated_filters = existing_filters ++ filter_values

      # Switch to detail view
      updated_view_config = state.view_config
      |> Map.put(:filters, updated_filters)
      |> Map.put(:view_mode, "detail")

      updated_state = %{state | view_config: updated_view_config}
      {:ok, updated_state}
    else
      {:ok, state}
    end
  end

  defp handle_list_picker_remove(_view, list, item_uuid, state) do
    # Remove item from list picker (selected fields, group_by, etc.)
    list_key = String.to_existing_atom(list)
    current_list = Map.get(state.view_config, list_key, %{})

    updated_list = Map.delete(current_list, item_uuid)
    updated_view_config = Map.put(state.view_config, list_key, updated_list)
    updated_state = %{state | view_config: updated_view_config}
    {:ok, updated_state}
  end

  defp handle_list_picker_move(_view, list, uuid, direction, state) do
    # Reorder items in list picker
    list_key = String.to_existing_atom(list)
    current_list = Map.get(state.view_config, list_key, %{})

    # Convert map to ordered list
    items = current_list
    |> Enum.sort_by(fn {_k, v} -> Map.get(v, "order", 0) end)
    |> Enum.map(fn {k, v} -> {k, v} end)

    # Find current index
    current_index = Enum.find_index(items, fn {k, _v} -> k == uuid end)

    if current_index do
      new_index = case direction do
        :up -> max(0, current_index - 1)
        :down -> min(length(items) - 1, current_index + 1)
        _ -> current_index
      end

      if new_index != current_index do
        # Swap items
        reordered = items
        |> List.delete_at(current_index)
        |> List.insert_at(new_index, Enum.at(items, current_index))
        |> Enum.with_index()
        |> Enum.map(fn {{k, v}, idx} -> {k, Map.put(v, "order", idx)} end)
        |> Enum.into(%{})

        updated_view_config = Map.put(state.view_config, list_key, reordered)
        updated_state = %{state | view_config: updated_view_config}
        {:ok, updated_state}
      else
        {:ok, state}
      end
    else
      {:ok, state}
    end
  end

  defp handle_list_picker_add(_view, list, item, state) do
    # Add item to list picker
    list_key = String.to_existing_atom(list)
    current_list = Map.get(state.view_config, list_key, %{})

    # Generate UUID for new item
    item_uuid = UUID.uuid4()
    order = map_size(current_list)
    new_item = Map.put(item, "order", order)

    updated_list = Map.put(current_list, item_uuid, new_item)
    updated_view_config = Map.put(state.view_config, list_key, updated_list)
    updated_state = %{state | view_config: updated_view_config}
    {:ok, updated_state}
  end

  defp apply_filters(selecto, filters) when is_list(filters) do
    # Apply filters to selecto query recursively
    Enum.reduce(filters, selecto, fn filter, acc ->
      apply_single_filter(acc, filter)
    end)
  end
  defp apply_filters(selecto, _), do: selecto

  defp apply_single_filter(selecto, %{"field" => field, "value" => value, "comp" => comp}) when not is_nil(field) and not is_nil(value) do
    filter_tuple = case comp do
      "=" -> {field, value}
      "!=" -> {field, {:ne, value}}
      ">" -> {field, {:gt, value}}
      ">=" -> {field, {:gte, value}}
      "<" -> {field, {:lt, value}}
      "<=" -> {field, {:lte, value}}
      "like" -> {field, {:like, value}}
      "ilike" -> {field, {:ilike, value}}
      "in" -> {field, {:in, value}}
      "not_in" -> {field, {:not_in, value}}
      "is_null" -> {field, {:is_null, true}}
      "is_not_null" -> {field, {:is_null, false}}
      _ -> {field, value}
    end
    Selecto.filter(selecto, filter_tuple)
  end
  defp apply_single_filter(selecto, %{"comp" => "AND", "filters" => nested_filters}) do
    # AND group - apply all filters
    apply_filters(selecto, nested_filters)
  end
  defp apply_single_filter(selecto, %{"comp" => "OR", "filters" => nested_filters}) do
    # OR group - apply as OR filter
    Selecto.filter(selecto, {:or, Enum.map(nested_filters, &filter_to_tuple/1)})
  end
  defp apply_single_filter(selecto, _), do: selecto

  defp filter_to_tuple(%{"field" => field, "value" => value}) when not is_nil(field), do: {field, value}
  defp filter_to_tuple(_), do: nil

  # Helper functions for filter manipulation

  defp extract_filter_by_uuid(filters, uuid) do
    case Enum.find_index(filters, fn f -> Map.get(f, "uuid") == uuid end) do
      nil -> {nil, filters}
      index ->
        {item, remaining} = List.pop_at(filters, index)
        {item, remaining}
    end
  end

  defp remove_filter_by_uuid(filters, uuid) do
    Enum.reject(filters, fn filter ->
      Map.get(filter, "uuid") == uuid
    end)
  end

  defp insert_filter_at_position(filters, item, target_uuid, position) do
    case Enum.find_index(filters, fn f -> Map.get(f, "uuid") == target_uuid end) do
      nil ->
        # Target not found, append at end
        filters ++ [item]
      target_index ->
        insert_index = case position do
          "before" -> target_index
          "after" -> target_index + 1
          "inside" -> target_index + 1  # For nested groups
          _ -> target_index + 1
        end
        List.insert_at(filters, insert_index, item)
    end
  end

  defp maybe_auto_pivot(selecto, view_config) do
    # Check if automatic pivot is needed
    selected_columns = get_selected_columns(view_config)

    # Clean column names (remove qualified prefixes like "film.title" -> "title")
    clean_columns = Enum.map(selected_columns, fn col ->
      col_str = to_string(col)
      if String.contains?(col_str, ".") do
        [_, column_name] = String.split(col_str, ".", parts: 2)
        column_name
      else
        col_str
      end
    end)

    if should_auto_pivot?(selecto, selected_columns) do
      target_table = find_pivot_target(selecto, selected_columns)

      if target_table do
        # Apply pivot to the target table
        pivoted = Selecto.Pivot.pivot(selecto, target_table)

        # Apply selected columns after pivot
        if length(clean_columns) > 0 do
          Selecto.select(pivoted, clean_columns)
        else
          pivoted
        end
      else
        # No valid pivot target found, apply select to original selecto
        if length(clean_columns) > 0 do
          Selecto.select(selecto, clean_columns)
        else
          selecto
        end
      end
    else
      # No pivot needed, but still apply select if we have columns
      if length(clean_columns) > 0 do
        Selecto.select(selecto, clean_columns)
      else
        selecto
      end
    end
  end

  defp get_selected_columns(view_config) do
    # Extract selected columns from view config
    # This depends on the view mode (aggregate, detail, etc.)
    view_mode = Map.get(view_config, :view_mode) || Map.get(view_config, "view_mode")

    case view_mode do
      "aggregate" ->
        group_by_cols = Map.get(view_config, :group_by, Map.get(view_config, "group_by", %{}))
                       |> Map.values()
                       |> Enum.map(fn item -> Map.get(item, "field") end)

        aggregate_cols = Map.get(view_config, :aggregate, Map.get(view_config, "aggregate", %{}))
                        |> Map.values()
                        |> Enum.map(fn item -> Map.get(item, "field") end)

        group_by_cols ++ aggregate_cols

      "detail" ->
        # Handle both simple and qualified column names from selected map
        selected_map = Map.get(view_config, :selected, Map.get(view_config, "selected", %{}))

        # Extract field names from the selected map structure
        selected_fields =
          case selected_map do
            # If it's a map with UUID keys (typical case)
            map when is_map(map) ->
              Map.values(map)
              |> Enum.map(fn item ->
                Map.get(item, "field") || Map.get(item, :field)
              end)
              |> Enum.filter(&(&1 != nil))

            # If it's a list
            list when is_list(list) ->
              list

            _ ->
              []
          end

        selected_fields

      _ ->
        []
    end
  end

  defp should_auto_pivot?(selecto, selected_columns) do
    # Check if any selected columns are missing from the base table
    # or are qualified column names (e.g., "film.description")
    source_columns = get_source_columns(selecto)

    result = Enum.any?(selected_columns, fn col ->
      col_str = to_string(col)

      # Check if it's a qualified column name (contains a dot)
      if String.contains?(col_str, ".") do
        # Qualified columns like "film.description" should trigger pivot
        parts = String.split(col_str, ".", parts: 2)

        [table_name, _column_name] = parts
        # Pivot should be triggered for qualified names from joined tables
        should_pivot = table_name != "selecto_root" && table_name != ""
        should_pivot
      else
        # For simple column names, check if they exist in source
        exists = column_exists_in_source?(col, source_columns)
        not exists
      end
    end)

    result
  end

  defp get_source_columns(selecto) do
    # Get columns from the source table
    source_config = selecto.domain.source
    Map.keys(source_config.columns || %{})
  end

  defp column_exists_in_source?(column_name, source_columns) do
    # Check if column exists in source (handle string/atom conversion)
    # Use SafeAtom.to_existing to prevent atom table exhaustion from user input
    col_atom = if is_binary(column_name), do: SafeAtom.to_existing(column_name), else: column_name
    col_string = if is_atom(column_name), do: Atom.to_string(column_name), else: column_name

    Enum.any?(source_columns, fn source_col ->
      source_col == col_atom or source_col == col_string or
      Atom.to_string(source_col) == col_string
    end)
  end

  defp find_pivot_target(selecto, selected_columns) do
    # Find the first joined table that has all the selected columns
    # Handle both simple and qualified column names


    # Extract table names from qualified columns
    table_targets =
      selected_columns
      |> Enum.map(fn col ->
        col_str = to_string(col)
        if String.contains?(col_str, ".") do
          [table_name, _] = String.split(col_str, ".", parts: 2)
          # Use SafeAtom.to_existing to prevent atom table exhaustion
          SafeAtom.to_existing(table_name)
        else
          nil
        end
      end)
      |> Enum.filter(&(&1 != nil))
      |> Enum.uniq()


    # If we have explicit table references, use the first one
    if length(table_targets) > 0 do
      # Return the first table that was explicitly referenced
      target = hd(table_targets)
      target
    else
      # Fall back to original logic for simple column names
      schemas = Map.get(selecto.domain, :schemas, %{})

      result = Enum.find_value(schemas, fn {schema_name, schema_config} ->
        schema_columns = Map.keys(schema_config.columns || %{})

        if has_all_columns?(selected_columns, schema_columns) do
          schema_name
        else
          nil
        end
      end)

      result
    end
  end

  defp has_all_columns?(selected_columns, schema_columns) do
    # Check if schema has all selected columns
    # Handle both simple and qualified column names
    Enum.all?(selected_columns, fn col ->
      col_str = to_string(col)

      # If it's a qualified column name, extract just the column part
      col_name =
        if String.contains?(col_str, ".") do
          [_, column_name] = String.split(col_str, ".", parts: 2)
          column_name
        else
          col_str
        end

      # Use SafeAtom.to_existing to prevent atom table exhaustion from user input
      col_atom = if is_binary(col_name), do: SafeAtom.to_existing(col_name), else: col_name

      Enum.any?(schema_columns, fn schema_col ->
        schema_col == col_atom or
        Atom.to_string(schema_col) == col_name
      end)
    end)
  end
end
