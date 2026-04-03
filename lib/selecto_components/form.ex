defmodule SelectoComponents.Form do
  use Phoenix.LiveComponent

  import SelectoComponents.Components.Common
  alias Phoenix.LiveView.JS
  alias SelectoComponents.Theme
  alias SelectoComponents.ErrorHandling.ErrorBuilder
  alias SelectoComponents.ErrorHandling.ErrorSanitizer
  alias SelectoComponents.ErrorHandling.ErrorDisplay
  alias SelectoComponents.Form.FilterRendering
  alias SelectoComponents.Views.Runtime, as: ViewRuntime

  @doc """
  Form for configuing Selecto View

  attrs:
  selecto: the selecto structure
  view_config: attr which contains the data to draw the view

  """

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns,
        columns: build_column_list(assigns.selecto),
        field_filters: FilterRendering.build_filter_list(assigns.selecto),
        controller_title: Map.get(assigns, :controller_title, "View Controller"),
        show_view_configurator: Map.get(assigns, :show_view_configurator, true),
        current_view_label: current_view_label(assigns.views, assigns.view_config.view_mode),
        applied_filters:
          applied_filters(assigns.selecto, Map.get(assigns.view_config, :filters, [])),
        form_state_revision: Map.get(assigns, :form_state_revision, 0),
        theme: Theme.resolve_theme(assigns),
        use_saved_views: Map.get(assigns, :saved_view_module, false),
        use_exported_views: Map.get(assigns, :exported_view_module, false),
        use_export_delivery: Map.get(assigns, :export_delivery_module, false),
        use_scheduled_exports: Map.get(assigns, :scheduled_export_module, false),
        theme_stylesheet: Theme.stylesheet(),
        form: to_form(%{}, as: "view_config")
      )

    ~H"""
    <div
      id={"selecto-form-#{@id}"}
      phx-hook=".ExportDownloads"
      data-selecto-form
      data-selecto-theme={@theme.id}
      style={Theme.style_attr(@theme)}
      class={[Theme.slot(@theme, :root), Theme.slot(@theme, :panel), "border-2 p-1"]}
    >
      <style><%= Phoenix.HTML.raw(@theme_stylesheet) %></style>
      <.form for={@form} phx-change="view-validate" phx-submit="view-apply">
        <input type="hidden" name="form_state_revision" value={@form_state_revision} />
        <.live_component
          :if={Map.get(assigns, :execution_error) || Map.get(assigns, :component_errors, [])}
          module={ErrorDisplay}
          id="error_display"
          error={Map.get(assigns, :execution_error)}
          errors={Map.get(assigns, :component_errors, [])}
        />

        <div
          id={"selecto-controller-summary-#{@id}"}
          data-selecto-controller-summary
          class="mb-4 flex flex-col gap-3 rounded-lg border p-3 lg:flex-row lg:items-start lg:justify-between"
          style="border-color: var(--sc-surface-border); background: color-mix(in srgb, var(--sc-surface-bg-alt) 55%, var(--sc-surface-bg));"
        >
          <div class="min-w-0 space-y-3">
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

            <div class="flex flex-wrap items-center gap-2">
              <%= if Enum.empty?(@applied_filters) do %>
                <span class="text-sm" style="color: var(--sc-text-secondary);">
                  No filters applied
                </span>
              <% else %>
                <%= for filter_label <- Enum.take(@applied_filters, 4) do %>
                  <span
                    class="inline-flex items-center rounded-full border px-2.5 py-1 text-xs font-medium"
                    style="border-color: var(--sc-surface-border); background: var(--sc-surface-bg); color: var(--sc-text-secondary);"
                  >
                    {filter_label}
                  </span>
                <% end %>

                <span
                  :if={length(@applied_filters) > 4}
                  class="text-xs font-medium"
                  style="color: var(--sc-text-muted);"
                >
                  +{length(@applied_filters) - 4} more
                </span>
              <% end %>
            </div>
          </div>

          <button
            type="button"
            phx-click={JS.push("toggle_show_view_configurator")}
            aria-expanded={to_string(@show_view_configurator)}
            aria-controls={"selecto-controller-body-#{@id}"}
            class="inline-flex items-center justify-center rounded-md border px-3 py-2 text-sm font-medium transition"
            style="border-color: var(--sc-surface-border); background: var(--sc-surface-bg); color: var(--sc-text-primary);"
          >
            Toggle View Controller
          </button>
        </div>

        <div
          id={"selecto-controller-body-#{@id}"}
          data-selecto-controller-body
          aria-hidden={to_string(!@show_view_configurator)}
          class={if @show_view_configurator, do: "", else: "hidden"}
        >
          <.live_component
            :if={Map.get(assigns, :saved_view_config_module)}
            module={SelectoComponents.ViewConfigManager}
            id="view_config_manager"
            view_config={@view_config}
            saved_view_config_module={Map.get(assigns, :saved_view_config_module)}
            saved_view_context={
              SelectoComponents.Tenant.scoped_context(
                Map.get(assigns, :saved_view_context),
                Map.get(assigns, :tenant_context)
              )
            }
            current_user_id={Map.get(assigns, :current_user_id)}
            parent_id={@myself}
          />

          <div class="mb-4 flex border-b" style="border-color: var(--sc-surface-border)">
            <div class="flex space-x-1" role="tablist" aria-label="Configuration Sections">
              <button
                type="button"
                role="tab"
                aria-selected={@active_tab == "view" or @active_tab == nil}
                aria-controls="main-tabpanel-view"
                id="main-tab-view"
                phx-click={JS.push("set_active_tab", value: %{tab: "view"})}
                class={[
                  "px-4 py-2 text-sm font-medium",
                  if @active_tab == "view" or @active_tab == nil do
                    Theme.slot(@theme, :tab_active)
                  else
                    Theme.slot(@theme, :tab_inactive)
                  end
                ]}
              >
                View
              </button>

              <button
                type="button"
                role="tab"
                aria-selected={@active_tab == "filter"}
                aria-controls="main-tabpanel-filter"
                id="main-tab-filter"
                phx-click={JS.push("set_active_tab", value: %{tab: "filter"})}
                class={[
                  "px-4 py-2 text-sm font-medium",
                  if @active_tab == "filter" do
                    Theme.slot(@theme, :tab_active)
                  else
                    Theme.slot(@theme, :tab_inactive)
                  end
                ]}
              >
                Filters
              </button>

              <button
                :if={@use_saved_views}
                type="button"
                role="tab"
                aria-selected={@active_tab == "save"}
                aria-controls="main-tabpanel-save"
                id="main-tab-save"
                phx-click={JS.push("set_active_tab", value: %{tab: "save"})}
                class={[
                  "px-4 py-2 text-sm font-medium",
                  if @active_tab == "save" do
                    Theme.slot(@theme, :tab_active)
                  else
                    Theme.slot(@theme, :tab_inactive)
                  end
                ]}
              >
                Save View
              </button>

              <button
                type="button"
                role="tab"
                aria-selected={@active_tab == "export"}
                aria-controls="main-tabpanel-export"
                id="main-tab-export"
                phx-click={JS.push("set_active_tab", value: %{tab: "export"})}
                class={[
                  "px-4 py-2 text-sm font-medium",
                  if @active_tab == "export" do
                    Theme.slot(@theme, :tab_active)
                  else
                    Theme.slot(@theme, :tab_inactive)
                  end
                ]}
              >
                Export
              </button>
            </div>
          </div>

          <div
            role="tabpanel"
            id="main-tabpanel-view"
            aria-labelledby="main-tab-view"
            class={
              if @active_tab == "view" or @active_tab == nil do
                Theme.slot(@theme, :panel) <> " p-3"
              else
                "hidden"
              end
            }
          >
            <.live_component
              module={SelectoComponents.Components.Tabs}
              id="view_mode"
              fieldname="view_mode"
              view_mode={@view_config.view_mode}
              options={@views}
            >
              <:section :let={{id, _mod, _, _} = view}>
                <.live_component
                  module={ViewRuntime.form_component(view)}
                  id={"view_#{id}_form"}
                  theme={@theme}
                  columns={@columns}
                  view_config={@view_config}
                  view={view}
                  selecto={@selecto}
                />
              </:section>
            </.live_component>
          </div>

        <div
          role="tabpanel"
          id="main-tabpanel-filter"
          aria-labelledby="main-tab-filter"
          class={
            if @active_tab == "filter" do
              Theme.slot(@theme, :panel) <> " p-3"
            else
              "hidden"
            end
          }
        >
          <!-- Filter Sets Component -->
          <.live_component
            :if={Map.get(assigns, :filter_sets_adapter)}
            module={SelectoComponents.Filter.FilterSets}
            id="filter_sets"
            user_id={Map.get(assigns, :user_id)}
            domain={
              SelectoComponents.Tenant.scoped_context(
                Map.get(assigns, :domain) || Map.get(assigns, :path),
                Map.get(assigns, :tenant_context)
              )
            }
            current_filters={@view_config.filters}
            filter_sets_adapter={Map.get(assigns, :filter_sets_adapter)}
          />

          <.live_component
              module={SelectoComponents.Components.TreeBuilder}
              id={"#{@id}_tree_builder_#{FilterRendering.hash_filter_structure(@view_config.filters)}"}
              theme={@theme}
              available={FilterRendering.build_filter_list(@selecto)}
              filters={@view_config.filters}
          >
            <:filter_form :let={{uuid, index, section, filter_value}}>
              {FilterRendering.render_filter_form(assigns, uuid, index, section, filter_value)}
            </:filter_form>
          </.live_component>
        </div>

        <div
          :if={@use_saved_views}
          role="tabpanel"
          id="main-tabpanel-save"
          aria-labelledby="main-tab-save"
          class={
            if @active_tab == "save" do
              Theme.slot(@theme, :panel) <> " p-3"
            else
              "hidden"
            end
          }
        >
          <h3 class="text-base-content font-medium mb-2">Save View Configuration</h3>
          <div class="space-y-4">
            <p class="text-sm text-gray-600 dark:text-gray-400">
              Save your current view configuration for later use.
            </p>
            <div class="flex items-center gap-2">
              <label for="save_as" class="text-sm font-medium">Save As:</label>
              <.sc_input name="save_as" id="save_as" placeholder="Enter view name..." class="flex-1" theme={@theme} />
            </div>
          </div>
        </div>

        <div
          role="tabpanel"
          id="main-tabpanel-export"
          aria-labelledby="main-tab-export"
          class={
            if @active_tab == "export" do
              Theme.slot(@theme, :panel) <> " p-3"
            else
              "hidden"
            end
          }
        >
          <h3 class="text-base-content font-medium mb-2">Export Options</h3>
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

            <div :if={@use_export_delivery} class={Theme.slot(@theme, :panel) <> " space-y-4 p-4"} style="background: color-mix(in srgb, var(--sc-surface-bg-alt) 70%, var(--sc-surface-bg));">
              <div>
                <h4 class="text-sm font-semibold" style="color: var(--sc-text-primary);">Send Current Results by Email</h4>
                <p class="text-xs" style="color: var(--sc-text-muted);">
                  Uses the current query results and sends them through the configured host-app delivery adapter.
                </p>
              </div>

              <div class="grid gap-4 lg:grid-cols-2">
                <div class="space-y-2 lg:col-span-2">
                  <label class="text-sm font-medium" style="color: var(--sc-text-secondary);" for={"export-email-recipients-#{@id}"}>Recipients</label>
                  <input id={"export-email-recipients-#{@id}"} class={Theme.slot(@theme, :input)} placeholder="ops@example.com, finance@example.com" />
                  <p class="text-xs" style="color: var(--sc-text-muted);">Separate recipients with commas, semicolons, or new lines.</p>
                </div>

                <div class="space-y-2">
                  <label class="text-sm font-medium" style="color: var(--sc-text-secondary);" for={"export-email-format-#{@id}"}>Format</label>
                  <select id={"export-email-format-#{@id}"} class={Theme.slot(@theme, :select)}>
                    <option value="csv" selected>CSV</option>
                    <option value="tsv">TSV</option>
                    <option value="json">JSON</option>
                    <option value="xlsx">XLSX</option>
                  </select>
                </div>

                <div class="space-y-2">
                  <label class="text-sm font-medium" style="color: var(--sc-text-secondary);" for={"export-email-subject-#{@id}"}>Subject</label>
                  <input id={"export-email-subject-#{@id}"} class={Theme.slot(@theme, :input)} placeholder="Current Selecto export" />
                </div>

                <div class="space-y-2 lg:col-span-2">
                  <label class="text-sm font-medium" style="color: var(--sc-text-secondary);" for={"export-email-body-#{@id}"}>Body</label>
                  <textarea id={"export-email-body-#{@id}"} rows="4" class={Theme.slot(@theme, :input)} placeholder="Attached is the latest export."></textarea>
                </div>
              </div>

              <div class="flex items-center justify-between gap-3">
                <p class="text-xs" style="color: var(--sc-text-muted);">This first slice sends the already-loaded result set rather than re-running the query.</p>
                <button type="button" data-export-email-button="true" data-recipients-input={"export-email-recipients-#{@id}"} data-format-input={"export-email-format-#{@id}"} data-subject-input={"export-email-subject-#{@id}"} data-body-input={"export-email-body-#{@id}"} class={Theme.slot(@theme, :button_primary) <> " px-4 py-2 text-sm shadow-sm"}>
                  Send Email Export
                </button>
              </div>
            </div>

            <p :if={!@use_export_delivery} class="text-xs text-gray-500 dark:text-gray-400">
              Assign `export_delivery_module` in the host LiveView to enable one-off email delivery.
            </p>

            <.live_component
              :if={@use_scheduled_exports}
              module={SelectoComponents.ScheduledExports.Manager}
              id="scheduled_exports_manager"
              scheduled_export_module={Map.get(assigns, :scheduled_export_module)}
              scheduled_export_context={
                Map.get(assigns, :scheduled_export_context) ||
                  SelectoComponents.Tenant.scoped_context(
                    Map.get(assigns, :saved_view_context) || Map.get(assigns, :path),
                    Map.get(assigns, :tenant_context)
                  )
              }
              current_user_id={Map.get(assigns, :current_user_id)}
              selecto={@selecto}
              views={@views}
              view_config={@view_config}
              path={Map.get(assigns, :path) || Map.get(assigns, :my_path)}
              tenant_context={Map.get(assigns, :tenant_context)}
            />

            <.live_component
              :if={@use_exported_views}
              module={SelectoComponents.ExportedViews.Manager}
              id="exported_views_manager"
              exported_view_module={Map.get(assigns, :exported_view_module)}
              exported_view_context={
                Map.get(assigns, :exported_view_context) ||
                  SelectoComponents.Tenant.scoped_context(
                    Map.get(assigns, :saved_view_context) || Map.get(assigns, :path),
                    Map.get(assigns, :tenant_context)
                  )
              }
              exported_view_endpoint={Map.get(assigns, :exported_view_endpoint)}
              exported_view_base_url={Map.get(assigns, :exported_view_base_url)}
              current_user_id={Map.get(assigns, :current_user_id)}
              selecto={@selecto}
              views={@views}
              view_config={@view_config}
              path={Map.get(assigns, :path) || Map.get(assigns, :my_path)}
              tenant_context={Map.get(assigns, :tenant_context)}
            />
          </div>
        </div>
          <.sc_button theme={@theme}>Submit</.sc_button>
        </div>
      </.form>

      <%!-- Render modal if enabled and triggered --%>
      <%= if detail_modal_visible?(assigns) do %>
        <%= if custom_modal_component = Map.get(assigns, :detail_modal_component) do %>
          <.live_component
            module={custom_modal_component}
            id="detail-modal"
            detail_data={@modal_detail_data}
          />
        <% else %>
          <%= case Map.get(@modal_detail_data, :action_type, :modal) do %>
            <% :iframe_modal -> %>
              <.live_component
                module={SelectoComponents.Modal.IframeModal}
                id="detail-modal"
                record={@modal_detail_data.record}
                current_index={@modal_detail_data.current_index}
                total_records={@modal_detail_data.total_records}
                records={@modal_detail_data.records}
                title={Map.get(@modal_detail_data, :title, "Preview")}
                title_template={Map.get(@modal_detail_data, :title_template)}
                iframe_url={Map.get(@modal_detail_data, :iframe_url)}
                url_template={Map.get(@modal_detail_data, :url_template)}
                iframe_allow={Map.get(@modal_detail_data, :iframe_allow)}
                iframe_referrer_policy={Map.get(@modal_detail_data, :iframe_referrer_policy)}
                iframe_sandbox={Map.get(@modal_detail_data, :iframe_sandbox)}
                size={Map.get(@modal_detail_data, :size, :xl)}
                navigation_enabled={Map.get(@modal_detail_data, :navigation_enabled, true)}
              />
            <% :live_component -> %>
              <.live_component
                module={SelectoComponents.Modal.LiveComponentModal}
                id="detail-modal"
                record={@modal_detail_data.record}
                current_index={@modal_detail_data.current_index}
                total_records={@modal_detail_data.total_records}
                records={@modal_detail_data.records}
                title={Map.get(@modal_detail_data, :title, "Detail Component")}
                title_template={Map.get(@modal_detail_data, :title_template)}
                component_module={Map.get(@modal_detail_data, :component_module)}
                component_assigns={Map.get(@modal_detail_data, :component_assigns, %{})}
                component_assigns_template={Map.get(@modal_detail_data, :component_assigns_template, %{})}
                size={Map.get(@modal_detail_data, :size, :xl)}
                navigation_enabled={Map.get(@modal_detail_data, :navigation_enabled, true)}
              />
            <% _ -> %>
              <.live_component
                module={SelectoComponents.Modal.DetailModal}
                id="detail-modal"
                record={@modal_detail_data.record}
                current_index={@modal_detail_data.current_index}
                total_records={@modal_detail_data.total_records}
                records={@modal_detail_data.records}
                fields={@modal_detail_data.fields}
                related_data={@modal_detail_data.related_data}
                title={Map.get(@modal_detail_data, :title, "Record Details")}
                title_template={Map.get(@modal_detail_data, :title_template)}
                subtitle_field={Map.get(@modal_detail_data, :subtitle_field)}
                size={Map.get(@modal_detail_data, :size, :lg)}
                navigation_enabled={Map.get(@modal_detail_data, :navigation_enabled, true)}
                edit_enabled={Map.get(@modal_detail_data, :edit_enabled, false)}
              />
          <% end %>
        <% end %>
      <% end %>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".ExportDownloads">
        export default {
          mounted() {
            this.bindEmailExportButton();
            this.bindScheduledExportButton();

            this.handleEvent("selecto_export_download", (payload) => {
              const filename = payload.filename || "selecto_export.txt";
              const mimeType = payload.mime_type || "text/plain;charset=utf-8";
              const encoding = payload.browser_content_encoding || "utf8";
              const content = payload.browser_content || payload.content || "";

              let blobContent;

              if (encoding === "base64") {
                const decoded = atob(content);
                const bytes = new Uint8Array(decoded.length);

                for (let index = 0; index < decoded.length; index += 1) {
                  bytes[index] = decoded.charCodeAt(index);
                }

                blobContent = bytes;
              } else {
                blobContent = content;
              }

              const blob = new Blob([blobContent], { type: mimeType });
              const url = URL.createObjectURL(blob);
              const link = document.createElement("a");

              link.href = url;
              link.download = filename;
              document.body.appendChild(link);
              link.click();
              link.remove();

              setTimeout(() => URL.revokeObjectURL(url), 0);
            });
          },

          updated() {
            this.bindEmailExportButton();
            this.bindScheduledExportButton();
          },

          destroyed() {
            if (this.emailExportCleanup) {
              this.emailExportCleanup();
            }

            if (this.scheduledExportCleanup) {
              this.scheduledExportCleanup();
            }
          },

          bindEmailExportButton() {
            if (this.emailExportCleanup) {
              this.emailExportCleanup();
              this.emailExportCleanup = null;
            }

            const button = this.el.querySelector("[data-export-email-button='true']");

            if (!button) {
              return;
            }

            const handler = (event) => {
              event.preventDefault();

              const recipients = document.getElementById(button.dataset.recipientsInput)?.value || "";
              const format = document.getElementById(button.dataset.formatInput)?.value || "csv";
              const subject = document.getElementById(button.dataset.subjectInput)?.value || "";
              const body = document.getElementById(button.dataset.bodyInput)?.value || "";

              this.pushEvent("send_export_email", {
                recipients,
                format,
                subject,
                body
              });
            };

            button.addEventListener("click", handler);
            this.emailExportCleanup = () => button.removeEventListener("click", handler);
          },

          bindScheduledExportButton() {
            if (this.scheduledExportCleanup) {
              this.scheduledExportCleanup();
              this.scheduledExportCleanup = null;
            }

            const button = this.el.querySelector("[data-create-scheduled-export='true']");

            if (!button) {
              return;
            }

            const handler = (event) => {
              event.preventDefault();

              const payload = {
                public_id: button.dataset.publicId || "",
                name: document.getElementById(button.dataset.nameInput)?.value || "",
                export_format: document.getElementById(button.dataset.formatInput)?.value || "csv",
                recipients: document.getElementById(button.dataset.recipientsInput)?.value || "",
                subject_template: document.getElementById(button.dataset.subjectInput)?.value || "",
                body_template: document.getElementById(button.dataset.bodyInput)?.value || "",
                schedule: {
                  enabled: document.getElementById(button.dataset.enabledInput)?.checked || false,
                  kind: document.getElementById(button.dataset.kindInput)?.value || "daily",
                  time: document.getElementById(button.dataset.timeInput)?.value || "07:00",
                  timezone: document.getElementById(button.dataset.timezoneInput)?.value || "Etc/UTC",
                  day_of_week: document.getElementById(button.dataset.dayOfWeekInput)?.value || "1",
                  day_of_month: document.getElementById(button.dataset.dayOfMonthInput)?.value || "1"
                }
              };

              this.pushEventTo(button.dataset.target, "create_scheduled_export", payload);
            };

            button.addEventListener("click", handler);
            this.scheduledExportCleanup = () => button.removeEventListener("click", handler);
          }
        }
      </script>
    </div>
    """
  end

  defp current_view_label(views, view_mode) do
    normalized_view_mode = to_string(view_mode || "detail")

    case Enum.find(views, fn {id, _module, _name, _opts} ->
           Atom.to_string(id) == normalized_view_mode
         end) do
      {_id, _module, name, _opts} when is_binary(name) -> name
      _ -> normalized_view_mode |> Phoenix.Naming.humanize() |> Kernel.<>(" View")
    end
  end

  defp applied_filters(selecto, filters) do
    filters
    |> Enum.reduce([], fn
      {_uuid, _section, %{} = filter}, acc -> [filter_summary(selecto, filter) | acc]
      [_, _, %{} = filter], acc -> [filter_summary(selecto, filter) | acc]
      _, acc -> acc
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.reverse()
  end

  defp filter_summary(selecto, filter) do
    label = filter_label(selecto, filter)
    comp = normalize_summary_comp(Map.get(filter, "comp") || Map.get(filter, :comp))

    case {label, comp, filter_value_summary(filter)} do
      {nil, _comp, _value} ->
        nil

      {label, comp, nil} ->
        summarize_filter_without_value(label, comp)

      {label, "BETWEEN", value} ->
        "#{label} = #{value}"

      {label, "IN", value} ->
        "#{label} in #{value}"

      {label, "NOT IN", value} ->
        "#{label} not in #{value}"

      {label, "TEXT_SEARCH", value} ->
        "#{label} ~ #{value}"

      {label, comp, value} when comp in ["STARTS", "ENDS", "CONTAINS", "TEXT_PREFIX"] ->
        "#{label} ~ #{value}"

      {label, comp, value} when comp in ["=", "!=", "<", ">", "<=", ">="] ->
        "#{label} #{comp} #{value}"

      {label, _comp, value} ->
        "#{label} = #{value}"
    end
  end

  defp filter_label(selecto, filter) do
    filter_id = Map.get(filter, "filter") || Map.get(filter, :filter)

    filter_label_from_selecto(selecto, filter_id) || humanize_filter_id(filter_id)
  end

  defp filter_label_from_selecto(_selecto, nil), do: nil

  defp filter_label_from_selecto(selecto, filter_id) do
    filter_key = normalize_filter_lookup_key(filter_id)

    case Map.get(Selecto.filters(selecto) || %{}, filter_key) do
      %{name: name} when is_binary(name) ->
        name

      _ ->
        case Map.get(Selecto.columns(selecto) || %{}, filter_key) do
          %{name: name} when is_binary(name) -> name
          _ -> nil
        end
    end
  end

  defp normalize_filter_lookup_key(filter_id) when is_binary(filter_id) do
    try do
      String.to_existing_atom(filter_id)
    rescue
      ArgumentError -> filter_id
    end
  end

  defp normalize_filter_lookup_key(filter_id), do: filter_id

  defp humanize_filter_id(nil), do: nil

  defp humanize_filter_id(filter_id) do
    filter_id
    |> to_string()
    |> String.split(".")
    |> List.last()
    |> Phoenix.Naming.humanize()
  end

  defp normalize_summary_comp(nil), do: "="

  defp normalize_summary_comp(comp) when is_atom(comp) do
    comp |> Atom.to_string() |> normalize_summary_comp()
  end

  defp normalize_summary_comp(comp) when is_binary(comp) do
    comp
    |> String.trim()
    |> String.upcase()
    |> case do
      "" -> "="
      normalized -> normalized
    end
  end

  defp normalize_summary_comp(_comp), do: "="

  defp summarize_filter_without_value(label, comp)
       when comp in ["IS NULL", "NULL", "IS_EMPTY", "POLYMORPHIC"] do
    "#{label} is empty"
  end

  defp summarize_filter_without_value(label, comp)
       when comp in ["IS NOT NULL", "NOT_NULL", "IS_NOT_EMPTY"] do
    "#{label} has value"
  end

  defp summarize_filter_without_value(label, _comp), do: label

  defp filter_value_summary(filter) do
    cond do
      polymorphic_filter?(filter) ->
        polymorphic_value_summary(filter)

      between_filter?(filter) ->
        between_value_summary(filter)

      true ->
        filter
        |> scalar_filter_values()
        |> compact_filter_values()
    end
  end

  defp polymorphic_filter?(filter) do
    normalize_summary_comp(Map.get(filter, "comp") || Map.get(filter, :comp)) == "POLYMORPHIC" or
      is_map(Map.get(filter, "polymorphic_selection")) or
      is_map(Map.get(filter, :polymorphic_selection))
  end

  defp between_filter?(filter) do
    normalize_summary_comp(Map.get(filter, "comp") || Map.get(filter, :comp)) == "BETWEEN"
  end

  defp polymorphic_value_summary(filter) do
    selection =
      Map.get(filter, "polymorphic_selection") || Map.get(filter, :polymorphic_selection) || %{}

    values =
      selection
      |> Map.get("values", Map.get(selection, :values, %{}))
      |> Enum.map(fn {entity_type, raw_values} ->
        ids = raw_values |> split_filter_values() |> compact_filter_values(1)

        if ids in [nil, ""] do
          to_string(entity_type)
        else
          "#{entity_type}: #{ids}"
        end
      end)

    selected_types =
      selection
      |> Map.get("types", Map.get(selection, :types, []))
      |> Enum.map(&to_string/1)

    (values ++
       Enum.reject(
         selected_types,
         &Enum.member?(
           Enum.map(values, fn value -> value |> String.split(":", parts: 2) |> hd() end),
           &1
         )
       ))
    |> compact_filter_values()
  end

  defp between_value_summary(filter) do
    start_value =
      Map.get(filter, "value_start") || Map.get(filter, :value_start) || Map.get(filter, "value") ||
        Map.get(filter, :value)

    end_value =
      Map.get(filter, "value_end") || Map.get(filter, :value_end) || Map.get(filter, "value2") ||
        Map.get(filter, :value2)

    case Enum.reject([start_value, end_value], &blank_filter_value?/1) do
      [] ->
        nil

      [single] ->
        normalize_filter_value(single)

      [start_value, end_value] ->
        "#{normalize_filter_value(start_value)} to #{normalize_filter_value(end_value)}"
    end
  end

  defp scalar_filter_values(filter) do
    cond do
      is_list(Map.get(filter, "selected_values")) -> Map.get(filter, "selected_values")
      is_list(Map.get(filter, :selected_values)) -> Map.get(filter, :selected_values)
      is_list(Map.get(filter, "selected_ids")) -> Map.get(filter, "selected_ids")
      is_list(Map.get(filter, :selected_ids)) -> Map.get(filter, :selected_ids)
      true -> split_filter_values(Map.get(filter, "value") || Map.get(filter, :value))
    end
  end

  defp split_filter_values(value) when is_binary(value) do
    value
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&blank_filter_value?/1)
  end

  defp split_filter_values(value) when is_list(value) do
    value
    |> Enum.map(&normalize_filter_value/1)
    |> Enum.reject(&blank_filter_value?/1)
  end

  defp split_filter_values(value) when is_nil(value), do: []
  defp split_filter_values(value), do: [normalize_filter_value(value)]

  defp compact_filter_values(values, limit \\ 2)

  defp compact_filter_values(values, limit) when is_list(values) do
    values =
      values
      |> Enum.map(&normalize_filter_value/1)
      |> Enum.reject(&blank_filter_value?/1)

    case values do
      [] -> nil
      values when length(values) <= limit -> Enum.join(values, ", ")
      values -> Enum.take(values, limit) |> Enum.join(", ") |> Kernel.<>(", ...")
    end
  end

  defp compact_filter_values(value, _limit), do: normalize_filter_value(value)

  defp normalize_filter_value(value) when is_binary(value), do: String.trim(value)

  defp normalize_filter_value(value) when is_atom(value),
    do: value |> Atom.to_string() |> Phoenix.Naming.humanize()

  defp normalize_filter_value(value), do: to_string(value)

  defp blank_filter_value?(value) when value in [nil, ""], do: true
  defp blank_filter_value?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank_filter_value?(_value), do: false

  @impl true
  def handle_event("datetime-filter-change", params, socket) do
    # This event is triggered when datetime filter comparison mode changes
    # We need to update the view config to reflect the change
    require Logger
    Logger.debug("Datetime filter change event received")

    # Extract UUID from _target or params
    nested_params = Map.get(params, "view_config", params)

    uuid =
      params["uuid"] ||
        case get_in(params, ["_target"]) do
          ["filters", uuid_val, "comp"] -> uuid_val
          ["view_config", "filters", uuid_val, "comp"] -> uuid_val
          _ -> nil
        end

    # Get the new comparison value directly from filters
    new_comp = get_in(nested_params, ["filters", uuid, "comp"])

    Logger.debug("UUID: #{uuid}, New comparison: #{new_comp}")

    # Update the view_config in the socket assigns
    current_filters = Map.get(socket.assigns.view_config, :filters, [])

    updated_filters =
      current_filters
      |> Enum.map(fn
        {u, section, filter} ->
          if to_string(u) == to_string(uuid) do
            # Update the comparison operator and reset value when changing modes
            updated_filter =
              case new_comp do
                "BETWEEN" ->
                  # Reset to empty values for between mode
                  Map.merge(filter, %{
                    "comp" => new_comp,
                    "value" => nil,
                    "value_start" => nil,
                    "value_end" => nil
                  })

                "DATE_BETWEEN" ->
                  # Reset to empty values for date between mode
                  Map.merge(filter, %{
                    "comp" => new_comp,
                    "value" => nil,
                    "value_start" => nil,
                    "value_end" => nil
                  })

                "DATE=" ->
                  # Keep existing value or set to today's date
                  Map.merge(filter, %{
                    "comp" => new_comp,
                    "value" => filter["value"] || Date.utc_today()
                  })

                "DATE!=" ->
                  # Keep existing value or set to today's date
                  Map.merge(filter, %{
                    "comp" => new_comp,
                    "value" => filter["value"] || Date.utc_today()
                  })

                "SHORTCUT" ->
                  # Default to "today" for shortcuts
                  Map.merge(filter, %{"comp" => new_comp, "value" => "today"})

                "RELATIVE" ->
                  # Default to empty for relative
                  Map.merge(filter, %{"comp" => new_comp, "value" => ""})

                _ ->
                  # Keep existing value for standard operators
                  Map.put(filter, "comp", new_comp)
              end

            {u, section, updated_filter}
          else
            {u, section, filter}
          end

        other ->
          other
      end)

    updated_config = put_in(socket.assigns.view_config, [:filters], updated_filters)

    # Send the updated config to the parent LiveView
    send(self(), {:update_view_config, updated_config})

    # Also update the LiveComponent's state for immediate rendering
    {:noreply, assign(socket, view_config: updated_config)}
  end

  defmacro __using__(_opts \\ []) do
    quote do
      ### These run in the 'use'ing liveview's context

      # Import all event handlers (this brings in error handling, helpers, and all events)
      use SelectoComponents.Form.EventHandlers

      # Import utility functions for LiveView usage
      import SelectoComponents.Form, only: [dev_mode?: 0, sanitize_error_for_environment: 1]

      # All event handlers are now provided by SelectoComponents.Form.EventHandlers
      # which includes: ViewLifecycle, FilterOperations, DrillDown, ListOperations,
      # QueryOperations, ModalOperations, and ExportOperations
    end

    ### quote do
  end

  ### __using___

  defp build_column_list(selecto) do
    Map.values(Selecto.columns(selecto))
    |> Enum.sort(fn a, b -> a.name <= b.name end)
    |> Enum.map(fn c ->
      {c.colid, c.name,
       %{
         type: Selecto.Temporal.date_like_type(c) || Map.get(c, :type),
         format: Map.get(c, :format),
         icon: Map.get(c, :icon),
         icon_family: Map.get(c, :icon_family)
       }}
    end)
  end

  # defp build_available_fields(selecto) do
  #   Selecto.columns(selecto)
  #   |> Enum.map(fn {field_id, column} ->
  #     field_id_str = if is_atom(field_id), do: Atom.to_string(field_id), else: to_string(field_id)
  #     field_name = Map.get(column, :name, field_id_str)
  #     {field_id_str, %{name: field_name}}
  #   end)
  #   |> Map.new()
  # end

  # Helper to extract selected columns from params for retarget detection
  # This function is used both internally and by Selecto.AutoRetarget

  def get_selected_columns_from_params(params) do
    view_mode = Map.get(params, "view_mode", "")

    case view_mode do
      "aggregate" ->
        group_by_cols =
          Map.get(params, "group_by", %{})
          |> Map.values()
          |> Enum.map(fn item -> Map.get(item, "field") end)

        aggregate_cols =
          Map.get(params, "aggregate", %{})
          |> Map.values()
          |> Enum.map(fn item -> Map.get(item, "field") end)

        group_by_cols ++ aggregate_cols

      "detail" ->
        # Handle the selected map structure from the UI
        selected_map = Map.get(params, "selected", %{})

        # Extract field names from the selected map
        Map.values(selected_map)
        |> Enum.map(fn item ->
          Map.get(item, "field")
        end)
        |> Enum.filter(&(&1 != nil))

      _ ->
        []
    end
  end

  defp detail_modal_visible?(assigns) do
    Map.get(assigns, :show_detail_modal) &&
      (Map.get(assigns, :enable_modal_detail, false) ||
         Map.get(Map.get(assigns, :modal_detail_data, %{}), :action_source) == :configured)
  end

  # Environment detection helpers
  def dev_mode? do
    # Check if we're in dev or test environment
    # You can also use Mix.env() if available, or Application.get_env
    case Application.get_env(:selecto_components, :environment) do
      nil ->
        # Fall back to checking common indicators
        System.get_env("MIX_ENV") in ["dev", "test", nil]

      :prod ->
        false

      :production ->
        false

      _ ->
        true
    end
  end

  def sanitize_error_for_environment(error, opts \\ []) do
    normalized = ErrorBuilder.build(error, opts)

    if dev_mode?() do
      normalized
    else
      sanitize_normalized_error(normalized)
    end
  end

  @doc false
  def selecto_error?(%{__struct__: module}) when module == Selecto.Error, do: true
  def selecto_error?(_), do: false

  @doc false
  def build_selecto_error(type, message, details \\ %{}) do
    maybe_build_selecto_error(%{
      type: type,
      message: message,
      details: details,
      query: nil,
      params: []
    })
  end

  defp maybe_build_selecto_error(attrs) do
    if Code.ensure_loaded?(Selecto.Error) do
      try do
        struct(Selecto.Error, attrs)
      rescue
        _ -> attrs
      end
    else
      attrs
    end
  end

  defp sanitize_normalized_error(error_info) do
    sanitized_message =
      error_info.user_message
      |> then(&ErrorSanitizer.sanitize_error(%{message: &1, details: %{}}))
      |> Map.get(:message)

    sanitized_suggestions =
      if error_info.suggestions != [] do
        ErrorSanitizer.sanitize_suggestions(error_info.suggestions)
      else
        ErrorSanitizer.safe_suggestions(error_info.category)
      end

    %{
      error_info
      | source: :application,
        user_message: sanitized_message,
        detail: nil,
        suggestion: List.first(sanitized_suggestions),
        suggestions: sanitized_suggestions,
        debug: %{},
        error: nil
    }
  end

  @doc false
  def build_debug_data(assigns) do
    query_data = Map.get(assigns, :last_query_info, %{})

    # Extract row count from query_results
    row_count =
      case Map.get(assigns, :query_results) do
        {rows, _columns, _aliases} when is_list(rows) ->
          length(rows)

        [] ->
          # Initial state has empty list
          0

        nil ->
          0

        other ->
          # Try to handle other formats
          case other do
            list when is_list(list) -> length(list)
            _ -> 0
          end
      end

    %{
      query: Map.get(query_data, :sql),
      params: Map.get(query_data, :params, []),
      timing: Map.get(query_data, :timing),
      row_count: row_count,
      execution_plan: Map.get(query_data, :execution_plan)
    }
  end
end
