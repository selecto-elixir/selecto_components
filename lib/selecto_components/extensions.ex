defmodule SelectoComponents.Extensions do
  @moduledoc """
  Extension helpers for view registration in `selecto_components`.
  """

  @type view_tuple :: {atom(), module(), String.t(), map()}

  @doc """
  Merge extension-provided views into a base view list.

  Existing view ids in `views` take precedence.
  """
  @spec merge_views([view_tuple()], term()) :: [view_tuple()]
  def merge_views(views, selecto_or_domain) when is_list(views) do
    extension_specs = Selecto.Extensions.from_source(selecto_or_domain)
    extension_views = Selecto.Extensions.components_views(selecto_or_domain, extension_specs)

    Enum.reduce(extension_views, views, fn {view_id, _module, _name, _opts} = extension_view,
                                           acc ->
      if Enum.any?(acc, fn {existing_id, _, _, _} -> existing_id == view_id end) do
        acc
      else
        acc ++ [extension_view]
      end
    end)
  end

  def merge_views(_views, _selecto_or_domain), do: []
end
