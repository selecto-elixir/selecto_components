defmodule SelectoComponents.ScheduledExports.Service do
  @moduledoc false

  alias SelectoComponents.ExportSnapshots
  alias SelectoComponents.Exporter
  alias SelectoComponents.ExportedViews.Renderer
  alias SelectoComponents.QueryContract
  alias SelectoComponents.ScheduledExports

  @default_max_attachment_bytes 6_000_000

  @spec create(module(), map(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def create(adapter, assigns, attrs, opts \\ []) do
    adapter.create_scheduled_export(
      ScheduledExports.build_create_attrs(assigns, attrs),
      Keyword.get(opts, :adapter_opts, [])
    )
  end

  @spec update(module(), map(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def update(adapter, scheduled_export, attrs, opts \\ []) do
    adapter.update_scheduled_export(
      scheduled_export,
      attrs,
      Keyword.get(opts, :adapter_opts, [])
    )
  end

  @spec delete(module(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def delete(adapter, scheduled_export, opts \\ []) do
    adapter.delete_scheduled_export(scheduled_export, Keyword.get(opts, :adapter_opts, []))
  end

  @spec list(module(), term(), keyword()) :: [map()]
  def list(adapter, context, opts \\ []) do
    adapter.list_scheduled_exports(context, Keyword.get(opts, :adapter_opts, []))
  end

  @spec get(module(), String.t(), keyword()) :: map() | nil
  def get(adapter, public_id, opts \\ []) do
    adapter.get_scheduled_export_by_public_id(public_id, Keyword.get(opts, :adapter_opts, []))
  end

  @spec due(module(), DateTime.t(), keyword()) :: [map()]
  def due(adapter, now \\ DateTime.utc_now(), opts \\ []) do
    adapter.due_scheduled_exports(now, Keyword.get(opts, :adapter_opts, []))
  end

  @spec list_runs(module(), String.t(), keyword()) :: [map()]
  def list_runs(adapter, public_id, opts \\ []) do
    adapter.list_scheduled_export_runs(public_id, Keyword.get(opts, :adapter_opts, []))
  end

  @spec create_run(module(), map(), atom(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def create_run(adapter, scheduled_export, trigger_type, attrs \\ %{}, opts \\ []) do
    adapter.create_scheduled_export_run(
      ScheduledExports.build_run_attrs(scheduled_export, trigger_type, attrs),
      Keyword.get(opts, :adapter_opts, [])
    )
  end

  @spec update_run(module(), map(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def update_run(adapter, run, attrs, opts \\ []) do
    adapter.update_scheduled_export_run(run, attrs, Keyword.get(opts, :adapter_opts, []))
  end

  @spec deliver_now(module(), term(), map(), keyword()) ::
          {:ok, %{export: map(), delivery: map(), payload_bytes: non_neg_integer()}}
          | {:error, term()}
  def deliver_now(delivery_adapter, query_results, delivery_config, opts \\ []) do
    delivery = ScheduledExports.normalize_delivery(delivery_config)
    recipients = delivery.email.recipients
    invalid_recipients = Enum.reject(recipients, &ScheduledExports.valid_email?/1)

    cond do
      delivery.channel != :email ->
        {:error, :unsupported_delivery_channel}

      recipients == [] ->
        {:error, :missing_recipients}

      invalid_recipients != [] ->
        {:error, {:invalid_recipients, invalid_recipients}}

      true ->
        do_deliver_now(delivery_adapter, query_results, delivery, opts)
    end
  end

  @spec run_scheduled_export(module(), map() | String.t(), keyword()) ::
          {:ok,
           %{
             scheduled_export: map(),
             run: map(),
             export: map() | nil,
             delivery: map() | nil,
             payload_bytes: non_neg_integer(),
             row_count: non_neg_integer(),
             execution_time_ms: term()
           }}
          | {:error, term()}
  def run_scheduled_export(adapter, scheduled_export_or_public_id, opts \\ []) do
    adapter_opts = Keyword.get(opts, :adapter_opts, [])

    with {:ok, scheduled_export} <-
           fetch_scheduled_export(adapter, scheduled_export_or_public_id, adapter_opts),
         {:ok, run} <-
           create_run(
             adapter,
             scheduled_export,
             Keyword.get(opts, :trigger_type, :scheduled),
             %{},
             opts
           ) do
      case do_run_scheduled_export(scheduled_export, opts) do
        {:ok, result} ->
          finish_run_success(adapter, scheduled_export, run, result, opts)

        {:skip, reason} ->
          finish_run_skipped(adapter, scheduled_export, run, reason, opts)

        {:error, reason} ->
          finish_run_failure(adapter, scheduled_export, run, reason, opts)
      end
    end
  end

  defp do_deliver_now(delivery_adapter, query_results, delivery, opts) do
    format = ScheduledExports.normalize_export_format(Keyword.get(opts, :format, "csv"))

    exported_at =
      Keyword.get(opts, :exported_at, DateTime.utc_now() |> DateTime.truncate(:second))

    with {:ok, export} <-
           Exporter.build(format, query_results,
             view_mode: Keyword.get(opts, :view_mode, "results"),
             view_config: Keyword.get(opts, :view_config),
             selecto: Keyword.get(opts, :selecto),
             presentation_context: Keyword.get(opts, :presentation_context, %{}),
             export_mode: Keyword.get(opts, :export_mode, :raw),
             exported_at: exported_at
           ),
         :ok <-
           ensure_payload_size(
             export,
             Keyword.get(opts, :max_attachment_bytes, @default_max_attachment_bytes)
           ),
         {:ok, delivery_result} <-
           delivery_adapter.deliver_email(
             delivery_payload(export, format, exported_at, opts),
             delivery,
             Keyword.get(opts, :delivery_opts, [])
           ) do
      {:ok,
       %{
         export: export,
         delivery: delivery_result,
         payload_bytes: byte_size(export.content)
       }}
    end
  end

  defp do_run_scheduled_export(scheduled_export, opts) do
    with :ok <- ensure_active(scheduled_export),
         :ok <- authorize_scheduled_export_run(scheduled_export, opts),
         {:ok, delivery_adapter} <- fetch_delivery_adapter(opts),
         {:ok, snapshot} <-
           ExportSnapshots.decode_term(ScheduledExports.field(scheduled_export, :snapshot_blob)),
         {:ok, render_payload, stats} <-
           snapshot_runner(opts).render_snapshot(
             snapshot,
             Keyword.get(opts, :snapshot_runner_opts, [])
           ),
         {:ok, delivery_result} <-
           deliver_now(
             delivery_adapter,
             render_payload.query_results,
             ScheduledExports.field(scheduled_export, :delivery, %{}),
             format: ScheduledExports.field(scheduled_export, :export_format, "csv"),
             view_mode: render_payload.applied_view,
             view_config: snapshot_to_view_config(snapshot),
             exported_at: DateTime.utc_now() |> DateTime.truncate(:second),
             max_attachment_bytes:
               Keyword.get(opts, :max_attachment_bytes, @default_max_attachment_bytes),
             path: ScheduledExports.field(scheduled_export, :path, snapshot[:path]),
             export_name: ScheduledExports.field(scheduled_export, :name),
             delivery_opts: Keyword.get(opts, :delivery_opts, [])
           ) do
      {:ok,
       %{
         export: delivery_result.export,
         delivery: delivery_result.delivery,
         payload_bytes: delivery_result.payload_bytes,
         row_count: row_count(render_payload.query_results, stats),
         execution_time_ms: Map.get(stats, :execution_time_ms),
         delivery_count: recipient_count(scheduled_export)
       }}
    else
      {:error, :disabled} -> {:skip, :disabled}
      {:error, {:capability_denied, _message, _details} = reason} -> {:skip, reason}
      {:error, reason} -> {:error, reason}
      other -> {:error, other}
    end
  end

  defp authorize_scheduled_export_run(scheduled_export, opts) do
    case Keyword.get(opts, :capability_resolver) do
      resolver when is_function(resolver, 1) or is_function(resolver, 2) ->
        scheduled_export
        |> scheduled_export_run_request(opts)
        |> call_capability_resolver(resolver, opts)
        |> normalize_capability_decision("selecto.scheduled_exports.run")

      _resolver ->
        :ok
    end
  end

  defp scheduled_export_run_request(scheduled_export, opts) do
    capability = "selecto.scheduled_exports.run"

    Selecto.Capabilities.request(
      actor: Keyword.get(opts, :actor),
      tenant: Keyword.get(opts, :tenant),
      domain: Keyword.get(opts, :domain),
      capability: capability,
      operation: :run,
      target: %{
        capability: capability,
        public_id: ScheduledExports.field(scheduled_export, :public_id),
        context: ScheduledExports.field(scheduled_export, :context),
        format: ScheduledExports.field(scheduled_export, :export_format, "csv"),
        path: ScheduledExports.field(scheduled_export, :path),
        name: ScheduledExports.field(scheduled_export, :name)
      },
      context:
        opts
        |> Keyword.get(:context, %{})
        |> map_or_empty()
        |> Map.merge(%{
          surface: :scheduled_exports_service,
          trigger_type: Keyword.get(opts, :trigger_type, :scheduled)
        }),
      metadata:
        opts
        |> Keyword.get(:metadata, %{})
        |> map_or_empty()
    )
  end

  defp call_capability_resolver(request, resolver, _opts) when is_function(resolver, 1),
    do: resolver.(request)

  defp call_capability_resolver(request, resolver, opts) when is_function(resolver, 2),
    do: resolver.(request, Keyword.get(opts, :resolver_context, %{}))

  defp normalize_capability_decision({:ok, decision}, capability),
    do: normalize_capability_decision(decision, capability)

  defp normalize_capability_decision({:error, reason}, capability) do
    capability_denied("Capability check failed.", %{
      capability: capability,
      operation: :run,
      reason: inspect(reason)
    })
  end

  defp normalize_capability_decision(
         %Selecto.Capabilities.Decision{status: :allow},
         _capability
       ),
       do: :ok

  defp normalize_capability_decision(%Selecto.Capabilities.Decision{} = decision, capability) do
    capability_denied(decision.user_message || "Scheduled export run is not allowed.", %{
      capability: capability,
      operation: :run,
      code: decision.reason_code,
      status: decision.status,
      visibility: decision.visibility,
      audit_reason: decision.audit_reason,
      metadata: decision.metadata
    })
  end

  defp normalize_capability_decision(decision, capability) when is_map(decision) do
    status = map_value(decision, :status)
    visibility = map_value(decision, :visibility)

    if status in [:allow, "allow", :enabled, "enabled"] or
         (is_nil(status) and visibility in [:enabled, "enabled"]) do
      :ok
    else
      capability_denied(
        map_value(decision, :reason) || map_value(decision, :user_message) ||
          "Scheduled export run is not allowed.",
        %{
          capability: map_value(decision, :capability, capability),
          operation: :run,
          code: map_value(decision, :code) || map_value(decision, :reason_code),
          status: status,
          visibility: visibility,
          reason: map_value(decision, :reason),
          audit: map_value(decision, :audit),
          metadata: map_value(decision, :metadata, %{})
        }
      )
    end
  end

  defp normalize_capability_decision(false, capability) do
    capability_denied("Scheduled export run is not allowed.", %{
      capability: capability,
      operation: :run
    })
  end

  defp normalize_capability_decision(_decision, _capability), do: :ok

  defp capability_denied(message, details) do
    {:error, {:capability_denied, message, QueryContract.json_safe(map_or_empty(details))}}
  end

  defp finish_run_success(adapter, scheduled_export, run, result, opts) do
    finished_at = DateTime.utc_now() |> DateTime.truncate(:second)
    adapter_opts = Keyword.get(opts, :adapter_opts, [])

    with {:ok, updated_run} <-
           update_run(
             adapter,
             run,
             %{
               finished_at: finished_at,
               status: :ok,
               row_count: result.row_count,
               payload_bytes: result.payload_bytes,
               execution_time_ms: result.execution_time_ms,
               delivery_count: result.delivery_count,
               error_message: nil
             },
             opts
           ),
         {:ok, updated_scheduled_export} <-
           adapter.update_scheduled_export(
             scheduled_export,
             %{
               last_run_at: finished_at,
               next_run_at: next_run_at(scheduled_export, finished_at),
               last_status: :ok,
               last_error: nil
             },
             adapter_opts
           ) do
      {:ok,
       %{
         scheduled_export: updated_scheduled_export,
         run: updated_run,
         export: result.export,
         delivery: result.delivery,
         payload_bytes: result.payload_bytes,
         row_count: result.row_count,
         execution_time_ms: result.execution_time_ms
       }}
    end
  end

  defp finish_run_failure(adapter, scheduled_export, run, reason, opts) do
    finished_at = DateTime.utc_now() |> DateTime.truncate(:second)
    adapter_opts = Keyword.get(opts, :adapter_opts, [])
    error_message = error_message(reason)

    _ =
      update_run(
        adapter,
        run,
        %{finished_at: finished_at, status: :failed, error_message: error_message},
        opts
      )

    _ =
      adapter.update_scheduled_export(
        scheduled_export,
        %{
          last_run_at: finished_at,
          next_run_at: next_run_at(scheduled_export, finished_at),
          last_status: :failed,
          last_error: error_message
        },
        adapter_opts
      )

    {:error, reason}
  end

  defp finish_run_skipped(adapter, scheduled_export, run, reason, opts) do
    finished_at = DateTime.utc_now() |> DateTime.truncate(:second)
    adapter_opts = Keyword.get(opts, :adapter_opts, [])
    error_message = error_message(reason)

    with {:ok, updated_run} <-
           update_run(
             adapter,
             run,
             %{finished_at: finished_at, status: :skipped, error_message: error_message},
             opts
           ),
         {:ok, updated_scheduled_export} <-
           adapter.update_scheduled_export(
             scheduled_export,
             %{
               last_run_at: finished_at,
               next_run_at: nil,
               last_status: :skipped,
               last_error: error_message
             },
             adapter_opts
           ) do
      {:ok,
       %{
         scheduled_export: updated_scheduled_export,
         run: updated_run,
         export: nil,
         delivery: nil,
         payload_bytes: 0,
         row_count: 0,
         execution_time_ms: nil
       }}
    end
  end

  defp delivery_payload(export, format, exported_at, opts) do
    %{
      format: format,
      filename: export.filename,
      mime_type: export.mime_type,
      content: export.content,
      attachment: %{
        filename: export.filename,
        mime_type: export.mime_type,
        content: export.content
      },
      exported_at: exported_at,
      view_mode: Keyword.get(opts, :view_mode, "results"),
      path: Keyword.get(opts, :path),
      export_name: Keyword.get(opts, :export_name)
    }
  end

  defp ensure_payload_size(export, max_bytes) do
    if byte_size(export.content) > max_bytes do
      {:error, :payload_too_large}
    else
      :ok
    end
  end

  defp fetch_scheduled_export(_adapter, %{} = scheduled_export, _adapter_opts),
    do: {:ok, scheduled_export}

  defp fetch_scheduled_export(adapter, public_id, adapter_opts) when is_binary(public_id) do
    case adapter.get_scheduled_export_by_public_id(public_id, adapter_opts) do
      nil -> {:error, :not_found}
      scheduled_export -> {:ok, scheduled_export}
    end
  end

  defp fetch_scheduled_export(_adapter, _other, _adapter_opts), do: {:error, :not_found}

  defp fetch_delivery_adapter(opts) do
    case Keyword.get(opts, :delivery_adapter) do
      nil -> {:error, :missing_delivery_adapter}
      false -> {:error, :missing_delivery_adapter}
      adapter -> {:ok, adapter}
    end
  end

  defp snapshot_runner(opts), do: Keyword.get(opts, :snapshot_runner, Renderer)

  defp snapshot_to_view_config(%{params: params}) when is_map(params) do
    %{
      views: Map.get(params, "views", %{}),
      filters: Map.get(params, "filters", []),
      view_mode: Map.get(params, "view_mode", "detail")
    }
  end

  defp snapshot_to_view_config(_), do: %{views: %{}, filters: [], view_mode: "detail"}

  defp row_count(query_results, stats) do
    Map.get(stats, :row_count, row_count(query_results))
  end

  defp row_count({rows, _columns, _aliases}) when is_list(rows), do: length(rows)
  defp row_count(_), do: 0

  defp recipient_count(scheduled_export) do
    scheduled_export
    |> ScheduledExports.field(:delivery, %{})
    |> ScheduledExports.field(:email, %{})
    |> ScheduledExports.field(:recipients, [])
    |> length()
  end

  defp next_run_at(scheduled_export, now) do
    scheduled_export
    |> ScheduledExports.field(:schedule, %{})
    |> ScheduledExports.next_run_at(now)
  end

  defp ensure_active(scheduled_export) do
    if ScheduledExports.field(scheduled_export, :disabled_at) in [nil, ""] do
      :ok
    else
      {:error, :disabled}
    end
  end

  defp error_message(reason) when is_binary(reason), do: reason
  defp error_message(%_{} = reason), do: Exception.message(reason)
  defp error_message(reason), do: inspect(reason)

  defp map_value(map, key, default \\ nil)

  defp map_value(map, key, default) when is_map(map),
    do: Map.get(map, key, Map.get(map, to_string(key), default))

  defp map_value(_map, _key, default), do: default

  defp map_or_empty(value) when is_map(value), do: value
  defp map_or_empty(_value), do: %{}
end
