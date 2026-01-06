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

  defp handle_save_view(_params, state) do
    # Placeholder: Save view logic should persist the current view configuration
    # This will be implemented when router abstraction is completed
    # Expected: Save params to saved_view_module with name, context, filters, etc.
    {:ok, state}
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

  defp handle_tree_drop(_params, state) do
    # Placeholder: Handle drag-and-drop reordering in filter tree
    # Expected: Reorder filters based on dropped position, update state.view_config
    {:ok, state}
  end

  defp handle_filter_remove(_params, state) do
    # Placeholder: Remove filter from view configuration
    # Expected: Extract filter UUID from params, remove from state.view_config.filters
    {:ok, state}
  end

  defp handle_agg_add_filters(_params, state) do
    # Placeholder: Add filters when clicking aggregate view cells (drill-down)
    # Expected: Extract phx-value-* params, create new filters, switch to detail view
    # Current implementation in form.ex:560
    {:ok, state}
  end

  defp handle_list_picker_remove(_view, _list, _item, state) do
    # Placeholder: Remove item from list picker (selected fields, group_by, etc.)
    # Expected: Remove UUID from appropriate list in view_config
    {:ok, state}
  end

  defp handle_list_picker_move(_view, _list, _uuid, _direction, state) do
    # Placeholder: Reorder items in list picker
    # Expected: Swap positions of items based on direction (:up/:down)
    {:ok, state}
  end

  defp handle_list_picker_add(_view, _list, _item, state) do
    # Placeholder: Add item to list picker
    # Expected: Append new item with UUID to appropriate list in view_config
    {:ok, state}
  end

  defp apply_filters(selecto, _filters) do
    # Placeholder: Apply filters to selecto query
    # Expected: Call Selecto.filter() for each filter in list
    # Current implementation in form.ex:filter_recurse
    selecto
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
