defmodule SelectoComponents.Views do
@moduledoc """

Define a view for Selecto Components.

In addition to the built in views such as Aggregate and Detail, you can create custom views.

When mounting your Selecto Liveview, you configure the views to use in a list, and pass that to get_initial_state and as an assign.

```elixir

    views = [
      {:aggregate, SelectoComponents.Views.Aggregate, "Aggregate View", %{drill_down: :detail}},
      {:detail, SelectoComponents.Views.Detail, "Detail View", %{}}
      # {:graph, SelectoComponents.Views.Graph, "Graph View", %{}},
    ]

    state = get_initial_state(views, selecto)
    socket = assign(socket, views: views)

```


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
