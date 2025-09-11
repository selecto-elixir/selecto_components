defmodule SelectoComponents.Sharing.LinkPreview do
  @moduledoc """
  Preview component for shareable links showing the preserved view state.
  """

  use Phoenix.LiveComponent
  alias SelectoComponents.Sharing.LinkGenerator

  def render(assigns) do
    ~H"""
    <div class="link-preview-container">
      <div class="bg-white rounded-lg shadow-lg overflow-hidden">
        <div class="bg-gray-50 px-6 py-4 border-b">
          <h3 class="text-lg font-semibold">View Preview</h3>
          <p class="text-sm text-gray-600 mt-1">
            Preview of the shared view configuration
          </p>
        </div>
        
        <div class="p-6">
          <%= if @loading do %>
            <div class="flex items-center justify-center py-8">
              <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
            </div>
          <% else %>
            <%= if @error do %>
              <div class="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded">
                <%= @error %>
              </div>
            <% else %>
              <div class="space-y-4">
                <.preview_section title="Filters" items={@view_state["filters"]} />
                <.preview_section title="Sorting" items={@view_state["sorting"]} />
                <.preview_section title="Columns" items={@view_state["columns"]} />
                <.preview_section title="Grouping" items={@view_state["grouping"]} />
                <.preview_section title="Aggregates" items={@view_state["aggregates"]} />
                
                <div class="mt-6 pt-4 border-t">
                  <div class="flex items-center justify-between text-sm text-gray-600">
                    <span>Created: <%= format_date(@created_at) %></span>
                    <span>Expires: <%= format_date(@expires_at) %></span>
                  </div>
                </div>
              </div>
            <% end %>
          <% end %>
        </div>
        
        <div class="bg-gray-50 px-6 py-4 border-t">
          <div class="flex justify-between items-center">
            <div class="flex space-x-2">
              <button
                type="button"
                phx-click="apply_view"
                phx-target={@myself}
                class="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 transition-colors"
                disabled={@error != nil}
              >
                Apply This View
              </button>
              
              <button
                type="button"
                phx-click="copy_link"
                phx-target={@myself}
                class="px-4 py-2 bg-gray-600 text-white rounded hover:bg-gray-700 transition-colors"
              >
                Copy Link
              </button>
            </div>
            
            <button
              type="button"
              phx-click="close_preview"
              phx-target={@myself}
              class="px-4 py-2 border border-gray-300 rounded hover:bg-gray-100 transition-colors"
            >
              Close
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def preview_section(assigns) do
    ~H"""
    <div class="preview-section">
      <h4 class="font-medium text-sm text-gray-700 mb-2"><%= @title %></h4>
      <%= if @items && @items != [] do %>
        <div class="bg-gray-50 rounded p-3">
          <%= case @items do %>
            <% items when is_list(items) -> %>
              <ul class="space-y-1">
                <%= for item <- items do %>
                  <li class="text-sm text-gray-600">
                    <%= format_item(item) %>
                  </li>
                <% end %>
              </ul>
            <% items when is_map(items) -> %>
              <dl class="space-y-1">
                <%= for {key, value} <- items do %>
                  <div class="flex text-sm">
                    <dt class="font-medium text-gray-700 mr-2"><%= humanize(key) %>:</dt>
                    <dd class="text-gray-600"><%= format_value(value) %></dd>
                  </div>
                <% end %>
              </dl>
            <% item -> %>
              <p class="text-sm text-gray-600"><%= format_item(item) %></p>
          <% end %>
        </div>
      <% else %>
        <p class="text-sm text-gray-500 italic">None configured</p>
      <% end %>
    </div>
    """
  end

  def mount(socket) do
    {:ok, assign(socket,
      loading: true,
      error: nil,
      view_state: %{},
      created_at: nil,
      expires_at: nil
    )}
  end

  def update(%{link: link} = assigns, socket) do
    socket = 
      socket
      |> assign(assigns)
      |> load_preview(link)
    
    {:ok, socket}
  end

  def handle_event("apply_view", _params, socket) do
    send(self(), {:apply_shared_view, socket.assigns.view_state})
    {:noreply, socket}
  end

  def handle_event("copy_link", _params, socket) do
    {:noreply, push_event(socket, "copy_to_clipboard", %{text: socket.assigns.link})}
  end

  def handle_event("close_preview", _params, socket) do
    send(self(), :close_preview)
    {:noreply, socket}
  end

  # Private functions

  defp load_preview(socket, link) do
    case LinkGenerator.parse_link(link) do
      {:ok, view_state} ->
        socket
        |> assign(loading: false, error: nil, view_state: view_state)
        |> load_link_metadata(link)
      
      {:error, reason} ->
        assign(socket, loading: false, error: format_error(reason), view_state: %{})
    end
  end

  defp load_link_metadata(socket, link) do
    # Extract short code if it's a shortened URL
    short_code = extract_short_code(link)
    
    if short_code do
      case SelectoTest.UrlShortener.get_analytics(short_code) do
        {:ok, analytics} ->
          assign(socket,
            created_at: analytics.created_at,
            expires_at: analytics.expires_at
          )
        
        _ ->
          socket
      end
    else
      socket
    end
  end

  defp extract_short_code(link) do
    case Regex.run(~r{/s/([^/]+)$}, link) do
      [_, code] -> code
      _ -> nil
    end
  end

  defp format_error(:not_found), do: "This link has expired or does not exist."
  defp format_error(:invalid_link), do: "The link format is invalid."
  defp format_error(:invalid_state), do: "The view configuration is corrupted."
  defp format_error(:missing_state), do: "No view configuration found in this link."
  defp format_error(_), do: "An error occurred loading the preview."

  defp format_item(item) when is_map(item) do
    item
    |> Enum.map(fn {k, v} -> "#{humanize(k)}: #{format_value(v)}" end)
    |> Enum.join(", ")
  end
  defp format_item(item), do: to_string(item)

  defp format_value(value) when is_list(value), do: Enum.join(value, ", ")
  defp format_value(value) when is_map(value), do: Jason.encode!(value)
  defp format_value(value), do: to_string(value)

  defp humanize(atom) when is_atom(atom), do: humanize(Atom.to_string(atom))
  defp humanize(string) when is_binary(string) do
    string
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp format_date(nil), do: "Never"
  defp format_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%b %d, %Y at %I:%M %p")
  defp format_date(_), do: "Unknown"
end