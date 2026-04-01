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
      <div
        id={"#{@component_dom_id}-filter"}
        phx-hook=".ListPickerFilter"
        data-list-picker-root
        class="grid min-w-0 grid-cols-[minmax(12rem,16rem)_minmax(0,1fr)] items-start gap-3"
      >
        <section class="min-w-0 space-y-2">
          <div class="min-w-0 text-base-content">
            <div class="text-sm font-semibold">Available</div>

            <div class="mt-2 flex items-center gap-1">
              <input data-filter-input placeholder="Filter Available Items" class="input input-bordered input-sm min-w-0 flex-1"/>
              <button data-filter-clear class="btn btn-sm btn-square btn-outline hidden" type="button">
                <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
          </div>

          <div class="flex h-96 min-w-0 flex-col gap-1 overflow-auto rounded-xl border border-base-300 bg-base-100 p-2 shadow-sm">
            <div
              :for={{id, name, _f} <- @available}
              data-picker-action="add"
              data-view-id={@view_id}
              data-list-id={@fieldname}
              data-item-id={id}
              data-available-item
              class="w-full min-w-0 cursor-pointer rounded-lg border border-base-300 bg-base-200 px-3 py-2 text-sm text-base-content transition hover:bg-base-300"
            >
              <span class="block break-words">{name}</span>
            </div>
          </div>
        </section>

        <section
          id={@component_dom_id}
          phx-hook=".ListPickerSortable"
          data-reorder-button-id={"#{@component_dom_id}-reorder-button"}
          class="flex min-w-0 flex-col gap-3 rounded-xl border border-base-300 bg-base-100 p-2 shadow-sm"
        >
          <div class="min-w-0 text-base-content">
            <div class="text-sm font-semibold">Selected</div>
          </div>

          <div class="min-h-0 flex-1 space-y-2 overflow-auto xl:h-96">
            <button
              id={"#{@component_dom_id}-reorder-button"}
              type="button"
              class="hidden"
              data-picker-action="reorder"
              data-view-id={@view_id}
              data-list-id={@fieldname}
              data-item-id=""
              data-target-item-id=""
            />

            <div :if={Enum.empty?(@selected_items)} class="rounded-lg border border-dashed border-base-300 px-4 py-6 text-center text-sm text-base-content/60">
              Pick items from the available list to add them here.
            </div>

            <div
              :for={{{id, item, conf}, index} <- Enum.with_index(@selected_items)}
              id={"#{@component_dom_id}-item-#{id}"}
              phx-hook=".ListPickerEditor"
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
                  <.sc_x_button data-picker-action="remove" data-view-id={@view_id} data-list-id={@fieldname} data-item-id={id}/>
                </div>
              </div>

              <div data-editor-content class="mt-3 hidden border-t border-base-300 pt-3">
                <%= render_slot(@item_form, {id, item, conf, index}) %>
              </div>
            </div>
          </div>
        </section>

        <script :type={Phoenix.LiveView.ColocatedHook} name=".ListPickerSortable">
          export default {
            mounted() {
              this.draggedItemId = null;

              const reorderButtonId = this.el.dataset.reorderButtonId;
              const reorderButton = reorderButtonId ? document.getElementById(reorderButtonId) : null;

              const itemElements = () => Array.from(this.el.querySelectorAll('[data-picker-item-id]'));

              const clearDropIndicators = () => {
                itemElements().forEach((item) => {
                  item.classList.remove('ring-2', 'ring-primary/40');
                });
              };

              const bindItem = (item) => {
                if (item.dataset.sortableBound === 'true') {
                  return;
                }

                item.dataset.sortableBound = 'true';

                item.addEventListener('dragstart', (event) => {
                  this.draggedItemId = item.dataset.pickerItemId;
                  item.classList.add('opacity-60');

                  if (event.dataTransfer) {
                    event.dataTransfer.effectAllowed = 'move';
                    event.dataTransfer.setData('text/plain', this.draggedItemId || '');
                  }
                });

                item.addEventListener('dragend', () => {
                  item.classList.remove('opacity-60');
                  clearDropIndicators();
                });

                item.addEventListener('dragover', (event) => {
                  if (!this.draggedItemId || this.draggedItemId === item.dataset.pickerItemId) {
                    return;
                  }

                  event.preventDefault();
                  clearDropIndicators();
                  item.classList.add('ring-2', 'ring-primary/40');
                });

                item.addEventListener('dragleave', () => {
                  item.classList.remove('ring-2', 'ring-primary/40');
                });

                item.addEventListener('drop', (event) => {
                  event.preventDefault();

                  const targetItemId = item.dataset.pickerItemId;

                  clearDropIndicators();

                  if (!this.draggedItemId || !targetItemId || this.draggedItemId === targetItemId || !reorderButton) {
                    return;
                  }

                  reorderButton.dataset.itemId = this.draggedItemId;
                  reorderButton.dataset.targetItemId = targetItemId;

                  const root = this.el.closest('[data-list-picker-root]');
                  const form = root?.closest('form');

                  this.pushEventTo(this.el, 'reorder', {
                    view: reorderButton.dataset.viewId,
                    'list-id': reorderButton.dataset.listId,
                    item: this.draggedItemId,
                    'target-item': targetItemId,
                    form_state_query: form ? new URLSearchParams(new FormData(form)).toString() : null
                  });
                });
              };

              this.bindItems = () => {
                itemElements().forEach(bindItem);
              };

              this.bindItems();
            },

            updated() {
              if (this.bindItems) {
                this.bindItems();
              }
            }
          };
        </script>

        <script :type={Phoenix.LiveView.ColocatedHook} name=".ListPickerFilter">
          export default {
            persistKey() {
              return this.el.id || 'list-picker-filter';
            },

            readPersistedFilter() {
              const store = window.__selectoListPickerFilterValues || {};
              return store[this.persistKey()] || '';
            },

            writePersistedFilter(value) {
              window.__selectoListPickerFilterValues = window.__selectoListPickerFilterValues || {};
              window.__selectoListPickerFilterValues[this.persistKey()] = value || '';
            },

            mounted() {
              this.filterValue = this.readPersistedFilter();
              this.filterWasFocused = false;

              this.bindActionHandlers();
              this.bindFilter();
              this.applyFilter();
            },

            beforeUpdate() {
              this.filterWasFocused = document.activeElement === this.filterInput;
              this.filterValue = this.filterInput ? this.filterInput.value : (this.filterValue || '');
              this.writePersistedFilter(this.filterValue);
            },

            updated() {
              this.bindActionHandlers();
              this.bindFilter();
              this.applyFilter();

              if (this.filterWasFocused && this.filterInput) {
                this.filterInput.focus();

                if (this.filterInput.setSelectionRange) {
                  const length = this.filterInput.value.length;
                  this.filterInput.setSelectionRange(length, length);
                }
              }
            },

            destroyed() {
              if (this.filterInput && this.handleFilterInput) {
                this.filterInput.removeEventListener('input', this.handleFilterInput);
                this.filterInput.removeEventListener('keydown', this.handleFilterKeydown);
              }

              if (this.clearButton && this.handleClearClick) {
                this.clearButton.removeEventListener('click', this.handleClearClick);
              }

              if (this.handleActionClick) {
                this.el.removeEventListener('click', this.handleActionClick);
              }

              this.writePersistedFilter(this.filterValue || '');
            },

            bindActionHandlers() {
              if (this.actionsBound) {
                return;
              }

              this.actionsBound = true;
              this.handleActionClick = (event) => {
                const trigger = event.target.closest('[data-picker-action]');

                if (!trigger || !this.el.contains(trigger)) {
                  return;
                }

                const action = trigger.dataset.pickerAction;

                if (!['add', 'remove'].includes(action)) {
                  return;
                }

                event.preventDefault();

                const form = this.el.closest('form');
                this.filterValue = this.filterInput ? this.filterInput.value : (this.filterValue || '');
                this.writePersistedFilter(this.filterValue);

                this.pushEventTo(this.el, action, {
                  view: trigger.dataset.viewId,
                  'list-id': trigger.dataset.listId,
                  item: trigger.dataset.itemId,
                  form_state_query: form ? new URLSearchParams(new FormData(form)).toString() : null
                });
              };

              this.el.addEventListener('click', this.handleActionClick);
            },

            bindFilter() {
              const filterInput = this.el.querySelector('[data-filter-input]');
              const clearButton = this.el.querySelector('[data-filter-clear]');

              if (this.filterInput !== filterInput) {
                if (this.filterInput && this.handleFilterInput) {
                  this.filterInput.removeEventListener('input', this.handleFilterInput);
                  this.filterInput.removeEventListener('keydown', this.handleFilterKeydown);
                }

                this.filterInput = filterInput;

                if (this.filterInput) {
                  this.filterInput.value = this.filterValue || '';

                  this.handleFilterInput = () => {
                    this.filterValue = this.filterInput.value;
                    this.writePersistedFilter(this.filterValue);
                    this.applyFilter();
                  };

                  this.handleFilterKeydown = (event) => {
                    if (event.key === 'Escape') {
                      this.filterValue = '';
                      this.filterInput.value = '';
                      this.writePersistedFilter(this.filterValue);
                      this.applyFilter();
                    }
                  };

                  this.filterInput.addEventListener('input', this.handleFilterInput);
                  this.filterInput.addEventListener('keydown', this.handleFilterKeydown);
                }
              }

              if (this.clearButton !== clearButton) {
                if (this.clearButton && this.handleClearClick) {
                  this.clearButton.removeEventListener('click', this.handleClearClick);
                }

                this.clearButton = clearButton;

                if (this.clearButton) {
                  this.handleClearClick = () => {
                    if (!this.filterInput) {
                      return;
                    }

                    this.filterValue = '';
                    this.filterInput.value = '';
                    this.writePersistedFilter(this.filterValue);
                    this.applyFilter();
                    this.filterInput.focus();
                  };

                  this.clearButton.addEventListener('click', this.handleClearClick);
                }
              }
            },

            applyFilter() {
              const filterValue = (this.filterValue || '').trim().toUpperCase();
              const items = this.el.querySelectorAll('[data-available-item]');

              items.forEach((item) => {
                const text = item.textContent.toUpperCase();
                item.style.display = !filterValue || text.includes(filterValue) ? '' : 'none';
              });

              if (this.filterInput && this.filterInput.value !== (this.filterValue || '')) {
                this.filterInput.value = this.filterValue || '';
              }

              if (this.clearButton) {
                this.clearButton.classList.toggle('hidden', filterValue === '');
              }
            }
          };
        </script>

        <script :type={Phoenix.LiveView.ColocatedHook} name=".ListPickerEditor">
          export default {
            mounted() {
              this.open = false;

              this.applyState = () => {
                const content = this.el.querySelector('[data-editor-content]');
                const openLabel = this.el.querySelector('[data-editor-open-label]');
                const closeLabel = this.el.querySelector('[data-editor-close-label]');

                if (content) {
                  content.classList.toggle('hidden', !this.open);
                }

                if (openLabel) {
                  openLabel.classList.toggle('hidden', this.open);
                }

                if (closeLabel) {
                  closeLabel.classList.toggle('hidden', !this.open);
                }
              };

              this.setOpen = (nextOpen) => {
                this.open = nextOpen;
                this.applyState();
              };

              this.handleClick = (event) => {
                if (event.target.closest('[data-editor-toggle]')) {
                  event.preventDefault();
                  this.setOpen(!this.open);
                }
              };

              this.handleDocumentClick = (event) => {
                if (!this.open || this.el.contains(event.target)) {
                  return;
                }

                this.setOpen(false);
              };

              this.el.addEventListener('click', this.handleClick);
              document.addEventListener('click', this.handleDocumentClick);
              this.applyState();
            },

            updated() {
              this.applyState();
            },

            destroyed() {
              if (this.handleClick) {
                this.el.removeEventListener('click', this.handleClick);
              }

              if (this.handleDocumentClick) {
                document.removeEventListener('click', this.handleDocumentClick);
              }
            }
          };
        </script>
      </div>
    """
  end

  def handle_event("remove", params, socket) do
    send(
      self(),
      {:list_picker_remove, params["form_state_query"], params["view"], params["list-id"],
       params["item"]}
    )

    {:noreply, socket}
  end

  def handle_event("add", params, socket) do
    send(
      self(),
      {:list_picker_add, params["form_state_query"], params["view"], params["list-id"],
       params["item"]}
    )

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
      {:list_picker_reorder, params["form_state_query"], params["view"], params["list-id"],
       params["item"], params["target-item"]}
    )

    {:noreply, socket}
  end
end
