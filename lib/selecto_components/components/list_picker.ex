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
  slot(:item_summary)

  def render(assigns) do
    {view_id, _, _, _} = assigns.view
    # Sort available items alphabetically by display name (second element in tuple)
    sorted_available =
      Enum.sort_by(assigns.available, fn {_id, name, _format} -> String.downcase(name) end)

    assigns =
      assigns
      |> assign(view_id: view_id)
      |> assign(available: sorted_available)
      |> assign(component_dom_id: "list-picker-#{assigns.id}")

    ~H"""
      <div class="grid grid-cols-1 gap-3 lg:grid-cols-[minmax(0,1fr)_minmax(0,1.15fr)]" x-data="{ filter: '' }">
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

        <div class="flex flex-col gap-1 rounded-xl border border-base-300 bg-base-100 p-2 shadow-sm h-72 overflow-auto">
          <div :for={{id, name, _f} <- @available} phx-click="add" phx-target={@myself} phx-value-view={@view_id} phx-value-list-id={@fieldname} phx-value-item={id}
            class="max-w-100 rounded-lg border border-base-300 bg-base-200 px-3 py-2 text-sm text-base-content transition hover:bg-base-300 cursor-pointer"
            x-show="filter == '' || $el.innerHTML.toUpperCase().includes(filter.toUpperCase())"
            x-transition
            >
            <%= name %>
          </div>
        </div>

        <div
          id={@component_dom_id}
          phx-hook="ListPickerSortable"
          data-reorder-button-id={"#{@component_dom_id}-reorder-button"}
          class="flex flex-col gap-2 rounded-xl border border-base-300 bg-base-100 p-2 shadow-sm h-96 overflow-auto"
        >
          <button
            id={"#{@component_dom_id}-reorder-button"}
            type="button"
            class="hidden"
            phx-click="reorder"
            phx-target={@myself}
            phx-value-view={@view_id}
            phx-value-list-id={@fieldname}
            phx-value-item=""
            phx-value-target-item=""
          />

          <div :if={Enum.empty?(@selected_items)} class="rounded-lg border border-dashed border-base-300 px-4 py-6 text-center text-sm text-base-content/60">
            Pick items from the left to add them here.
          </div>

          <div
            :for={{{id, item, conf}, index} <- Enum.with_index(@selected_items)}
            id={"#{@component_dom_id}-item-#{id}"}
            phx-hook="ListPickerEditor"
            draggable="true"
            data-picker-item-id={id}
            class="w-full rounded-xl border border-base-300 bg-base-200/80 px-3 py-2 text-base-content shadow-sm transition hover:border-base-400 hover:bg-base-300/60"
          >
            <div class="flex items-center gap-3">
              <button type="button" class="cursor-grab text-base-content/45 active:cursor-grabbing" title="Drag to reorder">
                <svg class="h-4 w-4" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                  <path d="M7 4a1.5 1.5 0 1 1-3 0 1.5 1.5 0 0 1 3 0Zm0 6a1.5 1.5 0 1 1-3 0 1.5 1.5 0 0 1 3 0Zm-1.5 7.5a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3Zm10-13.5a1.5 1.5 0 1 1-3 0 1.5 1.5 0 0 1 3 0Zm-1.5 7.5a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3Zm1.5 6a1.5 1.5 0 1 1-3 0 1.5 1.5 0 0 1 3 0Z" />
                </svg>
              </button>

              <div class="min-w-0 flex-1">
                <div class="flex min-w-0 items-center gap-2 text-sm">
                  <div class="min-w-0 flex-1 truncate font-medium">
                    <%= if @item_summary != [] do %>
                      <%= render_slot(@item_summary, {id, item, conf, index}) %>
                    <% else %>
                      <span class="truncate"><%= item %></span>
                    <% end %>
                  </div>
                </div>
              </div>

              <div class="flex shrink-0 items-center gap-1.5">
                <button
                  type="button"
                  data-editor-toggle
                  class="inline-flex h-7 items-center rounded-md border border-base-300 bg-base-100 px-2 text-xs font-medium text-base-content transition hover:border-primary/40 hover:bg-base-200"
                >
                  <span data-editor-open-label>Edit</span>
                  <span data-editor-close-label class="hidden">Close</span>
                </button>
                <.sc_x_button phx-click="remove" phx-target={@myself} phx-value-view={@view_id} phx-value-list-id={@fieldname} phx-value-item={id}/>
              </div>
            </div>

            <div data-editor-content class="mt-3 hidden border-t border-base-300 pt-3">
              <%= render_slot(@item_form, {id, item, conf, index}) %>
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

  def handle_event("reorder", params, socket) do
    send(
      self(),
      {:list_picker_reorder, params["view"], params["list-id"], params["item"],
       params["target-item"]}
    )

    {:noreply, socket}
  end
end
