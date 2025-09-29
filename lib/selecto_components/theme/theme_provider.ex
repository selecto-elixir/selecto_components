defmodule SelectoComponents.Theme.ThemeProvider do
  @moduledoc """
  Comprehensive theming system using CSS variables for SelectoComponents customization.
  """
  
  use Phoenix.Component
  
  @default_themes %{
    light: %{
      # Primary colors
      primary_50: "#eff6ff",
      primary_100: "#dbeafe",
      primary_200: "#bfdbfe",
      primary_300: "#93c5fd",
      primary_400: "#60a5fa",
      primary_500: "#3b82f6",
      primary_600: "#2563eb",
      primary_700: "#1d4ed8",
      primary_800: "#1e40af",
      primary_900: "#1e3a8a",
      
      # Gray colors
      gray_50: "#f9fafb",
      gray_100: "#f3f4f6",
      gray_200: "#e5e7eb",
      gray_300: "#d1d5db",
      gray_400: "#9ca3af",
      gray_500: "#6b7280",
      gray_600: "#4b5563",
      gray_700: "#374151",
      gray_800: "#1f2937",
      gray_900: "#111827",
      
      # Semantic colors
      success: "#10b981",
      success_bg: "#d1fae5",
      success_border: "#6ee7b7",
      
      warning: "#f59e0b",
      warning_bg: "#fed7aa",
      warning_border: "#fbbf24",
      
      error: "#ef4444",
      error_bg: "#fee2e2",
      error_border: "#fca5a5",
      
      info: "#3b82f6",
      info_bg: "#dbeafe",
      info_border: "#93c5fd",
      
      # Background and surface
      bg_primary: "#ffffff",
      bg_secondary: "#f9fafb",
      bg_tertiary: "#f3f4f6",
      surface: "#ffffff",
      surface_hover: "#f9fafb",
      
      # Text colors
      text_primary: "#111827",
      text_secondary: "#4b5563",
      text_tertiary: "#6b7280",
      text_disabled: "#9ca3af",
      text_inverse: "#ffffff",
      
      # Border colors
      border_primary: "#e5e7eb",
      border_secondary: "#d1d5db",
      border_focus: "#3b82f6",
      
      # Shadows
      shadow_sm: "0 1px 2px 0 rgb(0 0 0 / 0.05)",
      shadow_md: "0 4px 6px -1px rgb(0 0 0 / 0.1)",
      shadow_lg: "0 10px 15px -3px rgb(0 0 0 / 0.1)",
      shadow_xl: "0 20px 25px -5px rgb(0 0 0 / 0.1)",
      
      # Other
      overlay_bg: "rgba(0, 0, 0, 0.5)",
      focus_ring: "0 0 0 3px rgba(59, 130, 246, 0.5)"
    },
    
    dark: %{
      # Primary colors
      primary_50: "#1e3a8a",
      primary_100: "#1e40af",
      primary_200: "#1d4ed8",
      primary_300: "#2563eb",
      primary_400: "#3b82f6",
      primary_500: "#60a5fa",
      primary_600: "#93c5fd",
      primary_700: "#bfdbfe",
      primary_800: "#dbeafe",
      primary_900: "#eff6ff",
      
      # Gray colors
      gray_50: "#111827",
      gray_100: "#1f2937",
      gray_200: "#374151",
      gray_300: "#4b5563",
      gray_400: "#6b7280",
      gray_500: "#9ca3af",
      gray_600: "#d1d5db",
      gray_700: "#e5e7eb",
      gray_800: "#f3f4f6",
      gray_900: "#f9fafb",
      
      # Semantic colors
      success: "#10b981",
      success_bg: "#064e3b",
      success_border: "#065f46",
      
      warning: "#f59e0b",
      warning_bg: "#78350f",
      warning_border: "#92400e",
      
      error: "#ef4444",
      error_bg: "#7f1d1d",
      error_border: "#991b1b",
      
      info: "#3b82f6",
      info_bg: "#1e3a8a",
      info_border: "#1e40af",
      
      # Background and surface
      bg_primary: "#0f172a",
      bg_secondary: "#1e293b",
      bg_tertiary: "#334155",
      surface: "#1e293b",
      surface_hover: "#334155",
      
      # Text colors
      text_primary: "#f9fafb",
      text_secondary: "#d1d5db",
      text_tertiary: "#9ca3af",
      text_disabled: "#6b7280",
      text_inverse: "#111827",
      
      # Border colors
      border_primary: "#334155",
      border_secondary: "#475569",
      border_focus: "#60a5fa",
      
      # Shadows
      shadow_sm: "0 1px 2px 0 rgb(0 0 0 / 0.25)",
      shadow_md: "0 4px 6px -1px rgb(0 0 0 / 0.3)",
      shadow_lg: "0 10px 15px -3px rgb(0 0 0 / 0.4)",
      shadow_xl: "0 20px 25px -5px rgb(0 0 0 / 0.5)",
      
      # Other
      overlay_bg: "rgba(0, 0, 0, 0.7)",
      focus_ring: "0 0 0 3px rgba(96, 165, 250, 0.5)"
    },
    
    high_contrast: %{
      # Primary colors
      primary_50: "#ffffff",
      primary_100: "#ffffff",
      primary_200: "#000000",
      primary_300: "#000000",
      primary_400: "#000000",
      primary_500: "#000000",
      primary_600: "#000000",
      primary_700: "#000000",
      primary_800: "#000000",
      primary_900: "#000000",
      
      # Gray colors
      gray_50: "#ffffff",
      gray_100: "#ffffff",
      gray_200: "#000000",
      gray_300: "#000000",
      gray_400: "#000000",
      gray_500: "#000000",
      gray_600: "#000000",
      gray_700: "#000000",
      gray_800: "#000000",
      gray_900: "#000000",
      
      # Background and surface
      bg_primary: "#ffffff",
      bg_secondary: "#ffffff",
      bg_tertiary: "#ffffff",
      surface: "#ffffff",
      surface_hover: "#f0f0f0",
      
      # Text colors
      text_primary: "#000000",
      text_secondary: "#000000",
      text_tertiary: "#000000",
      text_disabled: "#666666",
      text_inverse: "#ffffff",
      
      # Border colors
      border_primary: "#000000",
      border_secondary: "#000000",
      border_focus: "#000000",
      
      # Semantic colors
      success: "#008000",
      error: "#ff0000",
      warning: "#ffff00",
      info: "#0000ff",
      
      # Other
      overlay_bg: "rgba(0, 0, 0, 0.9)",
      focus_ring: "0 0 0 4px #000000"
    }
  }
  
  @doc """
  Theme provider wrapper that injects CSS variables.
  """
  def theme_provider(assigns) do
    theme = assigns[:theme] || :light
    custom_theme = assigns[:custom_theme] || %{}
    theme_vars = build_theme_variables(theme, custom_theme)
    
    assigns = 
      assigns
      |> assign(:theme_vars, theme_vars)
      |> assign(:current_theme, theme)
    
    ~H"""
    <div 
      id={@id}
      class="selecto-theme-provider"
      style={@theme_vars}
      data-theme={@current_theme}
      phx-hook="ThemeProvider"
    >
      <%= render_slot(@inner_block) %>
    </div>
    """
  end
  
  @doc """
  Generate CSS for theme variables.
  """
  def generate_theme_css do
    """
    /* SelectoComponents Theme Variables */
    :root {
      #{build_css_variables(@default_themes.light)}
    }
    
    [data-theme="dark"] {
      #{build_css_variables(@default_themes.dark)}
    }
    
    [data-theme="high-contrast"] {
      #{build_css_variables(@default_themes.high_contrast)}
    }
    
    /* Component styles using CSS variables */
    .selecto-theme-provider {
      background-color: var(--bg-primary);
      color: var(--text-primary);
      transition: background-color 0.3s ease, color 0.3s ease;
    }
    
    /* Tables */
    .selecto-table {
      background-color: var(--surface);
      border-color: var(--border-primary);
    }
    
    .selecto-table th {
      background-color: var(--bg-secondary);
      color: var(--text-secondary);
      border-color: var(--border-primary);
    }
    
    .selecto-table td {
      border-color: var(--border-primary);
      color: var(--text-primary);
    }
    
    .selecto-table tr:hover {
      background-color: var(--surface-hover);
    }
    
    /* Buttons */
    .selecto-btn-primary {
      background-color: var(--primary-500);
      color: var(--text-inverse);
      border-color: var(--primary-600);
    }
    
    .selecto-btn-primary:hover {
      background-color: var(--primary-600);
      border-color: var(--primary-700);
    }
    
    .selecto-btn-secondary {
      background-color: var(--bg-secondary);
      color: var(--text-primary);
      border: 1px solid var(--border-primary);
    }
    
    .selecto-btn-secondary:hover {
      background-color: var(--bg-tertiary);
    }
    
    /* Forms */
    .selecto-input {
      background-color: var(--surface);
      border-color: var(--border-primary);
      color: var(--text-primary);
    }
    
    .selecto-input:focus {
      border-color: var(--border-focus);
      box-shadow: var(--focus-ring);
    }
    
    .selecto-input:disabled {
      background-color: var(--bg-secondary);
      color: var(--text-disabled);
    }
    
    /* Cards */
    .selecto-card {
      background-color: var(--surface);
      border-color: var(--border-primary);
      box-shadow: var(--shadow-md);
    }
    
    /* Modals */
    .selecto-modal-backdrop {
      background-color: var(--overlay-bg);
    }
    
    .selecto-modal-content {
      background-color: var(--surface);
      box-shadow: var(--shadow-xl);
    }
    
    /* Alerts */
    .selecto-alert-success {
      background-color: var(--success-bg);
      border-color: var(--success-border);
      color: var(--success);
    }
    
    .selecto-alert-warning {
      background-color: var(--warning-bg);
      border-color: var(--warning-border);
      color: var(--warning);
    }
    
    .selecto-alert-error {
      background-color: var(--error-bg);
      border-color: var(--error-border);
      color: var(--error);
    }
    
    .selecto-alert-info {
      background-color: var(--info-bg);
      border-color: var(--info-border);
      color: var(--info);
    }
    
    /* Transitions */
    * {
      transition-property: background-color, border-color, color, fill, stroke;
      transition-timing-function: cubic-bezier(0.4, 0, 0.2, 1);
      transition-duration: 150ms;
    }
    
    /* Print styles */
    @media print {
      .selecto-theme-provider {
        background-color: white !important;
        color: black !important;
      }
      
      .selecto-table * {
        background-color: white !important;
        color: black !important;
        border-color: #000 !important;
      }
    }
    
    /* High contrast mode adjustments */
    @media (prefers-contrast: high) {
      :root {
        #{build_css_variables(@default_themes.high_contrast)}
      }
    }
    
    /* Dark mode preference */
    @media (prefers-color-scheme: dark) {
      :root:not([data-theme]) {
        #{build_css_variables(@default_themes.dark)}
      }
    }
    """
  end
  
  @doc """
  Get available theme names.
  """
  def available_themes do
    Map.keys(@default_themes)
  end
  
  @doc """
  Get theme configuration.
  """
  def get_theme(theme_name) do
    Map.get(@default_themes, theme_name, @default_themes.light)
  end
  
  @doc """
  Merge custom theme with base theme.
  """
  def merge_theme(base_theme, custom_theme) do
    base = get_theme(base_theme)
    Map.merge(base, custom_theme)
  end
  
  @doc """
  Export theme as JSON for storage.
  """
  def export_theme(theme_config) do
    Jason.encode!(theme_config)
  end
  
  @doc """
  Import theme from JSON.
  """
  def import_theme(json_string) do
    case Jason.decode(json_string) do
      {:ok, theme} -> {:ok, atomize_keys(theme)}
      error -> error
    end
  end
  
  # Private functions
  
  defp build_theme_variables(theme_name, custom_overrides) do
    theme = 
      get_theme(theme_name)
      |> Map.merge(custom_overrides)
    
    theme
    |> Enum.map(fn {key, value} ->
      "--#{String.replace(to_string(key), "_", "-")}: #{value}"
    end)
    |> Enum.join("; ")
  end
  
  defp build_css_variables(theme) do
    theme
    |> Enum.map(fn {key, value} ->
      "  --#{String.replace(to_string(key), "_", "-")}: #{value};"
    end)
    |> Enum.join("\n")
  end
  
  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} ->
      {String.to_atom(k), v}
    end)
  end
  
  @doc """
  JavaScript hooks for theme management.
  """
  def __hooks__() do
    %{
      "ThemeProvider" => %{
        mounted: """
        // Load saved theme preference
        const savedTheme = localStorage.getItem('selecto-theme');
        if (savedTheme && savedTheme !== this.el.dataset.theme) {
          this.pushEvent('change_theme', {theme: savedTheme});
        }
        
        // Watch for system theme changes
        if (window.matchMedia) {
          const darkModeQuery = window.matchMedia('(prefers-color-scheme: dark)');
          this.handleSystemThemeChange = (e) => {
            if (!localStorage.getItem('selecto-theme')) {
              this.pushEvent('change_theme', {theme: e.matches ? 'dark' : 'light'});
            }
          };
          darkModeQuery.addEventListener('change', this.handleSystemThemeChange);
        }
        
        // Watch for high contrast mode
        if (window.matchMedia) {
          const highContrastQuery = window.matchMedia('(prefers-contrast: high)');
          this.handleContrastChange = (e) => {
            if (e.matches && !localStorage.getItem('selecto-theme')) {
              this.pushEvent('change_theme', {theme: 'high_contrast'});
            }
          };
          highContrastQuery.addEventListener('change', this.handleContrastChange);
        }
        """,
        
        updated: """
        // Save theme preference when changed
        const currentTheme = this.el.dataset.theme;
        if (currentTheme) {
          localStorage.setItem('selecto-theme', currentTheme);
          
          // Dispatch custom event for other components
          window.dispatchEvent(new CustomEvent('selecto-theme-changed', {
            detail: {theme: currentTheme}
          }));
        }
        """,
        
        destroyed: """
        if (this.darkModeQuery) {
          this.darkModeQuery.removeEventListener('change', this.handleSystemThemeChange);
        }
        if (this.highContrastQuery) {
          this.highContrastQuery.removeEventListener('change', this.handleContrastChange);
        }
        """
      }
    }
  end
end