defmodule SelectoComponents.Form.ExportPanel do
  use Phoenix.Component

  import SelectoComponents.Components.Common

  alias SelectoComponents.Theme

  attr(:theme, :map, required: true)
  attr(:id, :any, required: true)
  attr(:use_export_delivery, :boolean, default: false)
  attr(:use_scheduled_exports, :boolean, default: false)
  attr(:use_exported_views, :boolean, default: false)
  attr(:scheduled_export_module, :any, default: nil)
  attr(:scheduled_export_context, :any, default: nil)
  attr(:exported_view_module, :any, default: nil)
  attr(:exported_view_context, :any, default: nil)
  attr(:exported_view_endpoint, :any, default: nil)
  attr(:exported_view_base_url, :any, default: nil)
  attr(:current_user_id, :any, default: nil)
  attr(:selecto, :any, required: true)
  attr(:views, :list, required: true)
  attr(:view_config, :map, required: true)
  attr(:path, :any, default: nil)
  attr(:tenant_context, :any, default: nil)

  def panel(assigns) do
    ~H"""
    <div class="space-y-6">
      <p class="text-sm" style="color: var(--sc-text-secondary);">
        Export current query results now:
      </p>

      <div class="flex flex-wrap gap-2">
        <.sc_button type="button" phx-click="export_data" phx-value-format="csv" theme={@theme}>
          Download CSV
        </.sc_button>
        <.sc_button type="button" phx-click="export_data" phx-value-format="tsv" theme={@theme}>
          Download TSV
        </.sc_button>
        <.sc_button type="button" phx-click="export_data" phx-value-format="json" theme={@theme}>
          Download JSON
        </.sc_button>
        <.sc_button type="button" phx-click="export_data" phx-value-format="xlsx" theme={@theme}>
          Download XLSX
        </.sc_button>
      </div>

      <div
        :if={@use_export_delivery}
        class={Theme.slot(@theme, :panel) <> " space-y-4 p-4"}
        style="background: color-mix(in srgb, var(--sc-surface-bg-alt) 70%, var(--sc-surface-bg));"
      >
        <div>
          <h4 class="text-sm font-semibold" style="color: var(--sc-text-primary);">
            Send Current Results by Email
          </h4>
          <p class="text-xs" style="color: var(--sc-text-muted);">
            Uses the current query results and sends them through the configured host-app delivery adapter.
          </p>
        </div>

        <div class="grid gap-4 lg:grid-cols-2">
          <div class="space-y-2 lg:col-span-2">
            <label
              class="text-sm font-medium"
              style="color: var(--sc-text-secondary);"
              for={"export-email-recipients-#{@id}"}
            >
              Recipients
            </label>
            <input
              id={"export-email-recipients-#{@id}"}
              class={Theme.slot(@theme, :input)}
              placeholder="ops@example.com, finance@example.com"
            />
            <p class="text-xs" style="color: var(--sc-text-muted);">
              Separate recipients with commas, semicolons, or new lines.
            </p>
          </div>

          <div class="space-y-2">
            <label
              class="text-sm font-medium"
              style="color: var(--sc-text-secondary);"
              for={"export-email-format-#{@id}"}
            >
              Format
            </label>
            <select id={"export-email-format-#{@id}"} class={Theme.slot(@theme, :select)}>
              <option value="csv" selected>CSV</option>
              <option value="tsv">TSV</option>
              <option value="json">JSON</option>
              <option value="xlsx">XLSX</option>
            </select>
          </div>

          <div class="space-y-2">
            <label
              class="text-sm font-medium"
              style="color: var(--sc-text-secondary);"
              for={"export-email-subject-#{@id}"}
            >
              Subject
            </label>
            <input
              id={"export-email-subject-#{@id}"}
              class={Theme.slot(@theme, :input)}
              placeholder="Current Selecto export"
            />
          </div>

          <div class="space-y-2 lg:col-span-2">
            <label
              class="text-sm font-medium"
              style="color: var(--sc-text-secondary);"
              for={"export-email-body-#{@id}"}
            >
              Body
            </label>
            <textarea
              id={"export-email-body-#{@id}"}
              rows="4"
              class={Theme.slot(@theme, :input)}
              placeholder="Attached is the latest export."
            ></textarea>
          </div>
        </div>

        <div class="flex items-center justify-between gap-3">
          <p class="text-xs" style="color: var(--sc-text-muted);">
            This first slice sends the already-loaded result set rather than re-running the query.
          </p>
          <button
            type="button"
            data-export-email-button="true"
            data-recipients-input={"export-email-recipients-#{@id}"}
            data-format-input={"export-email-format-#{@id}"}
            data-subject-input={"export-email-subject-#{@id}"}
            data-body-input={"export-email-body-#{@id}"}
            class={Theme.slot(@theme, :button_primary) <> " px-4 py-2 text-sm shadow-sm"}
          >
            Send Email Export
          </button>
        </div>
      </div>

      <p :if={!@use_export_delivery} class="text-xs" style="color: var(--sc-text-muted);">
        Assign `export_delivery_module` in the host LiveView to enable one-off email delivery.
      </p>

      <.live_component
        :if={@use_scheduled_exports}
        module={SelectoComponents.ScheduledExports.Manager}
        id="scheduled_exports_manager"
        scheduled_export_module={@scheduled_export_module}
        scheduled_export_context={@scheduled_export_context}
        theme={@theme}
        current_user_id={@current_user_id}
        selecto={@selecto}
        views={@views}
        view_config={@view_config}
        path={@path}
        tenant_context={@tenant_context}
      />

      <.live_component
        :if={@use_exported_views}
        module={SelectoComponents.ExportedViews.Manager}
        id="exported_views_manager"
        exported_view_module={@exported_view_module}
        exported_view_context={@exported_view_context}
        exported_view_endpoint={@exported_view_endpoint}
        exported_view_base_url={@exported_view_base_url}
        theme={@theme}
        current_user_id={@current_user_id}
        selecto={@selecto}
        views={@views}
        view_config={@view_config}
        path={@path}
        tenant_context={@tenant_context}
      />
    </div>
    """
  end
end
