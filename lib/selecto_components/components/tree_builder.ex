defmodule SelectoComponents.Components.TreeBuilder do
  use Phoenix.LiveComponent

  # available,
  # filters

  import SelectoComponents.Components.Common
  alias SelectoComponents.Theme

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    # When the component ID changes, Phoenix will remount the component entirely
    # This ensures all form fields are properly recreated
    {:ok, assign(socket, Map.put_new(assigns, :theme, Theme.default_theme(:light)))}
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :type_filters, available_type_filters(assigns.available))

    ~H"""
    <div class="tree-builder-component" style="color: var(--sc-text-primary);">
      <div class="">
        <div phx-hook=".TreeBuilder" id={"tree-builder-#{@id}"} class="grid grid-cols-2 gap-1 h-80" data-filter="">

          <div style="color: var(--sc-text-primary);">Available Filter Columns. Double Click or Drag to build area.
            <div class="mt-2 flex items-center gap-1">
              <input type="text" id={"filter-input-#{@id}"} placeholder="Filter Available Items" class={Theme.slot(@theme, :input) <> " min-w-0 flex-1"} />
              <div class="relative">
                <button id={"type-filter-toggle-#{@id}"} data-type-filter-toggle class={[Theme.slot(@theme, :button_secondary), "h-7", "w-8", "px-0"]} type="button" title="Filter by type" aria-expanded="false">
                  <svg class="h-4 w-4" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                    <path d="M3.75 4.5A.75.75 0 0 1 4.5 3.75h11a.75.75 0 0 1 .56 1.25L12 9.57v4.18a.75.75 0 0 1-.38.65l-2 1.14A.75.75 0 0 1 8.5 14.9V9.57L3.94 5a.75.75 0 0 1-.19-.5Z" />
                  </svg>
                </button>
                <div data-type-filter-menu class="absolute right-0 z-20 mt-2 hidden min-w-[12rem] rounded-xl border p-3 shadow-lg" style="border-color: var(--sc-surface-border); background: var(--sc-surface-bg); color: var(--sc-text-primary);">
                  <div class="mb-2 text-[0.7rem] font-semibold uppercase tracking-[0.18em]" style="color: var(--sc-text-muted);">Show types</div>
                  <div class="space-y-2">
                    <label :for={type_filter <- @type_filters} class="flex items-center gap-2 text-sm" style="color: var(--sc-text-secondary);">
                      <input data-type-filter-checkbox type="checkbox" value={to_string(type_filter.key)} class="checkbox checkbox-sm" style="border-color: var(--sc-surface-border); background: var(--sc-surface-bg); color: var(--sc-accent);" />
                      <.type_glyph type={%{icon: type_filter.key}} />
                      <span class="flex-1">{type_filter.label}</span>
                      <span class="text-xs" style="color: var(--sc-text-muted);">{type_filter.count}</span>
                    </label>
                  </div>
                </div>
              </div>
              <button id={"clear-filter-#{@id}"} class={[Theme.slot(@theme, :button_danger), "h-7", "w-7"]} type="button" title="Clear filter">×</button>
            </div>
          </div>
          <div style="color: var(--sc-text-primary);">Build Area. All top level filters are AND'd together and AND'd with the required filters from the domain.</div>

          <div class={Theme.slot(@theme, :panel) <> " flex flex-col gap-1 overflow-auto p-1"} style="background: var(--sc-surface-bg-alt);" id={"available-items-#{@id}"}>



            <div class="max-w-100 min-h-10 cursor-pointer rounded-md border p-1 filterable-item"
              style="background: var(--sc-surface-bg); border-color: var(--sc-surface-border); color: var(--sc-text-primary);"
              draggable="true" data-item-id="__AND__" id={"#{@id}-__AND__"}>AND group</div>
            <div class="max-w-100 min-h-10 cursor-pointer rounded-md border p-1 filterable-item"
              style="background: var(--sc-surface-bg); border-color: var(--sc-surface-border); color: var(--sc-text-primary);"
              draggable="true" data-item-id="__OR__" id={"#{@id}-__OR__"}>OR group</div>


            <div :for={{{id, name, type_meta}, idx} <- Enum.with_index(@available)}
              class="max-w-100 min-h-10 cursor-pointer rounded-md border p-1 filterable-item"
              style="background: var(--sc-surface-bg); border-color: var(--sc-surface-border); color: var(--sc-text-primary);"
              draggable="true" data-item-id={id}
              data-type-key={normalize_icon_key(type_meta)}
              id={"#{@id}-available-#{id}-#{idx}"}>
              <div class="flex items-center gap-2">
                <.type_glyph type={type_meta} />
                <span><%= name %></span>
              </div>
            </div>

          </div>
          <div class={Theme.slot(@theme, :panel) <> " grid grid-cols-1 gap-1 overflow-auto p-1 drop-zone"} style="background: var(--sc-surface-bg);" data-drop-zone="filters">
            <%= render_area(%{ available: @available, filters: Enum.with_index(@filters), section: "filters", index: 0, conjunction: "AND", filter_form: @filter_form, component_id: @id }) %>
          </div>
        </div>
      </div>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".TreeBuilder">
        export default {
          draggedElement: null,
          initialized: false,

          componentId() {
            return this.el.id.replace('tree-builder-', '');
          },

          persistKey() {
            return this.componentId().replace(/_\d+$/, '');
          },

          readPersistedFilter() {
            const store = window.__selectoTreeBuilderFilterValues || {};
            return store[this.persistKey()] || '';
          },

          writePersistedFilter(value) {
            window.__selectoTreeBuilderFilterValues = window.__selectoTreeBuilderFilterValues || {};
            window.__selectoTreeBuilderFilterValues[this.persistKey()] = value || '';
          },

          typePersistKey() {
            return `${this.persistKey()}::type-filters`;
          },

          readPersistedTypeFilters() {
            const store = window.__selectoTreeBuilderTypeFilterValues || {};
            return store[this.typePersistKey()] || [];
          },

          writePersistedTypeFilters(values) {
            window.__selectoTreeBuilderTypeFilterValues = window.__selectoTreeBuilderTypeFilterValues || {};
            window.__selectoTreeBuilderTypeFilterValues[this.typePersistKey()] = values || [];
          },

          initializeDragDrop() {
            if (this.initialized) {
              return;
            }

            const hook = this;

            this.onDragStart = (e) => {
              if (e.target.getAttribute('draggable') === 'true') {
                hook.draggedElement = e.target.getAttribute('data-item-id') || e.target.id;
                e.dataTransfer.effectAllowed = 'move';
                e.dataTransfer.setData('text/plain', hook.draggedElement);
                e.target.style.opacity = '0.5';
              }
            };

            this.onDragEnd = (e) => {
              if (e.target.getAttribute('draggable') === 'true') {
                e.target.style.opacity = '';
              }
            };

            this.onDoubleClick = (e) => {
              if (e.target.getAttribute('draggable') === 'true') {
                const elementId = e.target.getAttribute('data-item-id') || e.target.id;
                hook.pushEvent('treedrop', {
                  target: 'filters',
                  element: elementId
                });
              }
            };

            this.onDragOver = (e) => {
              if (e.target.classList.contains('drop-zone') || e.target.hasAttribute('data-drop-zone')) {
                e.preventDefault();
                e.dataTransfer.dropEffect = 'move';
                e.target.classList.add('bg-blue-50');
              }
            };

            this.onDragLeave = (e) => {
              if (e.target.classList.contains('drop-zone') || e.target.hasAttribute('data-drop-zone')) {
                if (!e.target.contains(e.relatedTarget)) {
                  e.target.classList.remove('bg-blue-50');
                }
              }
            };

            this.onDrop = (e) => {
              if (e.target.classList.contains('drop-zone') || e.target.hasAttribute('data-drop-zone')) {
                e.preventDefault();
                e.stopPropagation();
                e.target.classList.remove('bg-blue-50');

                const draggedId = e.dataTransfer.getData('text/plain') || hook.draggedElement;
                const targetId = e.target.getAttribute('data-drop-zone') || e.target.id;

                if (draggedId && targetId) {
                  hook.pushEvent('treedrop', {
                    target: targetId,
                    element: draggedId
                  });
                }
                hook.draggedElement = null;
              }
            };

            this.el.addEventListener('dragstart', this.onDragStart);
            this.el.addEventListener('dragend', this.onDragEnd);
            this.el.addEventListener('dblclick', this.onDoubleClick);
            this.el.addEventListener('dragover', this.onDragOver);
            this.el.addEventListener('dragleave', this.onDragLeave);
            this.el.addEventListener('drop', this.onDrop);

            this.initialized = true;
          },

            bindFilter() {
            const componentId = this.componentId();
            const filterInput = this.el.querySelector(`#filter-input-${componentId}`);
            const clearButton = this.el.querySelector(`#clear-filter-${componentId}`);

            if (this.filterInput !== filterInput) {
              if (this.filterInput && this.onFilterInput) {
                this.filterInput.removeEventListener('input', this.onFilterInput);
              }

              if (this.filterInput && this.onFilterKeydown) {
                this.filterInput.removeEventListener('keydown', this.onFilterKeydown);
              }

              this.filterInput = filterInput;

              if (this.filterInput) {
                this.filterInput.value = this.filterValue || '';

                this.onFilterInput = (e) => {
                  e.stopPropagation();
                  this.filterValue = e.target.value;
                  this.writePersistedFilter(this.filterValue);
                  this.applyFilter();
                };

                this.onFilterKeydown = (e) => {
                  if (e.key === 'Escape') {
                    this.filterValue = '';
                    this.filterInput.value = '';
                    this.writePersistedFilter(this.filterValue);
                    this.applyFilter();
                  }
                };

                this.filterInput.addEventListener('input', this.onFilterInput);
                this.filterInput.addEventListener('keydown', this.onFilterKeydown);
              }
            } else if (this.filterInput && this.filterInput.value !== (this.filterValue || '')) {
              this.filterInput.value = this.filterValue || '';
            }

              if (this.clearButton !== clearButton) {
              if (this.clearButton && this.onClearClick) {
                this.clearButton.removeEventListener('click', this.onClearClick);
              }

              this.clearButton = clearButton;

                if (this.clearButton) {
                  this.onClearClick = () => {
                  if (!this.filterInput) {
                    return;
                  }

                  this.filterValue = '';
                  this.filterInput.value = '';
                  this.writePersistedFilter(this.filterValue);
                  this.applyFilter();
                  this.filterInput.focus();
                };

                  this.clearButton.addEventListener('click', this.onClearClick);
                }
              }
            },

            bindTypeFilters() {
              this.typeFilterToggle = this.el.querySelector('[data-type-filter-toggle]');
              this.typeFilterMenu = this.el.querySelector('[data-type-filter-menu]');
              this.typeFilterCheckboxes = Array.from(this.el.querySelectorAll('[data-type-filter-checkbox]'));

              if (this.typeFilterToggle && !this.onTypeFilterToggle) {
                this.onTypeFilterToggle = (event) => {
                  event.preventDefault();
                  this.typeFilterMenu?.classList.toggle('hidden');
                  this.typeFilterToggle.setAttribute(
                    'aria-expanded',
                    this.typeFilterMenu?.classList.contains('hidden') ? 'false' : 'true'
                  );
                };

                this.typeFilterToggle.addEventListener('click', this.onTypeFilterToggle);
              }

              if (!this.onTypeFilterDocumentClick) {
                this.onTypeFilterDocumentClick = (event) => {
                  if (!this.typeFilterMenu || this.typeFilterMenu.classList.contains('hidden')) {
                    return;
                  }

                  if (this.typeFilterMenu.contains(event.target) || this.typeFilterToggle?.contains(event.target)) {
                    return;
                  }

                  this.typeFilterMenu.classList.add('hidden');
                  this.typeFilterToggle?.setAttribute('aria-expanded', 'false');
                };

                document.addEventListener('click', this.onTypeFilterDocumentClick);
              }

              this.onTypeFilterChange = () => {
                this.selectedTypeFilters = this.typeFilterCheckboxes
                  .filter((checkbox) => checkbox.checked)
                  .map((checkbox) => checkbox.value);

                this.writePersistedTypeFilters(this.selectedTypeFilters);
                this.applyFilter();
              };

              this.typeFilterCheckboxes.forEach((checkbox) => {
                checkbox.checked = (this.selectedTypeFilters || []).includes(checkbox.value);
                checkbox.removeEventListener('change', this.onTypeFilterChange);
                checkbox.addEventListener('change', this.onTypeFilterChange);
              });
            },

            applyFilter() {
              const filterValue = (this.filterValue || '').trim().toUpperCase();
              const filterableItems = this.el.querySelectorAll('.filterable-item');
              const typeFilters = this.selectedTypeFilters || [];

              filterableItems.forEach(item => {
                const text = item.textContent.toUpperCase();
                const typeKey = item.dataset.typeKey || 'unknown';
                const textMatch = !filterValue || text.includes(filterValue);
                const typeMatch = typeFilters.length === 0 || typeFilters.includes(typeKey);
                const shouldShow = textMatch && typeMatch;
                item.style.display = shouldShow ? '' : 'none';
              });

              if (this.clearButton) {
                this.clearButton.style.display = '';
              }
            },

            mounted() {
              this.filterValue = this.readPersistedFilter();
              this.selectedTypeFilters = this.readPersistedTypeFilters();
              this.filterWasFocused = false;
              this.bindFilter();
              this.bindTypeFilters();
              this.initializeDragDrop();
              this.applyFilter();
            },

          beforeUpdate() {
            this.filterWasFocused = document.activeElement === this.filterInput;
            this.filterValue = this.filterInput ? this.filterInput.value : (this.filterValue || '');
            this.writePersistedFilter(this.filterValue);
          },

            updated() {
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
            this.el.removeEventListener('dragstart', this.onDragStart);
            this.el.removeEventListener('dragend', this.onDragEnd);
            this.el.removeEventListener('dblclick', this.onDoubleClick);
            this.el.removeEventListener('dragover', this.onDragOver);
            this.el.removeEventListener('dragleave', this.onDragLeave);
            this.el.removeEventListener('drop', this.onDrop);

            if (this.filterInput && this.onFilterInput) {
              this.filterInput.removeEventListener('input', this.onFilterInput);
            }

            if (this.filterInput && this.onFilterKeydown) {
              this.filterInput.removeEventListener('keydown', this.onFilterKeydown);
            }

              if (this.clearButton && this.onClearClick) {
                this.clearButton.removeEventListener('click', this.onClearClick);
              }

              if (this.typeFilterToggle && this.onTypeFilterToggle) {
                this.typeFilterToggle.removeEventListener('click', this.onTypeFilterToggle);
              }

              if (this.typeFilterCheckboxes && this.onTypeFilterChange) {
                this.typeFilterCheckboxes.forEach((checkbox) => {
                  checkbox.removeEventListener('change', this.onTypeFilterChange);
                });
              }

              if (this.onTypeFilterDocumentClick) {
                document.removeEventListener('click', this.onTypeFilterDocumentClick);
              }

              this.draggedElement = null;
              this.initialized = false;
              this.writePersistedFilter(this.filterValue || '');
              this.writePersistedTypeFilters(this.selectedTypeFilters || []);
            }
        }
      </script>
    </div>
    """
  end

  defp get_filter_name(available, filter_id) do
    case Enum.find(available, fn {id, _name, _meta} -> id == filter_id end) do
      {_id, name, _meta} -> name
      nil -> filter_id || "Unknown Filter"
    end
  end

  attr(:type, :any, required: true)

  defp type_glyph(assigns) do
    icon_key = normalize_icon_key(assigns.type)

    assigns =
      assigns
      |> assign(:icon_key, icon_key)
      |> assign(:label, type_badge_label(assigns.type))
      |> assign(:style, type_badge_style(assigns.type))

    ~H"""
    <span data-type-icon={@label} aria-label={@label} title={@label} class="inline-flex h-4 w-4 shrink-0 items-center justify-center" style={@style}>
      <%= case @icon_key do %>
        <% :number -> %>
          <svg class="h-3.5 w-3.5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true"><path d="M7.5 4.5a1 1 0 0 1 2 0V8h2V4.5a1 1 0 1 1 2 0V8h1a1 1 0 1 1 0 2h-1v2h1a1 1 0 1 1 0 2h-1v1.5a1 1 0 1 1-2 0V14h-2v1.5a1 1 0 1 1-2 0V14h-1a1 1 0 1 1 0-2h1v-2h-1a1 1 0 1 1 0-2h1V4.5Zm2 5.5v2h2v-2h-2Z" /></svg>
        <% :currency -> %>
          <svg class="h-3.5 w-3.5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true"><path d="M10.75 2.75a.75.75 0 0 0-1.5 0v.64c-1.92.26-3.25 1.52-3.25 3.28 0 1.95 1.55 2.77 3.3 3.3l.7.22v4.03c-1.14-.14-1.95-.8-2.34-1.78a.75.75 0 1 0-1.4.56c.58 1.46 1.85 2.36 3.74 2.55v.7a.75.75 0 0 0 1.5 0v-.7c2.05-.22 3.5-1.55 3.5-3.5 0-2.02-1.54-2.9-3.47-3.48l-.03-.01V5c.86.13 1.46.63 1.8 1.32a.75.75 0 1 0 1.35-.66c-.56-1.13-1.53-1.83-3.15-2V2.75ZM10 8.63c-1.46-.45-2.25-.9-2.25-1.92 0-.9.72-1.56 2.25-1.73v3.65Zm1.5 1.83c1.57.5 2.5.98 2.5 2.12 0 1.02-.8 1.78-2.5 1.96v-4.08Z" /></svg>
        <% :percentage -> %>
          <svg class="h-3.5 w-3.5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true"><path d="M5.5 5.25a1.75 1.75 0 1 1 0 3.5 1.75 1.75 0 0 1 0-3.5Zm9 6a1.75 1.75 0 1 1 0 3.5 1.75 1.75 0 0 1 0-3.5ZM14.03 4.47a.75.75 0 0 1 .5 1.06l-7.5 10a.75.75 0 1 1-1.2-.9l7.5-10a.75.75 0 0 1 .7-.16Z" /></svg>
        <% :date -> %>
          <svg class="h-3.5 w-3.5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true"><path d="M6 2.75a.75.75 0 0 1 1.5 0V4h5V2.75a.75.75 0 0 1 1.5 0V4h.5A2.5 2.5 0 0 1 17 6.5v8A2.5 2.5 0 0 1 14.5 17h-9A2.5 2.5 0 0 1 3 14.5v-8A2.5 2.5 0 0 1 5.5 4H6V2.75ZM4.5 8v6.5c0 .552.448 1 1 1h9c.552 0 1-.448 1-1V8h-11Z" /></svg>
        <% :time -> %>
          <svg class="h-3.5 w-3.5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true"><path d="M10 3a7 7 0 1 0 0 14 7 7 0 0 0 0-14Zm.75 3.25a.75.75 0 0 0-1.5 0V10c0 .24.11.47.3.61l2.5 1.88a.75.75 0 1 0 .9-1.2l-2.2-1.65V6.25Z" /></svg>
        <% :boolean -> %>
          <svg class="h-3.5 w-3.5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true"><path d="M3 10a4 4 0 0 1 4-4h6a4 4 0 1 1 0 8H7a4 4 0 0 1-4-4Zm10 2a2 2 0 1 0 0-4 2 2 0 0 0 0 4Z" /></svg>
        <% :text -> %>
          <svg class="h-3.5 w-3.5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true"><path d="M4.5 5.5A1.5 1.5 0 0 1 6 4h8a1 1 0 1 1 0 2H11v8a1 1 0 1 1-2 0V6H6a1.5 1.5 0 0 1-1.5-1.5Z" /></svg>
        <% :relation -> %>
          <svg class="h-3.5 w-3.5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true"><path d="M4.75 3a1.75 1.75 0 1 0 0 3.5A1.75 1.75 0 0 0 4.75 3ZM13.5 5.5a1.5 1.5 0 0 1 1.5 1.5v1.2a2.3 2.3 0 0 0-.7-.1H9.44a2.75 2.75 0 0 0-2.44-1.5H6.3a2.74 2.74 0 0 0-.31-1.2H13.5ZM15.25 13.5a1.75 1.75 0 1 0 0 3.5 1.75 1.75 0 0 0 0-3.5ZM5 9.1A1.5 1.5 0 0 1 6.5 7.6h.5A1.5 1.5 0 0 1 8.5 9.1v.4h5.8A1.7 1.7 0 0 1 16 11.2v1.1a2.74 2.74 0 0 0-1.2-.3h-.46A2.75 2.75 0 0 0 11.7 10H8.4A2.4 2.4 0 0 1 6 12.4H5V9.1Z" /></svg>
        <% :list -> %>
          <svg class="h-3.5 w-3.5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true"><path d="M5 4.75A1.25 1.25 0 1 1 2.5 4.75 1.25 1.25 0 0 1 5 4.75ZM6.75 4a.75.75 0 0 0 0 1.5H16a.75.75 0 0 0 0-1.5H6.75ZM5 10a1.25 1.25 0 1 1-2.5 0A1.25 1.25 0 0 1 5 10Zm1.75-.75a.75.75 0 0 0 0 1.5H16a.75.75 0 0 0 0-1.5H6.75ZM5 15.25a1.25 1.25 0 1 1-2.5 0 1.25 1.25 0 0 1 2.5 0ZM6.75 14.5a.75.75 0 0 0 0 1.5H16a.75.75 0 0 0 0-1.5H6.75Z" /></svg>
        <% :json -> %>
          <svg class="h-3.5 w-3.5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true"><path d="M7.25 4a.75.75 0 0 1 0 1.5c-.69 0-1.25.56-1.25 1.25v1.5c0 .86-.37 1.63-.96 2.15.59.52.96 1.29.96 2.15v1.5c0 .69.56 1.25 1.25 1.25a.75.75 0 0 1 0 1.5A2.75 2.75 0 0 1 4.5 15.25v-1.5c0-.78-.52-1.45-1.24-1.66a.75.75 0 0 1 0-1.44c.72-.2 1.24-.88 1.24-1.65v-1.5A2.75 2.75 0 0 1 7.25 4Zm5.5 0A2.75 2.75 0 0 1 15.5 6.75v1.5c0 .77.52 1.44 1.24 1.65a.75.75 0 0 1 0 1.44c-.72.2-1.24.88-1.24 1.66v1.5A2.75 2.75 0 0 1 12.75 18a.75.75 0 0 1 0-1.5c.69 0 1.25-.56 1.25-1.25v-1.5c0-.86.37-1.63.96-2.15a2.88 2.88 0 0 1-.96-2.15v-1.5c0-.69-.56-1.25-1.25-1.25a.75.75 0 0 1 0-1.5Z" /></svg>
        <% :uuid -> %>
          <svg class="h-3.5 w-3.5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true"><path d="M7.5 3.5A2.5 2.5 0 0 0 5 6v1.1a2.4 2.4 0 0 0-1.5 2.24v1.3A2.5 2.5 0 0 0 6 13.15h1.1A2.4 2.4 0 0 0 9.35 15.5h1.3a2.4 2.4 0 0 0 2.25-1.5H14A2.5 2.5 0 0 0 16.5 11.5V10.2A2.4 2.4 0 0 0 18 7.95v-1.3A2.5 2.5 0 0 0 15.5 4.15H14.4A2.4 2.4 0 0 0 12.15 2h-1.3A2.4 2.4 0 0 0 8.6 3.5H7.5Zm1 1.5h2.9a.75.75 0 0 0 .74-.62A.9.9 0 0 1 13 3.5h1.3c.43 0 .79.3.88.72a.75.75 0 0 0 .73.58H17a1 1 0 0 1 1 1v1.3a.9.9 0 0 1-.72.88.75.75 0 0 0-.58.73V10a.75.75 0 0 0 .62.74c.42.09.73.45.73.88V13a1 1 0 0 1-1 1h-1.1a.75.75 0 0 0-.74.62.9.9 0 0 1-.88.73H13a.9.9 0 0 1-.88-.73.75.75 0 0 0-.73-.62H8.5a.75.75 0 0 0-.74.62.9.9 0 0 1-.88.73H5.6A.9.9 0 0 1 4.7 13.9V12.6c0-.43.3-.79.72-.88A.75.75 0 0 0 6 11V8.5a.75.75 0 0 0-.62-.74.9.9 0 0 1-.73-.88V5.6a.9.9 0 0 1 .9-.9H6.9a.75.75 0 0 0 .73-.58A.9.9 0 0 1 8.5 5Z" /></svg>
        <% :binary -> %>
          <svg class="h-3.5 w-3.5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true"><path d="M4 4.75A1.75 1.75 0 1 1 7.5 4.75 1.75 1.75 0 0 1 4 4.75Zm0 10.5A1.75 1.75 0 1 1 7.5 15.25 1.75 1.75 0 0 1 4 15.25ZM12.5 4.75a1.75 1.75 0 1 1 3.5 0 1.75 1.75 0 0 1-3.5 0Zm0 10.5a1.75 1.75 0 1 1 3.5 0 1.75 1.75 0 0 1-3.5 0ZM8.75 5.5h2.5v1.5h-2.5V5.5Zm0 7.5h2.5v1.5h-2.5V13Z" /></svg>
        <% :spatial -> %>
          <svg class="h-3.5 w-3.5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true"><path d="M10 2.5c-2.76 0-5 2.11-5 4.72 0 3.28 4.23 8.37 4.41 8.58a.75.75 0 0 0 1.18 0c.18-.21 4.41-5.3 4.41-8.58C15 4.61 12.76 2.5 10 2.5Zm0 6.22a1.75 1.75 0 1 1 0-3.5 1.75 1.75 0 0 1 0 3.5Z" /></svg>
        <% _ -> %>
          <svg class="h-3.5 w-3.5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true"><path d="M10 3a7 7 0 1 0 0 14 7 7 0 0 0 0-14Zm.75 10.25a.75.75 0 0 1-1.5 0v-3a.75.75 0 0 1 1.5 0v3Zm0-5.5a.75.75 0 1 1-1.5 0 .75.75 0 0 1 1.5 0Z" /></svg>
      <% end %>
    </span>
    """
  end

  defp available_type_filters(available) do
    available
    |> Enum.reduce(%{}, fn {_id, _name, field_type}, acc ->
      key = normalize_icon_key(field_type)
      Map.update(acc, key, 1, &(&1 + 1))
    end)
    |> Enum.map(fn {key, count} ->
      %{key: key, label: type_badge_label(%{icon: key}), count: count}
    end)
    |> Enum.sort_by(& &1.label)
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

  defp render_area(assigns) do
    assigns = Map.put(assigns, :new_uuid, UUID.uuid4())
    # Create a unique key based on component ID and filter UUIDs to force proper re-rendering
    component_id = Map.get(assigns, :component_id, "")

    filter_key =
      assigns.filters
      |> Enum.map(fn
        {{uuid, _section, config}, _idx} when is_map(config) ->
          comp = Map.get(config, "comp") || Map.get(config, :comp) || ""
          "#{uuid}:#{comp}"

        {{uuid, _section, _conjunction}, _idx} ->
          to_string(uuid)
      end)
      |> Enum.join("-")
      |> then(fn key -> "#{component_id}-#{assigns.section}-#{key}" end)

    assigns = Map.put(assigns, :filter_key, filter_key)

    ~H"""
      <div class="rounded-xl border p-1 pb-8 drop-zone"
      style="border-width: 4px; border-color: var(--sc-accent); background: var(--sc-surface-bg);"
      data-drop-zone={@section}
      id={@filter_key}>

        <span class="text-base-content font-medium"><%= @conjunction %></span>
        <%= for {{uuid, s_section, config} = s, index} <-
              Enum.filter(@filters, fn
                {{_uuid, section, _conf}, _i} -> section == @section
              end) do %>
          <div class="relative border p-2 pl-6 pr-10"
               style="border-color: var(--sc-surface-border); background: var(--sc-surface-bg); color: var(--sc-text-primary);"
               id={uuid}>

            <%= case {uuid, s_section, config} do %>
              <% {uuid, _section, conjunction} when is_binary(conjunction) -> %>
                <input name={"filters[#{uuid}][uuid]"} type="hidden" value={uuid}/>
                <input name={"filters[#{uuid}][section]"} type="hidden" value={@section}/>
                <input name={"filters[#{uuid}][index]"} type="hidden" value={@index}/>
                <input name={"filters[#{uuid}][conjunction]"} type="hidden" value={conjunction}/>
                <input name={"filters[#{uuid}][is_section]"} type="hidden" value="Y"/>
                <%= render_area(%{ available: @available, filters: @filters, section: uuid, index: index, conjunction: conjunction, filter_form: @filter_form, component_id: @component_id }) %>
                <div class="absolute top-1 right-1 flex">
                  <.sc_x_button phx-click="filter_remove" phx-value-uuid={uuid}/>
                </div>

              <% {uuid, section, fv} -> %>
                <div class="rounded-md border p-2 pl-6" style="border-color: var(--sc-surface-border); background: var(--sc-surface-bg-alt);">
                  <div class="mb-1 text-sm font-medium" style="color: var(--sc-text-secondary);">
                    <%= get_filter_name(@available, fv["filter"]) %>
                  </div>
                  <div id={filter_form_dom_id(uuid, fv)}>
                    <%= render_slot(@filter_form, {uuid, index, section, fv}) %>
                  </div>
                </div>
                <div class="absolute top-1 right-1 flex">
                  <.sc_x_button phx-click="filter_remove" phx-value-uuid={uuid}/>
                </div>

            <% end %>
            <!-- new section -->

          </div>
        <% end %>

      </div>
    """
  end

  defp filter_form_dom_id(uuid, filter_value) do
    case normalize_filter_comp(filter_value) do
      comp when comp in ["IN", "NOT IN"] ->
        "filter-form-#{uuid}-#{:erlang.phash2(in_filter_dom_state(filter_value))}"

      _ ->
        "filter-form-#{uuid}"
    end
  end

  defp normalize_filter_comp(filter_value) when is_map(filter_value) do
    filter_value
    |> Map.get("comp", Map.get(filter_value, :comp, ""))
    |> to_string()
    |> String.upcase()
  end

  defp normalize_filter_comp(_filter_value), do: ""

  defp in_filter_dom_state(filter_value) do
    %{
      comp: Map.get(filter_value, "comp", Map.get(filter_value, :comp)),
      value: Map.get(filter_value, "value", Map.get(filter_value, :value)),
      selected_values:
        Map.get(filter_value, "selected_values", Map.get(filter_value, :selected_values, []))
    }
  end
end
