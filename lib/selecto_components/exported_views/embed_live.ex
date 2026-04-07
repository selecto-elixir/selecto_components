defmodule SelectoComponents.ExportedViews.EmbedLive do
  @moduledoc """
  Wrapper functions for serving an exported iframe view from a host app LiveView.

  Usage:

      defmodule MyAppWeb.ExportedViewLive do
        use MyAppWeb, :live_view

        def mount(params, session, socket) do
          SelectoComponents.ExportedViews.EmbedLive.mount(
            params,
            session,
            socket,
            adapter: MyApp.ExportedViews,
            endpoint: MyAppWeb.Endpoint
          )
        end

        def handle_info(msg, socket) do
          SelectoComponents.ExportedViews.EmbedLive.handle_info(msg, socket)
        end

        def handle_event(event, params, socket) do
          SelectoComponents.ExportedViews.EmbedLive.handle_event(event, params, socket)
        end

        def render(assigns) do
          SelectoComponents.ExportedViews.EmbedLive.render(assigns)
        end
      end
  """

  use Phoenix.Component

  alias SelectoComponents.ErrorHandling.ErrorBuilder
  alias SelectoComponents.ExportedViews
  alias SelectoComponents.ExportedViews.Renderer
  alias SelectoComponents.ExportedViews.Service

  def mount(%{"public_id" => public_id} = params, _session, socket, opts) do
    adapter = Keyword.fetch!(opts, :adapter)
    endpoint = Keyword.fetch!(opts, :endpoint)
    signature = Map.get(params, "sig")
    request_ip = Service.request_ip(socket)

    socket =
      socket
      |> assign(:page_title, Keyword.get(opts, :page_title, "Exported View"))
      |> assign(:export_adapter, adapter)
      |> assign(:export_endpoint, endpoint)
      |> assign(:export_public_id, public_id)
      |> assign(:export_signature, signature)
      |> assign(:export_request_ip, request_ip)
      |> assign(:sort_by, nil)

    case Service.resolve_for_embed(adapter, public_id, signature, request_ip, endpoint: endpoint) do
      {:ok, view, render_payload, status} ->
        {:ok, assign_embed(socket, view, render_payload, status)}

      {:error, reason} ->
        {:ok, assign_error(socket, reason)}
    end
  end

  def handle_info({:update_detail_page, page}, socket) do
    {:noreply, rerender_with(socket, detail_page: page)}
  end

  def handle_info({:rerun_query_with_sort, sort_by}, socket) do
    {:noreply, rerender_with(socket, sort_by: sort_by)}
  end

  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  def handle_event(_event, _params, socket) do
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[linear-gradient(180deg,#f7f7f2_0%,#ffffff_100%)] px-3 py-3 sm:px-6 sm:py-6">
      <div :if={@embed_error} class="mx-auto max-w-4xl rounded-2xl border border-rose-200 bg-white p-8 shadow-sm">
        <div class="inline-flex rounded-full bg-rose-50 px-3 py-1 text-xs font-semibold uppercase tracking-[0.18em] text-rose-700">
          Export unavailable
        </div>
        <h1 class="mt-4 text-2xl font-semibold text-slate-900">{@embed_error.summary}</h1>
        <p class="mt-2 text-sm text-slate-600">{@embed_error.user_message}</p>
        <p :if={@embed_error.suggestion} class="mt-2 text-sm font-medium text-slate-700">
          Next step: {@embed_error.suggestion}
        </p>
      </div>

      <div :if={!@embed_error} class="mx-auto max-w-[1600px] rounded-3xl border border-slate-200/80 bg-white p-3 shadow-[0_24px_80px_rgba(15,23,42,0.08)] sm:p-5">
        <div class="mb-4 flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-slate-200 bg-slate-50 px-4 py-3">
          <div>
            <div class="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">Selecto Exported View</div>
            <div class="mt-1 text-sm text-slate-700">{ExportedViews.field(@exported_view || %{}, :name, @page_title)}</div>
          </div>
          <div class="flex items-center gap-2 text-xs text-slate-500">
            <span class="rounded-full bg-white px-2.5 py-1 font-medium text-slate-600">{String.capitalize(to_string(@embed_status || :fresh))}</span>
            <span>Cached until {format_datetime(ExportedViews.field(@exported_view || %{}, :cache_expires_at))}</span>
          </div>
        </div>

        <.live_component
          module={SelectoComponents.Results}
          id="exported-view-results"
          selecto={@render_payload.selecto}
          views={@render_payload.views}
          query_results={@render_payload.query_results}
          view_meta={@render_payload.view_meta}
          applied_view={@render_payload.applied_view}
          executed={@render_payload.executed}
          execution_error={@render_payload.execution_error}
          last_query_info={@render_payload.last_query_info}
          params={@render_payload.params}
          used_params={@render_payload.used_params}
          enable_modal_detail={false}
          component_errors={[]}
        />
      </div>
    </div>
    """
  end

  defp rerender_with(socket, opts) do
    snapshot = socket.assigns.snapshot
    params = transient_params(snapshot.params, opts)
    sort_by = Keyword.get(opts, :sort_by, socket.assigns[:sort_by])

    case Renderer.render_snapshot(%{snapshot | params: params}, sort_by: sort_by) do
      {:ok, render_payload, _stats} ->
        socket
        |> assign(:render_payload, render_payload)
        |> assign(:sort_by, sort_by)
        |> assign(:snapshot, %{snapshot | params: params})

      {:error, _reason} ->
        socket
    end
  end

  defp transient_params(params, opts) do
    params = Map.new(params)

    case Keyword.fetch(opts, :detail_page) do
      {:ok, page} -> Map.put(params, "detail_page", to_string(page))
      :error -> params
    end
  end

  defp assign_embed(socket, view, render_payload, status) do
    snapshot =
      case ExportedViews.decode_snapshot(view) do
        {:ok, snapshot} -> snapshot
        _ -> %{params: render_payload.used_params}
      end

    socket
    |> assign(:embed_error, nil)
    |> assign(:embed_status, status)
    |> assign(:exported_view, view)
    |> assign(:render_payload, render_payload)
    |> assign(:snapshot, snapshot)
    |> assign(:page_title, ExportedViews.field(view, :name, socket.assigns.page_title))
  end

  defp assign_error(socket, reason) do
    error =
      ErrorBuilder.build(inspect(reason),
        stage: :persistence,
        category: embed_error_category(reason),
        code: embed_error_code(reason),
        user_message: embed_error_message(reason),
        summary: embed_error_title(reason)
      )

    socket
    |> assign(:embed_error, error)
    |> assign(:embed_status, nil)
    |> assign(:exported_view, nil)
    |> assign(:render_payload, nil)
    |> assign(:snapshot, nil)
  end

  defp embed_error_title(:not_found), do: "Export not found"
  defp embed_error_title(:invalid_signature), do: "Signature rejected"
  defp embed_error_title(:forbidden), do: "Access blocked"
  defp embed_error_title(:disabled), do: "Export disabled"
  defp embed_error_title(_), do: "Export failed"

  defp embed_error_category(reason) when reason in [:not_found, :disabled], do: :persistence

  defp embed_error_category(reason) when reason in [:invalid_signature, :forbidden],
    do: :authorization

  defp embed_error_category(_), do: :runtime

  defp embed_error_code(reason) when is_atom(reason), do: reason
  defp embed_error_code(_), do: :export_embed_failed

  defp embed_error_message(:not_found), do: "This exported view no longer exists."
  defp embed_error_message(:invalid_signature), do: "The signed request could not be verified."

  defp embed_error_message(:forbidden),
    do: "The current request IP is not allowed for this exported view."

  defp embed_error_message(:disabled),
    do: "This exported view has been disabled by an administrator."

  defp embed_error_message(reason),
    do: "The exported view could not be loaded: #{inspect(reason)}"

  defp format_datetime(nil), do: "-"

  defp format_datetime(value) do
    value
    |> ExportedViews.normalize_datetime()
    |> Calendar.strftime("%Y-%m-%d %H:%M UTC")
  rescue
    _ -> "-"
  end
end
