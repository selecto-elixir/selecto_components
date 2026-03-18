defmodule SelectoComponents.ExportedViews.Manager do
  @moduledoc """
  LiveComponent for creating and managing exported iframe views.
  """

  use Phoenix.LiveComponent

  alias SelectoComponents.ExportedViews
  alias SelectoComponents.ExportedViews.Service
  alias SelectoComponents.ExportedViews.Snippets

  @impl true
  def mount(socket) do
    {:ok,
     assign(socket,
       exported_views: [],
       snippets: nil,
       snippets_view_id: nil,
       form: default_form(),
       loaded_context: nil
     )}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> maybe_load_exported_views()

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6 rounded-xl border border-base-300 bg-base-100 p-4 shadow-sm">
      <div class="space-y-2">
        <h3 class="text-base font-semibold text-base-content">Exported Views</h3>
        <p class="text-sm text-base-content/70">
          Create signed iframe exports for aggregate, detail, and graph views with 3, 6, or 12 hour cache windows.
        </p>
      </div>

      <div id={"exported-view-form-#{@id}"} class="space-y-4">
        <div class="grid gap-4 lg:grid-cols-[minmax(0,1.3fr)_180px]">
          <div class="space-y-2">
            <label class="text-sm font-medium text-base-content/80" for={"exported-view-name-#{@id}"}>Name</label>
            <input id={"exported-view-name-#{@id}"} value={@form.name} class="w-full rounded-lg border border-base-300 bg-base-100 px-3 py-2 text-sm text-base-content shadow-sm" placeholder="Executive detail snapshot" />
          </div>

          <div class="space-y-2">
            <label class="text-sm font-medium text-base-content/80" for={"exported-view-ttl-#{@id}"}>Cache TTL</label>
            <select id={"exported-view-ttl-#{@id}"} class="w-full rounded-lg border border-base-300 bg-base-100 px-3 py-2 text-sm text-base-content shadow-sm">
              <option value="3" selected={to_string(@form.cache_ttl_hours) == "3"}>3 hours</option>
              <option value="6" selected={to_string(@form.cache_ttl_hours) == "6"}>6 hours</option>
              <option value="12" selected={to_string(@form.cache_ttl_hours) == "12"}>12 hours</option>
            </select>
          </div>
        </div>

        <div class="mt-4 space-y-2">
          <label class="text-sm font-medium text-base-content/80" for={"exported-view-ip-#{@id}"}>IP allowlist</label>
          <textarea id={"exported-view-ip-#{@id}"} rows="3" class="w-full rounded-lg border border-base-300 bg-base-100 px-3 py-2 text-sm text-base-content shadow-sm" placeholder="203.0.113.8\n10.0.0.0/24"><%= @form.ip_allowlist_text %></textarea>
          <p class="text-xs text-base-content/60">Leave blank for unrestricted access. Use one IP or CIDR per line.</p>
        </div>

        <div class="mt-4 flex items-center justify-between gap-3">
          <p class="text-xs text-base-content/60">The current active view snapshot is saved and cached immediately.</p>
          <button type="button" id={"exported-view-create-#{@id}"} phx-hook="CreateExportedView" data-target={@myself} data-name-input={"exported-view-name-#{@id}"} data-ttl-input={"exported-view-ttl-#{@id}"} data-ip-input={"exported-view-ip-#{@id}"} class="inline-flex items-center rounded-lg bg-primary px-4 py-2 text-sm font-medium text-primary-content shadow-sm transition hover:bg-primary/90">
            Create Exported View
          </button>
        </div>
      </div>

      <div class="space-y-4">
        <div class="flex items-center justify-between gap-3">
          <h4 class="text-sm font-semibold uppercase tracking-[0.18em] text-base-content/60">Managed Exports</h4>
          <span class="text-xs text-base-content/60">{@exported_views |> length()} total</span>
        </div>

        <div :if={@exported_views == []} class="rounded-xl border border-dashed border-base-300 bg-base-200/50 px-4 py-6 text-sm text-base-content/70">
          No exported views yet.
        </div>

        <div :for={view <- @exported_views} class="rounded-xl border border-base-300 bg-base-100 p-4 shadow-sm">
          <div class="flex flex-col gap-4 xl:flex-row xl:items-start xl:justify-between">
            <div class="space-y-3">
              <div class="flex flex-wrap items-center gap-2">
                <h5 class="text-base font-semibold text-base-content">{ExportedViews.field(view, :name, "Untitled export")}</h5>
                <span class={status_badge_class(ExportedViews.cache_status(view))}>{status_label(ExportedViews.cache_status(view))}</span>
                <span class="rounded-full bg-base-200 px-2.5 py-1 text-xs font-medium text-base-content/70">{String.capitalize(to_string(ExportedViews.field(view, :view_type, "detail")))}</span>
              </div>

              <div class="grid gap-2 text-sm text-base-content/70 md:grid-cols-2 xl:grid-cols-3">
                <div>Execution: {format_execution_time(ExportedViews.field(view, :last_execution_time_ms))}</div>
                <div>Rows: {format_integer(ExportedViews.field(view, :last_row_count))}</div>
                <div>Payload: {format_bytes(ExportedViews.field(view, :last_payload_bytes))}</div>
                <div>Generated: {format_datetime(ExportedViews.field(view, :cache_generated_at))}</div>
                <div>Expires: {format_datetime(ExportedViews.field(view, :cache_expires_at))}</div>
                <div>Accesses: {format_integer(ExportedViews.field(view, :access_count, 0))}</div>
              </div>

              <div class="space-y-1 text-xs text-base-content/60">
                <div>Public ID: <span class="font-mono">{ExportedViews.field(view, :public_id, "-")}</span></div>
                <div>Signature version: {ExportedViews.field(view, :signature_version, 1)}</div>
                <div>IP allowlist: {present_allowlist(ExportedViews.field(view, :ip_allowlist_text))}</div>
                <div :if={ExportedViews.field(view, :last_error)} class="text-error">Last error: {ExportedViews.field(view, :last_error)}</div>
              </div>
            </div>

            <div class="flex flex-wrap gap-2 xl:max-w-[340px] xl:justify-end">
              <button type="button" phx-click="regen_exported_view" phx-value-id={ExportedViews.field(view, :public_id)} phx-target={@myself} class="rounded-lg border border-base-300 bg-base-100 px-3 py-2 text-sm font-medium text-base-content transition hover:bg-base-200">Regen</button>
              <button type="button" phx-click="toggle_exported_view_disabled" phx-value-id={ExportedViews.field(view, :public_id)} phx-target={@myself} class="rounded-lg border border-base-300 bg-base-100 px-3 py-2 text-sm font-medium text-base-content transition hover:bg-base-200">{if ExportedViews.disabled?(view), do: "Enable", else: "Disable"}</button>
              <button type="button" phx-click="rotate_exported_view_signature" phx-value-id={ExportedViews.field(view, :public_id)} phx-target={@myself} class="rounded-lg border border-base-300 bg-base-100 px-3 py-2 text-sm font-medium text-base-content transition hover:bg-base-200">Rotate token</button>
              <button type="button" phx-click="show_exported_view_snippets" phx-value-id={ExportedViews.field(view, :public_id)} phx-target={@myself} class="rounded-lg border border-base-300 bg-base-100 px-3 py-2 text-sm font-medium text-base-content transition hover:bg-base-200">Use</button>
              <button type="button" phx-click="delete_exported_view" phx-value-id={ExportedViews.field(view, :public_id)} phx-target={@myself} data-confirm="Delete this exported view?" class="rounded-lg border border-error/30 bg-error/10 px-3 py-2 text-sm font-medium text-error transition hover:bg-error/20">Delete</button>
            </div>
          </div>
        </div>
      </div>

      <div :if={@snippets} class="space-y-4 rounded-xl border border-base-300 bg-base-200/40 p-4">
        <div class="flex items-center justify-between gap-3">
          <div>
            <h4 class="text-sm font-semibold text-base-content">Use This Export</h4>
            <p class="text-xs text-base-content/60">Signed iframe snippets for HTML, JS, Vue, and React.</p>
          </div>
          <button type="button" phx-click="clear_exported_view_snippets" phx-target={@myself} class="rounded-lg border border-base-300 bg-base-100 px-3 py-2 text-xs font-medium text-base-content transition hover:bg-base-200">Close</button>
        </div>

        <div class="space-y-3">
          <div>
            <label class="mb-1 block text-xs font-semibold uppercase tracking-[0.18em] text-base-content/60">Embed URL</label>
            <textarea rows="2" readonly class="w-full rounded-lg border border-base-300 bg-base-100 px-3 py-2 font-mono text-xs text-base-content shadow-sm"><%= @snippets.embed_url %></textarea>
          </div>
          <div>
            <label class="mb-1 block text-xs font-semibold uppercase tracking-[0.18em] text-base-content/60">HTML</label>
            <textarea rows="6" readonly class="w-full rounded-lg border border-base-300 bg-base-100 px-3 py-2 font-mono text-xs text-base-content shadow-sm"><%= @snippets.html %></textarea>
          </div>
          <div>
            <label class="mb-1 block text-xs font-semibold uppercase tracking-[0.18em] text-base-content/60">JavaScript</label>
            <textarea rows="8" readonly class="w-full rounded-lg border border-base-300 bg-base-100 px-3 py-2 font-mono text-xs text-base-content shadow-sm"><%= @snippets.javascript %></textarea>
          </div>
          <div class="grid gap-3 xl:grid-cols-2">
            <div>
              <label class="mb-1 block text-xs font-semibold uppercase tracking-[0.18em] text-base-content/60">Vue</label>
              <textarea rows="10" readonly class="w-full rounded-lg border border-base-300 bg-base-100 px-3 py-2 font-mono text-xs text-base-content shadow-sm"><%= @snippets.vue %></textarea>
            </div>
            <div>
              <label class="mb-1 block text-xs font-semibold uppercase tracking-[0.18em] text-base-content/60">React</label>
              <textarea rows="10" readonly class="w-full rounded-lg border border-base-300 bg-base-100 px-3 py-2 font-mono text-xs text-base-content shadow-sm"><%= @snippets.react %></textarea>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("update_exported_view_form", %{"exported_view" => params}, socket) do
    {:noreply, assign(socket, :form, merge_form(socket.assigns.form, params))}
  end

  def handle_event("update_exported_view_form", %{"field" => field, "value" => value}, socket) do
    {:noreply, assign(socket, :form, merge_form(socket.assigns.form, %{field => value}))}
  end

  def handle_event("create_exported_view", %{"exported_view" => params}, socket) do
    case Service.create(adapter(socket), socket.assigns, params, service_opts(socket)) do
      {:ok, _view} ->
        {:noreply,
         socket
         |> put_flash(:info, "Exported view created")
         |> assign(:form, default_form())
         |> reload_exported_views()}

      {:error, reason} ->
        {:noreply,
         put_flash(socket, :error, "Failed to create exported view: #{inspect(reason)}")}
    end
  end

  def handle_event("create_exported_view", params, socket) when is_map(params) do
    normalized_params = normalize_create_params(params, socket.assigns.form)

    handle_event("create_exported_view", %{"exported_view" => normalized_params}, socket)
  end

  def handle_event("regen_exported_view", %{"id" => public_id}, socket) do
    with {:ok, view} <- fetch_view(socket, public_id),
         {:ok, _updated_view} <- Service.regenerate(adapter(socket), view, service_opts(socket)) do
      {:noreply, socket |> put_flash(:info, "Export regenerated") |> reload_exported_views()}
    else
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Regen failed: #{inspect(reason)}")}
    end
  end

  def handle_event("rotate_exported_view_signature", %{"id" => public_id}, socket) do
    with {:ok, view} <- fetch_view(socket, public_id),
         {:ok, _updated_view} <-
           Service.rotate_signature(adapter(socket), view, service_opts(socket)) do
      {:noreply, socket |> put_flash(:info, "Signature rotated") |> reload_exported_views()}
    else
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Rotation failed: #{inspect(reason)}")}
    end
  end

  def handle_event("toggle_exported_view_disabled", %{"id" => public_id}, socket) do
    with {:ok, view} <- fetch_view(socket, public_id),
         {:ok, _updated_view} <-
           adapter(socket).update_exported_view(
             view,
             %{
               disabled_at:
                 if(ExportedViews.disabled?(view),
                   do: nil,
                   else: DateTime.utc_now() |> DateTime.truncate(:second)
                 )
             },
             adapter_opts(socket)
           ) do
      {:noreply, socket |> put_flash(:info, "Export updated") |> reload_exported_views()}
    else
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Update failed: #{inspect(reason)}")}
    end
  end

  def handle_event("delete_exported_view", %{"id" => public_id}, socket) do
    with {:ok, view} <- fetch_view(socket, public_id),
         {:ok, _deleted_view} <- Service.delete(adapter(socket), view, service_opts(socket)) do
      {:noreply,
       socket
       |> put_flash(:info, "Export deleted")
       |> assign(:snippets, nil)
       |> assign(:snippets_view_id, nil)
       |> reload_exported_views()}
    else
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Delete failed: #{inspect(reason)}")}
    end
  end

  def handle_event("show_exported_view_snippets", %{"id" => public_id}, socket) do
    with {:ok, view} <- fetch_view(socket, public_id),
         {:ok, snippets} <- build_snippets(view, socket) do
      {:noreply, assign(socket, snippets: snippets, snippets_view_id: public_id)}
    else
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, snippet_error_message(reason))}
    end
  end

  def handle_event("clear_exported_view_snippets", _params, socket) do
    {:noreply, assign(socket, snippets: nil, snippets_view_id: nil)}
  end

  defp maybe_load_exported_views(socket) do
    context = Map.get(socket.assigns, :exported_view_context)

    if context != socket.assigns.loaded_context do
      reload_exported_views(socket)
    else
      socket
    end
  end

  defp reload_exported_views(socket) do
    views =
      Service.list(
        adapter(socket),
        Map.get(socket.assigns, :exported_view_context),
        service_opts(socket)
      )
      |> Enum.sort_by(
        fn view ->
          updated_at =
            view
            |> ExportedViews.field(:updated_at, DateTime.utc_now())
            |> ExportedViews.normalize_datetime()
            |> DateTime.to_unix(:microsecond)

          {updated_at, ExportedViews.field(view, :name, "")}
        end,
        :desc
      )

    assign(socket,
      exported_views: views,
      loaded_context: Map.get(socket.assigns, :exported_view_context)
    )
  rescue
    _ ->
      assign(socket,
        exported_views: [],
        loaded_context: Map.get(socket.assigns, :exported_view_context)
      )
  end

  defp build_snippets(view, socket) do
    case Map.get(socket.assigns, :exported_view_endpoint) do
      nil ->
        {:error, :missing_endpoint}

      endpoint ->
        {:ok,
         Snippets.build(view,
           endpoint: endpoint,
           base_url:
             Map.get(socket.assigns, :exported_view_base_url, ExportedViews.default_embed_path())
         )}
    end
  end

  defp fetch_view(socket, public_id) do
    case Enum.find(socket.assigns.exported_views, fn view ->
           ExportedViews.field(view, :public_id) == public_id
         end) do
      nil -> {:error, :not_found}
      view -> {:ok, view}
    end
  end

  defp adapter(socket), do: Map.fetch!(socket.assigns, :exported_view_module)

  defp adapter_opts(socket) do
    [user_id: Map.get(socket.assigns, :current_user_id)]
  end

  defp service_opts(socket) do
    [adapter_opts: adapter_opts(socket)]
  end

  defp merge_form(form, params) do
    %{
      name: Map.get(params, "name", form.name),
      cache_ttl_hours:
        ExportedViews.normalize_ttl_hours(
          Map.get(params, "cache_ttl_hours", form.cache_ttl_hours)
        ),
      ip_allowlist_text: Map.get(params, "ip_allowlist_text", form.ip_allowlist_text)
    }
  end

  defp default_form do
    %{name: "", cache_ttl_hours: 3, ip_allowlist_text: ""}
  end

  defp normalize_create_params(params, form) do
    params = Enum.into(params, %{}, fn {key, value} -> {to_string(key), value} end)

    %{
      "name" => present_param(Map.get(params, "name"), form.name),
      "cache_ttl_hours" =>
        present_param(Map.get(params, "cache_ttl_hours"), to_string(form.cache_ttl_hours)),
      "ip_allowlist_text" =>
        present_param(Map.get(params, "ip_allowlist_text"), form.ip_allowlist_text)
    }
  end

  defp present_param(value, fallback) when value in [nil, ""], do: fallback
  defp present_param(value, _fallback), do: value

  defp status_badge_class(:fresh),
    do: "rounded-full bg-emerald-100 px-2.5 py-1 text-xs font-medium text-emerald-700"

  defp status_badge_class(:stale),
    do: "rounded-full bg-amber-100 px-2.5 py-1 text-xs font-medium text-amber-700"

  defp status_badge_class(:missing),
    do: "rounded-full bg-sky-100 px-2.5 py-1 text-xs font-medium text-sky-700"

  defp status_badge_class(:error),
    do: "rounded-full bg-rose-100 px-2.5 py-1 text-xs font-medium text-rose-700"

  defp status_badge_class(:disabled),
    do: "rounded-full bg-base-200 px-2.5 py-1 text-xs font-medium text-base-content/70"

  defp status_label(status), do: status |> Atom.to_string() |> String.capitalize()

  defp format_execution_time(nil), do: "-"

  defp format_execution_time(value) when is_float(value),
    do: :erlang.float_to_binary(value, decimals: 1) <> " ms"

  defp format_execution_time(value), do: to_string(value) <> " ms"

  defp format_integer(nil), do: "-"
  defp format_integer(value) when is_integer(value), do: Integer.to_string(value)
  defp format_integer(value), do: to_string(value)

  defp format_bytes(nil), do: "-"

  defp format_bytes(value) when is_integer(value) and value < 1024 do
    Integer.to_string(value) <> " B"
  end

  defp format_bytes(value) when is_integer(value) and value < 1_048_576 do
    :erlang.float_to_binary(value / 1024, decimals: 1) <> " KB"
  end

  defp format_bytes(value) when is_integer(value) do
    :erlang.float_to_binary(value / 1_048_576, decimals: 1) <> " MB"
  end

  defp format_datetime(nil), do: "-"

  defp format_datetime(value) do
    value
    |> ExportedViews.normalize_datetime()
    |> Calendar.strftime("%Y-%m-%d %H:%M UTC")
  rescue
    _ -> "-"
  end

  defp present_allowlist(nil), do: "Any IP"
  defp present_allowlist(text), do: String.replace(text, "\n", ", ")

  defp snippet_error_message(:missing_endpoint) do
    "Snippet generation requires `exported_view_endpoint` to be assigned by the host LiveView"
  end

  defp snippet_error_message(reason), do: "Failed to build snippets: #{inspect(reason)}"
end
