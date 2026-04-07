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
  alias SelectoComponents.Theme

  def render(assigns) do
    assigns = Map.put_new(assigns, :theme, Theme.default_theme(:light))

    ~H"""
    <div id={"tabs-#{@id}"} phx-hook=".TabsFormSync" class="w-full">
      <!-- Tab Navigation Bar -->
      <div class="flex border-b" style="border-color: var(--sc-surface-border)">
        <div class="flex space-x-1" role="tablist" aria-label="View Type">
          <button
            :for={{id, _module, name, _opt} <- @options}
            type="button"
            role="tab"
            aria-selected={@view_mode == Atom.to_string(id)}
            aria-controls={"tabpanel-#{id}"}
            id={"tab-#{id}"}
            data-view-tab
            data-view-id={id}
            class={[
              "px-4 py-2 text-sm font-medium",
              if @view_mode == Atom.to_string(id) do
                Theme.slot(@theme, :tab_active)
              else
                Theme.slot(@theme, :tab_inactive)
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
      <input type="hidden" name={@fieldname} value={@view_mode} data-view-mode-input />

      <script :type={Phoenix.LiveView.ColocatedHook} name=".TabsFormSync">
        export default {
          mounted() {
            this.handleClick = (event) => {
              const button = event.target.closest('[data-view-tab]');

              if (!button || !this.el.contains(button)) {
                return;
              }

              const input = this.el.querySelector('[data-view-mode-input]');
              const nextView = button.dataset.viewId;

              if (!input || !nextView || input.value === nextView) {
                return;
              }

              input.value = nextView;
              input.dispatchEvent(new Event('input', { bubbles: true }));
              input.dispatchEvent(new Event('change', { bubbles: true }));
            };

            this.el.addEventListener('click', this.handleClick);
          },

          destroyed() {
            if (this.handleClick) {
              this.el.removeEventListener('click', this.handleClick);
            }
          }
        };
      </script>
    </div>
    """
  end
end
