defmodule SelectoComponents.ExportedViews.Service do
  @moduledoc false

  alias SelectoComponents.ExportedViews
  alias SelectoComponents.ExportedViews.IPAllowlist
  alias SelectoComponents.ExportedViews.Renderer
  alias SelectoComponents.ExportedViews.Token

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

    case adapter.get_exported_view_by_public_id(public_id, adapter_opts) do
      nil ->
        {:error, :not_found}

      view ->
        with :ok <- ensure_active(view),
             :ok <- Token.verify(view, signature, endpoint: Keyword.fetch!(opts, :endpoint)),
             true <- IPAllowlist.allowed?(view, request_ip) do
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
end
