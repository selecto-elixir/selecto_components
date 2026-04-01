defmodule SelectoComponents.ScheduledExports do
  @moduledoc """
  Behavior and helpers for persisted scheduled export definitions and run history.

  The persistence layer is intentionally app-owned. Host applications implement
  this behavior while SelectoComponents provides snapshot, normalization, and
  orchestration helpers.
  """

  alias SelectoComponents.ExportSnapshots
  alias SelectoComponents.ExportedViews

  @type scheduled_export :: map()
  @type scheduled_export_run :: map()

  @callback list_scheduled_exports(context :: term(), opts :: keyword()) :: [scheduled_export()]
  @callback get_scheduled_export_by_public_id(public_id :: String.t(), opts :: keyword()) ::
              scheduled_export() | nil
  @callback create_scheduled_export(attrs :: map(), opts :: keyword()) ::
              {:ok, scheduled_export()} | {:error, term()}
  @callback update_scheduled_export(scheduled_export(), attrs :: map(), opts :: keyword()) ::
              {:ok, scheduled_export()} | {:error, term()}
  @callback delete_scheduled_export(scheduled_export(), opts :: keyword()) ::
              {:ok, scheduled_export()} | {:error, term()}
  @callback create_scheduled_export_run(attrs :: map(), opts :: keyword()) ::
              {:ok, scheduled_export_run()} | {:error, term()}
  @callback update_scheduled_export_run(scheduled_export_run(), attrs :: map(), opts :: keyword()) ::
              {:ok, scheduled_export_run()} | {:error, term()}
  @callback due_scheduled_exports(now :: DateTime.t(), opts :: keyword()) :: [scheduled_export()]

  @supported_formats ~w(csv tsv json xlsx pdf)
  @run_statuses [:running, :ok, :failed, :skipped]
  @trigger_types [:manual_email, :scheduled, :retry]

  @doc """
  Build attributes for `create_scheduled_export/2` from current assigns.
  """
  @spec build_create_attrs(map(), map()) :: map()
  def build_create_attrs(assigns, attrs) when is_map(assigns) and is_map(attrs) do
    snapshot = ExportSnapshots.build_snapshot(assigns)
    schedule = normalize_schedule(schedule_attrs(attrs))
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %{
      name: normalize_name(field(attrs, :name, "")),
      context: snapshot.context,
      path: snapshot.path,
      view_type: Map.get(snapshot.params, "view_mode", "detail"),
      public_id: field(attrs, :public_id, generate_public_id()),
      export_format: normalize_export_format(field(attrs, :export_format, "csv")),
      snapshot_blob: ExportSnapshots.encode_term(snapshot),
      delivery: normalize_delivery(delivery_attrs(attrs)),
      schedule: schedule,
      last_run_at: nil,
      next_run_at: next_run_at(schedule, now),
      last_status: :never,
      last_error: nil,
      user_id: Map.get(assigns, :current_user_id),
      tenant_context: snapshot.tenant_context,
      disabled_at: nil
    }
  end

  @doc """
  Build normalized update attrs for an existing scheduled export definition.
  """
  @spec build_update_attrs(map(), map()) :: map()
  def build_update_attrs(scheduled_export, attrs)
      when is_map(scheduled_export) and is_map(attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    schedule = normalize_schedule(schedule_attrs(attrs))
    enabled? = field(schedule, :enabled, false)

    %{
      name: normalize_name(field(attrs, :name, field(scheduled_export, :name, ""))),
      export_format:
        normalize_export_format(
          field(attrs, :export_format, field(scheduled_export, :export_format, "csv"))
        ),
      delivery: normalize_delivery(delivery_attrs(attrs)),
      schedule: schedule,
      next_run_at: next_run_at(schedule, now),
      disabled_at:
        if(enabled?,
          do: nil,
          else: field(scheduled_export, :disabled_at, now)
        )
    }
  end

  @doc """
  Build attributes for a scheduled export run record.
  """
  @spec build_run_attrs(map(), atom(), map()) :: map()
  def build_run_attrs(scheduled_export, trigger_type, attrs \\ %{})
      when is_map(scheduled_export) and is_map(attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %{
      scheduled_export_id: field(scheduled_export, :id),
      scheduled_export_public_id: field(scheduled_export, :public_id),
      trigger_type: normalize_trigger_type(trigger_type),
      started_at: field(attrs, :started_at, now),
      finished_at: field(attrs, :finished_at),
      status: normalize_run_status(field(attrs, :status, :running)),
      row_count: field(attrs, :row_count),
      payload_bytes: field(attrs, :payload_bytes),
      execution_time_ms: field(attrs, :execution_time_ms),
      delivery_count: field(attrs, :delivery_count),
      error_message: normalize_optional_text(field(attrs, :error_message))
    }
  end

  @doc """
  Fetch a field from a map/struct, supporting atom and string keys.
  """
  @spec field(map() | nil, atom(), term()) :: term()
  def field(record, key, default \\ nil)

  def field(nil, _key, default), do: default

  def field(record, key, default) when is_map(record) do
    Map.get(record, key, Map.get(record, Atom.to_string(key), default))
  end

  @doc """
  Normalize the persisted delivery configuration.
  """
  @spec normalize_delivery(map() | nil) :: map()
  def normalize_delivery(%{} = delivery) do
    email = field(delivery, :email, %{})

    %{
      channel: normalize_channel(field(delivery, :channel, :email)),
      email: %{
        recipients: normalize_recipients(field(email, :recipients, [])),
        cc: normalize_recipients(field(email, :cc, [])),
        bcc: normalize_recipients(field(email, :bcc, [])),
        subject_template: normalize_optional_text(field(email, :subject_template)),
        body_template: normalize_optional_text(field(email, :body_template))
      }
    }
  end

  def normalize_delivery(_), do: normalize_delivery(%{})

  @doc """
  Normalize schedule configuration into the first-phase supported shape.
  """
  @spec normalize_schedule(map() | nil) :: map()
  def normalize_schedule(%{} = schedule) do
    kind = normalize_schedule_kind(field(schedule, :kind))

    %{
      enabled: truthy?(field(schedule, :enabled, false)) and not is_nil(kind),
      kind: kind,
      timezone: normalize_timezone(field(schedule, :timezone, "Etc/UTC")),
      time: normalize_time(field(schedule, :time, "07:00")),
      day_of_week: normalize_day_of_week(field(schedule, :day_of_week, 1)),
      day_of_month: normalize_day_of_month(field(schedule, :day_of_month, 1))
    }
  end

  def normalize_schedule(_), do: normalize_schedule(%{})

  @doc """
  Calculate the next run timestamp for a first-phase schedule definition.
  """
  @spec next_run_at(map() | nil, DateTime.t()) :: DateTime.t() | nil
  def next_run_at(schedule, now \\ DateTime.utc_now())

  def next_run_at(schedule, %DateTime{} = now) when is_map(schedule) do
    if truthy?(field(schedule, :enabled, false)) do
      timezone = normalize_timezone(field(schedule, :timezone, "Etc/UTC"))

      with {:ok, local_now} <- DateTime.shift_zone(now, timezone),
           {hour, minute} <- parse_time_parts(field(schedule, :time, "07:00")),
           %DateTime{} = local_next <- compute_local_next_run(schedule, local_now, hour, minute),
           {:ok, utc_next} <- DateTime.shift_zone(local_next, "Etc/UTC") do
        utc_next
      else
        _ -> nil
      end
    else
      nil
    end
  end

  def next_run_at(_schedule, _now), do: nil

  @doc false
  def normalize_export_format(format) when is_atom(format),
    do: format |> Atom.to_string() |> normalize_export_format()

  def normalize_export_format(format) when is_binary(format) do
    format = format |> String.trim() |> String.downcase()
    if format in @supported_formats, do: format, else: "csv"
  end

  def normalize_export_format(_), do: "csv"

  @doc false
  def normalize_name(name) when is_binary(name), do: String.trim(name)
  def normalize_name(_), do: ""

  @doc false
  def normalize_optional_text(nil), do: nil

  def normalize_optional_text(value) when is_binary(value) do
    trimmed = String.trim(value)
    if trimmed == "", do: nil, else: trimmed
  end

  def normalize_optional_text(value), do: value |> to_string() |> normalize_optional_text()

  @doc false
  def normalize_recipients(value) when is_binary(value) do
    value
    |> String.split(~r/[\n,;]/, trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  def normalize_recipients(value) when is_list(value) do
    value
    |> Enum.map(&normalize_optional_text/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  def normalize_recipients(_), do: []

  @doc false
  def valid_email?(email) when is_binary(email) do
    Regex.match?(~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/, email)
  end

  def valid_email?(_), do: false

  @doc false
  def generate_public_id, do: ExportedViews.generate_public_id()

  defp delivery_attrs(attrs) do
    field(attrs, :delivery, %{
      channel: field(attrs, :channel, :email),
      email: %{
        recipients: field(attrs, :recipients, []),
        cc: field(attrs, :cc, []),
        bcc: field(attrs, :bcc, []),
        subject_template: field(attrs, :subject_template),
        body_template: field(attrs, :body_template)
      }
    })
  end

  defp schedule_attrs(attrs), do: field(attrs, :schedule, %{})

  defp normalize_channel(:email), do: :email
  defp normalize_channel("email"), do: :email
  defp normalize_channel(_), do: :email

  defp normalize_schedule_kind(kind) when is_atom(kind) do
    if kind in [:hourly, :daily, :weekly, :monthly], do: kind, else: nil
  end

  defp normalize_schedule_kind(kind) when is_binary(kind) do
    kind
    |> String.trim()
    |> String.downcase()
    |> case do
      "hourly" -> :hourly
      "daily" -> :daily
      "weekly" -> :weekly
      "monthly" -> :monthly
      _ -> nil
    end
  end

  defp normalize_schedule_kind(_), do: nil

  defp normalize_timezone(value) when is_binary(value) do
    trimmed = String.trim(value)
    if trimmed == "", do: "Etc/UTC", else: trimmed
  end

  defp normalize_timezone(_), do: "Etc/UTC"

  defp normalize_time(value) when is_binary(value) do
    case String.trim(value) do
      <<h1, h2, ?:, m1, m2>> = time
      when h1 in ?0..?2 and h2 in ?0..?9 and m1 in ?0..?5 and m2 in ?0..?9 ->
        time

      _ ->
        "07:00"
    end
  end

  defp normalize_time(_), do: "07:00"

  defp normalize_day_of_week(value) when is_integer(value) and value in 1..7, do: value

  defp normalize_day_of_week(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {parsed, ""} -> normalize_day_of_week(parsed)
      _ -> 1
    end
  end

  defp normalize_day_of_week(_), do: 1

  defp normalize_day_of_month(value) when is_integer(value) and value in 1..31, do: value

  defp normalize_day_of_month(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {parsed, ""} -> normalize_day_of_month(parsed)
      _ -> 1
    end
  end

  defp normalize_day_of_month(_), do: 1

  defp normalize_trigger_type(trigger_type) when trigger_type in @trigger_types, do: trigger_type
  defp normalize_trigger_type(_), do: :scheduled

  defp normalize_run_status(status) when status in @run_statuses, do: status
  defp normalize_run_status(_), do: :running

  defp parse_time_parts(value) when is_binary(value) do
    case String.split(value, ":", parts: 2) do
      [hour, minute] ->
        {String.to_integer(hour), String.to_integer(minute)}

      _ ->
        {7, 0}
    end
  end

  defp compute_local_next_run(schedule, local_now, hour, minute) do
    kind = field(schedule, :kind)

    case kind do
      :hourly -> compute_hourly_run(local_now, minute)
      :daily -> compute_daily_run(local_now, hour, minute)
      :weekly -> compute_weekly_run(schedule, local_now, hour, minute)
      :monthly -> compute_monthly_run(schedule, local_now, hour, minute)
      _ -> nil
    end
  end

  defp compute_hourly_run(local_now, minute) do
    candidate =
      local_datetime(DateTime.to_date(local_now), local_now.hour, minute, local_now.time_zone)

    if DateTime.compare(candidate, local_now) == :gt do
      candidate
    else
      local_now
      |> DateTime.add(3600, :second)
      |> then(fn next_hour ->
        local_datetime(DateTime.to_date(next_hour), next_hour.hour, minute, next_hour.time_zone)
      end)
    end
  end

  defp compute_daily_run(local_now, hour, minute) do
    candidate = local_datetime(DateTime.to_date(local_now), hour, minute, local_now.time_zone)

    if DateTime.compare(candidate, local_now) == :gt do
      candidate
    else
      local_datetime(Date.add(DateTime.to_date(local_now), 1), hour, minute, local_now.time_zone)
    end
  end

  defp compute_weekly_run(schedule, local_now, hour, minute) do
    current_date = DateTime.to_date(local_now)
    target_day = normalize_day_of_week(field(schedule, :day_of_week, 1))
    current_day = Date.day_of_week(current_date)
    day_offset = rem(target_day - current_day + 7, 7)
    candidate_date = Date.add(current_date, day_offset)
    candidate = local_datetime(candidate_date, hour, minute, local_now.time_zone)

    if day_offset == 0 and DateTime.compare(candidate, local_now) != :gt do
      local_datetime(Date.add(candidate_date, 7), hour, minute, local_now.time_zone)
    else
      candidate
    end
  end

  defp compute_monthly_run(schedule, local_now, hour, minute) do
    current_date = DateTime.to_date(local_now)
    target_day = normalize_day_of_month(field(schedule, :day_of_month, 1))
    candidate_date = build_monthly_date(current_date.year, current_date.month, target_day)
    candidate = local_datetime(candidate_date, hour, minute, local_now.time_zone)

    if DateTime.compare(candidate, local_now) == :gt do
      candidate
    else
      {year, month} = next_month(current_date.year, current_date.month)
      next_date = build_monthly_date(year, month, target_day)
      local_datetime(next_date, hour, minute, local_now.time_zone)
    end
  end

  defp build_monthly_date(year, month, target_day) do
    day = min(target_day, Date.days_in_month(Date.new!(year, month, 1)))
    Date.new!(year, month, day)
  end

  defp next_month(year, 12), do: {year + 1, 1}
  defp next_month(year, month), do: {year, month + 1}

  defp local_datetime(date, hour, minute, timezone) do
    naive = NaiveDateTime.new!(date, Time.new!(hour, minute, 0))

    case DateTime.from_naive(naive, timezone) do
      {:ok, value} -> value
      {:ambiguous, first, _second} -> first
      {:gap, _before, after_dt} -> after_dt
      {:error, _} -> nil
    end
  end

  defp truthy?(value) when value in [true, "true", "on", "1", 1], do: true
  defp truthy?(_), do: false
end
