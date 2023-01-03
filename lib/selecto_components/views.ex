defmodule SelectoComponents.Views do
@moduledoc """

interface:

- component - the display LiveComponent
- process - provides methods to read views
  - initial_state - called when view is created without params
  - param_to_state - called when view is updated via submit or via param injection,
  - view - called when view is to be generated, returns the Selecto set structure that will be used to generate query and view
- form - provides configuration panel
"""

  ## Agg and Det forms use a common format for their subsections. This function reformats the parameters to use as state for form drawing
  def view_param_process(params, item_name, section) do
    Map.get(params, item_name, %{})
    |> Enum.reduce([], fn {u, f}, acc -> acc ++ [{u, f[section], f}] end)
    |> Enum.sort(fn {_u, _s, %{"index" => index}}, {_u2, _s2, %{"index" => index2}} ->
      String.to_integer(index) <= String.to_integer(index2)
    end)
  end

end
