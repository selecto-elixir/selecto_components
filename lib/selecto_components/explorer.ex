defmodule SelectoComponents.Explorer do
  @moduledoc """
  Top-level exploration surface for SelectoComponents.

  This is the intended default host-facing entrypoint. It reuses the existing
  `Form` and `Results` compatibility components through clearer explorer-level
  ownership modules.
  """

  use Phoenix.LiveComponent

  alias SelectoComponents.Explorer.Config
  alias SelectoComponents.Explorer.Controls
  alias SelectoComponents.Explorer.ResultsSurface
  alias SelectoComponents.Explorer.Shell
  alias SelectoComponents.Theme

  @impl true
  def render(assigns) do
    assigns = normalize_assigns(assigns)
    theme = Theme.resolve_theme(assigns)

    assigns =
      assign(assigns,
        theme: theme,
        explorer_assigns: Map.drop(assigns, [:__changed__, :theme, :config, :explorer_assigns])
      )

    ~H"""
    <div id={"selecto-explorer-root-#{@id}"} data-selecto-explorer-root>
      <Shell.surface id={@id} theme={@theme}>
        <:controls>
          <Controls.panel id={@id} assigns_map={@explorer_assigns} />
        </:controls>
        <:results>
          <ResultsSurface.panel id={@id} assigns_map={@explorer_assigns} />
        </:results>
      </Shell.surface>
    </div>
    """
  end

  defp normalize_assigns(assigns) do
    assigns =
      case Map.get(assigns, :config) do
        %Config{} = config ->
          assigns
          |> Map.put_new(:id, config.id || "explorer")
          |> Map.put_new(:selecto, config.selecto)
          |> Map.put_new(:views, config.views)
          |> maybe_put_feature_assigns(config.features)
          |> maybe_put_theme_assign(config.theme)
          |> maybe_put_presentation_assign(config.presentation)
          |> maybe_put_title(config.title)

        _ ->
          Map.put_new(assigns, :id, "explorer")
      end

    assigns
    |> Map.put_new(:controller_title, "Explorer")
  end

  defp maybe_put_feature_assigns(assigns, features) when is_map(features) do
    assigns
    |> Map.put_new(:saved_view_module, Map.get(features, :saved_views))
    |> Map.put_new(:exported_view_module, Map.get(features, :exported_views))
    |> Map.put_new(:export_delivery_module, Map.get(features, :export_delivery))
    |> Map.put_new(:scheduled_export_module, Map.get(features, :scheduled_exports))
  end

  defp maybe_put_feature_assigns(assigns, _features), do: assigns

  defp maybe_put_theme_assign(assigns, theme) when is_map(theme) and map_size(theme) > 0,
    do: Map.put_new(assigns, :theme, theme)

  defp maybe_put_theme_assign(assigns, _theme), do: assigns

  defp maybe_put_presentation_assign(assigns, presentation)
       when is_map(presentation) and map_size(presentation) > 0,
       do: Map.put_new(assigns, :presentation_context, presentation)

  defp maybe_put_presentation_assign(assigns, _presentation), do: assigns

  defp maybe_put_title(assigns, title) when is_binary(title) and title != "",
    do: Map.put_new(assigns, :controller_title, title)

  defp maybe_put_title(assigns, _title), do: assigns
end
