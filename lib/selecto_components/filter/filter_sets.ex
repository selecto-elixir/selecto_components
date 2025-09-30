defmodule SelectoComponents.Filter.FilterSets do
  @moduledoc """
  LiveComponent for managing saved filter sets.
  Provides UI for saving, loading, and managing filter configurations.
  """
  
  use Phoenix.LiveComponent
  import Phoenix.Component
  
  def render(assigns) do
    ~H"""
    <div class="filter-sets-component">
      <!-- Main Controls -->
      <div class="flex items-center gap-2">
        <select
          id={"filter-set-select-#{@id}"}
          name={"filter-set-select-#{@id}"}
          phx-change="load_filter_set"
          phx-target={@myself}
          class="select select-bordered select-sm"
        >
          <option value="">-- Select Filter Set --</option>
          
          <%= if length(@personal_sets) > 0 do %>
            <optgroup label="Personal">
              <option :for={set <- @personal_sets} value={set.id} selected={@current_set_id == set.id}>
                <%= set.name %><%= if set.is_default, do: " (Default)" %>
              </option>
            </optgroup>
          <% end %>
          
          <%= if length(@shared_sets) > 0 do %>
            <optgroup label="Shared">
              <option :for={set <- @shared_sets} value={set.id} selected={@current_set_id == set.id}>
                <%= set.name %>
              </option>
            </optgroup>
          <% end %>
          
          <%= if length(@system_sets) > 0 do %>
            <optgroup label="System">
              <option :for={set <- @system_sets} value={set.id} selected={@current_set_id == set.id}>
                <%= set.name %>
              </option>
            </optgroup>
          <% end %>
        </select>
        
        <button
          phx-click="toggle_save_dialog"
          phx-target={@myself}
          class="btn btn-sm btn-primary"
          title="Save current filters"
        >
          Save
        </button>
        
        <button
          phx-click="toggle_manage_dialog"
          phx-target={@myself}
          class="btn btn-sm btn-secondary"
          title="Manage filter sets"
        >
          Manage
        </button>
      </div>
      
      <!-- Save Dialog -->
      <%= if @show_save_dialog do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center">
          <div class="bg-white rounded-lg p-6 max-w-md w-full">
            <h3 class="text-lg font-semibold mb-4">Save Filter Set</h3>

            <.form for={%{}} as={:filter_set_form} phx-change="update_filter_set_form" phx-target={@myself}>
              <div class="space-y-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">
                    Name <span class="text-red-500">*</span>
                  </label>
                  <input
                    type="text"
                    name="filter_set_form[name]"
                    value={@save_form.name}
                    class={"w-full rounded-md " <> if(@save_form.name == "" || is_nil(@save_form.name), do: "border-red-300 focus:border-red-500 focus:ring-red-500", else: "border-gray-300")}
                    placeholder="Enter filter set name (required)"
                    required
                  />
                <%= if @save_form.name == "" || is_nil(@save_form.name) do %>
                  <p class="mt-1 text-sm text-red-600">Name is required</p>
                <% end %>
              </div>
              
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">
                    Description
                  </label>
                  <textarea
                    name="filter_set_form[description]"
                    class="w-full border-gray-300 rounded-md"
                    rows="3"
                    placeholder="Optional description"
                  ><%= @save_form.description %></textarea>
                </div>
              
                <div class="flex items-center gap-4">
                  <label class="flex items-center gap-2">
                    <input
                      type="checkbox"
                      phx-click="toggle_default"
                      phx-target={@myself}
                      checked={@save_form.is_default}
                      class="rounded border-gray-300"
                    />
                    <span class="text-sm">Set as default</span>
                  </label>

                  <label class="flex items-center gap-2">
                    <input
                      type="checkbox"
                      phx-click="toggle_shared"
                      phx-target={@myself}
                      checked={@save_form.is_shared}
                      class="rounded border-gray-300"
                    />
                    <span class="text-sm">Share with others</span>
                  </label>
                </div>
              </div>
            </.form>
            
            <div class="mt-6 flex justify-end gap-2">
              <button
                type="button"
                phx-click="toggle_save_dialog"
                phx-target={@myself}
                class="px-4 py-2 bg-gray-200 text-gray-700 rounded-md hover:bg-gray-300"
              >
                Cancel
              </button>
              <button
                type="button"
                phx-click="do_save_filter_set"
                phx-target={@myself}
                disabled={@save_form.name == "" || is_nil(@save_form.name)}
                class={"px-4 py-2 rounded-md " <> if(@save_form.name == "" || is_nil(@save_form.name), do: "bg-gray-400 text-gray-200 cursor-not-allowed", else: "bg-blue-600 text-white hover:bg-blue-700")}
              >
                Save
              </button>
            </div>
          </div>
        </div>
      <% end %>
      
      <!-- Manage Dialog -->
      <%= if @show_manage_dialog do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center">
          <div class="bg-white rounded-lg p-6 max-w-2xl w-full max-h-[80vh] overflow-y-auto">
            <h3 class="text-lg font-semibold mb-4">Manage Filter Sets</h3>
            
            <%= if length(@personal_sets) > 0 do %>
              <div class="mb-6">
                <h4 class="font-medium mb-2">Personal Filter Sets</h4>
                <div class="space-y-2">
                  <div :for={set <- @personal_sets} class="flex items-center justify-between p-2 border rounded">
                    <div>
                      <span class="font-medium"><%= set.name %></span>
                      <%= if set.is_default do %>
                        <span class="ml-2 text-xs bg-yellow-100 text-yellow-800 px-2 py-1 rounded">Default</span>
                      <% end %>
                      <%= if set.description do %>
                        <p class="text-sm text-gray-600"><%= set.description %></p>
                      <% end %>
                    </div>
                    <div class="flex gap-1">
                      <%= unless set.is_default do %>
                        <button
                          phx-click="set_default"
                          phx-value-id={set.id}
                          phx-target={@myself}
                          class="text-sm px-2 py-1 bg-yellow-100 text-yellow-800 rounded hover:bg-yellow-200"
                          title="Set as default"
                        >
                          Default
                        </button>
                      <% end %>
                      <button
                        phx-click="duplicate_set"
                        phx-value-id={set.id}
                        phx-target={@myself}
                        class="text-sm px-2 py-1 bg-blue-100 text-blue-800 rounded hover:bg-blue-200"
                        title="Duplicate"
                      >
                        Copy
                      </button>
                      <button
                        phx-click="share_filter_set"
                        phx-value-id={set.id}
                        phx-target={@myself}
                        class="text-sm px-2 py-1 bg-green-100 text-green-800 rounded hover:bg-green-200"
                        title="Share"
                      >
                        Share
                      </button>
                      <button
                        phx-click="delete_set"
                        phx-value-id={set.id}
                        phx-target={@myself}
                        class="text-sm px-2 py-1 bg-red-100 text-red-800 rounded hover:bg-red-200"
                        onclick="return confirm('Are you sure you want to delete this filter set?')"
                        title="Delete"
                      >
                        Delete
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            <% end %>
            
            <%= if length(@shared_sets) > 0 do %>
              <div class="mb-6">
                <h4 class="font-medium mb-2">Shared Filter Sets</h4>
                <div class="space-y-2">
                  <div :for={set <- @shared_sets} class="flex items-center justify-between p-2 border rounded">
                    <div>
                      <span class="font-medium"><%= set.name %></span>
                      <%= if set.description do %>
                        <p class="text-sm text-gray-600"><%= set.description %></p>
                      <% end %>
                    </div>
                    <div class="flex gap-1">
                      <button
                        phx-click="duplicate_set"
                        phx-value-id={set.id}
                        phx-target={@myself}
                        class="text-sm px-2 py-1 bg-blue-100 text-blue-800 rounded hover:bg-blue-200"
                        title="Duplicate"
                      >
                        Copy
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            <% end %>
            
            <div class="mt-6 flex justify-between">
              <div class="flex gap-2">
                <button
                  phx-click="import_set"
                  phx-target={@myself}
                  class="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700"
                >
                  Import
                </button>
              </div>
              <button
                type="button"
                phx-click="toggle_manage_dialog"
                phx-target={@myself}
                class="px-4 py-2 bg-gray-200 text-gray-700 rounded-md hover:bg-gray-300"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      <% end %>
      
      <!-- Share Dialog -->
      <%= if @show_share_dialog do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center">
          <div class="bg-white rounded-lg p-6 max-w-md w-full">
            <h3 class="text-lg font-semibold mb-4">Share Filter Set</h3>
            
            <div class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  Share URL
                </label>
                <input
                  type="text"
                  value={@share_url}
                  readonly
                  class="w-full border-gray-300 rounded-md bg-gray-50"
                  onclick="this.select()"
                />
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
       }
     )}
  end
  
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> maybe_load_filter_sets()}
  end

  defp maybe_load_filter_sets(socket) do
    # Only load filter sets if not already loaded
    if Map.get(socket.assigns, :filter_sets_loaded, false) do
      socket
    else
      socket
      |> load_filter_sets()
      |> assign(filter_sets_loaded: true)
    end
  end
  
  def handle_event("load_filter_set", params, socket) do
    # Handle both "value" and direct parameter access
    set_id = params["value"] || params["filter-set-select-#{socket.assigns.id}"] || ""
    
    if set_id == "" or is_nil(set_id) do
      {:noreply, socket}
    else
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
          {:noreply, put_flash(socket, :error, "Failed to load filter set")}
      end
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
  
  def handle_event("update_filter_set_form", %{"filter_set_form" => form_params}, socket) do
    save_form = %{
      name: form_params["name"] || "",
      description: form_params["description"] || "",
      is_default: socket.assigns.save_form.is_default,
      is_shared: socket.assigns.save_form.is_shared
    }
    {:noreply, assign(socket, save_form: save_form)}
  end
  
  def handle_event("toggle_default", _params, socket) do
    save_form = Map.put(socket.assigns.save_form, :is_default, !socket.assigns.save_form.is_default)
    {:noreply, assign(socket, save_form: save_form)}
  end
  
  def handle_event("toggle_shared", _params, socket) do
    save_form = Map.put(socket.assigns.save_form, :is_shared, !socket.assigns.save_form.is_shared)
    {:noreply, assign(socket, save_form: save_form)}
  end
  
  def handle_event("do_save_filter_set", _params, socket) do
    params = %{
      "name" => socket.assigns.save_form.name,
      "description" => socket.assigns.save_form.description,
      "is_default" => to_string(socket.assigns.save_form.is_default),
      "is_shared" => to_string(socket.assigns.save_form.is_shared)
    }

    require Logger
    Logger.debug("Saving filter set with params: #{inspect(params)}")
    Logger.debug("Current filters: #{inspect(socket.assigns[:current_filters])}")

    # Validate that name is not empty
    if params["name"] == "" || is_nil(params["name"]) do
      {:noreply, put_flash(socket, :error, "Filter set name cannot be empty")}
    else
      case save_filter_set(params, socket.assigns) do
        {:ok, filter_set} ->
          {:noreply,
           socket
           |> assign(
             show_save_dialog: false,
             current_set_id: filter_set.id,
             current_set: filter_set
           )
           |> assign(filter_sets_loaded: false)
           |> maybe_load_filter_sets()
           |> reset_save_form()
           |> put_flash(:info, "Filter set saved successfully")}

        {:error, changeset} ->
          error_msg = case changeset do
            %Ecto.Changeset{errors: errors} ->
              errors
              |> Enum.map(fn {field, {msg, _}} -> "#{field}: #{msg}" end)
              |> Enum.join(", ")
            _ ->
              "Failed to save filter set"
          end
          {:noreply, put_flash(socket, :error, error_msg)}
      end
    end
  end
  
  def handle_event("delete_set", %{"id" => id}, socket) do
    case delete_filter_set(id, socket.assigns) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(filter_sets_loaded: false)
         |> maybe_load_filter_sets()
         |> clear_current_if_deleted(id)
         |> put_flash(:info, "Filter set deleted")}
      
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete filter set")}
    end
  end
  
  def handle_event("set_default", %{"id" => id}, socket) do
    case set_default_filter_set(id, socket.assigns) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(filter_sets_loaded: false)
         |> maybe_load_filter_sets()
         |> put_flash(:info, "Default filter set updated")}
      
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to set default")}
    end
  end
  
  def handle_event("duplicate_set", %{"id" => id}, socket) do
    case duplicate_filter_set(id, socket.assigns) do
      {:ok, new_set} ->
        {:noreply,
         socket
         |> assign(filter_sets_loaded: false)
         |> maybe_load_filter_sets()
         |> assign(
           current_set_id: new_set.id,
           current_set: new_set
         )
         |> put_flash(:info, "Filter set duplicated")}
      
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to duplicate filter set")}
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
        {:noreply, put_flash(socket, :error, "Failed to generate share data")}
    end
  end
  
  def handle_event("close_share_dialog", _params, socket) do
    {:noreply, assign(socket, show_share_dialog: false)}
  end
  
  def handle_event("import_set", _params, socket) do
    # Implementation would handle JSON import
    {:noreply, put_flash(socket, :info, "Import functionality coming soon")}
  end
  
  def handle_event("export_set", %{"id" => id}, socket) do
    case export_filter_set(id, socket.assigns) do
      {:ok, json} ->
        send(self(), {:download_json, "filter_set_#{id}.json", json})
        {:noreply, put_flash(socket, :info, "Filter set exported")}
      
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to export filter set")}
    end
  end
  
  # Helper functions
  
  defp load_filter_sets(socket) do
    %{user_id: user_id, domain: domain} = socket.assigns
    adapter = socket.assigns[:filter_sets_adapter]

    # Normalize domain by removing leading slash for consistent lookups
    normalized_domain = String.trim_leading(to_string(domain), "/")

    personal_sets = list_personal_filter_sets(user_id, normalized_domain, adapter)
    shared_sets = list_shared_filter_sets(user_id, normalized_domain, adapter)
    system_sets = list_system_filter_sets(normalized_domain, adapter)
    
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
  
  # Adapter delegation functions
  
  defp list_personal_filter_sets(user_id, domain, adapter) when not is_nil(adapter) do
    adapter.list_personal_filter_sets(user_id, domain)
  end
  defp list_personal_filter_sets(_, _, _), do: []
  
  defp list_shared_filter_sets(user_id, domain, adapter) when not is_nil(adapter) do
    adapter.list_shared_filter_sets(user_id, domain)
  end
  defp list_shared_filter_sets(_, _, _), do: []
  
  defp list_system_filter_sets(domain, adapter) when not is_nil(adapter) do
    adapter.list_system_filter_sets(domain)
  end
  defp list_system_filter_sets(_, _), do: []
  
  defp get_filter_set(id, assigns) do
    adapter = assigns[:filter_sets_adapter]
    user_id = assigns[:user_id]
    
    if adapter do
      adapter.get_filter_set(id, user_id)
    else
      {:error, :no_adapter}
    end
  end
  
  defp save_filter_set(params, assigns) do
    require Logger
    adapter = assigns[:filter_sets_adapter]
    Logger.debug("Adapter: #{inspect(adapter)}")
    
    if adapter do
      # Convert filters from list format to map format
      filters_map = case assigns.current_filters do
        filters when is_list(filters) ->
          Enum.reduce(filters, %{}, fn
            {uuid, _section, filter_data}, acc ->
              Map.put(acc, uuid, filter_data)
            _, acc ->
              acc
          end)
        filters when is_map(filters) ->
          filters
        _ ->
          %{}
      end
      
      # Normalize domain by removing leading slash for consistent storage
      normalized_domain = String.trim_leading(to_string(assigns.domain), "/")

      attrs = %{
        name: params["name"],
        description: params["description"],
        domain: normalized_domain,
        filters: filters_map,
        user_id: assigns.user_id,
        is_shared: params["is_shared"] == "true"
      }
      
      Logger.debug("Creating filter set with attrs: #{inspect(attrs)}")
      result = adapter.create_filter_set(attrs)
      Logger.debug("Create result: #{inspect(result)}")
      result
    else
      Logger.debug("No adapter found")
      {:error, :no_adapter}
    end
  rescue
    e -> 
      Logger.error("Error creating filter set: #{inspect(e)}")
      {:error, :adapter_error}
  end
  
  defp update_filter_set(id, params, assigns) do
    adapter = assigns[:filter_sets_adapter]
    
    if adapter do
      attrs = %{
        name: params["name"],
        description: params["description"],
        is_shared: params["is_shared"] == "true"
      }
      
      adapter.update_filter_set(id, attrs, assigns.user_id)
    else
      {:error, :no_adapter}
    end
  end
  
  defp delete_filter_set(id, assigns) do
    adapter = assigns[:filter_sets_adapter]
    
    if adapter do
      adapter.delete_filter_set(id, assigns.user_id)
    else
      {:error, :no_adapter}
    end
  end
  
  defp set_default_filter_set(id, assigns) do
    adapter = assigns[:filter_sets_adapter]
    
    if adapter do
      adapter.set_default_filter_set(id, assigns.user_id)
    else
      {:error, :no_adapter}
    end
  end
  
  defp duplicate_filter_set(id, assigns) do
    adapter = assigns[:filter_sets_adapter]
    user_id = assigns[:user_id]
    
    if adapter do
      with {:ok, original} <- adapter.get_filter_set(id, user_id) do
        attrs = %{
          name: "#{original.name} (Copy)",
          description: original.description,
          domain: original.domain,
          filters: original.filters,
          user_id: user_id,
          is_shared: false,
          is_default: false
        }
        
        adapter.create_filter_set(attrs)
      end
    else
      {:error, :no_adapter}
    end
  end
  
  defp generate_share_data(_id, _assigns) do
    # TODO: Implement share URL generation
    {:error, :not_implemented}
  end
  
  defp export_filter_set(_id, _assigns) do
    # TODO: Implement JSON export
    {:error, :not_implemented}
  end
  
  # Flash helper removed - using Phoenix.LiveView.put_flash directly
  
  defp increment_usage(_id), do: :ok
end