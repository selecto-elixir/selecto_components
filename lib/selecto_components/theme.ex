defmodule SelectoComponents.Theme do
  @moduledoc false

  alias SelectoComponents.Theme.ThemeProvider
  alias SelectoComponents.Theme.ThemeSpec

  @default_slots %{
    root: "sc-theme-root",
    panel: "sc-panel",
    panel_header: "sc-panel-header",
    tab: "sc-tab",
    tab_active: "sc-tab sc-tab-active",
    tab_inactive: "sc-tab sc-tab-inactive",
    button_primary: "sc-btn sc-btn-primary",
    button_secondary: "sc-btn sc-btn-secondary",
    button_icon: "sc-btn sc-btn-icon",
    button_danger: "sc-btn sc-btn-danger",
    input: "sc-input",
    select: "sc-select",
    checkbox_label: "sc-checkbox-label"
  }

  @default_tokens %{
    surface_bg: "#ffffff",
    surface_bg_alt: "#f9fafb",
    surface_bg_muted: "#f3f4f6",
    surface_border: "#d1d5db",
    text_primary: "#111827",
    text_secondary: "#4b5563",
    text_muted: "#6b7280",
    accent: "#2563eb",
    accent_hover: "#1d4ed8",
    accent_soft: "rgba(37, 99, 235, 0.08)",
    accent_contrast: "#ffffff",
    danger: "#dc2626",
    danger_soft: "rgba(220, 38, 38, 0.08)",
    focus_ring: "rgba(37, 99, 235, 0.28)",
    radius_md: "0.5rem",
    radius_lg: "0.75rem",
    shadow_sm: "0 1px 2px 0 rgb(0 0 0 / 0.05)",
    shadow_md: "0 4px 6px -1px rgb(0 0 0 / 0.1)"
  }

  @spec resolve_theme(map()) :: ThemeSpec.t()
  def resolve_theme(assigns) when is_map(assigns) do
    cond do
      resolver = Map.get(assigns, :theme_resolver) ->
        resolver.resolve_theme(%{
          theme_id: Map.get(assigns, :theme_id) || Map.get(assigns, :selecto_theme),
          tenant_context: Map.get(assigns, :tenant_context),
          current_user: Map.get(assigns, :current_user),
          current_user_id: Map.get(assigns, :current_user_id),
          path: Map.get(assigns, :path) || Map.get(assigns, :my_path),
          domain: Map.get(assigns, :domain),
          selecto: Map.get(assigns, :selecto)
        })
        |> normalize_theme_spec()

      Map.get(assigns, :theme_id) || Map.get(assigns, :selecto_theme) ->
        default_theme(Map.get(assigns, :theme_id) || Map.get(assigns, :selecto_theme))

      match?(%ThemeSpec{}, Map.get(assigns, :theme)) ->
        normalize_theme_spec(Map.fetch!(assigns, :theme))

      is_map(Map.get(assigns, :theme)) ->
        build_theme_spec(Map.get(assigns, :theme_id, "custom"), Map.get(assigns, :theme))

      true ->
        theme_id =
          Map.get(assigns, :theme_id) || Map.get(assigns, :selecto_theme) ||
            Map.get(assigns, :theme) || :light

        default_theme(theme_id)
    end
  end

  @spec default_theme(atom() | String.t()) :: ThemeSpec.t()
  def default_theme(theme_id) do
    theme_name = normalize_theme_name(theme_id)
    base_theme = ThemeProvider.get_theme(theme_name)

    build_theme_spec(theme_name, %{
      tokens: default_tokens(base_theme),
      slots: @default_slots,
      mode: theme_name
    })
  end

  @spec style_attr(ThemeSpec.t()) :: String.t()
  def style_attr(%ThemeSpec{} = spec) do
    spec.tokens
    |> Enum.map(fn {key, value} ->
      "--sc-#{key |> to_string() |> String.replace("_", "-")}: #{value}"
    end)
    |> Enum.join("; ")
  end

  @spec slot(ThemeSpec.t(), atom()) :: String.t()
  def slot(%ThemeSpec{} = spec, key) when is_atom(key) do
    Map.get(spec.slots, key, Map.get(@default_slots, key, ""))
  end

  @spec stylesheet() :: String.t()
  def stylesheet do
    """
    .sc-theme-root {
      background: var(--sc-surface-bg);
      color: var(--sc-text-primary);
      border-color: var(--sc-surface-border);
    }

    .sc-panel {
      background: var(--sc-surface-bg);
      color: var(--sc-text-primary);
      border: 1px solid var(--sc-surface-border);
      border-radius: var(--sc-radius-lg);
      box-shadow: var(--sc-shadow-sm);
    }

    .sc-panel-header {
      color: var(--sc-text-primary);
    }

    .sc-tab {
      border-bottom-width: 2px;
      border-color: transparent;
      color: var(--sc-text-muted);
      transition: all 150ms ease;
    }

    .sc-tab:hover {
      color: var(--sc-text-primary);
      border-color: var(--sc-surface-border);
    }

    .sc-tab-active {
      border-color: var(--sc-accent);
      color: var(--sc-accent);
      background: var(--sc-accent-soft);
    }

    .sc-tab-inactive {
      color: var(--sc-text-muted);
    }

    .sc-btn {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 0.375rem;
      border-radius: var(--sc-radius-md);
      border: 1px solid var(--sc-surface-border);
      padding: 0.5rem 0.75rem;
      font-size: 0.875rem;
      font-weight: 500;
      transition: all 150ms ease;
    }

    .sc-btn:focus-visible,
    .sc-input:focus-visible,
    .sc-select:focus-visible {
      outline: 2px solid transparent;
      box-shadow: 0 0 0 3px var(--sc-focus-ring);
    }

    .sc-btn-secondary,
    .sc-btn-icon {
      background: var(--sc-surface-bg);
      color: var(--sc-text-primary);
    }

    .sc-btn-secondary:hover,
    .sc-btn-icon:hover {
      background: var(--sc-surface-bg-alt);
      border-color: color-mix(in srgb, var(--sc-accent) 35%, var(--sc-surface-border));
    }

    .sc-btn-primary {
      background: var(--sc-accent);
      color: var(--sc-accent-contrast);
      border-color: var(--sc-accent);
    }

    .sc-btn-primary:hover {
      background: var(--sc-accent-hover);
      border-color: var(--sc-accent-hover);
    }

    .sc-btn-danger {
      background: var(--sc-danger-soft);
      color: var(--sc-danger);
      border-color: color-mix(in srgb, var(--sc-danger) 35%, var(--sc-surface-border));
    }

    .sc-btn-danger:hover {
      background: color-mix(in srgb, var(--sc-danger) 14%, var(--sc-surface-bg));
    }

    .sc-input,
    .sc-select {
      width: 100%;
      border-radius: var(--sc-radius-md);
      border: 1px solid var(--sc-surface-border);
      background: var(--sc-surface-bg);
      color: var(--sc-text-primary);
      min-height: 2rem;
      padding: 0.375rem 0.625rem;
      font-size: 0.875rem;
    }

    .sc-checkbox-label {
      color: var(--sc-text-primary);
    }
    """
  end

  defp normalize_theme_spec(%ThemeSpec{} = spec) do
    %ThemeSpec{
      spec
      | tokens: Map.merge(@default_tokens, spec.tokens || %{}),
        slots: Map.merge(@default_slots, spec.slots || %{})
    }
  end

  defp build_theme_spec(theme_id, attrs) do
    %ThemeSpec{
      id: theme_id |> normalize_theme_name() |> to_string(),
      mode: Map.get(attrs, :mode, normalize_theme_name(theme_id)),
      tokens: Map.merge(@default_tokens, Map.get(attrs, :tokens, %{})),
      slots: Map.merge(@default_slots, Map.get(attrs, :slots, %{})),
      assets: Map.get(attrs, :assets, %{}),
      options: Map.get(attrs, :options, %{})
    }
  end

  defp normalize_theme_name(theme_name) when is_binary(theme_name) do
    case theme_name do
      "dark" -> :dark
      "high_contrast" -> :high_contrast
      _ -> :light
    end
  end

  defp normalize_theme_name(theme_name) when is_atom(theme_name) do
    if theme_name in [:light, :dark, :high_contrast], do: theme_name, else: :light
  end

  defp normalize_theme_name(_), do: :light

  defp default_tokens(base_theme) do
    %{
      surface_bg: Map.get(base_theme, :surface, @default_tokens.surface_bg),
      surface_bg_alt: Map.get(base_theme, :bg_secondary, @default_tokens.surface_bg_alt),
      surface_bg_muted: Map.get(base_theme, :bg_tertiary, @default_tokens.surface_bg_muted),
      surface_border: Map.get(base_theme, :border_secondary, @default_tokens.surface_border),
      text_primary: Map.get(base_theme, :text_primary, @default_tokens.text_primary),
      text_secondary: Map.get(base_theme, :text_secondary, @default_tokens.text_secondary),
      text_muted: Map.get(base_theme, :text_tertiary, @default_tokens.text_muted),
      accent: Map.get(base_theme, :primary_600, @default_tokens.accent),
      accent_hover: Map.get(base_theme, :primary_700, @default_tokens.accent_hover),
      accent_soft: "#{Map.get(base_theme, :info_bg, "rgba(37, 99, 235, 0.08)")}",
      accent_contrast: Map.get(base_theme, :text_inverse, @default_tokens.accent_contrast),
      danger: Map.get(base_theme, :error, @default_tokens.danger),
      danger_soft: Map.get(base_theme, :error_bg, @default_tokens.danger_soft),
      focus_ring: Map.get(base_theme, :focus_ring, @default_tokens.focus_ring),
      radius_md: @default_tokens.radius_md,
      radius_lg: @default_tokens.radius_lg,
      shadow_sm: Map.get(base_theme, :shadow_sm, @default_tokens.shadow_sm),
      shadow_md: Map.get(base_theme, :shadow_md, @default_tokens.shadow_md)
    }
  end
end
