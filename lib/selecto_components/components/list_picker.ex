defmodule SelectoComponents.Components.ListPicker do
  @doc """
    Given a list of items, allow user to select items, put them in order, configure the order

    To be used by view builder

    TODO
      ability to add tooltips or descriptions to available {id, name, descr}?

  """
  use Phoenix.LiveComponent

  import SelectoComponents.Components.Common

  attr(:avail, :list, required: true)
  attr(:selected_items, :list, required: true)
  attr(:fieldname, :string, required: true)

  slot(:item_form)
  # TODO fix the selected items spacing ...
  def render(assigns) do

    {view_id, _, _, _} = assigns.view
    assigns = assign(assigns, view_id: view_id)

    ~H"""
      <div class="grid grid-cols-2 gap-1 " x-data="{ filter: ''}">
        <div>Avialable
          <.input x-model="filter" placeholder="Filter Available Items"/>
          <.x_button x-on:click="filter = ''" x-show="filter != ''"/>
        </div>

        <div>Selected</div>

        <div class="flex flex-col gap-1 border rounded-md border-grey dark:border-black h-60 overflow-auto p-1">
          <div :for={{id, name, _f} <- @available} phx-click="add" phx-target={@myself} phx-value-view={@view_id} phx-value-list-id={@fieldname} phx-value-item={id}
            class="max-w-100 bg-slate-100	dark:bg-slate-700 border-solid border rounded-md border-grey-900 dark:border-black relative p-1 hover:bg-slate-200 dark:hover:bg-slate-600 h-10"
            x-show="filter == '' || $el.innerHTML.toUpperCase().includes(filter.toUpperCase())"
            x-transition
            >
            <%= name %>
          </div>
        </div>

        <div class="flex flex-col gap-1 border rounded-md border-grey dark:border-black h-60 overflow-auto p-1">
          <div :for={{{id, item, conf}, index} <- Enum.with_index(@selected_items)}
            class="max-w-100 bg-slate-100	dark:bg-slate-700 border-solid border rounded-md border-grey-900 dark:border-black relative p-1 hover:bg-slate-200 dark:hover:bg-slate-600 min-h-10 ">
            <%= render_slot(@item_form, {id, item, conf, index}) %>

            <div class="absolute top-1 right-1">
              <.up_button :if={index > 0} phx-click="move" phx-target={@myself} phx-value-view={@view_id} phx-value-list-id={@fieldname} phx-value-item={id} phx-value-direction="up"/>
              <.down_button :if={index < Enum.count(@selected_items) -1} phx-click="move" phx-target={@myself} phx-value-view={@view_id} phx-value-list-id={@fieldname} phx-value-item={id} phx-value-direction="down"/>
              <.x_button phx-click="remove" phx-target={@myself} phx-value-view={@view_id} phx-value-list-id={@fieldname} phx-value-item={id}/>

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
    send(self(), {:list_picker_move, params["view"], params["list-id"], params["item"], params["direction"]})
    {:noreply, socket}
  end
end
