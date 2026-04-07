defmodule SelectoComponents.Components.ListPicker do
  @doc """
    Given a list of items, allow user to select items, put them in order, configure the order

    To be used by view builder

    TODO
      ability to add tooltips or descriptions to available {id, name, descr}?

  """
  use Phoenix.LiveComponent

  import SelectoComponents.Components.Common
  alias SelectoComponents.Theme

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
      |> Map.put_new(:theme, Theme.default_theme(:light))
      |> assign(view_id: view_id)
      |> assign(available: sorted_available)
      |> assign(type_filters: available_type_filters(sorted_available))
      |> assign(component_dom_id: "list-picker-#{assigns.id}")

    ~H"""
    <div
      id={"#{@component_dom_id}-filter"}
      phx-hook=".ListPickerFilter"
      data-list-picker-root
      class="grid min-w-0 grid-cols-[minmax(12rem,16rem)_minmax(0,1fr)] items-start gap-3"
    >
      <section class="min-w-0 space-y-2">
        <div class="min-w-0" style="color: var(--sc-text-primary);">
          <div class="text-sm font-semibold">Available</div>

          <div class="mt-2 flex items-center gap-1">
            <input
              data-filter-input
              placeholder="Filter Available Items"
              class={Theme.slot(@theme, :input) <> " min-w-0 flex-1"}
            />
            <div class="relative">
              <button
                data-type-filter-toggle
                class={[Theme.slot(@theme, :button_secondary), "h-9", "w-9", "px-0"]}
                type="button"
                title="Filter by type"
                aria-expanded="false"
              >
                <svg class="h-6 w-6" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                  <path d="M3.75 4.5A.75.75 0 0 1 4.5 3.75h11a.75.75 0 0 1 .56 1.25L12 9.57v4.18a.75.75 0 0 1-.38.65l-2 1.14A.75.75 0 0 1 8.5 14.9V9.57L3.94 5a.75.75 0 0 1-.19-.5Z" />
                </svg>
              </button>
              <div
                data-type-filter-menu
                class="absolute right-0 z-20 mt-2 hidden min-w-[12rem] rounded-xl border p-3 shadow-lg"
                style="border-color: var(--sc-surface-border); background: var(--sc-surface-bg); color: var(--sc-text-primary);"
              >
                <div
                  class="mb-2 text-[0.7rem] font-semibold uppercase tracking-[0.18em]"
                  style="color: var(--sc-text-muted);"
                >
                  Show types
                </div>
                <div class="space-y-2">
                  <label
                    :for={type_filter <- @type_filters}
                    class="flex items-center gap-2 text-sm"
                    style="color: var(--sc-text-secondary);"
                  >
                    <input
                      data-type-filter-checkbox
                      type="checkbox"
                      value={type_filter.key}
                      class="checkbox checkbox-sm"
                      style="border-color: var(--sc-surface-border); background: var(--sc-surface-bg); color: var(--sc-accent);"
                    />
                    <.type_badge type={%{icon: String.to_atom(type_filter.key)}} />
                    <span class="flex-1">{type_filter.label}</span>
                    <span class="text-xs" style="color: var(--sc-text-muted);">
                      {type_filter.count}
                    </span>
                  </label>
                </div>
              </div>
            </div>
            <button
              data-filter-clear
              class={[Theme.slot(@theme, :button_danger), "hidden", "h-7", "w-7"]}
              type="button"
              title="Clear filter"
            >
              <span aria-hidden="true" class="text-base leading-none">×</span>
            </button>
          </div>
        </div>

        <div
          class={Theme.slot(@theme, :panel) <> " flex h-96 min-w-0 flex-col gap-1 overflow-auto p-2"}
          style="background: var(--sc-surface-bg-alt);"
        >
          <div
            :for={{id, name, field_type} <- @available}
            data-picker-action="add"
            data-view-id={@view_id}
            data-list-id={@fieldname}
            data-item-id={id}
            data-type-key={normalize_icon_key(field_type)}
            data-available-item
            class="w-full min-w-0 cursor-pointer rounded-lg border px-3 py-2 text-sm transition"
            style="border-color: var(--sc-surface-border); background: var(--sc-surface-bg); color: var(--sc-text-primary);"
          >
            <div class="flex items-start gap-2">
              <.type_badge type={field_type} />
              <span class="block break-words">{name}</span>
            </div>
          </div>
        </div>
      </section>

      <section
        id={@component_dom_id}
        phx-hook=".ListPickerSortable"
        data-reorder-button-id={"#{@component_dom_id}-reorder-button"}
        class={Theme.slot(@theme, :panel) <> " flex min-w-0 flex-col gap-3 p-2"}
        style="background: var(--sc-surface-bg);"
      >
        <div class="min-w-0" style="color: var(--sc-text-primary);">
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

          <div
            :if={Enum.empty?(@selected_items)}
            class="rounded-lg border border-dashed px-4 py-6 text-center text-sm"
            style="border-color: var(--sc-surface-border); color: var(--sc-text-muted);"
          >
            Pick items from the available list to add them here.
          </div>

          <div
            :for={{{id, item, conf}, index} <- Enum.with_index(@selected_items)}
            id={"#{@component_dom_id}-item-#{id}"}
            phx-hook=".ListPickerEditor"
            draggable="true"
            data-picker-item-id={id}
            class="w-full rounded-xl border px-3 py-2 shadow-sm transition"
            style="border-color: var(--sc-surface-border); background: color-mix(in srgb, var(--sc-surface-bg-alt) 65%, var(--sc-surface-bg)); color: var(--sc-text-primary);"
          >
            <% selected_type = selected_item_type(@available, item) %>
            <div class="flex items-center gap-3">
              <button
                type="button"
                class="cursor-grab active:cursor-grabbing"
                style="color: var(--sc-text-muted);"
                title="Drag to reorder"
              >
                <svg class="h-4 w-4" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                  <path d="M7 4a1.5 1.5 0 1 1-3 0 1.5 1.5 0 0 1 3 0Zm0 6a1.5 1.5 0 1 1-3 0 1.5 1.5 0 0 1 3 0Zm-1.5 7.5a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3Zm10-13.5a1.5 1.5 0 1 1-3 0 1.5 1.5 0 0 1 3 0Zm-1.5 7.5a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3Zm1.5 6a1.5 1.5 0 1 1-3 0 1.5 1.5 0 0 1 3 0Z" />
                </svg>
              </button>

              <div class="min-w-0 flex-1">
                <div class="flex min-w-0 items-center gap-2 text-sm">
                  <.type_badge type={selected_type} />
                  <div class="min-w-0 flex-1 truncate font-medium">
                    <%= if @item_summary != [] do %>
                      {render_slot(@item_summary, {id, item, conf, index})}
                    <% else %>
                      <span class="truncate">{item}</span>
                    <% end %>
                  </div>
                </div>
              </div>

              <div class="flex shrink-0 items-center gap-1.5">
                <button
                  type="button"
                  data-editor-toggle
                  class={[Theme.slot(@theme, :button_secondary), "h-7", "px-2", "text-xs"]}
                >
                  <span data-editor-open-label>Edit</span>
                  <span data-editor-close-label class="hidden">Close</span>
                </button>
                <.sc_x_button
                  theme={@theme}
                  data-picker-action="remove"
                  data-view-id={@view_id}
                  data-list-id={@fieldname}
                  data-item-id={id}
                />
              </div>
            </div>

            <div
              data-editor-content
              class="mt-3 hidden border-t pt-3"
              style="border-color: var(--sc-surface-border);"
            >
              {render_slot(@item_form, {id, item, conf, index})}
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

          typePersistKey() {
            return `${this.persistKey()}::type-filters`;
          },

          readPersistedFilter() {
            const store = window.__selectoListPickerFilterValues || {};
            return store[this.persistKey()] || '';
          },

          readPersistedTypeFilters() {
            const store = window.__selectoListPickerTypeFilters || {};
            return store[this.typePersistKey()] || [];
          },

          writePersistedFilter(value) {
            window.__selectoListPickerFilterValues = window.__selectoListPickerFilterValues || {};
            window.__selectoListPickerFilterValues[this.persistKey()] = value || '';
          },

          writePersistedTypeFilters(values) {
            window.__selectoListPickerTypeFilters = window.__selectoListPickerTypeFilters || {};
            window.__selectoListPickerTypeFilters[this.typePersistKey()] = values || [];
          },

          mounted() {
            this.filterValue = this.readPersistedFilter();
            this.selectedTypeFilters = this.readPersistedTypeFilters();
            this.filterWasFocused = false;

            this.bindActionHandlers();
            this.bindFilter();
            this.bindTypeFilters();
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
            this.bindTypeFilters();
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

            if (this.typeFilterToggle && this.handleTypeFilterToggle) {
              this.typeFilterToggle.removeEventListener('click', this.handleTypeFilterToggle);
            }

            if (this.typeFilterMenu && this.handleTypeFilterDocumentClick) {
              document.removeEventListener('click', this.handleTypeFilterDocumentClick);
            }

            if (this.typeFilterCheckboxes && this.handleTypeFilterChange) {
              this.typeFilterCheckboxes.forEach((checkbox) => {
                checkbox.removeEventListener('change', this.handleTypeFilterChange);
              });
            }

            if (this.handleActionClick) {
              this.el.removeEventListener('click', this.handleActionClick);
            }

            this.writePersistedFilter(this.filterValue || '');
            this.writePersistedTypeFilters(this.selectedTypeFilters || []);
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

          bindTypeFilters() {
            this.typeFilterToggle = this.el.querySelector('[data-type-filter-toggle]');
            this.typeFilterMenu = this.el.querySelector('[data-type-filter-menu]');
            this.typeFilterCheckboxes = Array.from(this.el.querySelectorAll('[data-type-filter-checkbox]'));

            if (this.typeFilterToggle && !this.handleTypeFilterToggle) {
              this.handleTypeFilterToggle = (event) => {
                event.preventDefault();
                this.typeFilterMenu?.classList.toggle('hidden');
                this.typeFilterToggle.setAttribute(
                  'aria-expanded',
                  this.typeFilterMenu?.classList.contains('hidden') ? 'false' : 'true'
                );
              };

              this.typeFilterToggle.addEventListener('click', this.handleTypeFilterToggle);
            }

            if (!this.handleTypeFilterDocumentClick) {
              this.handleTypeFilterDocumentClick = (event) => {
                if (!this.typeFilterMenu || this.typeFilterMenu.classList.contains('hidden')) {
                  return;
                }

                if (this.typeFilterMenu.contains(event.target) || this.typeFilterToggle?.contains(event.target)) {
                  return;
                }

                this.typeFilterMenu.classList.add('hidden');
                this.typeFilterToggle?.setAttribute('aria-expanded', 'false');
              };

              document.addEventListener('click', this.handleTypeFilterDocumentClick);
            }

            this.handleTypeFilterChange = () => {
              this.selectedTypeFilters = this.typeFilterCheckboxes
                .filter((checkbox) => checkbox.checked)
                .map((checkbox) => checkbox.value);

              this.writePersistedTypeFilters(this.selectedTypeFilters);
              this.applyFilter();
            };

            this.typeFilterCheckboxes.forEach((checkbox) => {
              checkbox.checked = this.selectedTypeFilters.includes(checkbox.value);
              checkbox.removeEventListener('change', this.handleTypeFilterChange);
              checkbox.addEventListener('change', this.handleTypeFilterChange);
            });
          },

          applyFilter() {
            const filterValue = (this.filterValue || '').trim().toUpperCase();
            const items = this.el.querySelectorAll('[data-available-item]');
            const typeFilters = this.selectedTypeFilters || [];

            items.forEach((item) => {
              const text = item.textContent.toUpperCase();
              const typeKey = item.dataset.typeKey || 'unknown';
              const textMatch = !filterValue || text.includes(filterValue);
              const typeMatch = typeFilters.length === 0 || typeFilters.includes(typeKey);

              item.style.display = textMatch && typeMatch ? '' : 'none';
            });

            if (this.filterInput && this.filterInput.value !== (this.filterValue || '')) {
              this.filterInput.value = this.filterValue || '';
            }

            if (this.clearButton) {
              this.clearButton.classList.toggle('hidden', filterValue === '' && typeFilters.length === 0);
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

  defp selected_item_type(available, item) do
    item_str = to_string(item || "")

    Enum.find_value(available || [], :unknown, fn
      {id, name, field_type} ->
        cond do
          to_string(id) == item_str -> field_type
          to_string(name) == item_str -> field_type
          true -> nil
        end

      _ ->
        nil
    end)
  end

  defp available_type_filters(available) do
    available
    |> Enum.reduce(%{}, fn {_id, _name, field_type}, acc ->
      key = normalize_icon_key(field_type)
      Map.update(acc, key, 1, &(&1 + 1))
    end)
    |> Enum.map(fn {key, count} ->
      %{key: to_string(key), label: type_badge_label(%{icon: key}), count: count}
    end)
    |> Enum.sort_by(& &1.label)
  end

  attr(:type, :any, required: true)

  defp type_badge(assigns) do
    icon_key = normalize_icon_key(assigns.type)

    assigns =
      assigns
      |> assign(:icon_key, icon_key)
      |> assign(:label, type_badge_label(assigns.type))
      |> assign(:style, type_badge_style(assigns.type))

    ~H"""
    <span
      data-type-icon={@label}
      aria-label={@label}
      title={@label}
      class="inline-flex h-4 w-4 shrink-0 items-center justify-center"
      style={@style}
    >
      <%= case @icon_key do %>
        <% :number -> %>
          <svg class="h-3.5 w-3.5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
            <path d="M7.5 4.5a1 1 0 0 1 2 0V8h2V4.5a1 1 0 1 1 2 0V8h1a1 1 0 1 1 0 2h-1v2h1a1 1 0 1 1 0 2h-1v1.5a1 1 0 1 1-2 0V14h-2v1.5a1 1 0 1 1-2 0V14h-1a1 1 0 1 1 0-2h1v-2h-1a1 1 0 1 1 0-2h1V4.5Zm2 5.5v2h2v-2h-2Z" />
          </svg>
        <% :currency -> %>
          <svg class="h-3.5 w-3.5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
            <path d="M10.75 2.75a.75.75 0 0 0-1.5 0v.64c-1.92.26-3.25 1.52-3.25 3.28 0 1.95 1.55 2.77 3.3 3.3l.7.22v4.03c-1.14-.14-1.95-.8-2.34-1.78a.75.75 0 1 0-1.4.56c.58 1.46 1.85 2.36 3.74 2.55v.7a.75.75 0 0 0 1.5 0v-.7c2.05-.22 3.5-1.55 3.5-3.5 0-2.02-1.54-2.9-3.47-3.48l-.03-.01V5c.86.13 1.46.63 1.8 1.32a.75.75 0 1 0 1.35-.66c-.56-1.13-1.53-1.83-3.15-2V2.75ZM10 8.63c-1.46-.45-2.25-.9-2.25-1.92 0-.9.72-1.56 2.25-1.73v3.65Zm1.5 1.83c1.57.5 2.5.98 2.5 2.12 0 1.02-.8 1.78-2.5 1.96v-4.08Z" />
          </svg>
        <% :percentage -> %>
          <svg class="h-3.5 w-3.5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
            <path d="M5.5 5.25a1.75 1.75 0 1 1 0 3.5 1.75 1.75 0 0 1 0-3.5Zm9 6a1.75 1.75 0 1 1 0 3.5 1.75 1.75 0 0 1 0-3.5ZM14.03 4.47a.75.75 0 0 1 .5 1.06l-7.5 10a.75.75 0 1 1-1.2-.9l7.5-10a.75.75 0 0 1 .7-.16Z" />
          </svg>
        <% :date -> %>
          <svg class="h-3.5 w-3.5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
            <path d="M6 2.75a.75.75 0 0 1 1.5 0V4h5V2.75a.75.75 0 0 1 1.5 0V4h.5A2.5 2.5 0 0 1 17 6.5v8A2.5 2.5 0 0 1 14.5 17h-9A2.5 2.5 0 0 1 3 14.5v-8A2.5 2.5 0 0 1 5.5 4H6V2.75ZM4.5 8v6.5c0 .552.448 1 1 1h9c.552 0 1-.448 1-1V8h-11Z" />
          </svg>
        <% :time -> %>
          <svg class="h-3.5 w-3.5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
            <path d="M10 3a7 7 0 1 0 0 14 7 7 0 0 0 0-14Zm.75 3.25a.75.75 0 0 0-1.5 0V10c0 .24.11.47.3.61l2.5 1.88a.75.75 0 1 0 .9-1.2l-2.2-1.65V6.25Z" />
          </svg>
        <% :boolean -> %>
          <svg class="h-3.5 w-3.5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
            <path d="M3 10a4 4 0 0 1 4-4h6a4 4 0 1 1 0 8H7a4 4 0 0 1-4-4Zm10 2a2 2 0 1 0 0-4 2 2 0 0 0 0 4Z" />
          </svg>
        <% :text -> %>
          <svg class="h-3.5 w-3.5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
            <path d="M4.5 5.5A1.5 1.5 0 0 1 6 4h8a1 1 0 1 1 0 2H11v8a1 1 0 1 1-2 0V6H6a1.5 1.5 0 0 1-1.5-1.5Z" />
          </svg>
        <% :relation -> %>
          <svg class="h-3.5 w-3.5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
            <path d="M4.75 3a1.75 1.75 0 1 0 0 3.5A1.75 1.75 0 0 0 4.75 3ZM13.5 5.5a1.5 1.5 0 0 1 1.5 1.5v1.2a2.3 2.3 0 0 0-.7-.1H9.44a2.75 2.75 0 0 0-2.44-1.5H6.3a2.74 2.74 0 0 0-.31-1.2H13.5ZM15.25 13.5a1.75 1.75 0 1 0 0 3.5 1.75 1.75 0 0 0 0-3.5ZM5 9.1A1.5 1.5 0 0 1 6.5 7.6h.5A1.5 1.5 0 0 1 8.5 9.1v.4h5.8A1.7 1.7 0 0 1 16 11.2v1.1a2.74 2.74 0 0 0-1.2-.3h-.46A2.75 2.75 0 0 0 11.7 10H8.4A2.4 2.4 0 0 1 6 12.4H5V9.1Z" />
          </svg>
        <% :list -> %>
          <svg class="h-3.5 w-3.5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
            <path d="M5 4.75A1.25 1.25 0 1 1 2.5 4.75 1.25 1.25 0 0 1 5 4.75ZM6.75 4a.75.75 0 0 0 0 1.5H16a.75.75 0 0 0 0-1.5H6.75ZM5 10a1.25 1.25 0 1 1-2.5 0A1.25 1.25 0 0 1 5 10Zm1.75-.75a.75.75 0 0 0 0 1.5H16a.75.75 0 0 0 0-1.5H6.75ZM5 15.25a1.25 1.25 0 1 1-2.5 0 1.25 1.25 0 0 1 2.5 0ZM6.75 14.5a.75.75 0 0 0 0 1.5H16a.75.75 0 0 0 0-1.5H6.75Z" />
          </svg>
        <% :json -> %>
          <svg class="h-3.5 w-3.5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
            <path d="M7.25 4a.75.75 0 0 1 0 1.5c-.69 0-1.25.56-1.25 1.25v1.5c0 .86-.37 1.63-.96 2.15.59.52.96 1.29.96 2.15v1.5c0 .69.56 1.25 1.25 1.25a.75.75 0 0 1 0 1.5A2.75 2.75 0 0 1 4.5 15.25v-1.5c0-.78-.52-1.45-1.24-1.66a.75.75 0 0 1 0-1.44c.72-.2 1.24-.88 1.24-1.65v-1.5A2.75 2.75 0 0 1 7.25 4Zm5.5 0A2.75 2.75 0 0 1 15.5 6.75v1.5c0 .77.52 1.44 1.24 1.65a.75.75 0 0 1 0 1.44c-.72.2-1.24.88-1.24 1.66v1.5A2.75 2.75 0 0 1 12.75 18a.75.75 0 0 1 0-1.5c.69 0 1.25-.56 1.25-1.25v-1.5c0-.86.37-1.63.96-2.15a2.88 2.88 0 0 1-.96-2.15v-1.5c0-.69-.56-1.25-1.25-1.25a.75.75 0 0 1 0-1.5Z" />
          </svg>
        <% :uuid -> %>
          <svg class="h-3.5 w-3.5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
            <path d="M7.5 3.5A2.5 2.5 0 0 0 5 6v1.1a2.4 2.4 0 0 0-1.5 2.24v1.3A2.5 2.5 0 0 0 6 13.15h1.1A2.4 2.4 0 0 0 9.35 15.5h1.3a2.4 2.4 0 0 0 2.25-1.5H14A2.5 2.5 0 0 0 16.5 11.5V10.2A2.4 2.4 0 0 0 18 7.95v-1.3A2.5 2.5 0 0 0 15.5 4.15H14.4A2.4 2.4 0 0 0 12.15 2h-1.3A2.4 2.4 0 0 0 8.6 3.5H7.5Zm1 1.5h2.9a.75.75 0 0 0 .74-.62A.9.9 0 0 1 13 3.5h1.3c.43 0 .79.3.88.72a.75.75 0 0 0 .73.58H17a1 1 0 0 1 1 1v1.3a.9.9 0 0 1-.72.88.75.75 0 0 0-.58.73V10a.75.75 0 0 0 .62.74c.42.09.73.45.73.88V13a1 1 0 0 1-1 1h-1.1a.75.75 0 0 0-.74.62.9.9 0 0 1-.88.73H13a.9.9 0 0 1-.88-.73.75.75 0 0 0-.73-.62H8.5a.75.75 0 0 0-.74.62.9.9 0 0 1-.88.73H5.6A.9.9 0 0 1 4.7 13.9V12.6c0-.43.3-.79.72-.88A.75.75 0 0 0 6 11V8.5a.75.75 0 0 0-.62-.74.9.9 0 0 1-.73-.88V5.6a.9.9 0 0 1 .9-.9H6.9a.75.75 0 0 0 .73-.58A.9.9 0 0 1 8.5 5Z" />
          </svg>
        <% :binary -> %>
          <svg class="h-3.5 w-3.5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
            <path d="M4 4.75A1.75 1.75 0 1 1 7.5 4.75 1.75 1.75 0 0 1 4 4.75Zm0 10.5A1.75 1.75 0 1 1 7.5 15.25 1.75 1.75 0 0 1 4 15.25ZM12.5 4.75a1.75 1.75 0 1 1 3.5 0 1.75 1.75 0 0 1-3.5 0Zm0 10.5a1.75 1.75 0 1 1 3.5 0 1.75 1.75 0 0 1-3.5 0ZM8.75 5.5h2.5v1.5h-2.5V5.5Zm0 7.5h2.5v1.5h-2.5V13Z" />
          </svg>
        <% :spatial -> %>
          <svg class="h-3.5 w-3.5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
            <path d="M10 2.5c-2.76 0-5 2.11-5 4.72 0 3.28 4.23 8.37 4.41 8.58a.75.75 0 0 0 1.18 0c.18-.21 4.41-5.3 4.41-8.58C15 4.61 12.76 2.5 10 2.5Zm0 6.22a1.75 1.75 0 1 1 0-3.5 1.75 1.75 0 0 1 0 3.5Z" />
          </svg>
        <% _ -> %>
          <svg class="h-3.5 w-3.5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
            <path d="M10 3a7 7 0 1 0 0 14 7 7 0 0 0 0-14Zm.75 10.25a.75.75 0 0 1-1.5 0v-3a.75.75 0 0 1 1.5 0v3Zm0-5.5a.75.75 0 1 1-1.5 0 .75.75 0 0 1 1.5 0Z" />
          </svg>
      <% end %>
    </span>
    """
  end

  defp type_badge_label(type) do
    case normalize_icon_key(type) do
      :number -> "Numeric"
      :currency -> "Currency"
      :percentage -> "Percentage"
      :date -> "Date"
      :time -> "Time"
      :boolean -> "Boolean"
      :text -> "Text"
      :relation -> "Relation"
      :list -> "List"
      :json -> "JSON"
      :uuid -> "UUID"
      :binary -> "Binary"
      :spatial -> "Spatial"
      _ -> "Any"
    end
  end

  defp type_badge_style(type) do
    case normalize_icon_key(type) do
      :number ->
        "color: color-mix(in srgb, var(--sc-text-primary) 82%, var(--sc-accent)); opacity: 0.82;"

      :currency ->
        "color: color-mix(in srgb, var(--sc-text-primary) 84%, #3d7d62); opacity: 0.82;"

      :percentage ->
        "color: color-mix(in srgb, var(--sc-text-primary) 84%, #8a6a16); opacity: 0.82;"

      :date ->
        "color: color-mix(in srgb, var(--sc-text-primary) 84%, #4e8a73); opacity: 0.82;"

      :time ->
        "color: color-mix(in srgb, var(--sc-text-primary) 84%, #607aa0); opacity: 0.82;"

      :boolean ->
        "color: color-mix(in srgb, var(--sc-text-primary) 84%, #947339); opacity: 0.82;"

      :text ->
        "color: var(--sc-text-secondary); opacity: 0.8;"

      :relation ->
        "color: color-mix(in srgb, var(--sc-text-primary) 84%, #b16b80); opacity: 0.82;"

      :list ->
        "color: color-mix(in srgb, var(--sc-text-primary) 84%, #6b89b5); opacity: 0.82;"

      :json ->
        "color: color-mix(in srgb, var(--sc-text-primary) 84%, #8663a8); opacity: 0.82;"

      :uuid ->
        "color: color-mix(in srgb, var(--sc-text-primary) 84%, #7f7f9c); opacity: 0.82;"

      :binary ->
        "color: color-mix(in srgb, var(--sc-text-primary) 84%, #7d7d7d); opacity: 0.82;"

      :spatial ->
        "color: color-mix(in srgb, var(--sc-text-primary) 84%, #5f8b73); opacity: 0.82;"

      _ ->
        "color: var(--sc-text-muted); opacity: 0.78;"
    end
  end

  defp normalize_icon_key(%{} = metadata) do
    metadata[:icon] || metadata["icon"] || metadata[:icon_family] || metadata["icon_family"] ||
      icon_key_from_format(metadata[:format] || metadata["format"]) ||
      normalize_type_family(metadata[:type] || metadata["type"])
  end

  defp normalize_icon_key(type), do: icon_key_from_format(nil) || normalize_type_family(type)

  defp icon_key_from_format(format) when format in [:currency, :currency_with_symbol],
    do: :currency

  defp icon_key_from_format(format) when format in [:percentage, :percent], do: :percentage
  defp icon_key_from_format(_), do: nil

  defp normalize_type_family(type) when type in [:id, :integer, :float, :decimal], do: :number

  defp normalize_type_family(type)
       when type in [:utc_datetime, :naive_datetime, :date, :datetime], do: :date

  defp normalize_type_family(:boolean), do: :boolean
  defp normalize_type_family(type) when type in [:string, :text, :citext, :tsvector], do: :text
  defp normalize_type_family(:time), do: :time
  defp normalize_type_family(:uuid), do: :uuid
  defp normalize_type_family(:binary), do: :binary

  defp normalize_type_family(type)
       when type in [:lookup, :star_dimension, :tag_dimension, :component, :link], do: :relation

  defp normalize_type_family({:array, _}), do: :list
  defp normalize_type_family(type) when type in [:map, :json, :jsonb], do: :json

  defp normalize_type_family(type)
       when type in [
              :geometry,
              :geography,
              :point,
              :linestring,
              :polygon,
              :multipoint,
              :multilinestring,
              :multipolygon,
              :geometrycollection
            ],
       do: :spatial

  defp normalize_type_family(_), do: :unknown
end
