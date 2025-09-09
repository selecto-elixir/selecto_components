defmodule SelectoComponents.Components.TreeBuilder do
  use Phoenix.LiveComponent

  # available,
  # filters

  import SelectoComponents.Components.Common


  def render(assigns) do
    ~H"""
    <div class="tree-builder-component">
      <div class="">
        <div phx-hook=".TreeBuilder" id="relay" class="grid grid-cols-2 gap-1 h-80" data-filter="">

          <div class="text-base-content">Available Filter Columns. Double Click or Drag to build area.
            <input type="text" id="filter-input" placeholder="Filter Available Items" class="sc-input" />
            <button id="clear-filter" class="sc-x-button hidden">×</button>
          </div>
          <div class="text-base-content">Build Area. All top level filters are AND'd together and AND'd with the required filters from the domain.</div>

          <div class="flex flex-col gap-1 border-solid border rounded-md border-base-300 overflow-auto p-1 bg-base-100" id="available-items">



            <div class="max-w-100 bg-base-200 border-solid border rounded-md border-base-300 p-1 hover:bg-base-300 min-h-10 text-base-content cursor-pointer filterable-item"
              draggable="true" data-item-id="__AND__" id="__AND__">AND group</div>
            <div class="max-w-100 bg-base-200 border-solid border rounded-md border-base-300 p-1 hover:bg-base-300 min-h-10 text-base-content cursor-pointer filterable-item"
              draggable="true" data-item-id="__OR__" id="__OR__">OR group</div>


            <div :for={{id, name} <- @available}>
              <div
                class="max-w-100 bg-base-200 border-solid border rounded-md border-base-300 p-1 hover:bg-base-300 min-h-10 text-base-content cursor-pointer filterable-item"
                draggable="true" data-item-id={id}
                id={id}><%= name %></div>
            </div>

          </div>
          <div class="grid grid-cols-1 gap-1 border-solid border rounded-md border-base-300 overflow-auto p-1 bg-base-100 drop-zone" data-drop-zone="filters">
            <%= render_area(%{ available: @available, filters: Enum.with_index(@filters), section: "filters", index: 0, conjunction: "AND", filter_form: @filter_form }) %>

          </div>
        </div>
      </div>
      
      <script :type={Phoenix.LiveView.ColocatedHook} name=".TreeBuilder">
        export default {
          draggedElement: null,
          initialized: false,
          
          initializeDragDrop() {
            if (this.initialized) {
              return;
            }
            
            const hook = this;
            console.log('Initializing drag and drop');
            
            this.el.addEventListener('dragstart', (e) => {
              if (e.target.getAttribute('draggable') === 'true') {
                hook.draggedElement = e.target.getAttribute('data-item-id') || e.target.id;
                console.log('Dragging:', hook.draggedElement);
                e.dataTransfer.effectAllowed = 'move';
                e.dataTransfer.setData('text/plain', hook.draggedElement);
                e.target.style.opacity = '0.5';
              }
            });
            
            this.el.addEventListener('dragend', (e) => {
              if (e.target.getAttribute('draggable') === 'true') {
                e.target.style.opacity = '';
                console.log('Drag ended');
              }
            });
            
            this.el.addEventListener('dblclick', (e) => {
              if (e.target.getAttribute('draggable') === 'true') {
                const elementId = e.target.getAttribute('data-item-id') || e.target.id;
                console.log('Double click on:', elementId);
                hook.pushEvent('treedrop', {
                  target: 'filters',
                  element: elementId
                });
              }
            });
            
            this.el.addEventListener('dragover', (e) => {
              if (e.target.classList.contains('drop-zone') || e.target.hasAttribute('data-drop-zone')) {
                e.preventDefault();
                e.dataTransfer.dropEffect = 'move';
                e.target.classList.add('bg-blue-50');
              }
            });
            
            this.el.addEventListener('dragleave', (e) => {
              if (e.target.classList.contains('drop-zone') || e.target.hasAttribute('data-drop-zone')) {
                if (!e.target.contains(e.relatedTarget)) {
                  e.target.classList.remove('bg-blue-50');
                }
              }
            });
            
            this.el.addEventListener('drop', (e) => {
              if (e.target.classList.contains('drop-zone') || e.target.hasAttribute('data-drop-zone')) {
                e.preventDefault();
                e.stopPropagation();
                e.target.classList.remove('bg-blue-50');
                
                const draggedId = e.dataTransfer.getData('text/plain') || hook.draggedElement;
                const targetId = e.target.getAttribute('data-drop-zone') || e.target.id;
                
                console.log('Drop event - dragged:', draggedId, 'target:', targetId);
                
                if (draggedId && targetId) {
                  console.log('Pushing treedrop event');
                  hook.pushEvent('treedrop', {
                    target: targetId,
                    element: draggedId
                  });
                }
                hook.draggedElement = null;
              }
            });
            
            this.initialized = true;
          },
          
          initializeFilter() {
            const filterInput = this.el.querySelector('#filter-input');
            const clearButton = this.el.querySelector('#clear-filter');
            
            if (filterInput) {
              filterInput.addEventListener('input', (e) => {
                const filterValue = e.target.value.toUpperCase();
                if (clearButton) {
                  clearButton.style.display = filterValue ? '' : 'none';
                }
                
                const filterableItems = this.el.querySelectorAll('.filterable-item');
                filterableItems.forEach(item => {
                  const text = item.textContent.toUpperCase();
                  const shouldShow = !filterValue || text.includes(filterValue);
                  item.style.display = shouldShow ? '' : 'none';
                });
              });
            }
            
            if (clearButton) {
              clearButton.addEventListener('click', () => {
                filterInput.value = '';
                filterInput.dispatchEvent(new Event('input'));
              });
            }
          },
          
          mounted() {
            console.log('TreeBuilderHook mounted');
            this.initializeFilter();
            this.initializeDragDrop();
          },
          
          updated() {
            console.log('TreeBuilderHook updated');
          },
          
          destroyed() {
            console.log('TreeBuilderHook destroyed');
            this.draggedElement = null;
            this.initialized = false;
          }
        }
      </script>
    </div>
    """
  end

  defp render_area(assigns) do
    assigns = Map.put(assigns, :new_uuid, UUID.uuid4())

    ~H"""
      <div class="border-solid border border-4 rounded-xl border-primary p-1 pb-8 bg-base-100 drop-zone"
      data-drop-zone={@section}
      id={@section}>

        <span class="text-base-content font-medium"><%= @conjunction %></span>
        <div class="p-2 pl-6 pr-10 border-solid border border-base-300 bg-base-100 text-base-content relative"
          :for={ {s, index} <-
            Enum.filter( @filters, fn
            {{_uuid,section,_conf}, _i} -> section == @section
            end )
          } %>

          <%= case s do %>
            <% {uuid, _section, conjunction} when is_binary(conjunction) -> %>
              <input name={"filters[#{uuid}][uuid]"} type="hidden" value={uuid}/>
              <input name={"filters[#{uuid}][section]"} type="hidden" value={@section}/>
              <input name={"filters[#{uuid}][index]"} type="hidden" value={@index}/>
              <input name={"filters[#{uuid}][conjunction]"} type="hidden" value={conjunction}/>
              <input name={"filters[#{uuid}][is_section]"} type="hidden" value="Y"/>
              <%= render_area(%{ available: @available, filters: @filters, section: uuid, index: index, conjunction: conjunction, filter_form: @filter_form  }) %>
              <div class="absolute top-1 right-1 flex">
                <.sc_x_button phx-click="filter_remove" phx-value-uuid={uuid}/>
              </div>

            <% {uuid, section, fv} -> %>
              <div class="p-2 pl-6 border-solid border rounded-md border-base-300 bg-base-100">
                <%= render_slot(@filter_form, {uuid, index, section, fv}) %>
              </div>
              <div class="absolute top-1 right-1 flex">
                <.sc_x_button phx-click="filter_remove" phx-value-uuid={uuid}/>
              </div>

          <% end %>
            <!-- new section -->

        </div>

      </div>
    """
  end
end