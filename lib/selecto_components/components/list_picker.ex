defmodule SelectoComponents.Components.ListPicker do
  @doc """
    Given a list of items, allow user to select items, put them in order, configure the order

    To be used by view builder

    TODO
      ability to add tooltips or descriptions to available {id, name, descr}?

  """
  use Phoenix.LiveComponent

  import SelectoComponents.Components.Common

  attr(:available, :list, required: true)
  attr(:selected_items, :list, required: true)
  attr(:fieldname, :string, required: true)

  slot(:item_form)
  # TODO fix the selected items spacing ...
  def render(assigns) do
    {view_id, _, _, _} = assigns.view
    # Sort available items alphabetically by display name (second element in tuple)
    sorted_available = Enum.sort_by(assigns.available, fn {_id, name, _format} -> String.downcase(name) end)
    assigns = assigns
    |> assign(view_id: view_id)
    |> assign(available: sorted_available)

    ~H"""
      <div class="grid grid-cols-2 gap-1 " x-data="{ filter: ''}">
        <div class="text-base-content">Available
          <div class="flex items-center gap-1">
            <input x-model="filter" x-on:keydown.escape="filter = ''" placeholder="Filter Available Items" class="input input-bordered input-sm flex-1"/>
            <button x-on:click="filter = ''" x-show="filter != ''" class="btn btn-sm btn-square btn-outline" type="button">
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>
        </div>

        <div class="text-base-content">Selected</div>

        <div class="flex flex-col gap-1 border rounded-md border-base-300 h-60 overflow-auto p-1 bg-base-100">
          <div :for={{id, name, _f} <- @available} phx-click="add" phx-target={@myself} phx-value-view={@view_id} phx-value-list-id={@fieldname} phx-value-item={id}
            class="max-w-100 bg-base-200 border-solid border rounded-md border-base-300 relative p-1 hover:bg-base-300 h-10 text-base-content cursor-pointer"
            x-show="filter == '' || $el.innerHTML.toUpperCase().includes(filter.toUpperCase())"
            x-transition
            >
            <%= name %>
          </div>
        </div>

        <div class="flex flex-col gap-1 border rounded-md border-base-300 h-60 overflow-auto p-1 bg-base-100">
          <div :for={{{id, item, conf}, index} <- Enum.with_index(@selected_items)}
            class="w-full rounded-lg border border-base-300 bg-base-200 p-2.5 text-base-content shadow-sm transition hover:border-base-400 hover:bg-base-300/60">
            <div class="flex items-start gap-2">
              <div class="min-w-0 flex-1">
                <%= render_slot(@item_form, {id, item, conf, index}) %>
              </div>
              <div class="flex shrink-0 items-center gap-1.5 pt-0.5">
                <.sc_up_button :if={index > 0} phx-click="move" phx-target={@myself} phx-value-view={@view_id} phx-value-list-id={@fieldname} phx-value-item={id} phx-value-direction="up"/>
                <.sc_down_button :if={index < Enum.count(@selected_items) -1} phx-click="move" phx-target={@myself} phx-value-view={@view_id} phx-value-list-id={@fieldname} phx-value-item={id} phx-value-direction="down"/>
                <.sc_x_button phx-click="remove" phx-target={@myself} phx-value-view={@view_id} phx-value-list-id={@fieldname} phx-value-item={id}/>
              </div>
            </div>
          </div>
        </div>
      </div>
    """
  end

  def handle_event("remove", params, socket) do
    send(self(), {:list_picker_remove, params["view"], params["list-id"], params["item"]})
    {:noreply, socket}
  end

  def handle_event("add", params, socket) do
    send(self(), {:list_picker_add, params["view"], params["list-id"], params["item"]})
    {:noreply, socket}
  end

  def handle_event("move", params, socket) do
    send(
      self(),
      {:list_picker_move, params["view"], params["list-id"], params["item"], params["direction"]}
    )

    {:noreply, socket}
  end
end
