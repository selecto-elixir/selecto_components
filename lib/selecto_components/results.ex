defmodule SelectoComponents.Results do
  use Phoenix.LiveComponent
  alias SelectoComponents.Debug.DebugDisplay

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

    ~H"""
      <div>
        <!-- Debug Display Panel -->
        <.live_component
          :if={@executed && @query_results}
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
