defmodule SelectoComponents.Components.Tabs do
  @doc """
  Tab-based navigation component for view type selection.
  Displays tabs at the top with corresponding content sections below.
  
  ## Attributes
  - @fieldname: The form field name for the selected tab
  - @view_mode: Currently selected view mode (string)
  - @options: List of {id, module, name, opt} tuples for available views
  - @section: Slot for rendering tab content
  """
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
    <div class="w-full">
      <!-- Tab Navigation Bar -->
      <div class="flex border-b border-gray-200 dark:border-gray-700">
        <div class="flex space-x-1" role="tablist" aria-label="View Type">
          <button
            :for={{id, _module, name, _opt} <- @options}
            type="button"
            role="tab"
            aria-selected={@view_mode == Atom.to_string(id)}
            aria-controls={"tabpanel-#{id}"}
            id={"tab-#{id}"}
            phx-click="view_set"
            phx-target={@myself}
            phx-value-view={id}
            class={[
              "px-4 py-2 text-sm font-medium transition-all duration-200",
              "border-b-2 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary",
              if @view_mode == Atom.to_string(id) do
                "border-primary text-primary bg-primary/5"
              else
                "border-transparent text-gray-600 hover:text-gray-800 hover:border-gray-300 dark:text-gray-400 dark:hover:text-gray-200"
              end
            ]}
          >
            <%= name %>
          </button>
        </div>
      </div>
      
      <!-- Tab Content Panels -->
      <div class="mt-4">
        <div 
          :for={{id, module, name, opt} <- @options}
          role="tabpanel"
          id={"tabpanel-#{id}"}
          aria-labelledby={"tab-#{id}"}
          class={if @view_mode == Atom.to_string(id) do "" else "hidden" end}
        >
          <%= render_slot(@section, {id, module, name, opt}) %>
        </div>
      </div>
      
      <!-- Hidden radio input for form submission -->
      <input type="hidden" name={@fieldname} value={@view_mode} />
    </div>
    """
  end

  def handle_event("view_set", %{"view" => view_id}, socket) do
    send(self(), {:view_set, view_id})
    {:noreply, socket}
  end
end
