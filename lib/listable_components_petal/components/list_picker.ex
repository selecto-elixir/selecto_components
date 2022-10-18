defmodule ListableComponentsPetal.Components.ListPicker do
  @doc """
    Given a list of items, allow user to select items, put them in order, configure the order

    To be used by view builder

  """

  use Phoenix.LiveComponent

  attr(:avail, :list, required: true)
  attr(:selected_items, :list, required: true)
  attr(:fieldname, :string, required: true)

  slot(:item_form)

  def render(assigns) do
    ~H"""
      <div>
        <div>AVAIL</div>
          <button :for={o <- @available} phx-click="add" phx-target={@myself} phx-value-list-id={@fieldname} phx-value-item={o.colid}>
            <%= o.colid %>
          </button>

        <div>Selected
          <div :for={item <- @selected_items}>
            <%= render_slot(@item_form, item) %>
          </div>
        </div>
      </div>
    """
  end

  def handle_event("add", params, socket) do
    send(self(), {:list_picker_add, params["list-id"], params["item"]})
    {:noreply, socket}
  end
end
