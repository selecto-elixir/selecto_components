defmodule SelectoComponents.Views.Runtime do
  @moduledoc """
  Runtime helpers for executing configured view systems.

  Supports:
  - Formal behavior-based view systems (`SelectoComponents.Views.System`)
  - Legacy namespace-based modules (`MyView.Process`, `MyView.Form`, `MyView.Component`)
  """

  @type view_id :: atom()
  @type view_tuple :: {view_id(), module(), String.t(), map()}

  @spec initial_state(view_tuple(), term()) :: map()
  def initial_state({_id, view_module, _name, options}, selecto) do
    if function_exported?(view_module, :initial_state, 2) do
      view_module.initial_state(selecto, options)
    else
      process_module(view_module).initial_state(selecto, options)
    end
  end

  @spec param_to_state(view_tuple(), map()) :: map()
  def param_to_state({_id, view_module, _name, options}, params) do
    if function_exported?(view_module, :param_to_state, 2) do
      view_module.param_to_state(params, options)
    else
      process_module(view_module).param_to_state(params, options)
    end
  end

  @spec view(view_tuple(), map(), map(), term(), term()) :: {map(), map()}
  def view({_id, view_module, _name, options}, params, columns_map, filtered, selecto) do
    if function_exported?(view_module, :view, 5) do
      view_module.view(options, params, columns_map, filtered, selecto)
    else
      process_module(view_module).view(options, params, columns_map, filtered, selecto)
    end
  end

  @spec form_component(view_tuple()) :: module()
  def form_component({_id, view_module, _name, _options}) do
    if function_exported?(view_module, :form_component, 0) do
      view_module.form_component()
    else
      Module.concat(view_module, Form)
    end
  end

  @spec result_component(view_tuple()) :: module()
  def result_component({_id, view_module, _name, _options}) do
    if function_exported?(view_module, :result_component, 0) do
      view_module.result_component()
    else
      Module.concat(view_module, Component)
    end
  end

  defp process_module(view_module), do: Module.concat(view_module, Process)
end

