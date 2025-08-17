defmodule SelectoComponents.State do
  @moduledoc """
  State management for SelectoComponents.
  
  Handles state transitions, validation, and state updates for the form components
  without concern for UI rendering or routing logic.
  """

  @doc """
  Initializes the default state for a SelectoComponents form.
  """
  def init_state(selecto, views, opts \\ []) do
    %{
      selecto: selecto,
      views: views,
      active_tab: Keyword.get(opts, :active_tab, "view"),
      view_config: init_view_config(views, opts),
      execution_error: nil,
      query_results: nil
    }
  end

  @doc """
  Updates the active tab in the state.
  """
  def set_active_tab(state, tab) when is_binary(tab) do
    Map.put(state, :active_tab, tab)
  end

  @doc """
  Validates and updates the view configuration.
  """
  def update_view_config(state, params) do
    # Extract view configuration from params
    view_config = Map.get(params, "view_config", %{})
    
    # Update the state with new view config
    Map.put(state, :view_config, Map.merge(state.view_config, view_config))
  end

  @doc """
  Sets an execution error in the state.
  """
  def set_execution_error(state, error) do
    Map.put(state, :execution_error, error)
  end

  @doc """
  Clears the execution error from the state.
  """
  def clear_execution_error(state) do
    Map.put(state, :execution_error, nil)
  end

  @doc """
  Updates query results in the state.
  """
  def set_query_results(state, results) do
    Map.put(state, :query_results, results)
  end

  @doc """
  Updates the selecto configuration in the state.
  """
  def update_selecto(state, selecto) do
    Map.put(state, :selecto, selecto)
  end

  # Private helper functions

  defp init_view_config(views, opts) do
    default_view_mode = 
      case List.first(views) do
        {id, _, _, _} -> Atom.to_string(id)
        _ -> "aggregate"
      end

    %{
      view_mode: Keyword.get(opts, :view_mode, default_view_mode),
      views: init_view_configs(views),
      filters: %{}
    }
  end

  defp init_view_configs(views) do
    Enum.reduce(views, %{}, fn {id, _mod, _name, _opt}, acc ->
      Map.put(acc, id, %{
        columns: [],
        filters: [],
        group_by: [],
        order_by: []
      })
    end)
  end
end