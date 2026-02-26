defmodule SelectoComponents.Views do
  @moduledoc """
  View tuple helpers and shared parameter-shaping helpers.

  ## View Registration

  Register views in your LiveView as `{id, module, name, options}` tuples:

  ```elixir
  views = [
    SelectoComponents.Views.spec(
      :aggregate,
      SelectoComponents.Views.Aggregate,
      "Aggregate View",
      %{drill_down: :detail}
    ),
    SelectoComponents.Views.spec(:detail, SelectoComponents.Views.Detail, "Detail View", %{})
  ]

  state = get_initial_state(views, selecto)
  socket = assign(socket, views: views)
  ```

  ## Formal View Interface

  The preferred interface is `SelectoComponents.Views.System`:

  - `initial_state/2`
  - `param_to_state/2`
  - `view/5`
  - `form_component/0`
  - `result_component/0`

  Built-in views use this behavior (`Aggregate`, `Detail`, `Graph`).

  Legacy namespace-style modules (`MyView.Process`, `MyView.Form`,
  `MyView.Component`) are still supported via `SelectoComponents.Views.Runtime`.
  """

  @type view_id :: atom()
  @type view_module :: module()
  @type view_name :: String.t()
  @type view_options :: map()
  @type view_tuple :: {view_id(), view_module(), view_name(), view_options()}

  @doc """
  Canonical constructor for a view tuple used by SelectoComponents.

      views = [
        SelectoComponents.Views.spec(
          :workflow,
          SelectoComponentsWorkflow.Views.Workflow,
          "Workflow View",
          %{drill_down: :detail}
        )
      ]
  """
  @spec spec(view_id(), view_module(), view_name(), view_options()) :: view_tuple()
  def spec(id, module, name, options \\ %{})
      when is_atom(id) and is_atom(module) and is_binary(name) and is_map(options) do
    {id, module, name, options}
  end

  @doc """
  Append extension-provided views for a Selecto/domain source.

  Existing views take precedence when IDs collide.
  """
  @spec with_extensions([view_tuple()], map()) :: [view_tuple()]
  def with_extensions(base_views, selecto_or_domain)
      when is_list(base_views) and is_map(selecto_or_domain) do
    extension_specs = Selecto.Extensions.from_source(selecto_or_domain)
    extension_views = Selecto.Extensions.components_views(selecto_or_domain, extension_specs)

    existing_ids = base_views |> Enum.map(fn {id, _, _, _} -> id end) |> MapSet.new()

    additional_views =
      extension_views
      |> Enum.reject(fn {id, _, _, _} -> MapSet.member?(existing_ids, id) end)

    base_views ++ additional_views
  end

  def with_extensions(base_views, _), do: base_views

  ## Agg and Det forms use a common format for their subsections. This function reformats the parameters to use as state for form drawing
  def view_param_process(params, item_name, section) do
    Map.get(params, item_name, %{})
    |> Enum.reduce([], fn {u, f}, acc -> acc ++ [{u, f[section], f}] end)
    |> Enum.sort(fn {_u, _s, %{"index" => index}}, {_u2, _s2, %{"index" => index2}} ->
      String.to_integer(index) <= String.to_integer(index2)
    end)
  end
end
