defmodule SelectoComponents.Debug.DebugDisplay do
  @moduledoc """
  LiveComponent for displaying debug information based on domain configuration.
  """

  use Phoenix.LiveComponent
  alias SelectoComponents.Debug.ConfigReader

  def render(assigns) do
    ~H"""
    <div :if={@show_debug} class="selecto-debug-panel">
      <div class="bg-gray-100 border border-gray-300 rounded-md p-3 mt-2 text-xs">
        <div class="flex items-center justify-between mb-2">
          <h4 class="font-semibold text-gray-700">Debug Information</h4>
          <button 
            type="button"
            phx-click="toggle_debug_details" 
            phx-target={@myself}
            class="text-gray-500 hover:text-gray-700"
          >
            <%= if @expanded do %>
              <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
              </svg>
            <% else %>
              <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
              </svg>
            <% end %>
          </button>
        </div>
        
        <div :if={@expanded} class="space-y-2">
          <.debug_section 
            :if={@debug_info[:query]} 
            title="SQL Query" 
            content={@debug_info.query}
            type="code"
          />
          
          <.debug_section 
            :if={@debug_info[:params]} 
            title="Parameters" 
            content={@debug_info.params}
            type="list"
          />
          
          <.debug_section 
            :if={@debug_info[:timing]} 
            title="Execution Time" 
            content={format_timing(@debug_info.timing)}
            type="text"
          />
          
          <.debug_section 
            :if={@debug_info[:row_count]} 
            title="Row Count" 
            content={@debug_info.row_count}
            type="text"
          />
          
          <.debug_section 
            :if={@debug_info[:execution_plan]} 
            title="Execution Plan" 
            content={@debug_info.execution_plan}
            type="code"
          />
          
          <.debug_metadata metadata={@metadata} />
        </div>
        
        <div :if={!@expanded} class="text-gray-600">
          <%= summary_text(@debug_info) %>
        </div>
      </div>
    </div>
    """
  end

  def debug_section(assigns) do
    ~H"""
    <div class="border-t border-gray-200 pt-2">
      <h5 class="font-medium text-gray-600 mb-1"><%= @title %></h5>
      <%= case @type do %>
        <% "code" -> %>
          <pre class="bg-white p-2 rounded border border-gray-200 overflow-x-auto">
            <code class="text-xs"><%= @content %></code>
          </pre>
        <% "list" -> %>
          <ul class="bg-white p-2 rounded border border-gray-200">
            <%= for {item, index} <- Enum.with_index(@content) do %>
              <li class="text-xs">
                <span class="text-gray-500">[<%= index %>]</span> 
                <%= inspect(item, pretty: true, limit: 50) %>
              </li>
            <% end %>
          </ul>
        <% _ -> %>
          <div class="bg-white p-2 rounded border border-gray-200 text-xs">
            <%= @content %>
          </div>
      <% end %>
    </div>
    """
  end

  def debug_metadata(assigns) do
    ~H"""
    <div :if={@metadata && map_size(@metadata) > 0} class="border-t border-gray-200 pt-2">
      <h5 class="font-medium text-gray-600 mb-1">Metadata</h5>
      <dl class="grid grid-cols-2 gap-x-4 gap-y-1 text-xs">
        <%= for {key, value} <- @metadata do %>
          <dt class="text-gray-500"><%= humanize_key(key) %>:</dt>
          <dd class="text-gray-700"><%= format_metadata_value(value) %></dd>
        <% end %>
      </dl>
    </div>
    """
  end

  def mount(socket) do
    {:ok, assign(socket, expanded: false, show_debug: false, debug_info: %{}, metadata: %{})}
  end

  def update(assigns, socket) do
    domain_module = Map.get(assigns, :domain_module)
    view_type = Map.get(assigns, :view_type)
    
    config = ConfigReader.get_view_config(domain_module, view_type)
    show_debug = ConfigReader.debug_enabled?(domain_module, view_type)
    
    debug_info = if show_debug && assigns[:debug_data] do
      ConfigReader.build_debug_info(assigns.debug_data, config)
    else
      %{}
    end
    
    metadata = extract_metadata(assigns)
    
    {:ok,
     socket
     |> assign(assigns)
     |> assign(
       show_debug: show_debug,
       debug_info: debug_info,
       metadata: metadata,
       config: config
     )}
  end

  def handle_event("toggle_debug_details", _, socket) do
    {:noreply, assign(socket, expanded: !socket.assigns.expanded)}
  end

  # Helper functions

  defp format_timing(timing) when is_number(timing) do
    cond do
      timing < 1 -> "< 1ms"
      timing < 1000 -> "#{round(timing)}ms"
      true -> "#{Float.round(timing / 1000, 2)}s"
    end
  end
  defp format_timing(timing), do: inspect(timing)

  defp summary_text(debug_info) do
    parts = []
    
    parts = if debug_info[:timing] do
      ["Executed in #{format_timing(debug_info.timing)}" | parts]
    else
      parts
    end
    
    parts = if debug_info[:row_count] do
      ["#{debug_info.row_count} rows" | parts]
    else
      parts
    end
    
    if Enum.empty?(parts) do
      "Click to expand debug information"
    else
      Enum.join(parts, " • ")
    end
  end

  defp extract_metadata(assigns) do
    %{}
    |> maybe_add_metadata(:domain, assigns[:domain_module])
    |> maybe_add_metadata(:view_type, assigns[:view_type])
    |> maybe_add_metadata(:filters_count, count_filters(assigns[:filters]))
    |> maybe_add_metadata(:aggregates_count, count_items(assigns[:aggregates]))
    |> maybe_add_metadata(:columns_count, count_items(assigns[:columns]))
  end

  defp maybe_add_metadata(metadata, _key, nil), do: metadata
  defp maybe_add_metadata(metadata, _key, ""), do: metadata
  defp maybe_add_metadata(metadata, key, value), do: Map.put(metadata, key, value)

  defp count_filters(nil), do: nil
  defp count_filters(filters) when is_list(filters), do: length(filters)
  defp count_filters(filters) when is_map(filters), do: map_size(filters)
  defp count_filters(_), do: nil

  defp count_items(nil), do: nil
  defp count_items(items) when is_list(items), do: length(items)
  defp count_items(items) when is_map(items), do: map_size(items)
  defp count_items(_), do: nil

  defp humanize_key(key) when is_atom(key) do
    key
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end
  defp humanize_key(key), do: to_string(key)

  defp format_metadata_value(value) when is_atom(value) do
    value
    |> Atom.to_string()
    |> String.replace("_", " ")
  end
  defp format_metadata_value(value) when is_number(value), do: to_string(value)
  defp format_metadata_value(value), do: inspect(value, limit: 20)
end