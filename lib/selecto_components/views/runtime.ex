defmodule SelectoComponents.Views.Runtime do
  @moduledoc """
  Runtime helpers for executing configured view systems.

  View modules are expected to implement `SelectoComponents.Views.System`.
  """

  @type view_id :: atom()
  @type view_tuple :: {view_id(), module(), String.t(), map()}

  @spec initial_state(view_tuple(), term()) :: map()
  def initial_state({_id, view_module, _name, options}, selecto),
    do: view_module.initial_state(selecto, options)

  @spec param_to_state(view_tuple(), map()) :: map()
  def param_to_state({_id, view_module, _name, options}, params),
    do: view_module.param_to_state(params, options)

  @spec view(view_tuple(), map(), map(), term(), term()) :: {map(), map()}
  def view({_id, view_module, _name, options}, params, columns_map, filtered, selecto),
    do: view_module.view(options, params, columns_map, filtered, selecto)

  @spec form_component(view_tuple()) :: module()
  def form_component({_id, view_module, _name, _options}), do: view_module.form_component()

  @spec result_component(view_tuple()) :: module()
  def result_component({_id, view_module, _name, _options}), do: view_module.result_component()
end
