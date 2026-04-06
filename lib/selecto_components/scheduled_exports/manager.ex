defmodule SelectoComponents.ScheduledExports.Manager do
  @moduledoc """
  LiveComponent for creating and managing scheduled exports.
  """

  use Phoenix.LiveComponent

  alias SelectoComponents.ErrorHandling.ErrorBuilder
  alias SelectoComponents.ScheduledExports
  alias SelectoComponents.ScheduledExports.Service
  alias SelectoComponents.Theme

  @impl true
  def mount(socket) do
    {:ok,
     assign(socket,
       scheduled_exports: [],
       loaded_context: nil,
       form: default_form(),
       editing_public_id: nil
     )}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> maybe_load_scheduled_exports()

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    assigns = Map.put_new(assigns, :theme, Theme.default_theme(:light))

    ~H"""
    <div class={Theme.slot(@theme, :panel) <> " space-y-6 p-4"} style="background: var(--sc-surface-bg);">
      <div class="space-y-2">
        <h3 class="text-base font-semibold" style="color: var(--sc-text-primary);">Scheduled Exports</h3>
        <p class="text-sm" style="color: var(--sc-text-secondary);">
          Save a delivery definition now and let your host app execute due exports later via Oban, Quantum, or another scheduler.
        </p>
      </div>

      <div id={"scheduled-export-form-#{@id}"} class={Theme.slot(@theme, :panel) <> " space-y-4 p-4"} style="background: color-mix(in srgb, var(--sc-surface-bg-alt) 70%, var(--sc-surface-bg));">
        <div class="grid gap-4 xl:grid-cols-2">
          <div class="space-y-2">
            <label class="text-sm font-medium" style="color: var(--sc-text-secondary);" for={"scheduled-export-name-#{@id}"}>Name</label>
            <input id={"scheduled-export-name-#{@id}"} value={@form.name} class={Theme.slot(@theme, :input)} placeholder="Weekly revenue grid" />
          </div>

          <div class="space-y-2">
            <label class="text-sm font-medium" style="color: var(--sc-text-secondary);" for={"scheduled-export-format-#{@id}"}>Format</label>
            <select id={"scheduled-export-format-#{@id}"} class={Theme.slot(@theme, :select)}>
              <option value="csv" selected={@form.export_format == "csv"}>CSV</option>
              <option value="json" selected={@form.export_format == "json"}>JSON</option>
              <option value="tsv" selected={@form.export_format == "tsv"}>TSV</option>
              <option value="xlsx" selected={@form.export_format == "xlsx"}>XLSX</option>
            </select>
          </div>

          <div class="space-y-2 xl:col-span-2">
            <label class="text-sm font-medium" style="color: var(--sc-text-secondary);" for={"scheduled-export-recipients-#{@id}"}>Recipients</label>
            <textarea id={"scheduled-export-recipients-#{@id}"} rows="3" class={Theme.slot(@theme, :input)} placeholder="ops@example.com\nfinance@example.com"><%= @form.recipients_text %></textarea>
            <p class="text-xs" style="color: var(--sc-text-muted);">Separate recipients with commas, semicolons, or new lines.</p>
          </div>

          <div class="space-y-2">
            <label class="text-sm font-medium" style="color: var(--sc-text-secondary);" for={"scheduled-export-subject-#{@id}"}>Subject</label>
            <input id={"scheduled-export-subject-#{@id}"} value={@form.subject_template} class={Theme.slot(@theme, :input)} placeholder="Weekly export" />
          </div>

          <div class="space-y-2">
            <label class="text-sm font-medium" style="color: var(--sc-text-secondary);" for={"scheduled-export-kind-#{@id}"}>Cadence</label>
            <select id={"scheduled-export-kind-#{@id}"} class={Theme.slot(@theme, :select)}>
              <option value="daily" selected={@form.kind == "daily"}>Daily</option>
              <option value="hourly" selected={@form.kind == "hourly"}>Hourly</option>
              <option value="weekly" selected={@form.kind == "weekly"}>Weekly</option>
              <option value="monthly" selected={@form.kind == "monthly"}>Monthly</option>
            </select>
          </div>

          <div class="space-y-2 xl:col-span-2">
            <label class="text-sm font-medium" style="color: var(--sc-text-secondary);" for={"scheduled-export-body-#{@id}"}>Body</label>
            <textarea id={"scheduled-export-body-#{@id}"} rows="3" class={Theme.slot(@theme, :input)} placeholder="Attached is the latest export."><%= @form.body_template %></textarea>
          </div>

          <div class="space-y-2">
            <label class="text-sm font-medium" style="color: var(--sc-text-secondary);" for={"scheduled-export-time-#{@id}"}>Time</label>
            <input id={"scheduled-export-time-#{@id}"} value={@form.time} class={Theme.slot(@theme, :input)} placeholder="07:00" />
          </div>

          <div class="space-y-2">
            <label class="text-sm font-medium" style="color: var(--sc-text-secondary);" for={"scheduled-export-timezone-#{@id}"}>Timezone</label>
            <input id={"scheduled-export-timezone-#{@id}"} value={@form.timezone} class={Theme.slot(@theme, :input)} placeholder="America/New_York" />
          </div>

          <div class="space-y-2">
            <label class="text-sm font-medium" style="color: var(--sc-text-secondary);" for={"scheduled-export-day-of-week-#{@id}"}>Day of Week</label>
            <select id={"scheduled-export-day-of-week-#{@id}"} class={Theme.slot(@theme, :select)}>
              <option value="1" selected={@form.day_of_week == "1"}>Monday</option>
              <option value="2" selected={@form.day_of_week == "2"}>Tuesday</option>
              <option value="3" selected={@form.day_of_week == "3"}>Wednesday</option>
              <option value="4" selected={@form.day_of_week == "4"}>Thursday</option>
              <option value="5" selected={@form.day_of_week == "5"}>Friday</option>
              <option value="6" selected={@form.day_of_week == "6"}>Saturday</option>
              <option value="7" selected={@form.day_of_week == "7"}>Sunday</option>
            </select>
          </div>

          <div class="space-y-2">
            <label class="text-sm font-medium" style="color: var(--sc-text-secondary);" for={"scheduled-export-day-of-month-#{@id}"}>Day of Month</label>
            <input id={"scheduled-export-day-of-month-#{@id}"} value={@form.day_of_month} class={Theme.slot(@theme, :input)} placeholder="1" />
          </div>
        </div>

        <div class="mt-4 flex items-center justify-between gap-3">
          <div class="flex items-center gap-2 text-sm" style="color: var(--sc-text-secondary);">
            <input id={"scheduled-export-enabled-#{@id}"} type="checkbox" checked={@form.enabled} class="h-4 w-4 rounded border" style="border-color: var(--sc-surface-border); background: var(--sc-surface-bg); accent-color: var(--sc-accent);" />
            <label for={"scheduled-export-enabled-#{@id}"}>Enable schedule immediately</label>
          </div>

          <div class="flex items-center gap-2">
            <button :if={@editing_public_id} type="button" phx-click="cancel_edit_scheduled_export" phx-target={@myself} class={Theme.slot(@theme, :button_secondary) <> " px-4 py-2 text-sm shadow-sm"}>
              Cancel
            </button>
            <button type="button" data-create-scheduled-export="true" data-target={@myself} data-public-id={@editing_public_id} data-name-input={"scheduled-export-name-#{@id}"} data-format-input={"scheduled-export-format-#{@id}"} data-recipients-input={"scheduled-export-recipients-#{@id}"} data-subject-input={"scheduled-export-subject-#{@id}"} data-body-input={"scheduled-export-body-#{@id}"} data-kind-input={"scheduled-export-kind-#{@id}"} data-time-input={"scheduled-export-time-#{@id}"} data-timezone-input={"scheduled-export-timezone-#{@id}"} data-day-of-week-input={"scheduled-export-day-of-week-#{@id}"} data-day-of-month-input={"scheduled-export-day-of-month-#{@id}"} data-enabled-input={"scheduled-export-enabled-#{@id}"} class={Theme.slot(@theme, :button_primary) <> " px-4 py-2 text-sm shadow-sm"}>
              {if @editing_public_id, do: "Update Scheduled Export", else: "Create Scheduled Export"}
            </button>
          </div>
        </div>
      </div>

      <div class="space-y-4">
        <div class="flex items-center justify-between gap-3">
          <h4 class="text-sm font-semibold uppercase tracking-[0.18em]" style="color: var(--sc-text-muted);">Managed Schedules</h4>
          <span class="text-xs" style="color: var(--sc-text-muted);">{@scheduled_exports |> length()} total</span>
        </div>

        <div :if={@scheduled_exports == []} class="rounded-xl border border-dashed px-4 py-6 text-sm" style="border-color: var(--sc-surface-border); background: color-mix(in srgb, var(--sc-surface-bg-alt) 60%, var(--sc-surface-bg)); color: var(--sc-text-secondary);">
          No scheduled exports yet.
        </div>

        <div :for={scheduled_export <- @scheduled_exports} class={Theme.slot(@theme, :panel) <> " p-4"} style="background: var(--sc-surface-bg);">
          <div class="flex flex-col gap-4 xl:flex-row xl:items-start xl:justify-between">
            <div class="space-y-3">
              <div class="flex flex-wrap items-center gap-2">
                <h5 class="text-base font-semibold" style="color: var(--sc-text-primary);">{ScheduledExports.field(scheduled_export, :name, "Untitled schedule")}</h5>
                <span class={status_badge_class()} style={status_badge_style(schedule_status(scheduled_export))}>{status_label(schedule_status(scheduled_export))}</span>
                <span class={pill_class()} style={pill_style()}>{ScheduledExports.field(scheduled_export, :export_format, "csv") |> String.upcase()}</span>
                <span class={pill_class()} style={pill_style()}>{String.capitalize(to_string(ScheduledExports.field(scheduled_export, :view_type, "detail")))}</span>
              </div>

              <div class="grid gap-2 text-sm md:grid-cols-2 xl:grid-cols-3" style="color: var(--sc-text-secondary);">
                <div>Cadence: {schedule_summary(scheduled_export)}</div>
                <div>Next run: {format_datetime(ScheduledExports.field(scheduled_export, :next_run_at))}</div>
                <div>Last run: {format_datetime(ScheduledExports.field(scheduled_export, :last_run_at))}</div>
              </div>

              <div class="space-y-1 text-xs" style="color: var(--sc-text-muted);">
                <div>Recipients: {recipient_summary(scheduled_export)}</div>
                <div>Public ID: <span class="font-mono">{ScheduledExports.field(scheduled_export, :public_id, "-")}</span></div>
                <div :if={ScheduledExports.field(scheduled_export, :last_error)} class="text-error">Last error: {ScheduledExports.field(scheduled_export, :last_error)}</div>
              </div>
            </div>

            <div class="flex flex-wrap gap-2 xl:max-w-[340px] xl:justify-end">
              <button type="button" phx-click="edit_scheduled_export" phx-value-id={ScheduledExports.field(scheduled_export, :public_id)} phx-target={@myself} class={Theme.slot(@theme, :button_secondary) <> " px-3 py-2 text-sm"}>Edit</button>
              <button type="button" phx-click="toggle_scheduled_export_disabled" phx-value-id={ScheduledExports.field(scheduled_export, :public_id)} phx-target={@myself} class={Theme.slot(@theme, :button_secondary) <> " px-3 py-2 text-sm"}>{if schedule_enabled?(scheduled_export), do: "Pause", else: "Enable"}</button>
              <button type="button" phx-click="delete_scheduled_export" phx-value-id={ScheduledExports.field(scheduled_export, :public_id)} phx-target={@myself} data-confirm="Delete this scheduled export?" class={Theme.slot(@theme, :button_danger) <> " px-3 py-2 text-sm"}>Delete</button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("create_scheduled_export", %{"scheduled_export" => params}, socket) do
    upsert_scheduled_export(socket, params)
  end

  def handle_event("create_scheduled_export", params, socket) when is_map(params) do
    handle_event("create_scheduled_export", %{"scheduled_export" => params}, socket)
  end

  @impl true
  def handle_event("edit_scheduled_export", %{"id" => public_id}, socket) do
    with {:ok, scheduled_export} <- fetch_scheduled_export(socket, public_id) do
      {:noreply,
       assign(socket,
         form: form_from_scheduled_export(scheduled_export),
         editing_public_id: public_id
       )}
    else
      {:error, reason} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           scheduled_export_error_message(reason,
             code: :edit_scheduled_export_failed,
             operation: "edit_scheduled_export"
           )
         )}
    end
  end

  @impl true
  def handle_event("cancel_edit_scheduled_export", _params, socket) do
    {:noreply, assign(socket, form: default_form(), editing_public_id: nil)}
  end

  def handle_event("toggle_scheduled_export_disabled", %{"id" => public_id}, socket) do
    with {:ok, scheduled_export} <- fetch_scheduled_export(socket, public_id),
         {:ok, _updated_export} <-
           Service.update(
             adapter(socket),
             scheduled_export,
             toggle_attrs(scheduled_export),
             service_opts(socket)
           ) do
      {:noreply,
       socket
       |> put_flash(:info, "Scheduled export updated")
       |> reload_scheduled_exports()}
    else
      {:error, reason} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           scheduled_export_error_message(reason,
             code: :update_scheduled_export_failed,
             operation: "toggle_scheduled_export_disabled"
           )
         )}
    end
  end

  def handle_event("delete_scheduled_export", %{"id" => public_id}, socket) do
    with {:ok, scheduled_export} <- fetch_scheduled_export(socket, public_id),
         {:ok, _deleted_export} <-
           Service.delete(adapter(socket), scheduled_export, service_opts(socket)) do
      {:noreply,
       socket
       |> put_flash(:info, "Scheduled export deleted")
       |> assign(:form, default_form())
       |> assign(:editing_public_id, nil)
       |> reload_scheduled_exports()}
    else
      {:error, reason} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           scheduled_export_error_message(reason,
             code: :delete_scheduled_export_failed,
             operation: "delete_scheduled_export"
           )
         )}
    end
  end

  defp maybe_load_scheduled_exports(socket) do
    context = Map.get(socket.assigns, :scheduled_export_context)

    if context != socket.assigns.loaded_context do
      reload_scheduled_exports(socket)
    else
      socket
    end
  end

  defp reload_scheduled_exports(socket) do
    exports =
      Service.list(
        adapter(socket),
        Map.get(socket.assigns, :scheduled_export_context),
        service_opts(socket)
      )
      |> Enum.sort_by(
        fn scheduled_export ->
          updated_at =
            ScheduledExports.field(scheduled_export, :updated_at, DateTime.utc_now())
            |> normalize_datetime()
            |> DateTime.to_unix(:microsecond)

          {updated_at, ScheduledExports.field(scheduled_export, :name, "")}
        end,
        :desc
      )

    assign(socket,
      scheduled_exports: exports,
      loaded_context: Map.get(socket.assigns, :scheduled_export_context)
    )
  rescue
    _ ->
      assign(socket,
        scheduled_exports: [],
        loaded_context: Map.get(socket.assigns, :scheduled_export_context)
      )
  end

  defp fetch_scheduled_export(socket, public_id) do
    case Enum.find(socket.assigns.scheduled_exports, fn scheduled_export ->
           ScheduledExports.field(scheduled_export, :public_id) == public_id
         end) do
      nil -> {:error, :not_found}
      scheduled_export -> {:ok, scheduled_export}
    end
  end

  defp toggle_attrs(scheduled_export) do
    enabled? = schedule_enabled?(scheduled_export)
    current_schedule = ScheduledExports.field(scheduled_export, :schedule, %{})
    updated_schedule = Map.put(current_schedule, :enabled, !enabled?)

    %{
      schedule: updated_schedule,
      disabled_at: if(enabled?, do: DateTime.utc_now() |> DateTime.truncate(:second), else: nil),
      next_run_at: if(enabled?, do: nil, else: ScheduledExports.next_run_at(updated_schedule))
    }
  end

  defp upsert_scheduled_export(socket, params) do
    case Map.get(params, "public_id") do
      public_id when is_binary(public_id) and public_id != "" ->
        update_scheduled_export(socket, public_id, params)

      _ ->
        create_scheduled_export(socket, params)
    end
  end

  defp create_scheduled_export(socket, params) do
    case Service.create(adapter(socket), socket.assigns, params, service_opts(socket)) do
      {:ok, _scheduled_export} ->
        {:noreply,
         socket
         |> put_flash(:info, "Scheduled export created")
         |> assign(:form, default_form())
         |> assign(:editing_public_id, nil)
         |> reload_scheduled_exports()}

      {:error, reason} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           scheduled_export_error_message(reason,
             code: :create_scheduled_export_failed,
             operation: "create_scheduled_export"
           )
         )}
    end
  end

  defp update_scheduled_export(socket, public_id, params) do
    with {:ok, scheduled_export} <- fetch_scheduled_export(socket, public_id),
         {:ok, _updated_export} <-
           Service.update(
             adapter(socket),
             scheduled_export,
             ScheduledExports.build_update_attrs(scheduled_export, params),
             service_opts(socket)
           ) do
      {:noreply,
       socket
       |> put_flash(:info, "Scheduled export updated")
       |> assign(:form, default_form())
       |> assign(:editing_public_id, nil)
       |> reload_scheduled_exports()}
    else
      {:error, reason} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           scheduled_export_error_message(reason,
             code: :update_scheduled_export_failed,
             operation: "update_scheduled_export"
           )
         )}
    end
  end

  defp adapter(socket), do: Map.fetch!(socket.assigns, :scheduled_export_module)

  defp adapter_opts(socket) do
    [user_id: Map.get(socket.assigns, :current_user_id)]
  end

  defp service_opts(socket) do
    [adapter_opts: adapter_opts(socket)]
  end

  defp default_form do
    %{
      name: "",
      export_format: "csv",
      recipients_text: "",
      subject_template: "",
      body_template: "",
      kind: "daily",
      time: "07:00",
      timezone: "Etc/UTC",
      day_of_week: "1",
      day_of_month: "1",
      enabled: true
    }
  end

  defp form_from_scheduled_export(scheduled_export) do
    schedule = ScheduledExports.field(scheduled_export, :schedule, %{})

    email =
      scheduled_export
      |> ScheduledExports.field(:delivery, %{})
      |> ScheduledExports.field(:email, %{})

    %{
      name: ScheduledExports.field(scheduled_export, :name, ""),
      export_format: ScheduledExports.field(scheduled_export, :export_format, "csv"),
      recipients_text:
        email
        |> ScheduledExports.field(:recipients, [])
        |> Enum.join("\n"),
      subject_template: ScheduledExports.field(email, :subject_template, "") || "",
      body_template: ScheduledExports.field(email, :body_template, "") || "",
      kind: schedule |> ScheduledExports.field(:kind, :daily) |> to_string(),
      time: ScheduledExports.field(schedule, :time, "07:00"),
      timezone: ScheduledExports.field(schedule, :timezone, "Etc/UTC"),
      day_of_week: schedule |> ScheduledExports.field(:day_of_week, 1) |> to_string(),
      day_of_month: schedule |> ScheduledExports.field(:day_of_month, 1) |> to_string(),
      enabled: schedule |> ScheduledExports.field(:enabled, false)
    }
  end

  defp schedule_enabled?(scheduled_export) do
    ScheduledExports.field(scheduled_export, :disabled_at) in [nil, ""] and
      ScheduledExports.field(
        ScheduledExports.field(scheduled_export, :schedule, %{}),
        :enabled,
        false
      )
  end

  defp schedule_status(scheduled_export) do
    cond do
      not schedule_enabled?(scheduled_export) -> :disabled
      status = ScheduledExports.field(scheduled_export, :last_status) -> status
      true -> :never
    end
  end

  defp schedule_summary(scheduled_export) do
    schedule = ScheduledExports.field(scheduled_export, :schedule, %{})
    kind = ScheduledExports.field(schedule, :kind, :daily)
    time = ScheduledExports.field(schedule, :time, "07:00")
    timezone = ScheduledExports.field(schedule, :timezone, "Etc/UTC")

    case kind do
      :hourly ->
        "Hourly at minute #{hourly_minute(time)} #{timezone}"

      :weekly ->
        "Weekly on #{weekday_name(ScheduledExports.field(schedule, :day_of_week, 1))} at #{time} #{timezone}"

      :monthly ->
        "Monthly on day #{ScheduledExports.field(schedule, :day_of_month, 1)} at #{time} #{timezone}"

      _ ->
        "Daily at #{time} #{timezone}"
    end
  end

  defp recipient_summary(scheduled_export) do
    recipients =
      ScheduledExports.field(scheduled_export, :delivery, %{})
      |> ScheduledExports.field(:email, %{})
      |> ScheduledExports.field(:recipients, [])

    case recipients do
      [] -> "-"
      values -> Enum.join(values, ", ")
    end
  end

  defp hourly_minute(time) when is_binary(time) do
    case String.split(time, ":", parts: 2) do
      [_hour, minute] -> minute
      _ -> "00"
    end
  end

  defp weekday_name(1), do: "Monday"
  defp weekday_name(2), do: "Tuesday"
  defp weekday_name(3), do: "Wednesday"
  defp weekday_name(4), do: "Thursday"
  defp weekday_name(5), do: "Friday"
  defp weekday_name(6), do: "Saturday"
  defp weekday_name(7), do: "Sunday"
  defp weekday_name(_), do: "Monday"

  defp status_badge_class, do: "rounded-full px-2.5 py-1 text-xs font-medium"

  defp status_badge_style(:ok),
    do:
      "background: color-mix(in srgb, var(--sc-accent) 14%, var(--sc-surface-bg)); color: var(--sc-accent);"

  defp status_badge_style(:running),
    do:
      "background: color-mix(in srgb, var(--sc-accent) 10%, var(--sc-surface-bg-alt)); color: var(--sc-text-primary);"

  defp status_badge_style(:failed),
    do:
      "background: color-mix(in srgb, var(--sc-danger) 12%, var(--sc-surface-bg)); color: var(--sc-danger);"

  defp status_badge_style(:skipped),
    do:
      "background: color-mix(in srgb, var(--sc-text-muted) 12%, var(--sc-surface-bg)); color: var(--sc-text-secondary);"

  defp status_badge_style(:never), do: pill_style()
  defp status_badge_style(:disabled), do: pill_style()

  defp pill_class, do: "rounded-full px-2.5 py-1 text-xs font-medium"
  defp pill_style, do: "background: var(--sc-surface-bg-alt); color: var(--sc-text-secondary);"

  defp status_label(status), do: status |> Atom.to_string() |> String.capitalize()

  defp format_datetime(nil), do: "-"

  defp format_datetime(value) do
    value
    |> normalize_datetime()
    |> Calendar.strftime("%Y-%m-%d %H:%M UTC")
  rescue
    _ -> "-"
  end

  defp normalize_datetime(%DateTime{} = value), do: value

  defp normalize_datetime(%NaiveDateTime{} = value) do
    DateTime.from_naive!(value, "Etc/UTC")
  end

  defp normalize_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _offset} -> dt
      _ -> DateTime.utc_now()
    end
  end

  defp normalize_datetime(_value), do: DateTime.utc_now()

  defp scheduled_export_error_message(reason, opts) do
    error =
      ErrorBuilder.build(
        inspect(reason),
        Keyword.merge(
          [stage: :persistence, category: :persistence],
          opts
        )
      )

    error.summary <> ": " <> error.user_message
  end
end
