defmodule SelectoComponents.Modal.DetailModal do
  @moduledoc """
  Modal component for displaying detailed record information with related data.
  """
  
  use Phoenix.LiveComponent
  import SelectoComponents.Modal.ModalWrapper
  alias Phoenix.LiveView.JS
  
  @impl true
  def mount(socket) do
    {:ok, assign(socket,
      record: nil,
      loading: false,
      current_tab: "details",
      navigation_enabled: true,
      edit_mode: false
    )}
  end
  
  @impl true
  def update(assigns, socket) do
    socket = 
      socket
      |> assign(assigns)
      |> load_record_data()
    
    {:ok, socket}
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal
        id={@id}
        title={@title || "Record Details"}
        subtitle={build_subtitle(assigns)}
        size={@size || :lg}
        show_header={true}
        on_cancel={JS.push("close_modal", target: @myself)}
      >
        <:icon :if={@icon}>
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
              d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
          </svg>
        </:icon>
        
        <div class="space-y-4">
          <%!-- Navigation controls --%>
          <div :if={@navigation_enabled} class="flex justify-between items-center pb-2 border-b">
            <div class="flex space-x-2">
              <button
                type="button"
                class="px-3 py-1 text-sm bg-gray-100 hover:bg-gray-200 rounded-md disabled:opacity-50 disabled:cursor-not-allowed"
                phx-click="navigate_record"
                phx-value-direction="prev"
                phx-target={@myself}
                disabled={!has_prev_record?(assigns)}
              >
                ← Previous
              </button>
              <button
                type="button"
                class="px-3 py-1 text-sm bg-gray-100 hover:bg-gray-200 rounded-md disabled:opacity-50 disabled:cursor-not-allowed"
                phx-click="navigate_record"
                phx-value-direction="next"
                phx-target={@myself}
                disabled={!has_next_record?(assigns)}
              >
                Next →
              </button>
            </div>
            
            <div class="text-sm text-gray-500">
              Record <%= @current_index + 1 %> of <%= @total_records %>
            </div>
            
            <button
              :if={@edit_enabled}
              type="button"
              class="px-3 py-1 text-sm bg-blue-600 text-white hover:bg-blue-700 rounded-md"
              phx-click="toggle_edit_mode"
              phx-target={@myself}
            >
              <%= if @edit_mode, do: "Cancel", else: "Edit" %>
            </button>
          </div>
          
          <%!-- Tab navigation --%>
          <div :if={has_related_data?(assigns)} class="border-b">
            <nav class="-mb-px flex space-x-8">
              <button
                type="button"
                class={tab_class(@current_tab == "details")}
                phx-click="change_tab"
                phx-value-tab="details"
                phx-target={@myself}
              >
                Details
              </button>
              <%= for {key, config} <- @related_data do %>
                <button
                  type="button"
                  class={tab_class(@current_tab == to_string(key))}
                  phx-click="change_tab"
                  phx-value-tab={key}
                  phx-target={@myself}
                >
                  <%= config[:title] || humanize(key) %>
                  <span :if={config[:count]} class="ml-2 px-2 py-0.5 text-xs bg-gray-200 rounded-full">
                    <%= config[:count] %>
                  </span>
                </button>
              <% end %>
            </nav>
          </div>
          
          <%!-- Content area --%>
          <div class="mt-4">
            <%= if @loading do %>
              <div class="flex justify-center items-center py-8">
                <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
              </div>
            <% else %>
              <%= render_tab_content(assigns) %>
            <% end %>
          </div>
        </div>
        
        <:footer>
          <div class="flex justify-between w-full">
            <div class="flex space-x-2">
              <%= if @edit_mode do %>
                <button
                  type="button"
                  class="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700"
                  phx-click="save_changes"
                  phx-target={@myself}
                >
                  Save Changes
                </button>
                <button
                  type="button"
                  class="px-4 py-2 bg-gray-300 text-gray-700 rounded-md hover:bg-gray-400"
                  phx-click="toggle_edit_mode"
                  phx-target={@myself}
                >
                  Cancel
                </button>
              <% end %>
            </div>
            
            <button
              type="button"
              class="px-4 py-2 bg-gray-300 text-gray-700 rounded-md hover:bg-gray-400"
              phx-click={JS.push("close_modal", target: @myself)}
            >
              Close
            </button>
          </div>
        </:footer>
      </.modal>
    </div>
    """
  end
  
  # Render the content for the current tab
  defp render_tab_content(%{current_tab: "details"} = assigns) do
    ~H"""
    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <%= for {field, value} <- format_record_fields(@record, @fields) do %>
        <div>
          <dt class="text-sm font-medium text-gray-500"><%= humanize(field) %></dt>
          <dd class="mt-1 text-sm text-gray-900">
            <%= if @edit_mode do %>
              <input
                type="text"
                value={value}
                class="w-full px-2 py-1 border border-gray-300 rounded-md"
                phx-change="update_field"
                phx-value-field={field}
                phx-target={@myself}
              />
            <% else %>
              <%= format_value(value) %>
            <% end %>
          </dd>
        </div>
      <% end %>
    </div>
    """
  end
  
  defp render_tab_content(%{current_tab: tab} = assigns) when tab != "details" do
    assigns = assign(assigns, :related_records, get_related_records(assigns, tab))
    
    ~H"""
    <div class="overflow-x-auto">
      <%= if @related_records == [] do %>
        <p class="text-gray-500 italic">No related records found</p>
      <% else %>
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <%= for field <- get_related_fields(@related_records) do %>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  <%= humanize(field) %>
                </th>
              <% end %>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <%= for record <- @related_records do %>
              <tr class="hover:bg-gray-50">
                <%= for field <- get_related_fields(@related_records) do %>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    <%= format_value(Map.get(record, field)) %>
                  </td>
                <% end %>
              </tr>
            <% end %>
          </tbody>
        </table>
      <% end %>
    </div>
    """
  end
  
  # Event handlers
  
  @impl true
  def handle_event("close_modal", _params, socket) do
    send(self(), {:close_detail_modal, socket.assigns.id})
    {:noreply, socket}
  end
  
  def handle_event("navigate_record", %{"direction" => direction}, socket) do
    new_index = case direction do
      "prev" -> max(0, socket.assigns.current_index - 1)
      "next" -> min(socket.assigns.total_records - 1, socket.assigns.current_index + 1)
    end
    
    socket = 
      socket
      |> assign(current_index: new_index)
      |> load_record_at_index(new_index)
    
    {:noreply, socket}
  end
  
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, current_tab: tab)}
  end
  
  def handle_event("toggle_edit_mode", _params, socket) do
    {:noreply, update(socket, :edit_mode, &(!&1))}
  end
  
  def handle_event("update_field", %{"field" => field, "value" => value}, socket) do
    updated_record = Map.put(socket.assigns.record, String.to_atom(field), value)
    {:noreply, assign(socket, record: updated_record)}
  end
  
  def handle_event("save_changes", _params, socket) do
    # Send save event to parent
    send(self(), {:save_record_changes, socket.assigns.record})
    {:noreply, assign(socket, edit_mode: false)}
  end
  
  # Helper functions
  
  defp load_record_data(socket) do
    if socket.assigns[:record_id] && !socket.assigns[:record] do
      assign(socket, loading: true)
      # Trigger async load
      send(self(), {:load_record_details, socket.assigns.record_id})
      socket
    else
      socket
    end
  end
  
  defp load_record_at_index(socket, index) do
    if socket.assigns[:records] do
      record = Enum.at(socket.assigns.records, index)
      assign(socket, record: record, loading: false)
    else
      socket
    end
  end
  
  defp build_subtitle(assigns) do
    if assigns[:subtitle_field] && assigns[:record] do
      Map.get(assigns.record, assigns.subtitle_field)
    else
      nil
    end
  end
  
  defp has_prev_record?(assigns) do
    assigns[:current_index] && assigns.current_index > 0
  end
  
  defp has_next_record?(assigns) do
    assigns[:current_index] && assigns[:total_records] && 
    assigns.current_index < assigns.total_records - 1
  end
  
  defp has_related_data?(assigns) do
    assigns[:related_data] && map_size(assigns.related_data) > 0
  end
  
  defp get_related_records(assigns, tab) do
    if assigns[:related_data] && assigns[:related_data][String.to_atom(tab)] do
      assigns.related_data[String.to_atom(tab)][:records] || []
    else
      []
    end
  end
  
  defp get_related_fields(records) when is_list(records) and length(records) > 0 do
    records
    |> List.first()
    |> Map.keys()
    |> Enum.reject(&(&1 in [:__meta__, :__struct__]))
  end
  defp get_related_fields(_), do: []
  
  defp format_record_fields(nil, _fields), do: []
  defp format_record_fields(record, fields) when is_list(fields) do
    Enum.map(fields, fn field ->
      {field, Map.get(record, String.to_atom(field), "")}
    end)
  end
  defp format_record_fields(record, _fields) do
    record
    |> Map.from_struct()
    |> Map.drop([:__meta__, :__struct__])
    |> Enum.to_list()
  end
  
  defp format_value(nil), do: "-"
  defp format_value(value) when is_binary(value), do: value
  defp format_value(value) when is_number(value), do: to_string(value)
  defp format_value(value) when is_boolean(value), do: to_string(value)
  defp format_value(%{__struct__: Date} = date), do: Date.to_string(date)
  defp format_value(%{__struct__: DateTime} = datetime), do: Calendar.strftime(datetime, "%Y-%m-%d %H:%M")
  defp format_value(value), do: inspect(value)
  
  defp humanize(atom) when is_atom(atom), do: humanize(Atom.to_string(atom))
  defp humanize(string) when is_binary(string) do
    string
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
  
  defp tab_class(active) do
    base = "py-2 px-1 border-b-2 font-medium text-sm"
    if active do
      "#{base} border-blue-500 text-blue-600"
    else
      "#{base} border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
    end
  end
end