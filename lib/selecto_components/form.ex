defmodule SelectoComponents.Form do
  use Phoenix.LiveComponent

  alias SelectoComponents.Theme
  alias SelectoComponents.ErrorHandling.ErrorBuilder
  alias SelectoComponents.ErrorHandling.ErrorSanitizer
  alias SelectoComponents.ErrorHandling.ErrorDisplay
  alias SelectoComponents.Form.ColumnCatalog
  alias SelectoComponents.Form.ExportPanel
  alias SelectoComponents.Form.FilterPanel
  alias SelectoComponents.Form.FilterRendering
  alias SelectoComponents.Form.Header
  alias SelectoComponents.Form.ModalRouter
  alias SelectoComponents.Form.PromotedFilterEditor
  alias SelectoComponents.Form.SavePanel
  alias SelectoComponents.Form.SubmitFooter
  alias SelectoComponents.Form.TabPanel
  alias SelectoComponents.Form.Tabs
  alias SelectoComponents.Form.ViewPanel

  @doc """
  Form for configuing Selecto View

  attrs:
  selecto: the selecto structure
  view_config: attr which contains the data to draw the view

  """

  @impl true
  def render(assigns) do
    form_selecto = ColumnCatalog.picker_selecto(assigns.selecto)

    controller_filters =
      controller_filters(assigns.selecto, Map.get(assigns.view_config, :filters, []))

    assigns =
      assign(assigns,
        columns: build_column_list(assigns.selecto),
        form_selecto: form_selecto,
        field_filters: FilterRendering.build_filter_list(assigns.selecto),
        controller_title: Map.get(assigns, :controller_title, "View Controller"),
        show_view_configurator: Map.get(assigns, :show_view_configurator, true),
        current_view_label: current_view_label(assigns.views, assigns.view_config.view_mode),
        applied_filters:
          applied_filters(assigns.selecto, Map.get(assigns.view_config, :filters, [])),
        promoted_filters: Enum.filter(controller_filters, & &1.editable),
        summary_filters:
          controller_filters
          |> Enum.reject(& &1.editable)
          |> Enum.map(& &1.summary),
        form_state_revision: Map.get(assigns, :form_state_revision, 0),
        view_config_dirty?: Map.get(assigns, :view_config_dirty?, false),
        applied_form_state_revision:
          Map.get(
            assigns,
            :applied_form_state_revision,
            Map.get(assigns, :form_state_revision, 0)
          ),
        theme: Theme.resolve_theme(assigns),
        use_saved_views: Map.get(assigns, :saved_view_module, false),
        use_exported_views: Map.get(assigns, :exported_view_module, false),
        use_export_delivery: Map.get(assigns, :export_delivery_module, false),
        use_scheduled_exports: Map.get(assigns, :scheduled_export_module, false),
        theme_stylesheet: Theme.stylesheet(),
        scheduled_export_context: scheduled_export_context(assigns),
        exported_view_context: exported_view_context(assigns),
        saved_view_context: saved_view_context(assigns),
        filter_sets_domain: filter_sets_domain(assigns),
        tree_builder_suffix: FilterRendering.hash_filter_structure(assigns.view_config.filters),
        detail_modal_visible: detail_modal_visible?(assigns),
        detail_modal_component: Map.get(assigns, :detail_modal_component),
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
      <style>
        <%= Phoenix.HTML.raw(@theme_stylesheet) %>
      </style>
      <style>
        [data-selecto-submit-button="true"] {
          position: relative;
          isolation: isolate;
          overflow: hidden;
          min-width: 8.75rem;
          box-shadow: var(--sc-shadow-sm);
        }

        [data-selecto-submit-button="true"] > * {
          position: relative;
          z-index: 1;
        }

        [data-selecto-submit-badge="true"] {
          display: none;
          align-items: center;
          border-radius: 9999px;
          padding: 0.125rem 0.45rem;
          background: color-mix(in srgb, white 14%, transparent);
          font-size: 0.6875rem;
          font-weight: 700;
          letter-spacing: 0.08em;
          text-transform: uppercase;
        }

        [data-selecto-submit-button="true"][data-dirty="true"] {
          color: var(--sc-accent-contrast);
          border-color: color-mix(in srgb, var(--sc-accent) 72%, var(--sc-surface-border));
          background: color-mix(in srgb, var(--sc-accent) 94%, white);
          box-shadow:
            0 0 0 2px color-mix(in srgb, var(--sc-accent) 14%, transparent),
            0 8px 18px -14px color-mix(in srgb, var(--sc-accent) 36%, transparent),
            var(--sc-shadow-sm);
          animation: sc-submit-glow 2.6s ease-in-out infinite;
        }

        [data-selecto-submit-button="true"][data-dirty="true"] [data-selecto-submit-badge="true"] {
          display: inline-flex;
        }

        @keyframes sc-submit-glow {
          0%,
          100% {
            box-shadow:
              0 0 0 2px color-mix(in srgb, var(--sc-accent) 12%, transparent),
              0 8px 18px -14px color-mix(in srgb, var(--sc-accent) 28%, transparent),
              var(--sc-shadow-sm);
          }

          50% {
            box-shadow:
              0 0 0 3px color-mix(in srgb, var(--sc-accent) 18%, transparent),
              0 10px 20px -14px color-mix(in srgb, var(--sc-accent) 38%, transparent),
              var(--sc-shadow-sm);
          }
        }

        @media (prefers-reduced-motion: reduce) {
          [data-selecto-submit-button="true"][data-dirty="true"] {
            animation: none;
          }
        }
      </style>
      <.form
        id={"selecto-view-form-#{@id}"}
        for={@form}
        phx-change="view-validate"
        phx-submit="view-apply"
      >
        <input type="hidden" name="form_state_revision" value={@form_state_revision} />
        <.live_component
          :if={Map.get(assigns, :execution_error) || Map.get(assigns, :component_errors, [])}
          module={ErrorDisplay}
          id="error_display"
          error={Map.get(assigns, :execution_error)}
          errors={Map.get(assigns, :component_errors, [])}
        />

        <Header.summary
          id={@id}
          theme={@theme}
          controller_title={@controller_title}
          current_view_label={@current_view_label}
          applied_filters={@applied_filters}
          promoted_filters={@promoted_filters}
          summary_filters={@summary_filters}
          show_view_configurator={@show_view_configurator}
        >
          <:promoted_filter :let={filter}>
            <PromotedFilterEditor.editor filter={filter} theme={@theme} selecto={@selecto} />
          </:promoted_filter>
        </Header.summary>

        <div
          id={"selecto-controller-body-#{@id}"}
          data-selecto-controller-body
          aria-hidden={to_string(!@show_view_configurator)}
          class={if @show_view_configurator, do: "", else: "hidden"}
        >
          <Tabs.nav active_tab={@active_tab} theme={@theme} use_saved_views={@use_saved_views} />

          <ViewPanel.panel
            active_tab={@active_tab}
            theme={@theme}
            saved_view_config_module={Map.get(assigns, :saved_view_config_module)}
            view_config={@view_config}
            saved_view_context={@saved_view_context}
            current_user_id={Map.get(assigns, :current_user_id)}
            parent_id={@myself}
            views={@views}
            columns={@columns}
            selecto={@form_selecto}
          />

          <FilterPanel.panel
            active_tab={@active_tab}
            theme={@theme}
            filter_sets_adapter={Map.get(assigns, :filter_sets_adapter)}
            user_id={Map.get(assigns, :user_id)}
            domain={@filter_sets_domain}
            current_filters={@view_config.filters}
            id={@id}
            tree_builder_suffix={@tree_builder_suffix}
            available_filters={@field_filters}
            filters={@view_config.filters}
          >
            <:filter_form :let={{uuid, index, section, filter_value}}>
              {FilterRendering.render_filter_form(assigns, uuid, index, section, filter_value)}
            </:filter_form>
          </FilterPanel.panel>

          <TabPanel.panel :if={@use_saved_views} active_tab={@active_tab} tab="save" theme={@theme} title="Save View Configuration">
            <SavePanel.panel theme={@theme} />
          </TabPanel.panel>

          <TabPanel.panel active_tab={@active_tab} tab="export" theme={@theme} title="Export Options">
            <ExportPanel.panel
              theme={@theme}
              id={@id}
              use_export_delivery={@use_export_delivery}
              use_scheduled_exports={@use_scheduled_exports}
              use_exported_views={@use_exported_views}
              scheduled_export_module={Map.get(assigns, :scheduled_export_module)}
              scheduled_export_context={@scheduled_export_context}
              exported_view_module={Map.get(assigns, :exported_view_module)}
              exported_view_context={@exported_view_context}
              exported_view_endpoint={Map.get(assigns, :exported_view_endpoint)}
              exported_view_base_url={Map.get(assigns, :exported_view_base_url)}
              current_user_id={Map.get(assigns, :current_user_id)}
              selecto={@selecto}
              views={@views}
              view_config={@view_config}
              path={Map.get(assigns, :path) || Map.get(assigns, :my_path)}
              tenant_context={Map.get(assigns, :tenant_context)}
            />
          </TabPanel.panel>
        </div>

        <SubmitFooter.footer id={@id} theme={@theme} view_config_dirty?={@view_config_dirty?} />
      </.form>

      <%!-- Render modal if enabled and triggered --%>
      <ModalRouter.router
        visible={@detail_modal_visible}
        detail_modal_component={@detail_modal_component}
        modal_detail_data={Map.get(assigns, :modal_detail_data, %{})}
      />

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

  defp controller_filters(selecto, filters) do
    filters
    |> Enum.reduce([], fn
      {uuid, _section, %{} = filter}, acc ->
        case controller_filter_data(selecto, uuid, filter) do
          nil -> acc
          filter_data -> [filter_data | acc]
        end

      [uuid, _section, %{} = filter], acc ->
        case controller_filter_data(selecto, uuid, filter) do
          nil -> acc
          filter_data -> [filter_data | acc]
        end

      _, acc ->
        acc
    end)
    |> Enum.reverse()
  end

  defp controller_filter_data(selecto, uuid, filter) do
    label = filter_label(selecto, filter)
    comp = normalize_summary_comp(Map.get(filter, "comp") || Map.get(filter, :comp))
    summary = filter_summary(selecto, filter)
    render_kind = controller_filter_render_kind(selecto, filter, comp)

    case {label, summary} do
      {nil, _summary} ->
        nil

      {_label, nil} ->
        nil

      {label, summary} ->
        %{
          uuid: to_string(uuid),
          label: controller_filter_label(selecto, filter, label),
          summary: summary,
          comp: comp,
          value: controller_filter_value(filter),
          value_start: controller_filter_start_value(filter),
          value_end: controller_filter_end_value(filter),
          mode: controller_filter_mode(selecto, filter, render_kind),
          list_value: controller_filter_list_value(filter),
          field_type: controller_filter_field_type(selecto, filter),
          field_conf: controller_filter_field_conf(selecto, filter),
          render_kind: render_kind,
          text_search_mode_options: controller_filter_mode_options(selecto, render_kind),
          editable: promoted_filter?(filter) and render_kind != :unsupported
        }
    end
  end

  defp controller_filter_label(selecto, filter, label) do
    display_label =
      case normalize_controller_filter_label(label, filter) do
        nil -> humanize_filter_id(Map.get(filter, "filter") || Map.get(filter, :filter))
        normalized -> normalized
      end

    case controller_domain_name(selecto) do
      nil -> display_label
      domain_name -> "#{domain_name}: #{display_label}"
    end
  end

  defp normalize_controller_filter_label(nil, _filter), do: nil

  defp normalize_controller_filter_label(label, filter) when is_binary(label) do
    fallback = humanize_filter_id(Map.get(filter, "filter") || Map.get(filter, :filter))

    cond do
      String.trim(label) == "" ->
        fallback

      label == String.upcase(label) and is_binary(fallback) and fallback != "" ->
        fallback

      true ->
        label
    end
  end

  defp normalize_controller_filter_label(_label, filter) do
    humanize_filter_id(Map.get(filter, "filter") || Map.get(filter, :filter))
  end

  defp controller_domain_name(selecto) do
    case Selecto.domain(selecto) do
      %{name: name} when is_binary(name) ->
        case String.trim(name) do
          "" -> nil
          trimmed -> trimmed
        end

      _ ->
        nil
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

  defp controller_filter_value(filter) do
    Map.get(filter, "value") || Map.get(filter, :value) || ""
  end

  defp controller_filter_start_value(filter) do
    Map.get(filter, "value_start") || Map.get(filter, :value_start) || Map.get(filter, "value") ||
      Map.get(filter, :value) || ""
  end

  defp controller_filter_end_value(filter) do
    Map.get(filter, "value_end") || Map.get(filter, :value_end) || Map.get(filter, "value2") ||
      Map.get(filter, :value2) || ""
  end

  defp controller_filter_list_value(filter) do
    filter
    |> controller_filter_value()
    |> to_string()
    |> String.split(~r/[\r\n,]+/)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end

  defp controller_filter_mode(selecto, filter, :text_search) do
    case Map.get(filter, "mode") || Map.get(filter, :mode) do
      nil ->
        SelectoComponents.Helpers.default_text_search_mode(Map.get(selecto, :adapter))

      "" ->
        SelectoComponents.Helpers.default_text_search_mode(Map.get(selecto, :adapter))

      mode ->
        to_string(mode)
    end
  end

  defp controller_filter_mode(_selecto, _filter, _render_kind), do: nil

  defp controller_filter_mode_options(selecto, :text_search) do
    SelectoComponents.Helpers.text_search_mode_options(Map.get(selecto, :adapter))
  end

  defp controller_filter_mode_options(_selecto, _render_kind), do: []

  defp promoted_filter?(filter) do
    Map.get(filter, "promote", Map.get(filter, :promote)) in [true, "true", "on", "1", "Y", "y"]
  end

  defp controller_filter_render_kind(selecto, filter, comp) do
    cond do
      controller_filter_custom_component?(selecto, filter) ->
        :unsupported

      polymorphic_filter?(filter) ->
        :unsupported

      controller_filter_field_type(selecto, filter) == :tsvector ->
        :text_search

      controller_datetime_filter?(selecto, filter, comp) ->
        :datetime

      true ->
        :standard
    end
  end

  defp controller_filter_custom_component?(selecto, filter) do
    case controller_filter_definition(selecto, filter) do
      %{type: :component, component: component} when not is_nil(component) -> true
      _ -> false
    end
  end

  defp controller_filter_field_type(selecto, filter) do
    filter_def = controller_filter_definition(selecto, filter)
    column_def = controller_filter_column_definition(selecto, filter, filter_def)

    cond do
      filter_def && Selecto.Temporal.date_like?(filter_def) ->
        Selecto.Temporal.date_like_type(filter_def)

      column_def && Selecto.Temporal.date_like?(column_def) ->
        Selecto.Temporal.date_like_type(column_def)

      filter_def && Map.has_key?(filter_def, :type) ->
        Map.get(filter_def, :type)

      column_def && Map.has_key?(column_def, :type) ->
        Map.get(column_def, :type)

      true ->
        :string
    end
  end

  defp controller_filter_field_conf(selecto, filter) do
    filter_id = Map.get(filter, "filter") || Map.get(filter, :filter)
    filter_def = controller_filter_definition(selecto, filter)
    column_def = controller_filter_column_definition(selecto, filter, filter_def)

    controller_join_mode_field_conf(selecto, filter_id, filter_def || column_def) ||
      filter_def || column_def || controller_filter_field_type(selecto, filter)
  end

  defp controller_join_mode_field_conf(
         _selecto,
         _filter_id,
         %{
           join_mode: join_mode,
           filter_type: :multi_select_id
         } = current_def
       )
       when join_mode in [:lookup, :star, :tag],
       do: current_def

  defp controller_join_mode_field_conf(selecto, filter_id, current_def)
       when is_binary(filter_id) do
    domain = Selecto.domain(selecto)

    resolved_conf =
      cond do
        String.contains?(filter_id, ".") ->
          [schema_name, field_part] = String.split(filter_id, ".", parts: 2)

          if field_part == "id" or String.ends_with?(field_part, "_id") do
            controller_join_mode_conf_from_id_field(domain, schema_name, field_part)
          end

        String.ends_with?(filter_id, "_id") ->
          controller_join_mode_conf_from_group_by_filter(domain, filter_id)

        true ->
          nil
      end

    case resolved_conf do
      %{} = join_mode_conf -> Map.merge(current_def || %{}, join_mode_conf)
      _ -> nil
    end
  end

  defp controller_join_mode_field_conf(_selecto, _filter_id, _current_def), do: nil

  defp controller_join_mode_conf_from_id_field(domain, schema_name, field_part) do
    schema_atom =
      try do
        String.to_existing_atom(schema_name)
      rescue
        ArgumentError -> nil
      end

    if schema_atom do
      domain
      |> get_in([:schemas, schema_atom, :columns])
      |> case do
        columns when is_map(columns) ->
          Enum.find_value(columns, fn {_col_name, col_config} ->
            join_mode = Map.get(col_config, :join_mode)
            id_field = Map.get(col_config, :id_field)
            filter_type = Map.get(col_config, :filter_type)

            if join_mode in [:lookup, :star, :tag] and filter_type == :multi_select_id and
                 (id_field == :id or Atom.to_string(id_field) == field_part) do
              col_config
            end
          end)

        _ ->
          nil
      end
    end
  end

  defp controller_join_mode_conf_from_group_by_filter(domain, filter_id) do
    domain
    |> Map.get(:schemas, %{})
    |> Enum.find_value(fn {_schema_name, schema_config} ->
      schema_config
      |> Map.get(:columns, %{})
      |> Enum.find_value(fn {_col_name, col_config} ->
        join_mode = Map.get(col_config, :join_mode)
        filter_type = Map.get(col_config, :filter_type)
        group_by_filter = Map.get(col_config, :group_by_filter)

        if join_mode in [:lookup, :star, :tag] and filter_type == :multi_select_id and
             group_by_filter == filter_id do
          col_config
        end
      end)
    end)
  end

  defp controller_filter_definition(selecto, filter) do
    filter_id = Map.get(filter, "filter") || Map.get(filter, :filter)

    case Selecto.filters(selecto) do
      filters when is_map(filters) -> Map.get(filters, filter_id)
      _ -> nil
    end
  end

  defp controller_filter_column_definition(selecto, filter, filter_def) do
    if filter_def == nil do
      filter_id = Map.get(filter, "filter") || Map.get(filter, :filter)

      Selecto.columns(selecto)
      |> Enum.find_value(fn {_key, col} ->
        if col.colid == filter_id or to_string(col.colid) == filter_id, do: col, else: nil
      end)
    else
      filter_def
    end
  end

  defp controller_datetime_filter?(selecto, filter, comp) do
    field_conf = controller_filter_field_conf(selecto, filter)

    (is_map(field_conf) and Selecto.Temporal.date_like?(field_conf)) or
      controller_filter_field_type(selecto, filter) in [:date, :naive_datetime, :utc_datetime] or
      comp in [
        "DATE=",
        "DATE!=",
        "DATE_BETWEEN",
        "SHORTCUT",
        "RELATIVE",
        "WEEKDAY",
        "WEEKDAY_SUN1",
        "WEEK_OF_YEAR",
        "MONTH_OF_YEAR",
        "DAY_OF_MONTH",
        "HOUR_OF_DAY"
      ]
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

  defp build_column_list(selecto), do: ColumnCatalog.picker_columns(selecto)

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

  defp scheduled_export_context(assigns) do
    Map.get(assigns, :scheduled_export_context) ||
      SelectoComponents.Tenant.scoped_context(
        Map.get(assigns, :saved_view_context) || Map.get(assigns, :path),
        Map.get(assigns, :tenant_context)
      )
  end

  defp exported_view_context(assigns) do
    Map.get(assigns, :exported_view_context) ||
      SelectoComponents.Tenant.scoped_context(
        Map.get(assigns, :saved_view_context) || Map.get(assigns, :path),
        Map.get(assigns, :tenant_context)
      )
  end

  defp saved_view_context(assigns) do
    SelectoComponents.Tenant.scoped_context(
      Map.get(assigns, :saved_view_context),
      Map.get(assigns, :tenant_context)
    )
  end

  defp filter_sets_domain(assigns) do
    SelectoComponents.Tenant.scoped_context(
      Map.get(assigns, :domain) || Map.get(assigns, :path),
      Map.get(assigns, :tenant_context)
    )
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
