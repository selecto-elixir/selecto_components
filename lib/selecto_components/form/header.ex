defmodule SelectoComponents.Form.Header do
  use Phoenix.Component

  alias Phoenix.LiveView.JS
  alias SelectoComponents.Theme

  attr(:id, :any, required: true)
  attr(:theme, :map, required: true)
  attr(:controller_title, :string, required: true)
  attr(:current_view_label, :string, required: true)
  attr(:applied_filters, :list, default: [])
  attr(:promoted_filters, :list, default: [])
  attr(:summary_filters, :list, default: [])
  attr(:show_view_configurator, :boolean, default: true)

  slot(:promoted_filter)

  def summary(assigns) do
    ~H"""
    <div
      id={"selecto-controller-summary-#{@id}"}
      data-selecto-controller-summary
      class="mb-4 rounded-lg border p-3"
      style="border-color: var(--sc-surface-border); background: color-mix(in srgb, var(--sc-surface-bg-alt) 55%, var(--sc-surface-bg));"
    >
      <div class="flex items-start gap-3">
        <button
          type="button"
          phx-click={JS.push("toggle_show_view_configurator")}
          aria-expanded={to_string(@show_view_configurator)}
          aria-controls={"selecto-controller-body-#{@id}"}
          aria-label={if @show_view_configurator, do: "Collapse View Controller", else: "Expand View Controller"}
          title={if @show_view_configurator, do: "Collapse View Controller", else: "Expand View Controller"}
          class={[Theme.slot(@theme, :button_icon), "mt-0.5 h-10 w-10 shrink-0"]}
        >
          <svg
            class={["h-6 w-6 transition-transform", @show_view_configurator && "rotate-90"]}
            fill="none"
            viewBox="0 0 24 24"
            stroke-width="3"
            stroke="currentColor"
            aria-hidden="true"
          >
            <path stroke-linecap="round" stroke-linejoin="round" d="m9 5 7 7-7 7" />
          </svg>
        </button>

        <div class="min-w-0 flex-1 space-y-3">
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.2em]" style="color: var(--sc-text-muted);">
              {@controller_title}
            </p>
            <div class="mt-1 flex flex-wrap items-center gap-2">
              <h3 class="text-base font-semibold" style="color: var(--sc-text-primary);">
                {@current_view_label}
              </h3>
              <span
                class="inline-flex items-center rounded-full px-2 py-1 text-xs font-medium"
                style="background: color-mix(in srgb, var(--sc-primary) 14%, transparent); color: var(--sc-primary);"
              >
                {length(@applied_filters)} applied filter{if(length(@applied_filters) == 1, do: "", else: "s")}
              </span>
            </div>
          </div>

          <div :if={@promoted_filters != []} class="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
            <div
              :for={filter <- @promoted_filters}
              class="rounded-lg border p-3"
              style="border-color: var(--sc-surface-border); background: var(--sc-surface-bg);"
            >
              <label
                class="mb-1 block text-xs font-semibold tracking-[0.08em]"
                style="color: var(--sc-text-muted);"
              >
                {filter.label}
              </label>
              {render_slot(@promoted_filter, filter)}
            </div>
          </div>

          <div :if={Enum.empty?(@applied_filters) or @summary_filters != []} class="flex flex-wrap items-center gap-2">
            <%= if Enum.empty?(@applied_filters) do %>
              <span class="text-sm" style="color: var(--sc-text-secondary);">
                No filters applied
              </span>
            <% else %>
              <%= for filter_label <- Enum.take(@summary_filters, 4) do %>
                <span
                  class="inline-flex items-center rounded-full border px-2.5 py-1 text-xs font-medium"
                  style="border-color: var(--sc-surface-border); background: var(--sc-surface-bg); color: var(--sc-text-secondary);"
                >
                  {filter_label}
                </span>
              <% end %>

              <span :if={length(@summary_filters) > 4} class="text-xs font-medium" style="color: var(--sc-text-muted);">
                +{length(@summary_filters) - 4} more
              </span>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
