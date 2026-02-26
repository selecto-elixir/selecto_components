defmodule SelectoComponents.Views.System do
  @moduledoc """
  Formal contract for pluggable SelectoComponents view systems.

  A view system is the module referenced in the `views` configuration tuple:

      {:graph, SelectoComponents.Views.Graph, "Graph View", %{}}

  Any module used in that position can implement this behavior directly, or
  `use SelectoComponents.Views.System` to wire callbacks to separate modules.

  Additional view-local modules (for example drill-down handlers, option
  normalizers, pagination/query helpers) are optional implementation details
  and are not part of this behavior contract.

  This enables external packages (for example `selecto_components_workflow`)
  to integrate without relying on naming conventions like `\#{module}.Process`.
  """

  @type view_set :: map()
  @type view_meta :: map()
  @type columns_map :: map()
  @type filtered :: term()
  @type selecto :: term()
  @type params :: map()
  @type options :: map()

  @callback initial_state(selecto(), options()) :: map()
  @callback param_to_state(params(), options()) :: map()
  @callback view(options(), params(), columns_map(), filtered(), selecto()) ::
              {view_set(), view_meta()}
  @callback form_component() :: module()
  @callback result_component() :: module()

  defmacro __using__(opts) do
    process = Keyword.fetch!(opts, :process)
    form = Keyword.fetch!(opts, :form)
    component = Keyword.fetch!(opts, :component)

    quote do
      @behaviour SelectoComponents.Views.System

      @impl true
      def initial_state(selecto, options), do: unquote(process).initial_state(selecto, options)

      @impl true
      def param_to_state(params, options), do: unquote(process).param_to_state(params, options)

      @impl true
      def view(options, params, columns_map, filtered, selecto),
        do: unquote(process).view(options, params, columns_map, filtered, selecto)

      @impl true
      def form_component, do: unquote(form)

      @impl true
      def result_component, do: unquote(component)
    end
  end
end
