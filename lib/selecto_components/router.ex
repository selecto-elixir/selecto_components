defmodule SelectoComponents.Router do
  @moduledoc """
  Event routing and business logic for SelectoComponents.
  
  Handles event processing, query execution, and business logic
  without concern for UI rendering or direct state manipulation.
  """

  alias SelectoComponents.State
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
    case handle_filter_remove(params, state) do
      {:ok, updated_state} -> {:ok, updated_state}
    end
  end

  def handle_event("agg_add_filters", params, state) do
    {:ok, updated_state} = handle_agg_add_filters(params, state)
    {:ok, updated_state}
  end

  def handle_event(event, params, state) do
    # Fallback for unhandled events
    {:error, State.set_execution_error(state, "Unknown event: #{event}")}
  end

  @doc """
  Routes and processes info messages.
  """
  def handle_info(message, state)

  def handle_info({:view_set, view}, state) do
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
    # TODO: Implement save view logic
    {:ok, state}
  end

  defp execute_query(params, state) do
    try do
      # Process view configuration
      view_config = State.update_view_config(state, params).view_config
      selecto = state.selecto
      
      # Apply filters and configuration to selecto
      filtered_selecto = apply_filters(selecto, view_config.filters)
      
      
      # Execute the query
      case Selecto.execute(filtered_selecto) do
        {:ok, results} -> {:ok, results, filtered_selecto}
        {:error, error} -> {:error, error}
      end
    rescue
      e -> {:error, e}
    end
  end

  defp handle_tree_drop(_params, state) do
    # TODO: Implement tree drop logic
    {:ok, state}
  end

  defp handle_filter_remove(_params, state) do
    # TODO: Implement filter remove logic
    {:ok, state}
  end

  defp handle_agg_add_filters(_params, state) do
    # TODO: Implement aggregate add filters logic
    {:ok, state}
  end

  defp handle_list_picker_remove(_view, _list, _item, state) do
    # TODO: Implement list picker remove logic
    {:ok, state}
  end

  defp handle_list_picker_move(_view, _list, _uuid, _direction, state) do
    # TODO: Implement list picker move logic
    {:ok, state}
  end

  defp handle_list_picker_add(_view, _list, _item, state) do
    # TODO: Implement list picker add logic
    {:ok, state}
  end

  defp apply_filters(selecto, _filters) do
    # TODO: Implement filter application logic
    selecto
  end
end