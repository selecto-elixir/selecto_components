defmodule SelectoComponents.Results do
  use Phoenix.LiveComponent

  alias SelectoComponents.Debug.DebugDisplay
  alias SelectoComponents.Debug.ProductionConfig
  alias SelectoComponents.ErrorHandling.ErrorBuilder
  alias SelectoComponents.SafeAtom
  alias SelectoComponents.Theme
  alias SelectoComponents.Views.Runtime, as: ViewRuntime

  def render(assigns) do
    assigns =
      assigns
      |> Map.put_new(:component_module, nil)
      |> Map.put_new(:execution_error, nil)
      |> Map.put_new(:applied_view, nil)
      |> Map.put_new(:executed, false)
      |> Map.put_new(:query_results, nil)
      |> Map.put(:theme, Theme.resolve_theme(assigns))
      |> Map.put_new(:theme_stylesheet, Theme.stylesheet())

    if Mix.env() == :dev do
      IO.puts(
        "[theme-debug][Results] theme_id=#{inspect(assigns[:theme_id])} selecto_theme=#{inspect(assigns[:selecto_theme])} resolved=#{assigns.theme.id} applied_view=#{inspect(assigns[:applied_view])}"
      )
    end

    assigns =
      case assigns.applied_view do
        nil ->
          assigns

        _ ->
          selected_view = SafeAtom.to_view_mode(assigns.applied_view)

          view_tuple =
            Enum.find(assigns.views, fn {id, _, _, _} -> id == selected_view end)

          case view_tuple do
            {_id, _module, _name, opt} ->
              assigns
              |> Map.put(:component_module, ViewRuntime.result_component(view_tuple))
              |> Map.put(:view_opts, opt)

            nil ->
              assigns
          end
      end

    # Check debug permissions using params and session from socket
    show_debug = should_show_debug?(assigns)
    assigns = Map.put(assigns, :show_debug, show_debug)
    has_component_errors = match?([_ | _], Map.get(assigns, :component_errors, []))
    assigns = Map.put(assigns, :has_component_errors, has_component_errors)
    assigns = Map.put(assigns, :normalized_execution_error, normalize_execution_error(assigns))

    ~H"""
    <div id={"selecto-results-#{@id}-#{@theme.id}"} data-selecto-theme={@theme.id} style={Theme.style_attr(@theme)} class={Theme.slot(@theme, :root)}>
      <style><%= Phoenix.HTML.raw(@theme_stylesheet) %></style>
      <div
        :if={@normalized_execution_error && !@applied_view}
        class="mb-4 rounded-lg border px-4 py-3"
        style="background: var(--sc-danger-soft); border-color: color-mix(in srgb, var(--sc-danger) 35%, var(--sc-surface-border)); color: var(--sc-danger);"
        role="alert"
      >
        <strong class="font-bold">{@normalized_execution_error.summary}:</strong>
        <span class="block sm:inline ml-1">{@normalized_execution_error.user_message}</span>
        <div :if={@normalized_execution_error.detail} class="text-sm mt-1">
          {@normalized_execution_error.detail}
        </div>
        <div :if={@normalized_execution_error.suggestion} class="text-sm mt-1 font-medium">
          Next step: {@normalized_execution_error.suggestion}
        </div>
        <%= if Mix.env() == :dev && is_map(@normalized_execution_error.debug) && map_size(@normalized_execution_error.debug) > 0 do %>
          <details class="mt-2">
            <summary class="cursor-pointer text-sm">Debug Details</summary>
            <pre class="mt-2 overflow-x-auto rounded p-2 text-xs" style="background: color-mix(in srgb, var(--sc-danger-soft) 65%, var(--sc-surface-bg)); color: var(--sc-text-primary);"><%= inspect(@normalized_execution_error.debug, pretty: true) %></pre>
          </details>
        <% end %>
      </div>
      <div
        :if={@has_component_errors && !@applied_view}
        class="mb-4 rounded-lg border px-4 py-3"
        style="background: var(--sc-danger-soft); border-color: color-mix(in srgb, var(--sc-danger) 35%, var(--sc-surface-border)); color: var(--sc-danger);"
        role="alert"
      >
        <strong class="font-bold">View Error:</strong>
        <span class="block sm:inline ml-1">
          Saved view could not be applied. Open the View Controller and resubmit after adjusting fields.
        </span>
      </div>
      <!-- Debug Display Panel (only shown if debug is enabled) -->
      <.live_component
        :if={@show_debug && @executed && @query_results}
        module={DebugDisplay}
        id="debug_display"
        domain_module={Map.get(assigns, :domain_module)}
        view_type={if @applied_view, do: SafeAtom.to_view_mode(@applied_view), else: :detail}
        debug_data={build_debug_data(assigns)}
      />

      <div :if={@applied_view && @component_module}>
        <.live_component
          module={@component_module}
          id={"view_results_#{@applied_view}_#{@theme.id}"}
          theme={@theme}
          selecto={@selecto}
          query_results={@query_results}
          view_meta={@view_meta}
          view_opts={@view_opts}
          enable_modal_detail={Map.get(assigns, :enable_modal_detail, false)}
          executed={@executed}
          execution_error={assigns[:execution_error]}
        />
      </div>
    </div>
    """
  end

  defp should_show_debug?(assigns) do
    # Try to get params and session from the socket if it exists
    # Since this is a LiveComponent, we might not have direct access to socket
    # The parent LiveView should pass these through assigns if needed
    params = assigns[:params] || assigns[:used_params] || %{}
    session = assigns[:session] || %{}

    # Use ProductionConfig to check if debug should be shown
    ProductionConfig.debug_enabled?(params, session)
  end

  defp normalize_execution_error(assigns) do
    case Map.get(assigns, :execution_error) do
      nil -> nil
      error -> ErrorBuilder.normalize(error)
    end
  end

  defp build_debug_data(assigns) do
    query_data = assigns[:last_query_info] || %{}

    # Extract row count from query_results
    row_count =
      case assigns[:query_results] do
        {rows, _columns, _aliases} when is_list(rows) ->
          length(rows)

        nil ->
          0

        _ ->
          0
      end

    cache_metrics = build_cache_metrics(query_data, assigns, row_count)

    # Get SQL, params, and timing from last_query_info if available
    # This is passed from the parent LiveView which captured it during query execution
    {query_sql, params, timing} =
      if query_data != %{} do
        info = query_data

        {
          Map.get(info, :sql),
          Map.get(info, :params, []),
          Map.get(info, :timing)
        }
      else
        # Fallback to view_meta for timing if last_query_info is not available
        timing = get_in(assigns, [:view_meta, :execution_time])
        {nil, [], timing}
      end

    %{
      query: query_sql,
      params: params,
      timing: timing,
      row_count: row_count,
      page_cache_memory_bytes: cache_metrics.bytes,
      page_cache_pages: cache_metrics.pages,
      page_cache_rows: cache_metrics.rows,
      execution_plan: nil
    }
  end

  defp build_cache_metrics(query_data, assigns, row_count) do
    query_cache_bytes = Map.get(query_data, :page_cache_memory_bytes)

    if is_integer(query_cache_bytes) do
      %{
        bytes: query_cache_bytes,
        pages: Map.get(query_data, :page_cache_pages),
        rows: Map.get(query_data, :page_cache_rows)
      }
    else
      aggregate_cache_metrics(assigns, row_count)
    end
  end

  defp aggregate_cache_metrics(assigns, row_count) do
    if aggregate_view?(assigns) and is_integer(row_count) and row_count > 0 do
      %{
        bytes: term_size_bytes(assigns[:query_results]),
        pages: 1,
        rows: row_count
      }
    else
      %{bytes: nil, pages: nil, rows: nil}
    end
  end

  defp aggregate_view?(assigns) do
    case Map.get(assigns, :applied_view) do
      :aggregate -> true
      "aggregate" -> true
      view_mode when is_atom(view_mode) -> Atom.to_string(view_mode) == "aggregate"
      _ -> false
    end
  end

  defp term_size_bytes(nil), do: nil

  defp term_size_bytes(term) do
    :erts_debug.size(term) * :erlang.system_info(:wordsize)
  rescue
    _ -> nil
  end
end
