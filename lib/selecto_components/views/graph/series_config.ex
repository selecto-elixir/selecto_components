defmodule SelectoComponents.Views.Graph.SeriesConfig do
  use Phoenix.LiveComponent

  import SelectoComponents.Components.Common
  alias SelectoComponents.Theme

  def render(assigns) do
    col =
      case Map.get(assigns, :col) do
        %{} = col -> col
        _ -> %{name: Map.get(assigns, :item, "Unknown field"), type: :string}
      end

    config =
      case Map.get(assigns, :config) do
        %{} = config -> config
        _ -> %{}
      end

    assigns = assigns |> Map.put_new(:theme, Theme.default_theme(:light)) |> assign(:col, col)
    assigns = assign(assigns, :config, config)

    ~H"""
    <div class={Theme.slot(@theme, :panel) <> " p-3"} style="background: color-mix(in srgb, var(--sc-surface-bg-alt) 60%, var(--sc-accent-soft));">
      <div class="flex items-center justify-between mb-2">
        <span class="font-medium text-sm" style="color: var(--sc-text-primary)"><%= @col.name %></span>
        <span class="text-xs" style="color: var(--sc-text-muted)"><%= Map.get(@col, :type, :string) %></span>
      </div>
      
      <div class="grid grid-cols-1 gap-3">
        <!-- Custom Alias -->
        <div>
          <label class="mb-1 block text-xs font-medium" style="color: var(--sc-text-secondary)">Series Label</label>
          <.sc_input theme={@theme} name={"#{@prefix}[alias]"} value={Map.get(@config, "alias", "")} placeholder={@col.name} />
        </div>

        <!-- Datetime Formatting (if applicable) -->
        <div :if={Map.get(@col, :type, :string) in [:naive_datetime, :utc_datetime, :date]}>
          <label class="mb-1 block text-xs font-medium" style="color: var(--sc-text-secondary)">Date Format</label>
          <.sc_select_with_slot theme={@theme} name={"#{@prefix}[format]"}>
            <option value="" selected={Map.get(@config, "format", "") == ""}>Default</option>
            <%= for {value, label} <- SelectoComponents.Helpers.datetime_grouping_format_options() do %>
              <option value={value} selected={Map.get(@config, "format") == value}>{label}</option>
            <% end %>
          </.sc_select_with_slot>
        </div>

        <div :if={Map.get(@config, "format") in ["age_buckets", "custom_buckets", "year_buckets"]}>
          <label class="mb-1 block text-xs font-medium" style="color: var(--sc-text-secondary)">Bucket Ranges</label>
          <.sc_input theme={@theme} name={"#{@prefix}[bucket_ranges]"} value={Map.get(@config, "bucket_ranges", "")} placeholder={SelectoComponents.Helpers.datetime_bucket_placeholder(Map.get(@config, "format"))} />
        </div>

        <!-- Max Series Count -->
        <div>
          <label class="mb-1 block text-xs font-medium" style="color: var(--sc-text-secondary)">Max Series</label>
          <.sc_input theme={@theme} name={"#{@prefix}[max_series]"} type="number" value={Map.get(@config, "max_series", "10")} placeholder="10" min="1" max="20" />
          <p class="mt-1 text-xs" style="color: var(--sc-text-muted)">Limit number of series to prevent chart clutter</p>
        </div>

        <!-- Color Palette -->
        <div>
          <label class="mb-1 block text-xs font-medium" style="color: var(--sc-text-secondary)">Color Palette</label>
          <.sc_select_with_slot theme={@theme} name={"#{@prefix}[color_palette]"}>
            <option value="default" selected={Map.get(@config, "color_palette", "default") == "default"}>Default Blues</option>
            <option value="rainbow" selected={Map.get(@config, "color_palette") == "rainbow"}>Rainbow</option>
            <option value="warm" selected={Map.get(@config, "color_palette") == "warm"}>Warm Colors</option>
            <option value="cool" selected={Map.get(@config, "color_palette") == "cool"}>Cool Colors</option>
            <option value="pastel" selected={Map.get(@config, "color_palette") == "pastel"}>Pastel</option>
            <option value="high_contrast" selected={Map.get(@config, "color_palette") == "high_contrast"}>High Contrast</option>
          </.sc_select_with_slot>
        </div>

        <!-- Series Sorting -->
        <div>
          <label class="mb-1 block text-xs font-medium" style="color: var(--sc-text-secondary)">Sort Series By</label>
          <.sc_select_with_slot theme={@theme} name={"#{@prefix}[series_sort]"}>
            <option value="name_asc" selected={Map.get(@config, "series_sort", "name_asc") == "name_asc"}>Name (A-Z)</option>
            <option value="name_desc" selected={Map.get(@config, "series_sort") == "name_desc"}>Name (Z-A)</option>
            <option value="value_asc" selected={Map.get(@config, "series_sort") == "value_asc"}>Value (Low-High)</option>
            <option value="value_desc" selected={Map.get(@config, "series_sort") == "value_desc"}>Value (High-Low)</option>
          </.sc_select_with_slot>
        </div>
      </div>
    </div>
    """
  end
end
