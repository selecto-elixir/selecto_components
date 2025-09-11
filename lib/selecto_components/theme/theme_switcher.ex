defmodule SelectoComponents.Theme.ThemeSwitcher do
  @moduledoc """
  Theme switcher component with preset selection and custom theme builder.
  """
  
  use Phoenix.LiveComponent
  alias SelectoComponents.Theme.ThemeProvider
  alias Phoenix.LiveView.JS
  
  @impl true
  def mount(socket) do
    {:ok, 
      socket
      |> assign(
        current_theme: :light,
        show_menu: false,
        show_builder: false,
        custom_theme: %{},
        preview_mode: false
      )
    }
  end
  
  @impl true
  def update(assigns, socket) do
    socket = 
      socket
      |> assign(assigns)
      |> load_saved_theme()
    
    {:ok, socket}
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class="theme-switcher" phx-hook="ThemeSwitcher">
      <%!-- Theme Switcher Button --%>
      <div class="relative">
        <button
          type="button"
          class="flex items-center space-x-2 px-3 py-2 rounded-lg border border-gray-300 hover:bg-gray-50 dark:border-gray-600 dark:hover:bg-gray-800"
          phx-click="toggle_menu"
          phx-target={@myself}
        >
          <%= render_theme_icon(@current_theme) %>
          <span class="text-sm font-medium"><%= format_theme_name(@current_theme) %></span>
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
          </svg>
        </button>
        
        <%!-- Theme Menu --%>
        <div 
          class={"absolute right-0 mt-2 w-64 bg-white dark:bg-gray-800 rounded-lg shadow-lg border border-gray-200 dark:border-gray-700 z-50 #{if @show_menu, do: "", else: "hidden"}"}
          id="theme-menu"
        >
          <div class="p-2">
            <div class="text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wider px-2 py-1">
              Preset Themes
            </div>
            
            <%= for theme <- ThemeProvider.available_themes() do %>
              <button
                type="button"
                class={"w-full text-left px-3 py-2 rounded-md flex items-center space-x-3 hover:bg-gray-100 dark:hover:bg-gray-700 #{if @current_theme == theme, do: "bg-blue-50 dark:bg-blue-900"}"}
                phx-click="select_theme"
                phx-value-theme={theme}
                phx-target={@myself}
              >
                <%= render_theme_icon(theme) %>
                <div class="flex-1">
                  <div class="text-sm font-medium"><%= format_theme_name(theme) %></div>
                  <div class="text-xs text-gray-500 dark:text-gray-400">
                    <%= theme_description(theme) %>
                  </div>
                </div>
                <%= if @current_theme == theme do %>
                  <svg class="w-5 h-5 text-blue-600" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
                  </svg>
                <% end %>
              </button>
            <% end %>
            
            <hr class="my-2 border-gray-200 dark:border-gray-700" />
            
            <button
              type="button"
              class="w-full text-left px-3 py-2 rounded-md flex items-center space-x-3 hover:bg-gray-100 dark:hover:bg-gray-700"
              phx-click="open_builder"
              phx-target={@myself}
            >
              <svg class="w-5 h-5 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                  d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4" />
              </svg>
              <span class="text-sm font-medium">Custom Theme Builder</span>
            </button>
          </div>
        </div>
      </div>
      
      <%!-- Custom Theme Builder Modal --%>
      <%= if @show_builder do %>
        <%= render_theme_builder(assigns) %>
      <% end %>
    </div>
    """
  end
  
  defp render_theme_builder(assigns) do
    ~H"""
    <div id="theme-builder" class="fixed inset-0 z-50 overflow-y-auto" phx-hook="ThemeBuilder">
      <div class="flex items-center justify-center min-h-screen px-4">
        <div class="fixed inset-0 bg-gray-500 bg-opacity-75" phx-click="close_builder" phx-target={@myself}></div>
        
        <div class="relative bg-white dark:bg-gray-800 rounded-lg shadow-xl max-w-4xl w-full max-h-[90vh] overflow-hidden">
          <%!-- Header --%>
          <div class="px-6 py-4 border-b border-gray-200 dark:border-gray-700">
            <div class="flex items-center justify-between">
              <h2 class="text-xl font-semibold text-gray-900 dark:text-white">Custom Theme Builder</h2>
              <button
                type="button"
                class="text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
                phx-click="close_builder"
                phx-target={@myself}
              >
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
          </div>
          
          <%!-- Content --%>
          <div class="flex h-[60vh]">
            <%!-- Color Palette Editor --%>
            <div class="w-1/2 p-6 overflow-y-auto border-r border-gray-200 dark:border-gray-700">
              <h3 class="text-lg font-medium mb-4">Color Palette</h3>
              
              <%!-- Primary Colors --%>
              <div class="mb-6">
                <h4 class="text-sm font-medium text-gray-700 dark:text-gray-300 mb-3">Primary Colors</h4>
                <div class="space-y-3">
                  <%= for shade <- [50, 100, 200, 300, 400, 500, 600, 700, 800, 900] do %>
                    <div class="flex items-center space-x-3">
                      <label class="text-xs font-medium text-gray-600 dark:text-gray-400 w-12">
                        <%= shade %>
                      </label>
                      <input
                        type="color"
                        value={@custom_theme["primary_#{shade}"] || "#3b82f6"}
                        class="h-8 w-8 rounded border border-gray-300 cursor-pointer"
                        phx-change="update_color"
                        phx-value-key={"primary_#{shade}"}
                        phx-target={@myself}
                      />
                      <input
                        type="text"
                        value={@custom_theme["primary_#{shade}"] || "#3b82f6"}
                        class="flex-1 px-2 py-1 text-sm border border-gray-300 rounded-md"
                        phx-blur="update_color_text"
                        phx-value-key={"primary_#{shade}"}
                        phx-target={@myself}
                      />
                    </div>
                  <% end %>
                </div>
              </div>
              
              <%!-- Semantic Colors --%>
              <div class="mb-6">
                <h4 class="text-sm font-medium text-gray-700 dark:text-gray-300 mb-3">Semantic Colors</h4>
                <div class="space-y-3">
                  <%= for {name, default} <- [
                    {"Success", "#10b981"},
                    {"Warning", "#f59e0b"},
                    {"Error", "#ef4444"},
                    {"Info", "#3b82f6"}
                  ] do %>
                    <div class="flex items-center space-x-3">
                      <label class="text-xs font-medium text-gray-600 dark:text-gray-400 w-16">
                        <%= name %>
                      </label>
                      <input
                        type="color"
                        value={@custom_theme[String.downcase(name)] || default}
                        class="h-8 w-8 rounded border border-gray-300 cursor-pointer"
                        phx-change="update_color"
                        phx-value-key={String.downcase(name)}
                        phx-target={@myself}
                      />
                      <input
                        type="text"
                        value={@custom_theme[String.downcase(name)] || default}
                        class="flex-1 px-2 py-1 text-sm border border-gray-300 rounded-md"
                        phx-blur="update_color_text"
                        phx-value-key={String.downcase(name)}
                        phx-target={@myself}
                      />
                    </div>
                  <% end %>
                </div>
              </div>
              
              <%!-- Typography --%>
              <div class="mb-6">
                <h4 class="text-sm font-medium text-gray-700 dark:text-gray-300 mb-3">Typography</h4>
                <div class="space-y-3">
                  <div>
                    <label class="text-xs font-medium text-gray-600 dark:text-gray-400">Font Family</label>
                    <select
                      class="w-full mt-1 px-3 py-2 border border-gray-300 rounded-md"
                      phx-change="update_font"
                      phx-target={@myself}
                    >
                      <option value="system">System Default</option>
                      <option value="inter">Inter</option>
                      <option value="roboto">Roboto</option>
                      <option value="opensans">Open Sans</option>
                      <option value="lato">Lato</option>
                    </select>
                  </div>
                </div>
              </div>
            </div>
            
            <%!-- Live Preview --%>
            <div class="w-1/2 p-6 bg-gray-50 dark:bg-gray-900">
              <h3 class="text-lg font-medium mb-4">Live Preview</h3>
              
              <div class="space-y-4" style={build_preview_styles(@custom_theme)}>
                <%!-- Sample Components --%>
                <div class="p-4 bg-white dark:bg-gray-800 rounded-lg shadow">
                  <h4 class="text-lg font-semibold mb-2">Sample Card</h4>
                  <p class="text-sm text-gray-600 dark:text-gray-400">
                    This is how your theme looks in practice.
                  </p>
                  
                  <div class="mt-4 flex space-x-2">
                    <button class="px-3 py-1.5 bg-blue-600 text-white rounded text-sm">
                      Primary
                    </button>
                    <button class="px-3 py-1.5 bg-gray-200 text-gray-800 rounded text-sm">
                      Secondary
                    </button>
                  </div>
                </div>
                
                <%!-- Sample Table --%>
                <div class="bg-white dark:bg-gray-800 rounded-lg shadow overflow-hidden">
                  <table class="min-w-full">
                    <thead class="bg-gray-50 dark:bg-gray-700">
                      <tr>
                        <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 dark:text-gray-300">Name</th>
                        <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 dark:text-gray-300">Status</th>
                      </tr>
                    </thead>
                    <tbody class="divide-y divide-gray-200 dark:divide-gray-700">
                      <tr>
                        <td class="px-4 py-2 text-sm">Item 1</td>
                        <td class="px-4 py-2">
                          <span class="px-2 py-1 text-xs bg-green-100 text-green-800 rounded">Active</span>
                        </td>
                      </tr>
                      <tr>
                        <td class="px-4 py-2 text-sm">Item 2</td>
                        <td class="px-4 py-2">
                          <span class="px-2 py-1 text-xs bg-yellow-100 text-yellow-800 rounded">Pending</span>
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </div>
                
                <%!-- Sample Alerts --%>
                <div class="space-y-2">
                  <div class="p-3 bg-green-100 border border-green-400 text-green-700 rounded">
                    Success message
                  </div>
                  <div class="p-3 bg-red-100 border border-red-400 text-red-700 rounded">
                    Error message
                  </div>
                </div>
              </div>
            </div>
          </div>
          
          <%!-- Footer --%>
          <div class="px-6 py-4 border-t border-gray-200 dark:border-gray-700 flex justify-between">
            <div class="flex space-x-2">
              <button
                type="button"
                class="px-4 py-2 text-sm border border-gray-300 rounded-lg hover:bg-gray-50"
                phx-click="export_theme"
                phx-target={@myself}
              >
                Export Theme
              </button>
              <button
                type="button"
                class="px-4 py-2 text-sm border border-gray-300 rounded-lg hover:bg-gray-50"
                phx-click="import_theme"
                phx-target={@myself}
              >
                Import Theme
              </button>
            </div>
            
            <div class="flex space-x-2">
              <button
                type="button"
                class="px-4 py-2 text-sm border border-gray-300 rounded-lg hover:bg-gray-50"
                phx-click="close_builder"
                phx-target={@myself}
              >
                Cancel
              </button>
              <button
                type="button"
                class="px-4 py-2 text-sm bg-blue-600 text-white rounded-lg hover:bg-blue-700"
                phx-click="apply_custom_theme"
                phx-target={@myself}
              >
                Apply Theme
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
  
  # Event handlers
  
  @impl true
  def handle_event("toggle_menu", _params, socket) do
    {:noreply, update(socket, :show_menu, &(!&1))}
  end
  
  def handle_event("select_theme", %{"theme" => theme}, socket) do
    theme_atom = String.to_atom(theme)
    
    send(self(), {:theme_changed, theme_atom})
    
    {:noreply, 
      socket
      |> assign(current_theme: theme_atom, show_menu: false)
      |> save_theme_preference(theme_atom)
    }
  end
  
  def handle_event("open_builder", _params, socket) do
    {:noreply, assign(socket, show_builder: true, show_menu: false)}
  end
  
  def handle_event("close_builder", _params, socket) do
    {:noreply, assign(socket, show_builder: false, custom_theme: %{})}
  end
  
  def handle_event("update_color", %{"key" => key, "value" => value}, socket) do
    custom_theme = Map.put(socket.assigns.custom_theme, key, value)
    {:noreply, assign(socket, custom_theme: custom_theme)}
  end
  
  def handle_event("update_color_text", %{"key" => key, "value" => value}, socket) do
    if valid_hex_color?(value) do
      custom_theme = Map.put(socket.assigns.custom_theme, key, value)
      {:noreply, assign(socket, custom_theme: custom_theme)}
    else
      {:noreply, socket}
    end
  end
  
  def handle_event("apply_custom_theme", _params, socket) do
    send(self(), {:custom_theme_applied, socket.assigns.custom_theme})
    
    {:noreply, 
      socket
      |> assign(show_builder: false)
      |> save_custom_theme(socket.assigns.custom_theme)
    }
  end
  
  def handle_event("export_theme", _params, socket) do
    theme_json = ThemeProvider.export_theme(socket.assigns.custom_theme)
    
    # Trigger download
    send(self(), {:download_theme, theme_json})
    
    {:noreply, socket}
  end
  
  def handle_event("import_theme", _params, socket) do
    # This would trigger a file upload
    {:noreply, socket}
  end
  
  # Helper functions
  
  defp render_theme_icon(:light) do
    assigns = %{}
    ~H"""
    <svg class="w-5 h-5 text-yellow-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
        d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z" />
    </svg>
    """
  end
  
  defp render_theme_icon(:dark) do
    assigns = %{}
    ~H"""
    <svg class="w-5 h-5 text-indigo-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
        d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z" />
    </svg>
    """
  end
  
  defp render_theme_icon(:high_contrast) do
    assigns = %{}
    ~H"""
    <svg class="w-5 h-5 text-gray-900" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
        d="M12 3v1m0 16v1m9-9h-1M4 12H3m3.343-5.657L5.636 5.636m12.728 12.728l-.707.707M3.343 17.657l.707.707m12.728 0l.707-.707M6.343 6.343l.707-.707M9 12a3 3 0 116 0 3 3 0 01-6 0z" />
    </svg>
    """
  end
  
  defp render_theme_icon(_) do
    assigns = %{}
    ~H"""
    <svg class="w-5 h-5 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
        d="M7 21a4 4 0 01-4-4V5a2 2 0 012-2h4a2 2 0 012 2v12a4 4 0 01-4 4zm0 0h12a2 2 0 002-2v-4a2 2 0 00-2-2h-2.343M11 7.343l1.657-1.657a2 2 0 012.828 0l2.829 2.829a2 2 0 010 2.828l-8.486 8.485M7 17h.01" />
    </svg>
    """
  end
  
  defp format_theme_name(theme) do
    theme
    |> to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
  
  defp theme_description(:light), do: "Default light theme"
  defp theme_description(:dark), do: "Dark mode for low-light environments"
  defp theme_description(:high_contrast), do: "High contrast for accessibility"
  defp theme_description(_), do: "Custom theme"
  
  defp valid_hex_color?(color) do
    Regex.match?(~r/^#[0-9A-Fa-f]{6}$/, color)
  end
  
  defp build_preview_styles(custom_theme) do
    custom_theme
    |> Enum.map(fn {key, value} ->
      "--#{String.replace(key, "_", "-")}: #{value}"
    end)
    |> Enum.join("; ")
  end
  
  defp load_saved_theme(socket) do
    # This would load from localStorage via hooks
    socket
  end
  
  defp save_theme_preference(socket, theme) do
    # Save to localStorage via hooks
    socket
  end
  
  defp save_custom_theme(socket, theme) do
    # Save custom theme to storage
    socket
  end
  
  @doc """
  JavaScript hooks for theme switcher.
  """
  def __hooks__() do
    %{
      "ThemeSwitcher" => %{
        mounted: """
        // Close menu on outside click
        this.handleOutsideClick = (e) => {
          const menu = document.getElementById('theme-menu');
          if (menu && !menu.classList.contains('hidden') && !this.el.contains(e.target)) {
            this.pushEventTo(this.el, 'toggle_menu', {});
          }
        };
        
        document.addEventListener('click', this.handleOutsideClick);
        """,
        
        destroyed: """
        document.removeEventListener('click', this.handleOutsideClick);
        """
      },
      
      "ThemeBuilder" => %{
        mounted: """
        // Color picker handling
        this.handleColorChange = (e) => {
          if (e.target.type === 'color') {
            this.pushEventTo(this.el, 'update_color', {
              key: e.target.dataset.key,
              value: e.target.value
            });
          }
        };
        
        // Import theme file
        this.handleFileImport = (e) => {
          const file = e.target.files[0];
          if (file) {
            const reader = new FileReader();
            reader.onload = (e) => {
              this.pushEventTo(this.el, 'import_theme_data', {
                data: e.target.result
              });
            };
            reader.readAsText(file);
          }
        };
        """
      }
    }
  end
end