defmodule SelectoComponents.ScheduledExports.Manager do
  @moduledoc """
  LiveComponent for creating and managing scheduled exports.
  """

  use Phoenix.LiveComponent

  alias SelectoComponents.ErrorHandling.ErrorBuilder
  alias SelectoComponents.ScheduledExports
  alias SelectoComponents.ScheduledExports.Service

  @impl true
  def mount(socket) do
    {:ok,
     assign(socket,
       scheduled_exports: [],
       loaded_context: nil
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
    ~H"""
    <div class="space-y-6 rounded-xl border border-base-300 bg-base-100 p-4 shadow-sm">
      <div class="space-y-2">
        <h3 class="text-base font-semibold text-base-content">Scheduled Exports</h3>
        <p class="text-sm text-base-content/70">
          Save a delivery definition now and let your host app execute due exports later via Oban, Quantum, or another scheduler.
        </p>
      </div>

      <div id={"scheduled-export-form-#{@id}"} class="space-y-4 rounded-xl border border-base-300 bg-base-200/40 p-4">
        <div class="grid gap-4 xl:grid-cols-2">
          <div class="space-y-2">
            <label class="text-sm font-medium text-base-content/80" for={"scheduled-export-name-#{@id}"}>Name</label>
            <input id={"scheduled-export-name-#{@id}"} class="w-full rounded-lg border border-base-300 bg-base-100 px-3 py-2 text-sm text-base-content shadow-sm" placeholder="Weekly revenue grid" />
          </div>

          <div class="space-y-2">
            <label class="text-sm font-medium text-base-content/80" for={"scheduled-export-format-#{@id}"}>Format</label>
            <select id={"scheduled-export-format-#{@id}"} class="w-full rounded-lg border border-base-300 bg-base-100 px-3 py-2 text-sm text-base-content shadow-sm">
              <option value="csv" selected>CSV</option>
              <option value="json">JSON</option>
              <option value="tsv">TSV</option>
              <option value="xlsx">XLSX</option>
            </select>
          </div>

          <div class="space-y-2 xl:col-span-2">
            <label class="text-sm font-medium text-base-content/80" for={"scheduled-export-recipients-#{@id}"}>Recipients</label>
            <textarea id={"scheduled-export-recipients-#{@id}"} rows="3" class="w-full rounded-lg border border-base-300 bg-base-100 px-3 py-2 text-sm text-base-content shadow-sm" placeholder="ops@example.com\nfinance@example.com"></textarea>
            <p class="text-xs text-base-content/60">Separate recipients with commas, semicolons, or new lines.</p>
          </div>

          <div class="space-y-2">
            <label class="text-sm font-medium text-base-content/80" for={"scheduled-export-subject-#{@id}"}>Subject</label>
            <input id={"scheduled-export-subject-#{@id}"} class="w-full rounded-lg border border-base-300 bg-base-100 px-3 py-2 text-sm text-base-content shadow-sm" placeholder="Weekly export" />
          </div>

          <div class="space-y-2">
            <label class="text-sm font-medium text-base-content/80" for={"scheduled-export-kind-#{@id}"}>Cadence</label>
            <select id={"scheduled-export-kind-#{@id}"} class="w-full rounded-lg border border-base-300 bg-base-100 px-3 py-2 text-sm text-base-content shadow-sm">
              <option value="daily" selected>Daily</option>
              <option value="hourly">Hourly</option>
              <option value="weekly">Weekly</option>
              <option value="monthly">Monthly</option>
            </select>
          </div>

          <div class="space-y-2 xl:col-span-2">
            <label class="text-sm font-medium text-base-content/80" for={"scheduled-export-body-#{@id}"}>Body</label>
            <textarea id={"scheduled-export-body-#{@id}"} rows="3" class="w-full rounded-lg border border-base-300 bg-base-100 px-3 py-2 text-sm text-base-content shadow-sm" placeholder="Attached is the latest export."></textarea>
          </div>

          <div class="space-y-2">
            <label class="text-sm font-medium text-base-content/80" for={"scheduled-export-time-#{@id}"}>Time</label>
            <input id={"scheduled-export-time-#{@id}"} value="07:00" class="w-full rounded-lg border border-base-300 bg-base-100 px-3 py-2 text-sm text-base-content shadow-sm" placeholder="07:00" />
          </div>

          <div class="space-y-2">
            <label class="text-sm font-medium text-base-content/80" for={"scheduled-export-timezone-#{@id}"}>Timezone</label>
            <input id={"scheduled-export-timezone-#{@id}"} value="Etc/UTC" class="w-full rounded-lg border border-base-300 bg-base-100 px-3 py-2 text-sm text-base-content shadow-sm" placeholder="America/New_York" />
          </div>

          <div class="space-y-2">
            <label class="text-sm font-medium text-base-content/80" for={"scheduled-export-day-of-week-#{@id}"}>Day of Week</label>
            <select id={"scheduled-export-day-of-week-#{@id}"} class="w-full rounded-lg border border-base-300 bg-base-100 px-3 py-2 text-sm text-base-content shadow-sm">
              <option value="1" selected>Monday</option>
              <option value="2">Tuesday</option>
              <option value="3">Wednesday</option>
              <option value="4">Thursday</option>
              <option value="5">Friday</option>
              <option value="6">Saturday</option>
              <option value="7">Sunday</option>
            </select>
          </div>

          <div class="space-y-2">
            <label class="text-sm font-medium text-base-content/80" for={"scheduled-export-day-of-month-#{@id}"}>Day of Month</label>
            <input id={"scheduled-export-day-of-month-#{@id}"} value="1" class="w-full rounded-lg border border-base-300 bg-base-100 px-3 py-2 text-sm text-base-content shadow-sm" placeholder="1" />
          </div>
        </div>

        <div class="mt-4 flex items-center justify-between gap-3">
          <div class="flex items-center gap-2 text-sm text-base-content/70">
            <input id={"scheduled-export-enabled-#{@id}"} type="checkbox" checked class="rounded border border-base-300" />
            <label for={"scheduled-export-enabled-#{@id}"}>Enable schedule immediately</label>
          </div>

          <button type="button" data-create-scheduled-export="true" data-target={@myself} data-name-input={"scheduled-export-name-#{@id}"} data-format-input={"scheduled-export-format-#{@id}"} data-recipients-input={"scheduled-export-recipients-#{@id}"} data-subject-input={"scheduled-export-subject-#{@id}"} data-body-input={"scheduled-export-body-#{@id}"} data-kind-input={"scheduled-export-kind-#{@id}"} data-time-input={"scheduled-export-time-#{@id}"} data-timezone-input={"scheduled-export-timezone-#{@id}"} data-day-of-week-input={"scheduled-export-day-of-week-#{@id}"} data-day-of-month-input={"scheduled-export-day-of-month-#{@id}"} data-enabled-input={"scheduled-export-enabled-#{@id}"} class="inline-flex items-center rounded-lg bg-primary px-4 py-2 text-sm font-medium text-primary-content shadow-sm transition hover:bg-primary/90">
            Create Scheduled Export
          </button>
        </div>
      </div>

      <div class="space-y-4">
        <div class="flex items-center justify-between gap-3">
          <h4 class="text-sm font-semibold uppercase tracking-[0.18em] text-base-content/60">Managed Schedules</h4>
          <span class="text-xs text-base-content/60">{@scheduled_exports |> length()} total</span>
        </div>

        <div :if={@scheduled_exports == []} class="rounded-xl border border-dashed border-base-300 bg-base-200/50 px-4 py-6 text-sm text-base-content/70">
          No scheduled exports yet.
        </div>

        <div :for={scheduled_export <- @scheduled_exports} class="rounded-xl border border-base-300 bg-base-100 p-4 shadow-sm">
          <div class="flex flex-col gap-4 xl:flex-row xl:items-start xl:justify-between">
            <div class="space-y-3">
              <div class="flex flex-wrap items-center gap-2">
                <h5 class="text-base font-semibold text-base-content">{ScheduledExports.field(scheduled_export, :name, "Untitled schedule")}</h5>
                <span class={status_badge_class(schedule_status(scheduled_export))}>{status_label(schedule_status(scheduled_export))}</span>
                <span class="rounded-full bg-base-200 px-2.5 py-1 text-xs font-medium text-base-content/70">{ScheduledExports.field(scheduled_export, :export_format, "csv") |> String.upcase()}</span>
                <span class="rounded-full bg-base-200 px-2.5 py-1 text-xs font-medium text-base-content/70">{String.capitalize(to_string(ScheduledExports.field(scheduled_export, :view_type, "detail")))}</span>
              </div>

              <div class="grid gap-2 text-sm text-base-content/70 md:grid-cols-2 xl:grid-cols-3">
                <div>Cadence: {schedule_summary(scheduled_export)}</div>
                <div>Next run: {format_datetime(ScheduledExports.field(scheduled_export, :next_run_at))}</div>
                <div>Last run: {format_datetime(ScheduledExports.field(scheduled_export, :last_run_at))}</div>
              </div>

              <div class="space-y-1 text-xs text-base-content/60">
                <div>Recipients: {recipient_summary(scheduled_export)}</div>
                <div>Public ID: <span class="font-mono">{ScheduledExports.field(scheduled_export, :public_id, "-")}</span></div>
                <div :if={ScheduledExports.field(scheduled_export, :last_error)} class="text-error">Last error: {ScheduledExports.field(scheduled_export, :last_error)}</div>
              </div>
            </div>

            <div class="flex flex-wrap gap-2 xl:max-w-[340px] xl:justify-end">
              <button type="button" phx-click="toggle_scheduled_export_disabled" phx-value-id={ScheduledExports.field(scheduled_export, :public_id)} phx-target={@myself} class="rounded-lg border border-base-300 bg-base-100 px-3 py-2 text-sm font-medium text-base-content transition hover:bg-base-200">{if schedule_enabled?(scheduled_export), do: "Pause", else: "Enable"}</button>
              <button type="button" phx-click="delete_scheduled_export" phx-value-id={ScheduledExports.field(scheduled_export, :public_id)} phx-target={@myself} data-confirm="Delete this scheduled export?" class="rounded-lg border border-error/30 bg-error/10 px-3 py-2 text-sm font-medium text-error transition hover:bg-error/20">Delete</button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("create_scheduled_export", %{"scheduled_export" => params}, socket) do
    case Service.create(adapter(socket), socket.assigns, params, service_opts(socket)) do
      {:ok, _scheduled_export} ->
        {:noreply,
         socket
         |> put_flash(:info, "Scheduled export created")
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

  def handle_event("create_scheduled_export", params, socket) when is_map(params) do
    handle_event("create_scheduled_export", %{"scheduled_export" => params}, socket)
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

  defp adapter(socket), do: Map.fetch!(socket.assigns, :scheduled_export_module)

  defp adapter_opts(socket) do
    [user_id: Map.get(socket.assigns, :current_user_id)]
  end

  defp service_opts(socket) do
    [adapter_opts: adapter_opts(socket)]
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

  defp status_badge_class(:ok),
    do: "rounded-full bg-emerald-100 px-2.5 py-1 text-xs font-medium text-emerald-700"

  defp status_badge_class(:running),
    do: "rounded-full bg-sky-100 px-2.5 py-1 text-xs font-medium text-sky-700"

  defp status_badge_class(:failed),
    do: "rounded-full bg-rose-100 px-2.5 py-1 text-xs font-medium text-rose-700"

  defp status_badge_class(:skipped),
    do: "rounded-full bg-amber-100 px-2.5 py-1 text-xs font-medium text-amber-700"

  defp status_badge_class(:never),
    do: "rounded-full bg-base-200 px-2.5 py-1 text-xs font-medium text-base-content/70"

  defp status_badge_class(:disabled),
    do: "rounded-full bg-base-200 px-2.5 py-1 text-xs font-medium text-base-content/70"

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
