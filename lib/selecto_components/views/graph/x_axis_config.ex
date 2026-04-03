defmodule SelectoComponents.Views.Graph.XAxisConfig do
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

    assigns =
      assign(
        assigns,
        :col_type_label,
        format_type(Selecto.Temporal.date_like_type(col) || Map.get(col, :type, :string))
      )

    ~H"""
    <div class={Theme.slot(@theme, :panel) <> " p-3"} style="background: var(--sc-surface-bg-alt);">
      <div class="flex items-center justify-between mb-2">
        <span class="font-medium text-sm" style="color: var(--sc-text-primary)"><%= @col.name %></span>
        <span class="text-xs" style="color: var(--sc-text-muted)"><%= @col_type_label %></span>
      </div>
      
      <div class="grid grid-cols-1 gap-3">
        <!-- Custom Alias -->
        <div>
          <label class="mb-1 block text-xs font-medium" style="color: var(--sc-text-secondary)">Label</label>
          <.sc_input
            theme={@theme}
            name={"#{@prefix}[alias]"}
            value={Map.get(@config, "alias", "")}
            placeholder={@col.name}
          />
        </div>

        <!-- Datetime Formatting (if applicable) -->
        <div :if={(Selecto.Temporal.date_like_type(@col) || Map.get(@col, :type, :string)) in [:naive_datetime, :utc_datetime, :date]}>
          <label class="mb-1 block text-xs font-medium" style="color: var(--sc-text-secondary)">Date Format</label>
          <.sc_select_with_slot theme={@theme} name={"#{@prefix}[format]"} value={Map.get(@config, "format", "") == "" && ""}>
            <option value="" selected={Map.get(@config, "format", "") == ""}>Default</option>
            <%= for {value, label} <- SelectoComponents.Helpers.datetime_grouping_format_options() do %>
              <option value={value} selected={Map.get(@config, "format") == value}>{label}</option>
            <% end %>
          </.sc_select_with_slot>
        </div>

        <div :if={Map.get(@config, "format") in ["age_buckets", "custom_buckets", "year_buckets"]}>
          <label class="mb-1 block text-xs font-medium" style="color: var(--sc-text-secondary)">Bucket Ranges</label>
          <.sc_input
            theme={@theme}
            name={"#{@prefix}[bucket_ranges]"}
            value={Map.get(@config, "bucket_ranges", "")}
            placeholder={SelectoComponents.Helpers.datetime_bucket_placeholder(Map.get(@config, "format"))}
          />
        </div>

        <!-- String truncation (if applicable) -->
        <div :if={Map.get(@col, :type, :string) in [:string, :text]}>
          <label class="mb-1 block text-xs font-medium" style="color: var(--sc-text-secondary)">Max Length</label>
          <.sc_input
            theme={@theme}
            name={"#{@prefix}[max_length]"}
            type="number"
            value={Map.get(@config, "max_length", "")}
            placeholder="No limit"
            min="1"
          />
        </div>

        <!-- Sorting -->
        <div>
          <label class="mb-1 block text-xs font-medium" style="color: var(--sc-text-secondary)">Sort Order</label>
          <.sc_select_with_slot theme={@theme} name={"#{@prefix}[sort]"}>
            <option value="" selected={Map.get(@config, "sort", "") == ""}>Default</option>
            <option value="asc" selected={Map.get(@config, "sort") == "asc"}>Ascending</option>
            <option value="desc" selected={Map.get(@config, "sort") == "desc"}>Descending</option>
          </.sc_select_with_slot>
        </div>
      </div>
    </div>
    """
  end

  defp format_type(type) when is_atom(type), do: Atom.to_string(type)
  defp format_type(type), do: inspect(type)
end
