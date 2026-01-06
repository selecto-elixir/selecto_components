defmodule SelectoComponents.Dashboard.LayoutManager do
  @moduledoc """
  Manages dashboard layouts and widget positioning.
  Handles grid-based layouts, collision detection, and layout persistence.
  """

  use Phoenix.LiveComponent
  import Phoenix.LiveView
  alias SelectoComponents.Dashboard.Widget
  alias SelectoComponents.Dashboard.WidgetRegistry
  alias SelectoComponents.SafeAtom
  
  @grid_cols 12
  @grid_row_height 100
  @grid_gap 10
  
  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:widgets, [])
     |> assign(:layout_mode, :view)
     |> assign(:grid_visible, false)
     |> assign(:selected_widget, nil)
     |> assign(:available_widgets, WidgetRegistry.list_available())
     |> assign(:layout_config, default_layout_config())}
  end
  
  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> load_layout()}
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <div
      id={@id}
      class="dashboard-layout-manager"
      phx-hook="DashboardLayout"
      data-grid-cols={@grid_cols}
      data-row-height={@grid_row_height}
    >
      <div class="dashboard-toolbar">
        <div class="flex items-center justify-between mb-4">
          <div class="flex items-center gap-2">
            <button
              phx-click="toggle_layout_mode"
              phx-target={@myself}
              class={[
                "px-4 py-2 rounded-md transition-colors",
                if(@layout_mode == :edit,
                  do: "bg-blue-600 text-white",
                  else: "bg-gray-200 text-gray-700 hover:bg-gray-300"
                )
              ]}
            >
              <%= if @layout_mode == :edit do %>
                <span class="flex items-center gap-2">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                          d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                  </svg>
                  Edit Mode
                </span>
              <% else %>
                <span class="flex items-center gap-2">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                          d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                          d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                  </svg>
                  View Mode
                </span>
              <% end %>
            </button>
            
            <%= if @layout_mode == :edit do %>
              <button
                phx-click="toggle_grid"
                phx-target={@myself}
                class={[
                  "px-3 py-2 rounded-md transition-colors",
                  if(@grid_visible,
                    do: "bg-gray-700 text-white",
                    else: "bg-gray-200 text-gray-700 hover:bg-gray-300"
                  )
                ]}
                title="Toggle Grid"
              >
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                        d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z" />
                </svg>
              </button>
              
              <button
                phx-click="add_widget"
                phx-target={@myself}
                class="px-3 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 transition-colors"
              >
                <span class="flex items-center gap-2">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                          d="M12 4v16m8-8H4" />
                  </svg>
                  Add Widget
                </span>
              </button>
            <% end %>
          </div>
          
          <div class="flex items-center gap-2">
            <button
              phx-click="save_layout"
              phx-target={@myself}
              class="px-3 py-2 bg-gray-200 text-gray-700 rounded-md hover:bg-gray-300 transition-colors"
            >
              <span class="flex items-center gap-2">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                        d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3 3m0 0l-3-3m3 3V2" />
                </svg>
                Save Layout
              </span>
            </button>
            
            <button
              phx-click="load_layout"
              phx-target={@myself}
              class="px-3 py-2 bg-gray-200 text-gray-700 rounded-md hover:bg-gray-300 transition-colors"
            >
              <span class="flex items-center gap-2">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                        d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
                </svg>
                Load Layout
              </span>
            </button>
            
            <button
              phx-click="clear_layout"
              phx-target={@myself}
              class="px-3 py-2 bg-red-100 text-red-700 rounded-md hover:bg-red-200 transition-colors"
            >
              <span class="flex items-center gap-2">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                        d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                </svg>
                Clear
              </span>
            </button>
          </div>
        </div>
      </div>
      
      <div 
        class={[
          "dashboard-grid relative",
          if(@grid_visible, do: "show-grid"),
          if(@layout_mode == :edit, do: "edit-mode")
        ]}
        style={"min-height: #{calculate_min_height(@widgets)}px"}
      >
        <%= for widget <- @widgets do %>
          <div
            id={"widget-wrapper-#{widget.id}"}
            class={[
              "widget-wrapper absolute",
              if(@selected_widget == widget.id, do: "selected"),
              if(@layout_mode == :edit, do: "editable")
            ]}
            style={widget_position_style(widget)}
            data-widget-id={widget.id}
          >
            <Widget.widget
              id={widget.id}
              type={widget.type}
              config={widget.config}
              data={widget.data}
              class={if(@layout_mode == :edit, do: "edit-mode")}
            >
              <%= render_widget_content(widget) %>
            </Widget.widget>
          </div>
        <% end %>
        
        <%= if @grid_visible do %>
          <div class="grid-overlay">
            <%= for row <- 0..grid_rows(@widgets) do %>
              <%= for col <- 0..(@grid_cols - 1) do %>
                <div 
                  class="grid-cell"
                  style={"left: #{col * grid_cell_width()}%; top: #{row * @grid_row_height}px; width: #{grid_cell_width()}%; height: #{@grid_row_height}px"}
                  data-grid-x={col}
                  data-grid-y={row}
                />
              <% end %>
            <% end %>
          </div>
        <% end %>
      </div>
      
      <%= if @show_widget_selector do %>
        <div class="widget-selector-modal">
          <div class="fixed inset-0 bg-black bg-opacity-50 z-40" 
               phx-click="close_widget_selector" 
               phx-target={@myself} />
          
          <div class="fixed inset-0 flex items-center justify-center z-50 p-4">
            <div class="bg-white rounded-lg shadow-xl max-w-2xl w-full max-h-[80vh] overflow-hidden">
              <div class="px-6 py-4 border-b">
                <h3 class="text-lg font-semibold">Select a Widget</h3>
              </div>
              
              <div class="p-6 grid grid-cols-2 md:grid-cols-3 gap-4 max-h-[60vh] overflow-y-auto">
                <%= for widget_type <- @available_widgets do %>
                  <button
                    phx-click="select_widget_type"
                    phx-value-type={widget_type.type}
                    phx-target={@myself}
                    class="p-4 border-2 border-gray-200 rounded-lg hover:border-blue-500 hover:bg-blue-50 transition-colors"
                  >
                    <div class="text-4xl mb-2"><%= widget_type.icon %></div>
                    <div class="font-semibold"><%= widget_type.name %></div>
                    <div class="text-sm text-gray-600"><%= widget_type.description %></div>
                  </button>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
  
  # Event handlers
  
  @impl true
  def handle_event("toggle_layout_mode", _, socket) do
    new_mode = if socket.assigns.layout_mode == :edit, do: :view, else: :edit
    {:noreply, assign(socket, :layout_mode, new_mode)}
  end
  
  @impl true
  def handle_event("toggle_grid", _, socket) do
    {:noreply, assign(socket, :grid_visible, !socket.assigns.grid_visible)}
  end
  
  @impl true
  def handle_event("add_widget", _, socket) do
    {:noreply, assign(socket, :show_widget_selector, true)}
  end
  
  @impl true
  def handle_event("close_widget_selector", _, socket) do
    {:noreply, assign(socket, :show_widget_selector, false)}
  end
  
  @impl true
  def handle_event("select_widget_type", %{"type" => type}, socket) do
    widget = create_widget(type, socket.assigns.widgets)
    widgets = socket.assigns.widgets ++ [widget]
    
    {:noreply,
     socket
     |> assign(:widgets, widgets)
     |> assign(:show_widget_selector, false)
     |> push_event("widget_added", %{widget_id: widget.id})}
  end
  
  @impl true
  def handle_event("update_widget_position", %{"widget_id" => id, "x" => x, "y" => y}, socket) do
    widgets = update_widget_in_list(socket.assigns.widgets, id, fn widget ->
      %{widget | config: Map.merge(widget.config, %{x: x, y: y})}
    end)
    
    {:noreply, assign(socket, :widgets, widgets)}
  end
  
  @impl true
  def handle_event("update_widget_size", %{"widget_id" => id, "width" => w, "height" => h}, socket) do
    widgets = update_widget_in_list(socket.assigns.widgets, id, fn widget ->
      %{widget | config: Map.merge(widget.config, %{width: w, height: h})}
    end)
    
    {:noreply, assign(socket, :widgets, widgets)}
  end
  
  @impl true
  def handle_event("remove_widget", %{"id" => id}, socket) do
    widgets = Enum.reject(socket.assigns.widgets, &(&1.id == id))
    {:noreply, assign(socket, :widgets, widgets)}
  end
  
  @impl true
  def handle_event("save_layout", _, socket) do
    layout_data = serialize_layout(socket.assigns.widgets)
    
    case save_layout_to_storage(layout_data) do
      {:ok, _} ->
        {:noreply, put_flash(socket, :info, "Layout saved successfully")}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to save layout")}
    end
  end
  
  @impl true
  def handle_event("load_layout", _, socket) do
    case load_layout_from_storage() do
      {:ok, layout_data} ->
        widgets = deserialize_layout(layout_data)
        {:noreply, assign(socket, :widgets, widgets)}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to load layout")}
    end
  end
  
  @impl true
  def handle_event("clear_layout", _, socket) do
    {:noreply, assign(socket, :widgets, [])}
  end
  
  # Private functions
  
  defp default_layout_config do
    %{
      grid_cols: @grid_cols,
      row_height: @grid_row_height,
      grid_gap: @grid_gap,
      responsive_breakpoints: %{
        sm: 640,
        md: 768,
        lg: 1024,
        xl: 1280
      }
    }
  end
  
  defp load_layout(socket) do
    # Load saved layout if available
    case load_layout_from_storage() do
      {:ok, layout_data} ->
        widgets = deserialize_layout(layout_data)
        assign(socket, :widgets, widgets)
      _ ->
        socket
    end
  end
  
  defp create_widget(type, existing_widgets) do
    position = find_free_position(existing_widgets)
    widget_type = SafeAtom.to_widget_type(type)

    %{
      id: "widget-#{System.unique_integer([:positive])}",
      type: widget_type,
      config: Map.merge(
        %{
          title: "New #{String.capitalize(type)} Widget",
          x: position.x,
          y: position.y,
          width: 4,
          height: 3
        },
        default_widget_config(widget_type)
      ),
      data: nil
    }
  end
  
  defp default_widget_config(type) do
    case type do
      :chart -> %{chart_type: "line", refresh_interval: 30000}
      :table -> %{page_size: 10, sortable: true}
      :metric -> %{format: "number", prefix: "", suffix: ""}
      _ -> %{}
    end
  end
  
  defp find_free_position(widgets) do
    # Simple algorithm to find next free position
    occupied = Enum.map(widgets, fn w ->
      {w.config[:x] || 0, w.config[:y] || 0, 
       w.config[:width] || 4, w.config[:height] || 3}
    end)
    
    find_free_position_recursive(0, 0, occupied)
  end
  
  defp find_free_position_recursive(x, y, occupied) do
    if position_free?(x, y, 4, 3, occupied) do
      %{x: x, y: y}
    else
      if x + 4 <= @grid_cols do
        find_free_position_recursive(x + 1, y, occupied)
      else
        find_free_position_recursive(0, y + 1, occupied)
      end
    end
  end
  
  defp position_free?(x, y, width, height, occupied) do
    !Enum.any?(occupied, fn {ox, oy, ow, oh} ->
      x < ox + ow && x + width > ox &&
      y < oy + oh && y + height > oy
    end)
  end
  
  defp update_widget_in_list(widgets, id, update_fn) do
    Enum.map(widgets, fn widget ->
      if widget.id == id, do: update_fn.(widget), else: widget
    end)
  end
  
  defp widget_position_style(widget) do
    x = (widget.config[:x] || 0) * grid_cell_width()
    y = (widget.config[:y] || 0) * @grid_row_height
    width = (widget.config[:width] || 4) * grid_cell_width()
    height = (widget.config[:height] || 3) * @grid_row_height
    
    "left: #{x}%; top: #{y}px; width: #{width}%; height: #{height}px;"
  end
  
  defp grid_cell_width do
    100.0 / @grid_cols
  end
  
  defp grid_rows(widgets) do
    max_row = Enum.reduce(widgets, 0, fn widget, acc ->
      row = (widget.config[:y] || 0) + (widget.config[:height] || 3)
      max(row, acc)
    end)
    
    max(max_row, 8)
  end
  
  defp calculate_min_height(widgets) do
    grid_rows(widgets) * @grid_row_height
  end
  
  defp render_widget_content(widget) do
    # This would be implemented based on widget type
    # For now, return placeholder content
    nil
  end
  
  defp serialize_layout(widgets) do
    widgets
    |> Enum.map(fn widget ->
      %{
        type: widget.type,
        config: widget.config,
        data_config: widget.data_config
      }
    end)
    |> Jason.encode!()
  end
  
  defp deserialize_layout(layout_data) do
    layout_data
    |> Jason.decode!()
    |> Enum.map(fn widget_data ->
      %{
        id: "widget-#{System.unique_integer([:positive])}",
        type: SafeAtom.to_widget_type(widget_data["type"]),
        config: widget_data["config"],
        data_config: widget_data["data_config"],
        data: nil
      }
    end)
  end
  
  defp save_layout_to_storage(layout_data) do
    # Implementation would save to database or local storage
    {:ok, layout_data}
  end
  
  defp load_layout_from_storage do
    # Implementation would load from database or local storage
    {:error, :not_found}
  end
  
  def __hooks__ do
    """
    export const DashboardLayout = {
      mounted() {
        this.setupLayoutManager();
      },
      
      setupLayoutManager() {
        this.gridCols = parseInt(this.el.dataset.gridCols || '12');
        this.rowHeight = parseInt(this.el.dataset.rowHeight || '100');
        
        this.handleEvent('widget_added', ({widget_id}) => {
          this.animateWidgetEntry(widget_id);
        });
      },
      
      animateWidgetEntry(widgetId) {
        const widget = document.getElementById(`widget-wrapper-${widgetId}`);
        if (widget) {
          widget.style.opacity = '0';
          widget.style.transform = 'scale(0.9)';
          
          requestAnimationFrame(() => {
            widget.style.transition = 'opacity 0.3s, transform 0.3s';
            widget.style.opacity = '1';
            widget.style.transform = 'scale(1)';
          });
        }
      }
    };
    """
  end
end