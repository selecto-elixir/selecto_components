defmodule SelectoComponents.Form do
  use Phoenix.LiveComponent

  import SelectoComponents.Components.Common
  alias Phoenix.LiveView.JS
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
        use_saved_views: Map.get(assigns, :saved_view_module, false),
        use_exported_views: Map.get(assigns, :exported_view_module, false),
        use_export_delivery: Map.get(assigns, :export_delivery_module, false),
        use_scheduled_exports: Map.get(assigns, :scheduled_export_module, false),
        form:
          Ecto.Changeset.cast({%{}, %{}}, assigns.view_config, []) |> to_form(as: "view_config")
      )

    ~H"""
    <div
      id={"selecto-form-#{@id}"}
      phx-hook=".ExportDownloads"
      class="border-solid border border-2 rounded-md border-gray-300 p-1 bg-base-100 text-base-content"
    >
      <.form for={@form} phx-change="view-validate" phx-submit="view-apply">
        <!-- Comprehensive Error Display Component -->
        <.live_component
          :if={Map.get(assigns, :execution_error) || Map.get(assigns, :component_errors, [])}
          module={ErrorDisplay}
          id="error_display"
          error={Map.get(assigns, :execution_error)}
          errors={Map.get(assigns, :component_errors, [])}
        />
        
    <!-- View Config Manager for saving/loading view configurations -->
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
        
    <!-- Main Navigation Tabs -->
        <div class="flex border-b border-gray-200 dark:border-gray-700 mb-4">
          <div class="flex space-x-1" role="tablist" aria-label="Configuration Sections">
            <button
              type="button"
              role="tab"
              aria-selected={@active_tab == "view" or @active_tab == nil}
              aria-controls="main-tabpanel-view"
              id="main-tab-view"
              phx-click={JS.push("set_active_tab", value: %{tab: "view"})}
              class={[
                "px-4 py-2 text-sm font-medium transition-all duration-200",
                "border-b-2 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary",
                if @active_tab == "view" or @active_tab == nil do
                  "border-primary text-primary bg-primary/5"
                else
                  "border-transparent text-gray-600 hover:text-gray-800 hover:border-gray-300 dark:text-gray-400 dark:hover:text-gray-200"
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
                "px-4 py-2 text-sm font-medium transition-all duration-200",
                "border-b-2 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary",
                if @active_tab == "filter" do
                  "border-primary text-primary bg-primary/5"
                else
                  "border-transparent text-gray-600 hover:text-gray-800 hover:border-gray-300 dark:text-gray-400 dark:hover:text-gray-200"
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
                "px-4 py-2 text-sm font-medium transition-all duration-200",
                "border-b-2 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary",
                if @active_tab == "save" do
                  "border-primary text-primary bg-primary/5"
                else
                  "border-transparent text-gray-600 hover:text-gray-800 hover:border-gray-300 dark:text-gray-400 dark:hover:text-gray-200"
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
                "px-4 py-2 text-sm font-medium transition-all duration-200",
                "border-b-2 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary",
                if @active_tab == "export" do
                  "border-primary text-primary bg-primary/5"
                else
                  "border-transparent text-gray-600 hover:text-gray-800 hover:border-gray-300 dark:text-gray-400 dark:hover:text-gray-200"
                end
              ]}
            >
              Export
            </button>
          </div>
        </div>
        
    <!-- Tab Content Panels -->
        <div
          role="tabpanel"
          id="main-tabpanel-view"
          aria-labelledby="main-tab-view"
          class={
            if @active_tab == "view" or @active_tab == nil do
              "border-solid border rounded-md border-gray-300 p-3 bg-base-100 text-base-content"
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
              "border-solid border rounded-md border-gray-300 p-3 bg-base-100 text-base-content"
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
              "border-solid border rounded-md border-gray-300 p-3 bg-base-100 text-base-content"
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
              <.sc_input name="save_as" id="save_as" placeholder="Enter view name..." class="flex-1" />
            </div>
          </div>
        </div>

        <div
          role="tabpanel"
          id="main-tabpanel-export"
          aria-labelledby="main-tab-export"
          class={
            if @active_tab == "export" do
              "border-solid border rounded-md border-gray-300 p-3 bg-base-100 text-base-content"
            else
              "hidden"
            end
          }
        >
          <h3 class="text-base-content font-medium mb-2">Export Options</h3>
          <div class="space-y-6">
            <p class="text-sm text-gray-600 dark:text-gray-400">
              Export current query results now:
            </p>

            <div class="flex flex-wrap gap-2">
              <.sc_button type="button" phx-click="export_data" phx-value-format="csv">
                Download CSV
              </.sc_button>
              <.sc_button type="button" phx-click="export_data" phx-value-format="json">
                Download JSON
              </.sc_button>
            </div>

            <div :if={@use_export_delivery} class="space-y-4 rounded-xl border border-base-300 bg-base-200/40 p-4">
              <div>
                <h4 class="text-sm font-semibold text-base-content">Send Current Results by Email</h4>
                <p class="text-xs text-base-content/60">
                  Uses the current query results and sends them through the configured host-app delivery adapter.
                </p>
              </div>

              <div class="grid gap-4 lg:grid-cols-2">
                <div class="space-y-2 lg:col-span-2">
                  <label class="text-sm font-medium text-base-content/80" for={"export-email-recipients-#{@id}"}>Recipients</label>
                  <input id={"export-email-recipients-#{@id}"} class="w-full rounded-lg border border-base-300 bg-base-100 px-3 py-2 text-sm text-base-content shadow-sm" placeholder="ops@example.com, finance@example.com" />
                  <p class="text-xs text-base-content/60">Separate recipients with commas, semicolons, or new lines.</p>
                </div>

                <div class="space-y-2">
                  <label class="text-sm font-medium text-base-content/80" for={"export-email-format-#{@id}"}>Format</label>
                  <select id={"export-email-format-#{@id}"} class="w-full rounded-lg border border-base-300 bg-base-100 px-3 py-2 text-sm text-base-content shadow-sm">
                    <option value="csv" selected>CSV</option>
                    <option value="json">JSON</option>
                  </select>
                </div>

                <div class="space-y-2">
                  <label class="text-sm font-medium text-base-content/80" for={"export-email-subject-#{@id}"}>Subject</label>
                  <input id={"export-email-subject-#{@id}"} class="w-full rounded-lg border border-base-300 bg-base-100 px-3 py-2 text-sm text-base-content shadow-sm" placeholder="Current Selecto export" />
                </div>

                <div class="space-y-2 lg:col-span-2">
                  <label class="text-sm font-medium text-base-content/80" for={"export-email-body-#{@id}"}>Body</label>
                  <textarea id={"export-email-body-#{@id}"} rows="4" class="w-full rounded-lg border border-base-300 bg-base-100 px-3 py-2 text-sm text-base-content shadow-sm" placeholder="Attached is the latest export."></textarea>
                </div>
              </div>

              <div class="flex items-center justify-between gap-3">
                <p class="text-xs text-base-content/60">This first slice sends the already-loaded result set rather than re-running the query.</p>
                <button type="button" data-export-email-button="true" data-recipients-input={"export-email-recipients-#{@id}"} data-format-input={"export-email-format-#{@id}"} data-subject-input={"export-email-subject-#{@id}"} data-body-input={"export-email-body-#{@id}"} class="inline-flex items-center rounded-lg bg-primary px-4 py-2 text-sm font-medium text-primary-content shadow-sm transition hover:bg-primary/90">
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

        <.sc_button>Submit</.sc_button>
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
              const content = payload.content || "";

              const blob = new Blob([content], { type: mimeType });
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
    |> Enum.map(fn c -> {c.colid, c.name, Map.get(c, :format)} end)
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
