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
    ~H"""
    <div class="tree-builder-component" style="color: var(--sc-text-primary);">
      <div class="">
        <div phx-hook=".TreeBuilder" id={"tree-builder-#{@id}"} class="grid grid-cols-2 gap-1 h-80" data-filter="">

          <div style="color: var(--sc-text-primary);">Available Filter Columns. Double Click or Drag to build area.
            <input type="text" id={"filter-input-#{@id}"} placeholder="Filter Available Items" class={Theme.slot(@theme, :input)} />
            <button id={"clear-filter-#{@id}"} class={[Theme.slot(@theme, :button_danger), "hidden", "h-7", "w-7"]}>×</button>
          </div>
          <div style="color: var(--sc-text-primary);">Build Area. All top level filters are AND'd together and AND'd with the required filters from the domain.</div>

          <div class={Theme.slot(@theme, :panel) <> " flex flex-col gap-1 overflow-auto p-1"} style="background: var(--sc-surface-bg-alt);" id={"available-items-#{@id}"}>



            <div class="max-w-100 min-h-10 cursor-pointer rounded-md border p-1 filterable-item"
              style="background: var(--sc-surface-bg); border-color: var(--sc-surface-border); color: var(--sc-text-primary);"
              draggable="true" data-item-id="__AND__" id={"#{@id}-__AND__"}>AND group</div>
            <div class="max-w-100 min-h-10 cursor-pointer rounded-md border p-1 filterable-item"
              style="background: var(--sc-surface-bg); border-color: var(--sc-surface-border); color: var(--sc-text-primary);"
              draggable="true" data-item-id="__OR__" id={"#{@id}-__OR__"}>OR group</div>


            <div :for={{{id, name}, idx} <- Enum.with_index(@available)}
              class="max-w-100 min-h-10 cursor-pointer rounded-md border p-1 filterable-item"
              style="background: var(--sc-surface-bg); border-color: var(--sc-surface-border); color: var(--sc-text-primary);"
              draggable="true" data-item-id={id}
              id={"#{@id}-available-#{id}-#{idx}"}><%= name %></div>

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

          applyFilter() {
            const filterValue = (this.filterValue || '').trim().toUpperCase();
            const filterableItems = this.el.querySelectorAll('.filterable-item');

            filterableItems.forEach(item => {
              const text = item.textContent.toUpperCase();
              const shouldShow = !filterValue || text.includes(filterValue);
              item.style.display = shouldShow ? '' : 'none';
            });

            if (this.clearButton) {
              this.clearButton.style.display = filterValue ? '' : 'none';
            }
          },

          mounted() {
            this.filterValue = this.readPersistedFilter();
            this.filterWasFocused = false;
            this.bindFilter();
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

            this.draggedElement = null;
            this.initialized = false;
            this.writePersistedFilter(this.filterValue || '');
          }
        }
      </script>
    </div>
    """
  end

  defp get_filter_name(available, filter_id) do
    case Enum.find(available, fn {id, _name} -> id == filter_id end) do
      {_id, name} -> name
      nil -> filter_id || "Unknown Filter"
    end
  end

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
                  <div id={"filter-form-#{uuid}"}>
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
end
