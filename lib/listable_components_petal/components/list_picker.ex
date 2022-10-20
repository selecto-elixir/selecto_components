defmodule ListableComponentsPetal.Components.ListPicker do
  @doc """
    Given a list of items, allow user to select items, put them in order, configure the order

    To be used by view builder

    TODO
      add a little x button to remove
      up, down arrows on hover in selected section
      ability to add tooltips or descriptions to available {id, name, descr}?

  """
  use Phoenix.LiveComponent

  attr(:avail, :list, required: true)
  attr(:selected_items, :list, required: true)
  attr(:fieldname, :string, required: true)

  slot(:item_form)
  # TODO fix the selected items spacing ...
  def render(assigns) do
    ~H"""
      <div class="grid grid-cols-2 gap-1">
        <div>Avialable (search)</div>

        <div>Selected</div>

        <!-- Change to accept {id, name} here -->
        <div class="grid grid-cols-1 gap-1 border-solid border rounded-md border-grey dark:border-black max-h-60 overflow-auto p-1">
          <div :for={{id, name} <- @available} phx-click="add" phx-target={@myself} phx-value-list-id={@fieldname} phx-value-item={id}
            class="max-w-100 bg-slate-100	 border-solid border rounded-md border-grey-900 dark:border-black relative p-1 hover:bg-slate-200">
            <%= name %>
          </div>
        </div>

        <div class="grid grid-cols-1 gap-1 border rounded-md border-grey dark:border-black max-h-60 overflow-auto p-1">
          <div :for={{{id, item, conf}, index} <- Enum.with_index(@selected_items)}
            class="max-w-100 bg-slate-100	border-solid border rounded-md border-grey-900 dark:border-black relative p-1 max-h-12 hover:bg-slate-200">
            <%= render_slot(@item_form, {id, item, conf, index}) %>

            <div class="absolute top-1 right-1">
            <button type="button" phx-click="move" phx-target={@myself} phx-value-list-id={@fieldname} phx-value-item={id} phx-value-direction="up">[^]</button>
            <button type="button" phx-click="move" phx-target={@myself} phx-value-list-id={@fieldname} phx-value-item={id} phx-value-direction="down">[v]</button>
            <button type="button" phx-click="remove" phx-target={@myself} phx-value-list-id={@fieldname} phx-value-item={id}>[X]</button>
            </div>
          </div>
        </div>
      </div>
    """
  end

  def handle_event("remove", params, socket) do
    send(self(), {:list_picker_remove, params["list-id"], params["item"]})
    {:noreply, socket}
  end

  def handle_event("add", params, socket) do
    send(self(), {:list_picker_add, params["list-id"], params["item"]})
    {:noreply, socket}
  end

  def handle_event("move", params, socket) do
    send(self(), {:list_picker_move, params["list-id"], params["item"], params["direction"]})
    {:noreply, socket}
  end
end
