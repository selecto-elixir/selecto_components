defmodule SelectoComponents.Results do
  use Phoenix.LiveComponent
  alias SelectoComponents.Debug.DebugDisplay
  alias SelectoComponents.Debug.ProductionConfig
  alias SelectoComponents.SafeAtom
  alias SelectoComponents.Views.Runtime, as: ViewRuntime

  def render(assigns) do
    assigns =
      assigns
      |> Map.put_new(:component_module, nil)
      |> Map.put_new(:execution_error, nil)
      |> Map.put_new(:applied_view, nil)
      |> Map.put_new(:executed, false)
      |> Map.put_new(:query_results, nil)

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

    ~H"""
    <div>
      <div
        :if={Map.get(assigns, :execution_error) && !@applied_view}
        class="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded relative mb-4"
        role="alert"
      >
        <strong class="font-bold">View Error:</strong>
        <span class="block sm:inline ml-1">
          <%= case Map.get(assigns, :execution_error) do %>
            <% %{message: msg} -> %>
              {msg}
            <% error when is_binary(error) -> %>
              {error}
            <% error -> %>
              {inspect(error)}
          <% end %>
        </span>
        <%= if Mix.env() == :dev && is_map(@execution_error) && Map.has_key?(@execution_error, :details) && map_size(@execution_error.details) > 0 do %>
          <details class="mt-2">
            <summary class="cursor-pointer text-sm">Debug Details</summary>
            <pre class="text-xs mt-2 bg-red-100 p-2 rounded overflow-x-auto"><%= inspect(@execution_error.details, pretty: true) %></pre>
          </details>
        <% end %>
      </div>
      <div
        :if={@has_component_errors && !@applied_view}
        class="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded relative mb-4"
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
          id={"view_results_#{@applied_view}"}
          selecto={@selecto}
          query_results={@query_results}
          view_meta={@view_meta}
          view_opts={@view_opts}
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
      page_cache_memory_bytes: Map.get(query_data, :page_cache_memory_bytes),
      page_cache_pages: Map.get(query_data, :page_cache_pages),
      page_cache_rows: Map.get(query_data, :page_cache_rows),
      execution_plan: nil
    }
  end
end
