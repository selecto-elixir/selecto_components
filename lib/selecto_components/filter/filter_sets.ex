defmodule SelectoComponents.Filter.FilterSets do
  @moduledoc """
  Manages saved filter sets for quick application of common filter combinations.
  Provides save, load, edit, delete, and share functionality for filter configurations.
  """
  
  use Phoenix.LiveComponent
  
  def render(assigns) do
    ~H"""
    <div class="filter-sets-manager" id={"filter-sets-#{@id}"}>
      <!-- Quick Access Dropdown -->
      <div class="filter-sets-dropdown">
        <div class="flex items-center gap-2 mb-3">
          <select
            id={"filter-set-select-#{@id}"}
            phx-change="load_filter_set"
            phx-target={@myself}
            class="flex-1 text-sm border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500"
          >
            <option value="">Choose a filter set...</option>
            <optgroup label="Personal">
              <%= for set <- @personal_sets do %>
                <option value={set.id} selected={@current_set_id == set.id}>
                  <%= set.name %>
                  <%= if set.is_default do %>
                    (Default)
                  <% end %>
                </option>
              <% end %>
            </optgroup>
            <%= if length(@shared_sets) > 0 do %>
              <optgroup label="Shared">
                <%= for set <- @shared_sets do %>
                  <option value={set.id} selected={@current_set_id == set.id}>
                    <%= set.name %> (by <%= set.owner_name %>)
                  </option>
                <% end %>
              </optgroup>
            <% end %>
            <%= if length(@system_sets) > 0 do %>
              <optgroup label="System">
                <%= for set <- @system_sets do %>
                  <option value={set.id} selected={@current_set_id == set.id}>
                    <%= set.name %>
                  </option>
                <% end %>
              </optgroup>
            <% end %>
          </select>
          
          <!-- Action Buttons -->
          <button
            type="button"
            phx-click="toggle_save_dialog"
            phx-target={@myself}
            title="Save current filters"
            class="p-2 text-gray-600 hover:text-blue-600 hover:bg-blue-50 rounded transition-colors"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3 3m0 0l-3-3m3 3V2" />
            </svg>
          </button>
          
          <%= if @current_set_id && can_edit?(@current_set, @user_id) do %>
            <button
              type="button"
              phx-click="toggle_edit_dialog"
              phx-target={@myself}
              title="Edit filter set"
              class="p-2 text-gray-600 hover:text-green-600 hover:bg-green-50 rounded transition-colors"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
              </svg>
            </button>
          <% end %>
          
          <button
            type="button"
            phx-click="toggle_manage_dialog"
            phx-target={@myself}
            title="Manage filter sets"
            class="p-2 text-gray-600 hover:text-gray-800 hover:bg-gray-100 rounded transition-colors"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
            </svg>
          </button>
        </div>
        
        <!-- Current Set Info -->
        <%= if @current_set do %>
          <div class="current-set-info bg-blue-50 p-2 rounded text-xs">
            <div class="flex items-center justify-between">
              <span class="font-medium text-blue-900">
                <%= @current_set.name %>
              </span>
              <div class="flex items-center gap-2">
                <%= if @current_set.is_shared do %>
                  <span class="text-blue-600" title="Shared">
                    <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                      <path d="M15 8a3 3 0 10-2.977-2.63l-4.94 2.47a3 3 0 100 4.319l4.94 2.47a3 3 0 10.895-1.789l-4.94-2.47a3.027 3.027 0 000-.74l4.94-2.47C13.456 7.68 14.19 8 15 8z" />
                    </svg>
                  </span>
                <% end %>
                <button
                  type="button"
                  phx-click="share_filter_set"
                  phx-target={@myself}
                  phx-value-id={@current_set.id}
                  title="Share this filter set"
                  class="text-blue-600 hover:text-blue-800"
                >
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m9.032 4.026a3 3 0 10-5.432 0M5.432 17.026a3 3 0 100-5.432m0 5.432a3 3 0 100-5.432" />
                  </svg>
                </button>
              </div>
            </div>
            <%= if @current_set.description do %>
              <p class="text-blue-700 mt-1"><%= @current_set.description %></p>
            <% end %>
          </div>
        <% end %>
      </div>
      
      <!-- Save Dialog -->
      <%= if @show_save_dialog do %>
        <div class="fixed inset-0 bg-gray-500 bg-opacity-75 flex items-center justify-center z-50">
          <div class="bg-white rounded-lg p-6 max-w-md w-full">
            <h3 class="text-lg font-medium text-gray-900 mb-4">Save Filter Set</h3>
            
            <form phx-submit="save_filter_set" phx-target={@myself}>
              <div class="space-y-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">
                    Name
                  </label>
                  <input
                    type="text"
                    name="name"
                    value={@save_form.name}
                    required
                    class="w-full border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500"
                    placeholder="My Custom Filters"
                  />
                </div>
                
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">
                    Description (optional)
                  </label>
                  <textarea
                    name="description"
                    rows="2"
                    class="w-full border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500"
                    placeholder="Filters for Q4 analysis..."
                  ><%= @save_form.description %></textarea>
                </div>
                
                <div class="flex items-center gap-4">
                  <label class="flex items-center">
                    <input
                      type="checkbox"
                      name="is_default"
                      checked={@save_form.is_default}
                      class="mr-2 rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                    />
                    <span class="text-sm text-gray-700">Set as default</span>
                  </label>
                  
                  <label class="flex items-center">
                    <input
                      type="checkbox"
                      name="is_shared"
                      checked={@save_form.is_shared}
                      class="mr-2 rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                    />
                    <span class="text-sm text-gray-700">Share with team</span>
                  </label>
                </div>
              </div>
              
              <div class="mt-6 flex gap-3">
                <button
                  type="submit"
                  class="flex-1 px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500"
                >
                  Save Filter Set
                </button>
                <button
                  type="button"
                  phx-click="toggle_save_dialog"
                  phx-target={@myself}
                  class="px-4 py-2 bg-gray-200 text-gray-700 rounded-md hover:bg-gray-300 focus:outline-none focus:ring-2 focus:ring-gray-500"
                >
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      <% end %>
      
      <!-- Manage Dialog -->
      <%= if @show_manage_dialog do %>
        <div class="fixed inset-0 bg-gray-500 bg-opacity-75 flex items-center justify-center z-50">
          <div class="bg-white rounded-lg p-6 max-w-2xl w-full max-h-[80vh] overflow-y-auto">
            <h3 class="text-lg font-medium text-gray-900 mb-4">Manage Filter Sets</h3>
            
            <div class="space-y-6">
              <!-- Personal Filter Sets -->
              <div>
                <h4 class="text-sm font-medium text-gray-700 mb-2">Personal Filter Sets</h4>
                <div class="space-y-2">
                  <%= for set <- @personal_sets do %>
                    <div class="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                      <div class="flex-1">
                        <div class="flex items-center gap-2">
                          <span class="font-medium text-gray-900"><%= set.name %></span>
                          <%= if set.is_default do %>
                            <span class="text-xs bg-blue-100 text-blue-800 px-2 py-0.5 rounded">Default</span>
                          <% end %>
                          <%= if set.is_shared do %>
                            <span class="text-xs bg-green-100 text-green-800 px-2 py-0.5 rounded">Shared</span>
                          <% end %>
                        </div>
                        <%= if set.description do %>
                          <p class="text-xs text-gray-600 mt-1"><%= set.description %></p>
                        <% end %>
                        <p class="text-xs text-gray-500 mt-1">
                          Created <%= format_relative_time(set.inserted_at) %>
                          • Used <%= set.usage_count %> times
                        </p>
                      </div>
                      
                      <div class="flex items-center gap-2 ml-4">
                        <button
                          type="button"
                          phx-click="set_default"
                          phx-target={@myself}
                          phx-value-id={set.id}
                          title="Set as default"
                          class="p-1.5 text-gray-600 hover:text-blue-600 hover:bg-blue-50 rounded"
                        >
                          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                          </svg>
                        </button>
                        
                        <button
                          type="button"
                          phx-click="duplicate_set"
                          phx-target={@myself}
                          phx-value-id={set.id}
                          title="Duplicate"
                          class="p-1.5 text-gray-600 hover:text-green-600 hover:bg-green-50 rounded"
                        >
                          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
                          </svg>
                        </button>
                        
                        <button
                          type="button"
                          phx-click="export_set"
                          phx-target={@myself}
                          phx-value-id={set.id}
                          title="Export"
                          class="p-1.5 text-gray-600 hover:text-indigo-600 hover:bg-indigo-50 rounded"
                        >
                          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                          </svg>
                        </button>
                        
                        <button
                          type="button"
                          phx-click="delete_set"
                          phx-target={@myself}
                          phx-value-id={set.id}
                          data-confirm="Are you sure you want to delete this filter set?"
                          title="Delete"
                          class="p-1.5 text-gray-600 hover:text-red-600 hover:bg-red-50 rounded"
                        >
                          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                          </svg>
                        </button>
                      </div>
                    </div>
                  <% end %>
                  
                  <%= if length(@personal_sets) == 0 do %>
                    <p class="text-sm text-gray-500 italic">No personal filter sets saved yet.</p>
                  <% end %>
                </div>
              </div>
              
              <!-- Import Section -->
              <div>
                <h4 class="text-sm font-medium text-gray-700 mb-2">Import Filter Set</h4>
                <div class="flex gap-2">
                  <input
                    type="text"
                    id={"import-input-#{@id}"}
                    placeholder="Paste filter set JSON or URL..."
                    class="flex-1 text-sm border-gray-300 rounded-md"
                  />
                  <button
                    type="button"
                    phx-click="import_set"
                    phx-target={@myself}
                    class="px-4 py-2 bg-gray-600 text-white text-sm rounded-md hover:bg-gray-700"
                  >
                    Import
                  </button>
                </div>
              </div>
            </div>
            
            <div class="mt-6 flex justify-end">
              <button
                type="button"
                phx-click="toggle_manage_dialog"
                phx-target={@myself}
                class="px-4 py-2 bg-gray-200 text-gray-700 rounded-md hover:bg-gray-300 focus:outline-none focus:ring-2 focus:ring-gray-500"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      <% end %>
      
      <!-- Share Dialog -->
      <%= if @show_share_dialog do %>
        <div class="fixed inset-0 bg-gray-500 bg-opacity-75 flex items-center justify-center z-50">
          <div class="bg-white rounded-lg p-6 max-w-md w-full">
            <h3 class="text-lg font-medium text-gray-900 mb-4">Share Filter Set</h3>
            
            <div class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  Shareable URL
                </label>
                <div class="flex gap-2">
                  <input
                    type="text"
                    id={"share-url-#{@id}"}
                    value={@share_url}
                    readonly
                    class="flex-1 text-sm border-gray-300 rounded-md bg-gray-50"
                  />
                  <button
                    type="button"
                    id={"copy-btn-#{@id}"}
                    phx-click="copy_share_url"
                    phx-target={@myself}
                    phx-hook="CopyToClipboard"
                    data-target={"share-url-#{@id}"}
                    class="px-3 py-2 bg-blue-600 text-white text-sm rounded-md hover:bg-blue-700"
                  >
                    Copy
                  </button>
                </div>
              </div>
              
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  Export as JSON
                </label>
                <textarea
                  rows="4"
                  readonly
                  class="w-full text-xs font-mono border-gray-300 rounded-md bg-gray-50"
                ><%= @share_json %></textarea>
              </div>
            </div>
            
            <div class="mt-6 flex justify-end">
              <button
                type="button"
                phx-click="close_share_dialog"
                phx-target={@myself}
                class="px-4 py-2 bg-gray-200 text-gray-700 rounded-md hover:bg-gray-300"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
  
  def mount(socket) do
    {:ok,
     socket
     |> assign(
       id: Ecto.UUID.generate(),
       current_filters: %{},
       current_set_id: nil,
       current_set: nil,
       personal_sets: [],
       shared_sets: [],
       system_sets: [],
       show_save_dialog: false,
       show_manage_dialog: false,
       show_share_dialog: false,
       share_url: "",
       share_json: "",
       save_form: %{
         name: "",
         description: "",
         is_default: false,
         is_shared: false
       },
       user_id: nil,
       domain: nil
     )}
  end
  
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> load_filter_sets()}
  end
  
  def handle_event("load_filter_set", %{"value" => ""}, socket) do
    {:noreply, socket}
  end
  
  def handle_event("load_filter_set", %{"value" => set_id}, socket) do
    case get_filter_set(set_id, socket.assigns) do
      {:ok, filter_set} ->
        send(self(), {:apply_filter_set, filter_set})
        
        {:noreply,
         socket
         |> assign(
           current_set_id: filter_set.id,
           current_set: filter_set
         )}
      
      {:error, _} ->
        {:noreply, socket}
    end
  end
  
  def handle_event("toggle_save_dialog", _params, socket) do
    {:noreply,
     socket
     |> assign(show_save_dialog: !socket.assigns.show_save_dialog)
     |> reset_save_form()}
  end
  
  def handle_event("toggle_manage_dialog", _params, socket) do
    {:noreply, assign(socket, show_manage_dialog: !socket.assigns.show_manage_dialog)}
  end
  
  def handle_event("save_filter_set", params, socket) do
    case save_filter_set(params, socket.assigns) do
      {:ok, filter_set} ->
        {:noreply,
         socket
         |> assign(
           show_save_dialog: false,
           current_set_id: filter_set.id,
           current_set: filter_set
         )
         |> load_filter_sets()
         |> send_flash(:info, "Filter set saved successfully")}
      
      {:error, _changeset} ->
        {:noreply, send_flash(socket, :error, "Failed to save filter set")}
    end
  end
  
  def handle_event("delete_set", %{"id" => id}, socket) do
    case delete_filter_set(id, socket.assigns) do
      {:ok, _} ->
        {:noreply,
         socket
         |> load_filter_sets()
         |> clear_current_if_deleted(id)
         |> send_flash(:info, "Filter set deleted")}
      
      {:error, _} ->
        {:noreply, send_flash(socket, :error, "Failed to delete filter set")}
    end
  end
  
  def handle_event("set_default", %{"id" => id}, socket) do
    case set_default_filter_set(id, socket.assigns) do
      {:ok, _} ->
        {:noreply,
         socket
         |> load_filter_sets()
         |> send_flash(:info, "Default filter set updated")}
      
      {:error, _} ->
        {:noreply, send_flash(socket, :error, "Failed to set default")}
    end
  end
  
  def handle_event("duplicate_set", %{"id" => id}, socket) do
    case duplicate_filter_set(id, socket.assigns) do
      {:ok, new_set} ->
        {:noreply,
         socket
         |> load_filter_sets()
         |> assign(
           current_set_id: new_set.id,
           current_set: new_set
         )
         |> send_flash(:info, "Filter set duplicated")}
      
      {:error, _} ->
        {:noreply, send_flash(socket, :error, "Failed to duplicate filter set")}
    end
  end
  
  def handle_event("share_filter_set", %{"id" => id}, socket) do
    case generate_share_data(id, socket.assigns) do
      {:ok, url, json} ->
        {:noreply,
         socket
         |> assign(
           show_share_dialog: true,
           share_url: url,
           share_json: json
         )}
      
      {:error, _} ->
        {:noreply, send_flash(socket, :error, "Failed to generate share data")}
    end
  end
  
  def handle_event("close_share_dialog", _params, socket) do
    {:noreply, assign(socket, show_share_dialog: false)}
  end
  
  def handle_event("import_set", _params, socket) do
    # Implementation would handle JSON import
    {:noreply, send_flash(socket, :info, "Import functionality coming soon")}
  end
  
  def handle_event("export_set", %{"id" => id}, socket) do
    case export_filter_set(id, socket.assigns) do
      {:ok, json} ->
        send(self(), {:download_json, "filter_set_#{id}.json", json})
        {:noreply, send_flash(socket, :info, "Filter set exported")}
      
      {:error, _} ->
        {:noreply, send_flash(socket, :error, "Failed to export filter set")}
    end
  end
  
  # Helper functions
  
  defp load_filter_sets(socket) do
    %{user_id: user_id, domain: domain} = socket.assigns
    
    personal_sets = list_personal_filter_sets(user_id, domain)
    shared_sets = list_shared_filter_sets(user_id, domain)
    system_sets = list_system_filter_sets(domain)
    
    assign(socket,
      personal_sets: personal_sets,
      shared_sets: shared_sets,
      system_sets: system_sets
    )
  end
  
  defp reset_save_form(socket) do
    assign(socket, save_form: %{
      name: "",
      description: "",
      is_default: false,
      is_shared: false
    })
  end
  
  defp clear_current_if_deleted(socket, deleted_id) do
    if socket.assigns.current_set_id == deleted_id do
      assign(socket, current_set_id: nil, current_set: nil)
    else
      socket
    end
  end
  
  defp can_edit?(nil, _user_id), do: false
  defp can_edit?(%{owner_id: owner_id}, user_id), do: owner_id == user_id
  
  defp format_relative_time(datetime) do
    # Simple relative time formatting
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)
    
    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)} minutes ago"
      diff < 86400 -> "#{div(diff, 3600)} hours ago"
      diff < 604800 -> "#{div(diff, 86400)} days ago"
      true -> Calendar.strftime(datetime, "%b %d, %Y")
    end
  end
  
  # These would typically interact with a database context
  defp list_personal_filter_sets(_user_id, _domain), do: []
  defp list_shared_filter_sets(_user_id, _domain), do: []
  defp list_system_filter_sets(_domain), do: []
  defp get_filter_set(_id, _assigns), do: {:error, :not_found}
  defp save_filter_set(_params, _assigns), do: {:error, :not_implemented}
  defp delete_filter_set(_id, _assigns), do: {:error, :not_implemented}
  defp set_default_filter_set(_id, _assigns), do: {:error, :not_implemented}
  defp duplicate_filter_set(_id, _assigns), do: {:error, :not_implemented}
  defp generate_share_data(_id, _assigns), do: {:error, :not_implemented}
  defp export_filter_set(_id, _assigns), do: {:error, :not_implemented}
  defp increment_usage(_id), do: :ok
  
  defp send_flash(socket, type, message) do
    send(self(), {:put_flash, type, message})
    socket
  end
  
  @doc """
  JavaScript hook for copy to clipboard functionality.
  """
  def __hooks__() do
    %{
      "CopyToClipboard" => """
      export default {
        mounted() {
          this.el.addEventListener('click', e => {
            const targetId = this.el.dataset.target;
            const target = document.getElementById(targetId);
            if (target) {
              navigator.clipboard.writeText(target.value).then(() => {
                // Show temporary success state
                const originalText = this.el.innerText;
                this.el.innerText = 'Copied!';
                this.el.classList.add('bg-green-600');
                setTimeout(() => {
                  this.el.innerText = originalText;
                  this.el.classList.remove('bg-green-600');
                }, 2000);
              });
            }
          });
        }
      }
      """
    }
  end
end