defmodule SelectoComponents.ScheduledExports.Service do
  @moduledoc false

  alias SelectoComponents.Exporter
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

  @spec due(module(), DateTime.t(), keyword()) :: [map()]
  def due(adapter, now \\ DateTime.utc_now(), opts \\ []) do
    adapter.due_scheduled_exports(now, Keyword.get(opts, :adapter_opts, []))
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

  defp do_deliver_now(delivery_adapter, query_results, delivery, opts) do
    format = ScheduledExports.normalize_export_format(Keyword.get(opts, :format, "csv"))

    exported_at =
      Keyword.get(opts, :exported_at, DateTime.utc_now() |> DateTime.truncate(:second))

    with {:ok, export} <-
           Exporter.build(format, query_results,
             view_mode: Keyword.get(opts, :view_mode, "results"),
             view_config: Keyword.get(opts, :view_config),
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
end
