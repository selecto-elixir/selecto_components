defmodule SelectoComponents.ExportedViews.Service do
  @moduledoc false

  alias SelectoComponents.ExportedViews
  alias SelectoComponents.ExportedViews.IPAllowlist
  alias SelectoComponents.ExportedViews.Renderer
  alias SelectoComponents.ExportedViews.Token
  alias SelectoComponents.QueryContract

  @type resolve_result ::
          {:ok, map(), map(), :fresh | :stale | :missing}
          | {:error, :not_found | :invalid_signature | :forbidden | :disabled | term()}

  @spec create(module(), map(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def create(adapter, assigns, attrs, opts \\ []) do
    adapter_opts = Keyword.get(opts, :adapter_opts, [])
    create_attrs = ExportedViews.build_create_attrs(assigns, attrs)

    with {:ok, view} <- adapter.create_exported_view(create_attrs, adapter_opts),
         {:ok, view} <- regenerate(adapter, view, opts) do
      {:ok, view}
    end
  end

  @spec regenerate(module(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def regenerate(adapter, view, opts \\ []) do
    adapter_opts = Keyword.get(opts, :adapter_opts, [])

    with {:ok, snapshot} <- ExportedViews.decode_snapshot(view),
         {:ok, render_payload, stats} <- Renderer.render_snapshot(snapshot),
         {:ok, updated_view} <-
           adapter.update_exported_view(
             view,
             cache_attrs(view, render_payload, stats),
             adapter_opts
           ) do
      {:ok, updated_view}
    else
      {:error, reason} = error ->
        _ = adapter.update_exported_view(view, %{last_error: error_message(reason)}, adapter_opts)
        error
    end
  end

  @spec rotate_signature(module(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def rotate_signature(adapter, view, opts \\ []) do
    adapter.update_exported_view(
      view,
      %{signature_version: ExportedViews.field(view, :signature_version, 1) + 1},
      Keyword.get(opts, :adapter_opts, [])
    )
  end

  @spec delete(module(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def delete(adapter, view, opts \\ []) do
    adapter.delete_exported_view(view, Keyword.get(opts, :adapter_opts, []))
  end

  @spec list(module(), term(), keyword()) :: [map()]
  def list(adapter, context, opts \\ []) do
    adapter.list_exported_views(context, Keyword.get(opts, :adapter_opts, []))
  end

  @spec resolve_for_embed(module(), String.t(), String.t() | nil, tuple() | nil, keyword()) ::
          resolve_result()
  def resolve_for_embed(adapter, public_id, signature, request_ip, opts \\ []) do
    adapter_opts = Keyword.get(opts, :adapter_opts, [])
    opts = Keyword.put_new(opts, :request_ip, request_ip)

    case adapter.get_exported_view_by_public_id(public_id, adapter_opts) do
      nil ->
        {:error, :not_found}

      view ->
        with :ok <- ensure_active(view),
             :ok <- Token.verify(view, signature, endpoint: Keyword.fetch!(opts, :endpoint)),
             true <- IPAllowlist.allowed?(view, request_ip),
             :ok <- authorize_embed_access(view, opts) do
          do_resolve(adapter, view, opts)
        else
          {:error, :invalid} -> {:error, :invalid_signature}
          false -> {:error, :forbidden}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  @spec request_ip(Phoenix.LiveView.Socket.t()) :: tuple() | nil
  def request_ip(socket) do
    case Phoenix.LiveView.get_connect_info(socket, :peer_data) do
      %{address: address} -> address
      _ -> nil
    end
  rescue
    _ -> nil
  end

  defp do_resolve(adapter, view, opts) do
    adapter_opts = Keyword.get(opts, :adapter_opts, [])

    case ExportedViews.cache_status(view) do
      :missing ->
        with {:ok, updated_view} <- regenerate(adapter, view, opts),
             {:ok, payload} <- ExportedViews.decode_cache_payload(updated_view) do
          touched_view = touch_access(adapter, updated_view, adapter_opts)
          {:ok, touched_view, payload, :missing}
        end

      :fresh ->
        with {:ok, payload} <- ExportedViews.decode_cache_payload(view) do
          touched_view = touch_access(adapter, view, adapter_opts)
          {:ok, touched_view, payload, :fresh}
        end

      :stale ->
        with {:ok, payload} <- ExportedViews.decode_cache_payload(view) do
          start_async_regeneration(adapter, view, opts)
          touched_view = touch_access(adapter, view, adapter_opts)
          {:ok, touched_view, payload, :stale}
        else
          _ ->
            with {:ok, updated_view} <- regenerate(adapter, view, opts),
                 {:ok, payload} <- ExportedViews.decode_cache_payload(updated_view) do
              touched_view = touch_access(adapter, updated_view, adapter_opts)
              {:ok, touched_view, payload, :missing}
            end
        end

      :error ->
        with {:ok, updated_view} <- regenerate(adapter, view, opts),
             {:ok, payload} <- ExportedViews.decode_cache_payload(updated_view) do
          touched_view = touch_access(adapter, updated_view, adapter_opts)
          {:ok, touched_view, payload, :missing}
        end

      :disabled ->
        {:error, :disabled}
    end
  end

  defp touch_access(adapter, view, adapter_opts) do
    access_count = ExportedViews.field(view, :access_count, 0)

    case adapter.update_exported_view(
           view,
           %{access_count: access_count + 1, last_accessed_at: DateTime.utc_now()},
           adapter_opts
         ) do
      {:ok, updated_view} -> updated_view
      _ -> view
    end
  end

  defp start_async_regeneration(adapter, view, opts) do
    Task.Supervisor.start_child(SelectoComponents.TaskSupervisor, fn ->
      _ = regenerate(adapter, view, opts)
    end)

    :ok
  rescue
    _ -> :ok
  end

  defp ensure_active(view) do
    if ExportedViews.disabled?(view), do: {:error, :disabled}, else: :ok
  end

  defp authorize_embed_access(view, opts) do
    case Keyword.get(opts, :capability_resolver) do
      nil ->
        :ok

      resolver ->
        view
        |> embed_access_request(opts)
        |> resolve_capability(resolver, opts)
        |> normalize_capability_decision("selecto.exported_views.access", :access)
    end
  end

  defp embed_access_request(view, opts) do
    Selecto.Capabilities.request(
      actor: Keyword.get(opts, :actor),
      tenant: Keyword.get(opts, :tenant),
      domain: Keyword.get(opts, :domain),
      capability: "selecto.exported_views.access",
      operation: :access,
      target: %{
        public_id: ExportedViews.field(view, :public_id),
        name: ExportedViews.field(view, :name),
        context: ExportedViews.field(view, :context),
        path: ExportedViews.field(view, :path),
        view_type: ExportedViews.field(view, :view_type),
        cache_status: ExportedViews.cache_status(view)
      },
      context:
        opts
        |> Keyword.get(:context, %{})
        |> map_or_empty()
        |> Map.merge(%{
          surface: :exported_view_embed,
          public_id: ExportedViews.field(view, :public_id),
          request_ip: format_request_ip(Keyword.get(opts, :request_ip))
        }),
      metadata:
        opts
        |> Keyword.get(:metadata, %{})
        |> map_or_empty()
    )
  end

  defp resolve_capability(request, resolver, opts) do
    Selecto.Capabilities.decide(resolver, request,
      resolver_context: Keyword.get(opts, :resolver_context, %{})
    )
  rescue
    error -> {:error, error}
  end

  defp normalize_capability_decision({:ok, decision}, capability, operation),
    do: normalize_capability_decision(decision, capability, operation)

  defp normalize_capability_decision({:error, reason}, capability, operation) do
    capability_denied("Capability check failed.", %{
      capability: capability,
      operation: operation,
      reason: inspect(reason)
    })
  end

  defp normalize_capability_decision(
         %Selecto.Capabilities.Decision{status: :allow},
         _capability,
         _operation
       ),
       do: :ok

  defp normalize_capability_decision(
         %Selecto.Capabilities.Decision{} = decision,
         capability,
         operation
       ) do
    capability_denied(decision.user_message || "Exported view access is not allowed.", %{
      capability: capability,
      operation: operation,
      code: decision.reason_code,
      status: decision.status,
      visibility: decision.visibility,
      audit_reason: decision.audit_reason,
      metadata: decision.metadata
    })
  end

  defp normalize_capability_decision(decision, capability, operation) when is_map(decision) do
    status = map_value(decision, :status)
    visibility = map_value(decision, :visibility)

    if status in [:allow, "allow", :enabled, "enabled"] or
         (is_nil(status) and visibility in [:enabled, "enabled"]) do
      :ok
    else
      capability_denied(
        map_value(decision, :reason) || map_value(decision, :user_message) ||
          "Exported view access is not allowed.",
        %{
          capability: map_value(decision, :capability, capability),
          operation: operation,
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

  defp normalize_capability_decision(false, capability, operation) do
    capability_denied("Exported view access is not allowed.", %{
      capability: capability,
      operation: operation
    })
  end

  defp normalize_capability_decision(_decision, _capability, _operation), do: :ok

  defp capability_denied(message, details) do
    {:error, {:capability_denied, message, QueryContract.json_safe(details)}}
  end

  defp cache_attrs(view, render_payload, stats) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %{
      cache_blob: ExportedViews.encode_term(render_payload),
      cache_generated_at: now,
      cache_expires_at: DateTime.add(now, ExportedViews.ttl_seconds(view), :second),
      last_execution_time_ms: stats.execution_time_ms,
      last_row_count: stats.row_count,
      last_payload_bytes: stats.payload_bytes,
      last_error: nil
    }
  end

  defp error_message(reason) when is_binary(reason), do: reason
  defp error_message(%_{} = reason), do: Exception.message(reason)
  defp error_message(reason), do: inspect(reason)

  defp format_request_ip(nil), do: nil

  defp format_request_ip(address) when is_tuple(address),
    do: address |> :inet.ntoa() |> to_string()

  defp format_request_ip(address), do: to_string(address)

  defp map_value(map, key, default \\ nil)

  defp map_value(map, key, default) when is_map(map),
    do: Map.get(map, key, Map.get(map, to_string(key), default))

  defp map_value(_map, _key, default), do: default

  defp map_or_empty(value) when is_map(value), do: value
  defp map_or_empty(_value), do: %{}
end
