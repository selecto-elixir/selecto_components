defmodule SelectoComponents.FormRefactored do
  @moduledoc """
  Refactored SelectoComponents Form using separated concerns.
  
  This module demonstrates the separation of state management, routing logic,
  and UI concerns into their respective modules.
  """
  
  use Phoenix.LiveComponent

  import SelectoComponents.Components.Common
  alias SelectoComponents.{State, Router, UI}

  @doc """
  Form for configuring Selecto View with separated concerns.
  
  attrs:
  selecto: the selecto structure
  views: available view configurations
  saved_view_module: optional module for saved view functionality
  saved_view_context: context for saved views
  """

  def render(assigns) do
    # Use UI module to prepare all display-related data
    ui_assigns = UI.prepare_form_assigns(assigns.component_state, %{
      views: assigns.views,
      use_saved_views: UI.show_saved_views?(assigns),
      form: UI.build_form_config(assigns.component_state.view_config)
    })

    assigns = Map.merge(assigns, ui_assigns)

    ~H"""
      <div class="border-solid border border-2 rounded-md border-black dark:border-black h-100 overflow-auto p-1">
        <.form for={@form} phx-change="view-validate" phx-submit="view-apply">
          <!-- Error Display -->
          <div :if={@execution_error} class="bg-red-50 border border-red-200 rounded-md p-4 mb-4">
            <div class="flex">
              <div class="flex-shrink-0">
                <svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
                </svg>
              </div>
              <div class="ml-3">
                <h3 class="text-sm font-medium text-red-800">
                  Query Execution Failed
                </h3>
                <div class="mt-2 text-sm text-red-700">
                  <%= UI.format_error_message(@execution_error) %>
                </div>
                <div :if={@execution_error && Map.get(@execution_error, :query)} class="mt-2">
                  <details class="text-xs text-red-600">
                    <summary class="cursor-pointer">Show query details</summary>
                    <pre class="mt-1 whitespace-pre-wrap"><%= Map.get(@execution_error, :query) %></pre>
                    <div :if={Map.get(@execution_error, :params) && length(Map.get(@execution_error, :params, [])) > 0}>
                      <strong>Parameters:</strong> <%= inspect(Map.get(@execution_error, :params)) %>
                    </div>
                  </details>
                </div>
              </div>
            </div>
          </div>
          
          <!-- Tab Navigation -->
          <.sc_button type="button" phx-click="set_active_tab" phx-value-tab="view">View Tab</.sc_button>
          <.sc_button type="button" phx-click="set_active_tab" phx-value-tab="filter">Filter Tab</.sc_button>
          <.sc_button :if={@use_saved_views} type="button" phx-click="set_active_tab" phx-value-tab="save">Save View</.sc_button>
          <.sc_button type="button" phx-click="set_active_tab" phx-value-tab="export">Export Tab</.sc_button>

          <!-- View Tab -->
          <div class={UI.tab_class(@active_tab, "view")}>
            View Type
            <.live_component
              module={SelectoComponents.Components.RadioTabs}
              id="view_mode"
              fieldname="view_mode"
              view_mode={UI.extract_view_mode(@view_config)}
              options={@views}
              >
                <:section :let={{id, mod, _, _} = view}>
                  <.live_component
                    module={String.to_existing_atom("#{mod}.Form")}
                    id={"view_#{id}_form"}
                    columns={@columns}
                    view_config={@view_config}
                    view={view}
                    selecto={@selecto}
                  />
                </:section>
            </.live_component>
          </div>

          <!-- Filter Tab -->
          <div class={UI.tab_class(@active_tab, "filter")}>
            FILTER SECTION
            <.live_component
              module={SelectoComponents.Components.TreeBuilder}
              id="filter_tree"
              available={@field_filters}
              filters={@view_config.filters}
            >
              <:filter_form :let={{uuid, index, section, fv}}>
                <.live_component
                  module={SelectoComponents.Components.FilterForms}
                  id={uuid}
                  uuid={uuid}
                  section={section}
                  index={index}
                  filters={@field_filters}
                  value={fv}
                  selecto={@selecto}
                />
              </:filter_form>
            </.live_component>
          </div>

          <!-- Save Tab -->
          <div :if={@use_saved_views} class={UI.tab_class(@active_tab, "save")}>
            SAVE SECTION
            <label for="save_as">Save View As:</label>
            <input type="text" name="save_as" placeholder="Enter view name" class="border rounded px-2 py-1" />
            <.sc_button type="submit">Save View</.sc_button>
          </div>

          <!-- Export Tab -->
          <div class={UI.tab_class(@active_tab, "export")}>
            EXPORT SECTION
            <.sc_button type="button">Export CSV</.sc_button>
            <.sc_button type="button">Export JSON</.sc_button>
            <.sc_button type="button">Export SQL</.sc_button>
          </div>

          <.sc_button type="submit">Apply</.sc_button>
        </.form>
      </div>
    """
  end

  # Mount function using State module
  def mount(socket) do
    state = State.init_state(
      socket.assigns.selecto,
      socket.assigns.views,
      active_tab: Map.get(socket.assigns, :active_tab, "view")
    )
    
    {:ok, assign(socket, component_state: state)}
  end

  # Event handling using Router module
  def handle_event(event, params, socket) do
    case Router.handle_event(event, params, socket.assigns.component_state) do
      {:ok, new_state} ->
        {:noreply, assign(socket, component_state: new_state)}
      
      {:error, error_state} ->
        {:noreply, assign(socket, component_state: error_state)}
    end
  end

  def handle_info(message, socket) do
    case Router.handle_info(message, socket.assigns.component_state) do
      {:ok, new_state} ->
        {:noreply, assign(socket, component_state: new_state)}
      
      {:error, error_state} ->
        {:noreply, assign(socket, component_state: error_state)}
    end
  end

  # Additional helper functions can be moved to UI module
  defp params_to_state(params, socket) do
    # This logic should be moved to Router module
    # For now, keeping minimal implementation
    socket
  end

  defp view_from_params(params, socket) do
    # This logic should be moved to Router module
    # For now, keeping minimal implementation
    socket
  end

  defp state_to_url(params, socket) do
    # This logic should be moved to Router module
    # For now, keeping minimal implementation
    socket
  end
end