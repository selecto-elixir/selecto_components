defmodule SelectoComponents.ViewConfigManager do
  @moduledoc """
  Component for managing saved view configurations with view type separation.
  Allows saving and loading configurations specific to each view type.
  """

  use Phoenix.LiveComponent
  import Phoenix.HTML.Form
  alias Phoenix.LiveView.JS

  @impl true
  def mount(socket) do
    {:ok, assign(socket,
      show_save_dialog: false,
      show_load_menu: false,
      saved_configs: [],
      config_name: "",
      config_description: ""
    )}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> load_saved_configs()

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="relative inline-block text-left">
      <div class="flex items-center gap-2">
        <!-- Load button with dropdown -->
        <div class="relative">
          <button
            type="button"
            phx-click={toggle_load_menu()}
            phx-target={@myself}
            class="inline-flex items-center px-3 py-2 border border-gray-300 shadow-sm text-sm leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
          >
            <svg class="-ml-0.5 mr-2 h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
            </svg>
            Load View
            <svg class="-mr-1 ml-2 h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
            </svg>
          </button>

          <!-- Load dropdown menu -->
          <div
            :if={@show_load_menu}
            class="origin-top-left absolute left-0 mt-2 w-56 rounded-md shadow-lg bg-white ring-1 ring-black ring-opacity-5 divide-y divide-gray-100 z-50"
            phx-click-away={JS.push("hide_load_menu", target: @myself)}
          >
            <div class="py-1">
              <div class="px-3 py-2 text-xs text-gray-500 uppercase tracking-wider">
                <%= get_view_type_label(@view_config.view_mode) %> Views
              </div>
              <%= if Enum.empty?(@saved_configs) do %>
                <div class="px-3 py-2 text-sm text-gray-500 italic">
                  No saved <%= String.downcase(get_view_type_label(@view_config.view_mode)) %> views
                </div>
              <% else %>
                <%= for config <- @saved_configs do %>
                  <button
                    type="button"
                    phx-click="load_view_config"
                    phx-value-name={config.name}
                    phx-target={@parent_id}
                    class="w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 hover:text-gray-900"
                  >
                    <div class="font-medium"><%= config.name %></div>
                    <%= if config.description do %>
                      <div class="text-xs text-gray-500 mt-1"><%= config.description %></div>
                    <% end %>
                    <div class="text-xs text-gray-400 mt-1">
                      Updated <%= format_time_ago(config.updated_at) %>
                      <%= if config.user_id do %>
                        • Private
                      <% else %>
                        • Public
                      <% end %>
                    </div>
                  </button>
                <% end %>
              <% end %>
            </div>
          </div>
        </div>

        <!-- Save button -->
        <button
          type="button"
          phx-click={JS.push("show_save_dialog", target: @myself)}
          class="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
        >
          <svg class="-ml-0.5 mr-2 h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3 3m0 0l-3-3m3 3V2" />
          </svg>
          Save View
        </button>
      </div>

      <!-- Save dialog modal -->
      <%= if @show_save_dialog do %>
        <div class="fixed z-50 inset-0 overflow-y-auto" aria-labelledby="modal-title" role="dialog" aria-modal="true">
          <div class="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
            <!-- Background overlay -->
            <div
              class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity"
              aria-hidden="true"
              phx-click={JS.push("hide_save_dialog", target: @myself)}
            ></div>

            <!-- Modal panel -->
            <div class="inline-block align-bottom bg-white rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-lg sm:w-full">
              <form phx-submit="save_view_config" phx-target={@myself}>
                <div class="bg-white px-4 pt-5 pb-4 sm:p-6 sm:pb-4">
                  <div class="sm:flex sm:items-start">
                    <div class="mx-auto flex-shrink-0 flex items-center justify-center h-12 w-12 rounded-full bg-blue-100 sm:mx-0 sm:h-10 sm:w-10">
                      <svg class="h-6 w-6 text-blue-600" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3 3m0 0l-3-3m3 3V2" />
                      </svg>
                    </div>
                    <div class="mt-3 text-center sm:mt-0 sm:ml-4 sm:text-left w-full">
                      <h3 class="text-lg leading-6 font-medium text-gray-900" id="modal-title">
                        Save <%= get_view_type_label(@view_config.view_mode) %> View Configuration
                      </h3>
                      <div class="mt-4">
                        <label for="config_name" class="block text-sm font-medium text-gray-700">
                          Name <span class="text-red-500">*</span>
                        </label>
                        <input
                          type="text"
                          name="config_name"
                          id="config_name"
                          required
                          value={@config_name}
                          phx-change="update_config_name"
                          phx-target={@myself}
                          class="mt-1 focus:ring-indigo-500 focus:border-indigo-500 block w-full shadow-sm sm:text-sm border-gray-300 rounded-md"
                          placeholder="e.g., Weekly Report, Customer Analysis"
                        />
                      </div>
                      <div class="mt-4">
                        <label for="config_description" class="block text-sm font-medium text-gray-700">
                          Description
                        </label>
                        <textarea
                          name="config_description"
                          id="config_description"
                          rows="3"
                          value={@config_description}
                          phx-change="update_config_description"
                          phx-target={@myself}
                          class="mt-1 focus:ring-indigo-500 focus:border-indigo-500 block w-full shadow-sm sm:text-sm border-gray-300 rounded-md"
                          placeholder="Describe what this view shows..."
                        ><%= @config_description %></textarea>
                      </div>
                      <div class="mt-4">
                        <label class="inline-flex items-center">
                          <input
                            type="checkbox"
                            name="is_public"
                            class="rounded border-gray-300 text-indigo-600 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                          />
                          <span class="ml-2 text-sm text-gray-600">Make this view public (visible to all users)</span>
                        </label>
                      </div>
                    </div>
                  </div>
                </div>
                <div class="bg-gray-50 px-4 py-3 sm:px-6 sm:flex sm:flex-row-reverse">
                  <button
                    type="submit"
                    class="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-indigo-600 text-base font-medium text-white hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:ml-3 sm:w-auto sm:text-sm"
                  >
                    Save View
                  </button>
                  <button
                    type="button"
                    phx-click={JS.push("hide_save_dialog", target: @myself)}
                    class="mt-3 w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:mt-0 sm:ml-3 sm:w-auto sm:text-sm"
                  >
                    Cancel
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("show_save_dialog", _params, socket) do
    {:noreply, assign(socket, show_save_dialog: true)}
  end

  def handle_event("hide_save_dialog", _params, socket) do
    {:noreply, assign(socket, show_save_dialog: false, config_name: "", config_description: "")}
  end

  def handle_event("hide_load_menu", _params, socket) do
    {:noreply, assign(socket, show_load_menu: false)}
  end

  def handle_event("update_config_name", %{"config_name" => name}, socket) do
    {:noreply, assign(socket, config_name: name)}
  end

  def handle_event("update_config_description", %{"config_description" => desc}, socket) do
    {:noreply, assign(socket, config_description: desc)}
  end

  def handle_event("save_view_config", params, socket) do
    view_type = socket.assigns.view_config.view_mode || "detail"

    case socket.assigns.saved_view_config_module.save_view_config(
      params["config_name"],
      socket.assigns.saved_view_context,
      view_type,
      view_config_to_params(socket.assigns.view_config),
      user_id: Map.get(socket.assigns, :current_user_id),
      description: params["config_description"],
      is_public: params["is_public"] == "on"
    ) do
      {:ok, _config} ->
        socket =
          socket
          |> assign(show_save_dialog: false, config_name: "", config_description: "")
          |> load_saved_configs()

        send(self(), {:put_flash, :info, "View configuration saved successfully"})
        {:noreply, socket}

      {:error, _changeset} ->
        send(self(), {:put_flash, :error, "Failed to save view configuration"})
        {:noreply, socket}
    end
  end

  defp toggle_load_menu do
    JS.push("toggle_load_menu")
  end

  @impl true
  def handle_event("toggle_load_menu", _params, socket) do
    {:noreply, assign(socket, show_load_menu: !socket.assigns.show_load_menu)}
  end

  defp load_saved_configs(socket) do
    if has_view_config_module?(socket) do
      view_type = socket.assigns.view_config.view_mode || "detail"

      configs = socket.assigns.saved_view_config_module.list_view_configs(
        socket.assigns.saved_view_context,
        view_type,
        user_id: Map.get(socket.assigns, :current_user_id),
        include_public: true
      )

      assign(socket, saved_configs: configs)
    else
      socket
    end
  end

  defp has_view_config_module?(socket) do
    Map.has_key?(socket.assigns, :saved_view_config_module) &&
      socket.assigns.saved_view_config_module != nil
  end

  defp view_config_to_params(view_config) do
    Map.from_struct(view_config)
    |> Map.drop([:__struct__, :__meta__])
  end

  defp get_view_type_label("aggregate"), do: "Aggregate"
  defp get_view_type_label("graph"), do: "Graph"
  defp get_view_type_label(_), do: "Detail"

  defp format_time_ago(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)} min ago"
      diff < 86400 -> "#{div(diff, 3600)} hours ago"
      diff < 604800 -> "#{div(diff, 86400)} days ago"
      true -> "#{div(diff, 604800)} weeks ago"
    end
  end
end