defmodule SelectoComponents.ViewConfigManager do
  @moduledoc """
  Component for managing saved view configurations with view type separation.
  Allows saving and loading configurations specific to each view type.
  """

  use Phoenix.LiveComponent
  alias Phoenix.LiveView.JS
  alias SelectoComponents.ErrorHandling.ErrorBuilder
  alias SelectoComponents.SafeAtom
  alias SelectoComponents.Theme

  @impl true
  def mount(socket) do
    {:ok,
     assign(socket,
       compact: false,
       theme: Theme.default_theme(:light),
       show_save_dialog: false,
       show_load_menu: false,
       saved_configs: [],
       config_name: "",
       config_description: "",
       is_public: false
     )}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> maybe_load_saved_configs()

    {:ok, socket}
  end

  defp maybe_load_saved_configs(socket) do
    # Only load configs if not already loaded
    if Map.get(socket.assigns, :configs_loaded, false) do
      socket
    else
      socket
      |> load_saved_configs()
      |> assign(configs_loaded: true)
    end
  end

  @impl true
  def render(assigns) do
    assigns =
      assigns |> Map.put_new(:compact, false) |> Map.put_new(:theme, Theme.default_theme(:light))

    ~H"""
    <div class={if @compact, do: "flex items-center gap-2", else: Theme.slot(@theme, :panel) <> " mb-4 p-4"} style={if @compact, do: nil, else: "background: var(--sc-surface-bg-alt);"}>
      <div class="flex items-center justify-between gap-2">
        <h3 :if={!@compact} class="text-lg font-medium" style="color: var(--sc-text-primary);">
          View Configuration - {get_view_type_label(@view_config.view_mode)} Mode
        </h3>
        <div class="flex items-center gap-2">
          <!-- Load button with dropdown -->
          <div class="relative">
            <button
              type="button"
              phx-click="toggle_load_menu"
              phx-target={@myself}
              class={Theme.slot(@theme, :button_secondary) <> " px-3 py-2 text-sm leading-4 shadow-sm"}
            >
              <svg
                class="-ml-0.5 mr-2 h-4 w-4"
                xmlns="http://www.w3.org/2000/svg"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"
                />
              </svg>
              Load View
              <svg
                class="-mr-1 ml-2 h-4 w-4"
                xmlns="http://www.w3.org/2000/svg"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M19 9l-7 7-7-7"
                />
              </svg>
            </button>
            
    <!-- Load dropdown menu -->
              <div
                :if={@show_load_menu}
                class={Theme.slot(@theme, :panel) <> " origin-top-left absolute left-0 z-50 mt-2 w-56 divide-y"}
                style="background: var(--sc-surface-bg);"
                phx-click-away={JS.push("hide_load_menu", target: @myself)}
              >
              <div class="py-1">
                <div class="px-3 py-2 text-xs uppercase tracking-wider" style="color: var(--sc-text-muted);">
                  {get_view_type_label(@view_config.view_mode)} Views
                </div>
                <%= if Enum.empty?(@saved_configs) do %>
                  <div class="px-3 py-2 text-sm italic" style="color: var(--sc-text-muted);">
                    No saved {String.downcase(get_view_type_label(@view_config.view_mode))} views
                  </div>
                <% else %>
                  <%= for config <- @saved_configs do %>
                    <button
                      type="button"
                      phx-click="load_view_config"
                      phx-value-name={config.name}
                      phx-target={@myself}
                      class="w-full px-4 py-2 text-left text-sm"
                      style="color: var(--sc-text-secondary);"
                    >
                      <div class="font-medium">{config.name}</div>
                      <%= if config.description do %>
                        <div class="mt-1 text-xs" style="color: var(--sc-text-muted);">{config.description}</div>
                      <% end %>
                      <div class="mt-1 text-xs" style="color: var(--sc-text-muted); opacity: 0.85;">
                        Updated {format_time_ago(config.updated_at)}
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
            class={Theme.slot(@theme, :button_primary) <> " px-3 py-2 text-sm leading-4 shadow-sm"}
          >
            <svg
              class="-ml-0.5 mr-2 h-4 w-4"
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3 3m0 0l-3-3m3 3V2"
              />
            </svg>
            Save View
          </button>
        </div>
        
    <!-- Save dialog modal -->
        <%= if @show_save_dialog do %>
          <div
              class="fixed z-50 inset-0 overflow-y-auto"
            aria-labelledby="modal-title"
            role="dialog"
            aria-modal="true"
          >
            <div class="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
              <!-- Background overlay -->
              <div
                class="fixed inset-0 bg-neutral/60 transition-opacity"
                style="background: color-mix(in srgb, var(--sc-text-primary) 35%, transparent);"
                aria-hidden="true"
                phx-click={JS.push("hide_save_dialog", target: @myself)}
              >
              </div>
              
     <!-- Modal panel -->
              <div class={Theme.slot(@theme, :panel) <> " inline-block align-bottom text-left overflow-hidden transform transition-all sm:my-8 sm:align-middle sm:max-w-lg sm:w-full"} style="background: var(--sc-surface-bg);">
                <div>
                  <div class="px-4 pt-5 pb-4 sm:p-6 sm:pb-4">
                    <div class="sm:flex sm:items-start">
                      <div class="mx-auto flex-shrink-0 flex items-center justify-center h-12 w-12 rounded-full sm:mx-0 sm:h-10 sm:w-10" style="background: var(--sc-accent-soft); color: var(--sc-accent);">
                        <svg
                          class="h-6 w-6"
                          xmlns="http://www.w3.org/2000/svg"
                          fill="none"
                          viewBox="0 0 24 24"
                          stroke="currentColor"
                        >
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            stroke-width="2"
                            d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3 3m0 0l-3-3m3 3V2"
                          />
                        </svg>
                      </div>
                      <div class="mt-3 text-center sm:mt-0 sm:ml-4 sm:text-left w-full">
                        <h3 class="text-lg leading-6 font-medium text-base-content" id="modal-title">
                          Save {get_view_type_label(@view_config.view_mode)} View Configuration
                        </h3>
                        <div class="mt-4">
                          <label for="config_name" class="block text-sm font-medium text-base-content/80">
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
                            class={Theme.slot(@theme, :input) <> " mt-1 block sm:text-sm"}
                            placeholder="e.g., Weekly Report, Customer Analysis"
                          />
                        </div>
                        <div class="mt-4">
                          <label
                            for="config_description"
                            class="block text-sm font-medium"
                            style="color: var(--sc-text-secondary);"
                          >
                            Description
                          </label>
                          <textarea
                            name="config_description"
                            id="config_description"
                            rows="3"
                            value={@config_description}
                            phx-change="update_config_description"
                            phx-target={@myself}
                            class={Theme.slot(@theme, :input) <> " mt-1 block sm:text-sm"}
                            placeholder="Describe what this view shows..."
                          ><%= @config_description %></textarea>
                        </div>
                        <div class="mt-4">
                          <label class={Theme.slot(@theme, :checkbox_label) <> " inline-flex items-center"}>
                            <input
                              type="checkbox"
                              name="is_public"
                              phx-click="toggle_is_public"
                              phx-target={@myself}
                              checked={@is_public}
                              class="h-4 w-4 rounded border"
                              style="border-color: var(--sc-surface-border); background: var(--sc-surface-bg); accent-color: var(--sc-accent);"
                            />
                            <span class="ml-2 text-sm" style="color: var(--sc-text-secondary);">
                              Make this view public (visible to all users)
                            </span>
                          </label>
                        </div>
                      </div>
                    </div>
                  </div>
                  <div class="px-4 py-3 sm:px-6 sm:flex sm:flex-row-reverse" style="background: color-mix(in srgb, var(--sc-surface-bg-alt) 75%, var(--sc-surface-bg));">
                    <button
                      type="button"
                      phx-click="do_save_view_config"
                      phx-target={@myself}
                      class={Theme.slot(@theme, :button_primary) <> " w-full justify-center px-4 py-2 text-base shadow-sm sm:ml-3 sm:w-auto sm:text-sm"}
                    >
                      Save View
                    </button>
                    <button
                      type="button"
                      phx-click={JS.push("hide_save_dialog", target: @myself)}
                      class={Theme.slot(@theme, :button_secondary) <> " mt-3 w-full justify-center px-4 py-2 text-base shadow-sm sm:mt-0 sm:ml-3 sm:w-auto sm:text-sm"}
                    >
                      Cancel
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("show_save_dialog", _params, socket) do
    {:noreply, assign(socket, show_save_dialog: true)}
  end

  def handle_event("hide_save_dialog", _params, socket) do
    {:noreply,
     assign(socket,
       show_save_dialog: false,
       config_name: "",
       config_description: "",
       is_public: false
     )}
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

  def handle_event("toggle_is_public", _params, socket) do
    {:noreply, assign(socket, is_public: !socket.assigns.is_public)}
  end

  def handle_event("do_save_view_config", _params, socket) do
    view_type = normalize_view_type(socket.assigns.view_config.view_mode || "detail")

    # Only save view-specific configuration (not filters)
    view_specific_config = extract_view_specific_config(socket.assigns.view_config, view_type)

    case socket.assigns.saved_view_config_module.save_view_config(
           socket.assigns.config_name,
           socket.assigns.saved_view_context,
           view_type,
           view_specific_config,
           user_id: Map.get(socket.assigns, :current_user_id),
           description: socket.assigns.config_description,
           is_public: socket.assigns[:is_public] || false
         ) do
      {:ok, _config} ->
        socket =
          socket
          |> assign(
            show_save_dialog: false,
            config_name: "",
            config_description: "",
            is_public: false
          )
          |> assign(configs_loaded: false)
          |> maybe_load_saved_configs()

        # Component can't use put_flash directly, but can update assigns
        # The parent can check for this and display a message
        {:noreply, socket}

      {:error, reason} ->
        {:noreply,
         Phoenix.LiveView.put_flash(
           socket,
           :error,
           saved_view_config_error_message(reason,
             code: :save_view_config_failed,
             operation: "do_save_view_config"
           )
         )}
    end
  end

  @impl true
  def handle_event("toggle_load_menu", _params, socket) do
    {:noreply, assign(socket, show_load_menu: !socket.assigns.show_load_menu)}
  end

  def handle_event("load_view_config", %{"name" => name}, socket) do
    view_type = normalize_view_type(socket.assigns.view_config.view_mode || "detail")

    config =
      socket.assigns.saved_view_config_module.load_view_config(
        name,
        socket.assigns.saved_view_context,
        view_type,
        user_id: Map.get(socket.assigns, :current_user_id)
      )

    case config do
      nil ->
        {:noreply,
         Phoenix.LiveView.put_flash(
           socket,
           :error,
           saved_view_config_error_message("View configuration not found",
             stage: :persistence,
             category: :persistence,
             code: :view_config_not_found,
             operation: "load_view_config"
           )
         )}

      config ->
        # Send message to parent LiveView to apply the config
        send(self(), {:apply_view_config, config})

        {:noreply,
         socket
         |> assign(show_load_menu: false)}
    end
  end

  defp load_saved_configs(socket) do
    if has_view_config_module?(socket) do
      view_type = normalize_view_type(socket.assigns.view_config.view_mode || "detail")

      configs =
        socket.assigns.saved_view_config_module.list_view_configs(
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

  defp extract_view_specific_config(view_config, view_type) do
    normalized_view_type = normalize_view_type(view_type)

    # Extract only the configuration for the current view type
    # Exclude filters as they have their own save system
    views = Map.get(view_config, :views, %{})

    view_type_atom = SafeAtom.to_view_mode(normalized_view_type)
    current_view_config = Map.get(views, view_type_atom, %{})

    # For detail view, ensure we have the actual selected columns from the view_config
    current_view_config =
      case normalized_view_type do
        "detail" ->
          # Get the selected columns from the main Selecto configuration
          selected = get_selected_from_selecto(view_config)
          order_by = get_order_by_from_selecto(view_config)

          current_view_config
          |> Map.put(:selected, selected)
          |> Map.put(:order_by, order_by)
          |> Map.put(:per_page, Map.get(current_view_config, :per_page, "30"))

        _ ->
          current_view_config
      end

    # Return only the view-specific configuration
    %{
      normalized_view_type => current_view_config
    }
    |> sanitize_for_json()
  end

  defp normalize_view_type(view_type) do
    view_type
    |> SafeAtom.to_view_mode()
    |> Atom.to_string()
  end

  defp get_selected_from_selecto(view_config) do
    # Try to get from the detail view first, then fall back to the main columns
    case get_in(view_config, [:views, :detail, :selected]) do
      nil ->
        # Fall back to columns from view_config
        Map.get(view_config, :columns, [])
        |> Enum.map(fn col ->
          case col do
            {uuid, field, data} -> {uuid, field, data}
            %{"uuid" => uuid, "field" => field} = data -> {uuid, field, data}
            _ -> nil
          end
        end)
        |> Enum.filter(&(&1 != nil))

      selected ->
        selected
    end
  end

  defp get_order_by_from_selecto(view_config) do
    # Try to get from the detail view first, then fall back
    case get_in(view_config, [:views, :detail, :order_by]) do
      nil ->
        # Fall back to order_by from view_config
        Map.get(view_config, :order_by, [])
        |> Enum.map(fn item ->
          case item do
            {uuid, field, data} -> {uuid, field, data}
            %{"uuid" => uuid, "field" => field} = data -> {uuid, field, data}
            _ -> nil
          end
        end)
        |> Enum.filter(&(&1 != nil))

      order_by ->
        order_by
    end
  end

  # defp view_config_to_params(view_config) when is_struct(view_config) do
  #   Map.from_struct(view_config)
  #   |> Map.drop([:__struct__, :__meta__])
  #   |> sanitize_for_json()
  # end

  # defp view_config_to_params(view_config) when is_map(view_config) do
  #   view_config
  #   |> sanitize_for_json()
  # end

  # Convert tuples to lists for JSON encoding
  defp sanitize_for_json(data) when is_map(data) do
    Map.new(data, fn {k, v} -> {k, sanitize_for_json(v)} end)
  end

  defp sanitize_for_json(data) when is_list(data) do
    Enum.map(data, &sanitize_for_json/1)
  end

  defp sanitize_for_json(data) when is_tuple(data) do
    data
    |> Tuple.to_list()
    |> sanitize_for_json()
  end

  defp sanitize_for_json(data), do: data

  defp get_view_type_label("aggregate"), do: "Aggregate"
  defp get_view_type_label("graph"), do: "Graph"
  defp get_view_type_label("timeseries"), do: "Time Series"
  defp get_view_type_label("map"), do: "Map"
  defp get_view_type_label(_), do: "Detail"

  defp saved_view_config_error_message(reason, opts) do
    error =
      ErrorBuilder.build(
        if(is_binary(reason), do: reason, else: inspect(reason)),
        Keyword.merge(
          [stage: :persistence, category: :persistence],
          opts
        )
      )

    error.summary <> ": " <> error.user_message
  end

  defp format_time_ago(%DateTime{} = datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)} min ago"
      diff < 86400 -> "#{div(diff, 3600)} hours ago"
      diff < 604_800 -> "#{div(diff, 86400)} days ago"
      true -> "#{div(diff, 604_800)} weeks ago"
    end
  end

  defp format_time_ago(%NaiveDateTime{} = naive_datetime) do
    datetime = DateTime.from_naive!(naive_datetime, "Etc/UTC")
    format_time_ago(datetime)
  end

  defp format_time_ago(nil), do: "unknown"
end
