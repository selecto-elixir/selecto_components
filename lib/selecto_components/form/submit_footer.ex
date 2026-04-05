defmodule SelectoComponents.Form.SubmitFooter do
  use Phoenix.Component

  import SelectoComponents.Components.Common

  attr(:id, :any, required: true)
  attr(:theme, :map, required: true)
  attr(:view_config_dirty?, :boolean, default: false)

  def footer(assigns) do
    ~H"""
    <div class="mt-4 flex justify-end">
      <.sc_button
        id={"selecto-submit-#{@id}"}
        theme={@theme}
        data-selecto-submit-button="true"
        data-dirty={to_string(@view_config_dirty?)}
      >
        <span>Submit</span>
        <span data-selecto-submit-badge="true" aria-hidden="true">Unsaved</span>
      </.sc_button>
    </div>
    """
  end
end
