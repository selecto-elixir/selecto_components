defmodule SelectoComponents.Results do
  use Phoenix.LiveComponent
  alias SelectoComponents.Debug.DebugDisplay
  alias SelectoComponents.Debug.ProductionConfig

  def render(assigns) do
    assigns =
      case assigns.applied_view do
        nil ->
          assigns

        _ ->
          selected_view = String.to_atom(assigns.applied_view)

          {_, module, _, opt} =
            Enum.find(assigns.views, fn {id, _, _, _} -> id == selected_view end)

          assign(assigns, module: module, view_opts: opt)
      end
    
    # Check debug permissions using params and session from socket
    show_debug = should_show_debug?(assigns)
    assigns = assign(assigns, :show_debug, show_debug)

    ~H"""
      <div>
        <!-- Debug Display Panel (only shown if debug is enabled) -->
        <.live_component
          :if={@show_debug && @executed && @query_results}
          module={DebugDisplay}
          id="debug_display"
          domain_module={Map.get(assigns, :domain_module)}
          view_type={if @applied_view, do: String.to_atom(@applied_view), else: :detail}
          debug_data={build_debug_data(assigns)}
        />
        
        <div :if={@applied_view}>
            <.live_component
              module={String.to_existing_atom("#{@module}.Component")}
              id={"view_results_#{@applied_view}_#{Map.get(@view_meta, :exe_id, "default")}"}
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
    params = assigns[:params] || %{}
    session = assigns[:session] || %{}
    
    # Use ProductionConfig to check if debug should be shown
    ProductionConfig.debug_enabled?(params, session)
  end

  defp build_debug_data(assigns) do
    # Extract row count from query_results
    row_count = case assigns[:query_results] do
      {rows, _columns, _aliases} when is_list(rows) ->
        length(rows)
      nil ->
        0
      _ ->
        0
    end
    
    # Get SQL, params, and timing from last_query_info if available
    # This is passed from the parent LiveView which captured it during query execution
    {query_sql, params, timing} = if assigns[:last_query_info] && assigns.last_query_info != %{} do
      info = assigns.last_query_info
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
      execution_plan: nil
    }
  end
end
