defmodule SelectoComponents.Form.SavePanel do
  use Phoenix.Component

  import SelectoComponents.Components.Common

  attr(:theme, :map, required: true)

  def panel(assigns) do
    ~H"""
    <div class="space-y-4">
      <p class="text-sm text-gray-600 dark:text-gray-400">
        Save your current view configuration for later use.
      </p>
      <div class="flex items-center gap-2">
        <label for="save_as" class="text-sm font-medium">Save As:</label>
        <.sc_input
          name="save_as"
          id="save_as"
          placeholder="Enter view name..."
          class="flex-1"
          theme={@theme}
        />
      </div>
    </div>
    """
  end
end
