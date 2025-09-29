defmodule SelectoComponents.Dashboard.Widget do
  @moduledoc """
  Base component for dashboard widgets.
  Provides common functionality for all widget types.
  """
  
  use Phoenix.Component
  
  @default_config %{
    title: "Widget",
    min_width: 2,
    min_height: 2,
    max_width: 12,
    max_height: 8,
    resizable: true,
    draggable: true,
    closable: true,
    refreshable: true,
    configurable: true
  }
  
  @doc """
  Renders a widget container with standard controls and content area.
  """
  attr :id, :string, required: true
  attr :type, :atom, required: true
  attr :config, :map, default: %{}
  attr :data, :any, default: nil
  attr :class, :string, default: ""
  slot :inner_block
  slot :header
  slot :footer
  slot :actions
  
  def widget(assigns) do
    assigns = assign_widget_defaults(assigns)
    
    ~H"""
    <div
      id={@id}
      class={["widget-container", @class]}
      data-widget-type={@type}
      data-widget-id={@id}
      data-grid-x={@config[:x]}
      data-grid-y={@config[:y]}
      data-grid-w={@config[:width] || 4}
      data-grid-h={@config[:height] || 3}
      phx-hook="DashboardWidget"
    >
      <div class="widget-header">
        <div class="widget-title">
          <%= if @header != [] do %>
            <%= render_slot(@header) %>
          <% else %>
            <h3 class="text-lg font-semibold text-gray-900">
              <%= @config[:title] || "Widget" %>
            </h3>
          <% end %>
        </div>
        
        <div class="widget-controls flex items-center gap-2">
          <%= if @actions != [] do %>
            <%= render_slot(@actions) %>
          <% end %>
          
          <%= if @config[:refreshable] do %>
            <button
              phx-click="refresh_widget"
              phx-value-id={@id}
              class="p-1 text-gray-400 hover:text-gray-600"
              title="Refresh"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                      d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
              </svg>
            </button>
          <% end %>
          
          <%= if @config[:configurable] do %>
            <button
              phx-click={show_widget_config(@id)}
              class="p-1 text-gray-400 hover:text-gray-600"
              title="Configure"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                      d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                      d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
              </svg>
            </button>
          <% end %>
          
          <%= if @config[:closable] do %>
            <button
              phx-click="remove_widget"
              phx-value-id={@id}
              class="p-1 text-gray-400 hover:text-red-600"
              title="Remove"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                      d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          <% end %>
        </div>
      </div>
      
      <div class="widget-body">
        <%= if @inner_block != [] do %>
          <%= render_slot(@inner_block, @data) %>
        <% else %>
          <%= render_widget_content(assigns) %>
        <% end %>
      </div>
      
      <%= if @footer != [] do %>
        <div class="widget-footer">
          <%= render_slot(@footer) %>
        </div>
      <% end %>
      
      <%= if @config[:resizable] do %>
        <div class="widget-resize-handle" />
      <% end %>
    </div>
    """
  end
  
  @doc """
  Widget configuration modal component.
  """
  attr :id, :string, required: true
  attr :widget_id, :string, required: true
  attr :config, :map, required: true
  attr :on_save, :any, required: true
  slot :fields
  
  def widget_config_modal(assigns) do
    ~H"""
    <div
      id={@id}
      class="fixed inset-0 z-50 hidden"
      phx-mounted={show_modal(@id)}
    >
      <div class="fixed inset-0 bg-black bg-opacity-50" phx-click={hide_modal(@id)} />
      
      <div class="fixed inset-0 flex items-center justify-center p-4">
        <div class="bg-white rounded-lg shadow-xl max-w-md w-full max-h-[80vh] overflow-hidden">
          <div class="px-6 py-4 border-b">
            <h3 class="text-lg font-semibold">Widget Configuration</h3>
          </div>
          
          <form phx-submit={@on_save} phx-change="validate_widget_config">
            <input type="hidden" name="widget_id" value={@widget_id} />
            
            <div class="px-6 py-4 space-y-4 max-h-[60vh] overflow-y-auto">
              <%= if @fields != [] do %>
                <%= render_slot(@fields, @config) %>
              <% else %>
                <div class="space-y-4">
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">
                      Title
                    </label>
                    <input
                      type="text"
                      name="config[title]"
                      value={@config[:title]}
                      class="w-full px-3 py-2 border rounded-md"
                    />
                  </div>
                  
                  <div class="grid grid-cols-2 gap-4">
                    <div>
                      <label class="block text-sm font-medium text-gray-700 mb-1">
                        Width
                      </label>
                      <input
                        type="number"
                        name="config[width]"
                        value={@config[:width] || 4}
                        min={@config[:min_width] || 2}
                        max={@config[:max_width] || 12}
                        class="w-full px-3 py-2 border rounded-md"
                      />
                    </div>
                    
                    <div>
                      <label class="block text-sm font-medium text-gray-700 mb-1">
                        Height
                      </label>
                      <input
                        type="number"
                        name="config[height]"
                        value={@config[:height] || 3}
                        min={@config[:min_height] || 2}
                        max={@config[:max_height] || 8}
                        class="w-full px-3 py-2 border rounded-md"
                      />
                    </div>
                  </div>
                  
                  <div class="space-y-2">
                    <label class="flex items-center">
                      <input
                        type="checkbox"
                        name="config[refreshable]"
                        checked={@config[:refreshable]}
                        class="mr-2"
                      />
                      <span class="text-sm">Enable refresh</span>
                    </label>
                    
                    <label class="flex items-center">
                      <input
                        type="checkbox"
                        name="config[resizable]"
                        checked={@config[:resizable]}
                        class="mr-2"
                      />
                      <span class="text-sm">Allow resizing</span>
                    </label>
                    
                    <label class="flex items-center">
                      <input
                        type="checkbox"
                        name="config[draggable]"
                        checked={@config[:draggable]}
                        class="mr-2"
                      />
                      <span class="text-sm">Allow dragging</span>
                    </label>
                  </div>
                </div>
              <% end %>
            </div>
            
            <div class="px-6 py-4 border-t flex justify-end gap-3">
              <button
                type="button"
                phx-click={hide_modal(@id)}
                class="px-4 py-2 text-gray-700 hover:text-gray-900"
              >
                Cancel
              </button>
              <button
                type="submit"
                class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700"
              >
                Save Configuration
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end
  
  # Private functions
  
  defp assign_widget_defaults(assigns) do
    config = Map.merge(@default_config, assigns.config)
    assign(assigns, :config, config)
  end
  
  defp render_widget_content(%{type: type, data: data} = assigns) do
    case type do
      :chart -> render_chart_widget(assigns)
      :table -> render_table_widget(assigns)
      :metric -> render_metric_widget(assigns)
      :map -> render_map_widget(assigns)
      :text -> render_text_widget(assigns)
      :custom -> render_custom_widget(assigns)
      _ -> render_empty_widget(assigns)
    end
  end
  
  defp render_chart_widget(assigns) do
    ~H"""
    <div class="widget-chart">
      <div class="p-4 text-center text-gray-500">
        Chart widget: <%= inspect(@data) %>
      </div>
    </div>
    """
  end
  
  defp render_table_widget(assigns) do
    ~H"""
    <div class="widget-table">
      <div class="p-4 text-center text-gray-500">
        Table widget: <%= inspect(@data) %>
      </div>
    </div>
    """
  end
  
  defp render_metric_widget(assigns) do
    ~H"""
    <div class="widget-metric">
      <div class="p-4 text-center text-gray-500">
        Metric widget: <%= inspect(@data) %>
      </div>
    </div>
    """
  end
  
  defp render_map_widget(assigns) do
    ~H"""
    <div class="widget-map">
      <div class="p-4 text-center text-gray-500">
        Map widget: <%= inspect(@data) %>
      </div>
    </div>
    """
  end
  
  defp render_text_widget(assigns) do
    ~H"""
    <div class="widget-text">
      <div class="p-4">
        <%= @data || "No content" %>
      </div>
    </div>
    """
  end
  
  defp render_custom_widget(assigns) do
    ~H"""
    <div class="widget-custom">
      <div class="p-4 text-center text-gray-500">
        Custom widget
      </div>
    </div>
    """
  end
  
  defp render_empty_widget(assigns) do
    ~H"""
    <div class="widget-empty">
      <div class="p-4 text-center text-gray-500">
        No widget content
      </div>
    </div>
    """
  end
  
  defp show_modal(id) do
    JS.show(
      to: "##{id}",
      transition: {"ease-out duration-300", "opacity-0", "opacity-100"}
    )
  end
  
  defp hide_modal(id) do
    JS.hide(
      to: "##{id}",
      transition: {"ease-in duration-200", "opacity-100", "opacity-0"}
    )
  end
  
  defp show_widget_config(widget_id) do
    JS.push("show_widget_config", value: %{widget_id: widget_id})
  end
  
  def __hooks__ do
    """
    export const DashboardWidget = {
      mounted() {
        this.initWidget();
        this.setupDragDrop();
        this.setupResize();
      },
      
      updated() {
        this.updateWidgetPosition();
      },
      
      destroyed() {
        this.cleanup();
      },
      
      initWidget() {
        this.widgetId = this.el.dataset.widgetId;
        this.widgetType = this.el.dataset.widgetType;
        this.gridX = parseInt(this.el.dataset.gridX || '0');
        this.gridY = parseInt(this.el.dataset.gridY || '0');
        this.gridW = parseInt(this.el.dataset.gridW || '4');
        this.gridH = parseInt(this.el.dataset.gridH || '3');
      },
      
      setupDragDrop() {
        const header = this.el.querySelector('.widget-header');
        if (!header) return;
        
        let isDragging = false;
        let startX, startY, initialX, initialY;
        
        header.addEventListener('mousedown', (e) => {
          if (e.target.closest('.widget-controls')) return;
          
          isDragging = true;
          startX = e.clientX;
          startY = e.clientY;
          initialX = this.el.offsetLeft;
          initialY = this.el.offsetTop;
          
          this.el.classList.add('dragging');
          document.body.style.cursor = 'move';
        });
        
        document.addEventListener('mousemove', (e) => {
          if (!isDragging) return;
          
          const dx = e.clientX - startX;
          const dy = e.clientY - startY;
          
          this.el.style.left = (initialX + dx) + 'px';
          this.el.style.top = (initialY + dy) + 'px';
        });
        
        document.addEventListener('mouseup', () => {
          if (!isDragging) return;
          
          isDragging = false;
          this.el.classList.remove('dragging');
          document.body.style.cursor = '';
          
          this.updateGridPosition();
        });
      },
      
      setupResize() {
        const handle = this.el.querySelector('.widget-resize-handle');
        if (!handle) return;
        
        let isResizing = false;
        let startX, startY, startWidth, startHeight;
        
        handle.addEventListener('mousedown', (e) => {
          isResizing = true;
          startX = e.clientX;
          startY = e.clientY;
          startWidth = this.el.offsetWidth;
          startHeight = this.el.offsetHeight;
          
          this.el.classList.add('resizing');
          e.preventDefault();
        });
        
        document.addEventListener('mousemove', (e) => {
          if (!isResizing) return;
          
          const newWidth = startWidth + (e.clientX - startX);
          const newHeight = startHeight + (e.clientY - startY);
          
          this.el.style.width = Math.max(200, newWidth) + 'px';
          this.el.style.height = Math.max(150, newHeight) + 'px';
        });
        
        document.addEventListener('mouseup', () => {
          if (!isResizing) return;
          
          isResizing = false;
          this.el.classList.remove('resizing');
          
          this.updateGridSize();
        });
      },
      
      updateGridPosition() {
        const gridSize = 100; // pixels per grid unit
        const newGridX = Math.round(this.el.offsetLeft / gridSize);
        const newGridY = Math.round(this.el.offsetTop / gridSize);
        
        if (newGridX !== this.gridX || newGridY !== this.gridY) {
          this.gridX = newGridX;
          this.gridY = newGridY;
          
          this.pushEvent('update_widget_position', {
            widget_id: this.widgetId,
            x: this.gridX,
            y: this.gridY
          });
        }
      },
      
      updateGridSize() {
        const gridSize = 100; // pixels per grid unit
        const newGridW = Math.round(this.el.offsetWidth / gridSize);
        const newGridH = Math.round(this.el.offsetHeight / gridSize);
        
        if (newGridW !== this.gridW || newGridH !== this.gridH) {
          this.gridW = newGridW;
          this.gridH = newGridH;
          
          this.pushEvent('update_widget_size', {
            widget_id: this.widgetId,
            width: this.gridW,
            height: this.gridH
          });
        }
      },
      
      updateWidgetPosition() {
        const gridSize = 100;
        this.el.style.left = (this.gridX * gridSize) + 'px';
        this.el.style.top = (this.gridY * gridSize) + 'px';
        this.el.style.width = (this.gridW * gridSize) + 'px';
        this.el.style.height = (this.gridH * gridSize) + 'px';
      },
      
      cleanup() {
        // Clean up event listeners
      }
    };
    """
  end
end