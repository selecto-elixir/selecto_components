defmodule SelectoComponents.Views.Graph.YAxisConfig do
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
    <div class={Theme.slot(@theme, :panel) <> " p-3"} style="background: color-mix(in srgb, var(--sc-accent-soft) 55%, var(--sc-surface-bg));">
      <div class="flex items-center justify-between mb-2">
        <span class="font-medium text-sm" style="color: var(--sc-text-primary)"><%= @col.name %></span>
        <span class="text-xs" style="color: var(--sc-text-muted)"><%= Map.get(@col, :type, :string) %></span>
      </div>
      
      <div class="grid grid-cols-1 gap-3">
        <!-- Aggregate Function -->
        <div>
          <label class="mb-1 block text-xs font-medium" style="color: var(--sc-text-secondary)">Aggregate Function</label>
          <.sc_select_with_slot theme={@theme} name={"#{@prefix}[function]"}>
            <option value="count" selected={Map.get(@config, "function", "count") == "count"}>Count</option>
            <option value="sum" selected={Map.get(@config, "function") == "sum"}>Sum</option>
            <option value="avg" selected={Map.get(@config, "function") == "avg"}>Average</option>
            <option value="min" selected={Map.get(@config, "function") == "min"}>Minimum</option>
            <option value="max" selected={Map.get(@config, "function") == "max"}>Maximum</option>
            <option value="count_distinct" selected={Map.get(@config, "function") == "count_distinct"}>Count Distinct</option>
          </.sc_select_with_slot>
        </div>

        <!-- Custom Alias -->
        <div>
          <label class="mb-1 block text-xs font-medium" style="color: var(--sc-text-secondary)">Label</label>
          <.sc_input
            theme={@theme}
            name={"#{@prefix}[alias]"}
            value={Map.get(@config, "alias", "")}
            placeholder={generate_default_alias(@col.name, Map.get(@config, "function", "count"))}
          />
        </div>

        <!-- Number Formatting -->
        <div>
          <label class="mb-1 block text-xs font-medium" style="color: var(--sc-text-secondary)">Number Format</label>
          <.sc_select_with_slot theme={@theme} name={"#{@prefix}[number_format]"}>
            <option value="" selected={Map.get(@config, "number_format", "") == ""}>Default</option>
            <option value="integer" selected={Map.get(@config, "number_format") == "integer"}>Integer (1,234)</option>
            <option value="decimal_1" selected={Map.get(@config, "number_format") == "decimal_1"}>1 Decimal (1,234.5)</option>
            <option value="decimal_2" selected={Map.get(@config, "number_format") == "decimal_2"}>2 Decimals (1,234.56)</option>
            <option value="percentage" selected={Map.get(@config, "number_format") == "percentage"}>Percentage (12.34%)</option>
            <option value="currency" selected={Map.get(@config, "number_format") == "currency"}>Currency ($1,234.56)</option>
          </.sc_select_with_slot>
        </div>

        <div>
          <label class="mb-1 block text-xs font-medium" style="color: var(--sc-text-secondary)">Series Type</label>
          <.sc_select_with_slot theme={@theme} name={"#{@prefix}[series_type]"}>
            <option value="auto" selected={Map.get(@config, "series_type", "auto") == "auto"}>Auto</option>
            <option value="bar" selected={Map.get(@config, "series_type") == "bar"}>Bar</option>
            <option value="line" selected={Map.get(@config, "series_type") == "line"}>Line</option>
          </.sc_select_with_slot>
        </div>

        <div>
          <label class="mb-1 block text-xs font-medium" style="color: var(--sc-text-secondary)">Axis</label>
          <.sc_select_with_slot theme={@theme} name={"#{@prefix}[axis]"}>
            <option value="left" selected={Map.get(@config, "axis", "left") == "left"}>Left (Y)</option>
            <option value="right" selected={Map.get(@config, "axis") == "right"}>Right (Y2)</option>
          </.sc_select_with_slot>
        </div>

        <!-- Color (for multiple Y-axis series) -->
        <div>
          <label class="mb-1 block text-xs font-medium" style="color: var(--sc-text-secondary)">Color</label>
          <input
            name={"#{@prefix}[color]"}
            type="color"
            value={Map.get(@config, "color", "#3b82f6")}
            class="h-8 w-12 cursor-pointer rounded border"
            style="border-color: var(--sc-surface-border); background: var(--sc-surface-bg);"
          />
        </div>
      </div>
    </div>
    """
  end

  defp generate_default_alias(field_name, function) do
    case function do
      "count" -> "Count"
      "sum" -> "Sum of #{field_name}"
      "avg" -> "Average #{field_name}"
      "min" -> "Min #{field_name}"
      "max" -> "Max #{field_name}"
      "count_distinct" -> "Distinct #{field_name}"
      _ -> field_name
    end
  end
end
