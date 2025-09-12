defmodule SelectoComponents.CTE.Visualizer do
  @moduledoc """
  Visualizes Common Table Expression (CTE) dependencies and relationships.
  """

  use Phoenix.Component
  import Phoenix.LiveView
  alias Phoenix.LiveView.JS

  @doc """
  Renders a CTE dependency graph.
  """
  def cte_graph(assigns) do
    assigns = assign_defaults(assigns)
    
    ~H"""
    <div class="cte-visualizer" id={"cte-graph-#{@id}"}>
      <div class="bg-white rounded-lg shadow-lg">
        <div class="px-6 py-4 border-b bg-gray-50">
          <div class="flex items-center justify-between">
            <h3 class="text-lg font-semibold">CTE Dependency Graph</h3>
            <div class="flex space-x-2">
              <button
                type="button"
                phx-click="zoom_in"
                class="p-2 text-gray-600 hover:text-gray-800 transition-colors"
              >
                <.icon name="hero-magnifying-glass-plus" class="w-5 h-5" />
              </button>
              <button
                type="button"
                phx-click="zoom_out"
                class="p-2 text-gray-600 hover:text-gray-800 transition-colors"
              >
                <.icon name="hero-magnifying-glass-minus" class="w-5 h-5" />
              </button>
              <button
                type="button"
                phx-click="reset_zoom"
                class="p-2 text-gray-600 hover:text-gray-800 transition-colors"
              >
                <.icon name="hero-arrow-path" class="w-5 h-5" />
              </button>
            </div>
          </div>
        </div>
        
        <div class="p-6">
          <div
            class="cte-graph-container"
            id={"cte-graph-container-#{@id}"}
            phx-hook="CTEGraphRenderer"
            data-ctes={Jason.encode!(@ctes)}
            data-dependencies={Jason.encode!(@dependencies)}
            style="height: 400px; position: relative; overflow: hidden;"
          >
            <!-- Graph will be rendered here by JavaScript -->
            <svg class="w-full h-full">
              <%= for cte <- @ctes do %>
                <.cte_node cte={cte} position={get_position(cte, @layout)} />
              <% end %>
              
              <%= for dep <- @dependencies do %>
                <.cte_edge
                  from={dep.from}
                  to={dep.to}
                  from_pos={get_position(dep.from, @layout)}
                  to_pos={get_position(dep.to, @layout)}
                />
              <% end %>
            </svg>
          </div>
          
          <div class="mt-4 grid grid-cols-3 gap-4 text-sm">
            <div class="bg-blue-50 p-3 rounded">
              <div class="font-medium text-blue-900">Total CTEs</div>
              <div class="text-2xl font-bold text-blue-600"><%= length(@ctes) %></div>
            </div>
            <div class="bg-green-50 p-3 rounded">
              <div class="font-medium text-green-900">Dependencies</div>
              <div class="text-2xl font-bold text-green-600"><%= length(@dependencies) %></div>
            </div>
            <div class="bg-purple-50 p-3 rounded">
              <div class="font-medium text-purple-900">Max Depth</div>
              <div class="text-2xl font-bold text-purple-600"><%= calculate_max_depth(@ctes, @dependencies) %></div>
            </div>
          </div>
        </div>
        
        <%= if @selected_cte do %>
          <div class="px-6 py-4 border-t bg-gray-50">
            <.cte_details cte={@selected_cte} performance={@performance[@selected_cte.name]} />
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @doc """
  Renders a single CTE node in the graph.
  """
  def cte_node(assigns) do
    ~H"""
    <g
      transform={"translate(#{@position.x}, #{@position.y})"}
      class="cte-node cursor-pointer"
      phx-click="select_cte"
      phx-value-name={@cte.name}
    >
      <rect
        x="-60"
        y="-25"
        width="120"
        height="50"
        rx="5"
        fill={cte_color(@cte.type)}
        stroke="#374151"
        stroke-width="2"
      />
      <text
        text-anchor="middle"
        y="0"
        fill="white"
        font-weight="bold"
        font-size="14"
      >
        <%= @cte.name %>
      </text>
      <text
        text-anchor="middle"
        y="15"
        fill="white"
        font-size="12"
        opacity="0.9"
      >
        <%= @cte.type %>
      </text>
    </g>
    """
  end

  @doc """
  Renders an edge between CTE nodes.
  """
  def cte_edge(assigns) do
    assigns = assign(assigns, :path, calculate_edge_path(assigns.from_pos, assigns.to_pos))
    
    ~H"""
    <g class="cte-edge">
      <path
        d={@path}
        fill="none"
        stroke="#6B7280"
        stroke-width="2"
        marker-end="url(#arrowhead)"
      />
    </g>
    """
  end

  @doc """
  Shows detailed information about a selected CTE.
  """
  def cte_details(assigns) do
    ~H"""
    <div class="cte-details">
      <h4 class="font-semibold text-lg mb-3"><%= @cte.name %> Details</h4>
      
      <div class="grid grid-cols-2 gap-4">
        <div>
          <h5 class="font-medium text-sm text-gray-700 mb-2">Definition</h5>
          <pre class="bg-gray-100 p-3 rounded text-xs overflow-x-auto">
<%= format_sql(@cte.definition) %>
          </pre>
        </div>
        
        <div>
          <h5 class="font-medium text-sm text-gray-700 mb-2">Metrics</h5>
          <%= if @performance do %>
            <dl class="space-y-2">
              <div class="flex justify-between">
                <dt class="text-sm text-gray-600">Execution Time:</dt>
                <dd class="text-sm font-medium"><%= format_duration(@performance.execution_time) %></dd>
              </div>
              <div class="flex justify-between">
                <dt class="text-sm text-gray-600">Row Count:</dt>
                <dd class="text-sm font-medium"><%= format_number(@performance.row_count) %></dd>
              </div>
              <div class="flex justify-between">
                <dt class="text-sm text-gray-600">Memory Usage:</dt>
                <dd class="text-sm font-medium"><%= format_bytes(@performance.memory_usage) %></dd>
              </div>
            </dl>
          <% else %>
            <p class="text-sm text-gray-500 italic">No performance data available</p>
          <% end %>
        </div>
      </div>
      
      <div class="mt-4">
        <h5 class="font-medium text-sm text-gray-700 mb-2">Dependencies</h5>
        <div class="flex flex-wrap gap-2">
          <%= for dep <- get_cte_dependencies(@cte.name, @dependencies) do %>
            <span class="px-2 py-1 bg-blue-100 text-blue-700 rounded text-sm">
              <%= dep %>
            </span>
          <% end %>
        </div>
      </div>
      
      <div class="mt-4 flex space-x-2">
        <button
          type="button"
          phx-click="debug_cte"
          phx-value-name={@cte.name}
          class="px-3 py-1 bg-blue-600 text-white rounded text-sm hover:bg-blue-700"
        >
          Debug
        </button>
        <button
          type="button"
          phx-click="export_cte"
          phx-value-name={@cte.name}
          class="px-3 py-1 bg-gray-600 text-white rounded text-sm hover:bg-gray-700"
        >
          Export
        </button>
        <button
          type="button"
          phx-click="optimize_cte"
          phx-value-name={@cte.name}
          class="px-3 py-1 bg-green-600 text-white rounded text-sm hover:bg-green-700"
        >
          Optimize
        </button>
      </div>
    </div>
    """
  end

  # Private functions

  defp assign_defaults(assigns) do
    assigns
    |> assign_new(:id, fn -> Ecto.UUID.generate() end)
    |> assign_new(:ctes, fn -> [] end)
    |> assign_new(:dependencies, fn -> [] end)
    |> assign_new(:layout, fn -> calculate_layout(assigns[:ctes] || [], assigns[:dependencies] || []) end)
    |> assign_new(:selected_cte, fn -> nil end)
    |> assign_new(:performance, fn -> %{} end)
  end

  defp calculate_layout(ctes, dependencies) do
    # Simple hierarchical layout algorithm
    levels = calculate_levels(ctes, dependencies)
    
    Enum.reduce(ctes, %{}, fn cte, acc ->
      level = Map.get(levels, cte.name, 0)
      index = Enum.count(acc, fn {_, pos} -> pos.y == level * 100 + 50 end)
      
      Map.put(acc, cte.name, %{
        x: index * 150 + 100,
        y: level * 100 + 50
      })
    end)
  end

  defp calculate_levels(ctes, dependencies) do
    # Topological sort to determine CTE levels
    graph = build_dependency_graph(dependencies)
    
    Enum.reduce(ctes, %{}, fn cte, acc ->
      Map.put(acc, cte.name, calculate_node_level(cte.name, graph, %{}))
    end)
  end

  defp build_dependency_graph(dependencies) do
    Enum.reduce(dependencies, %{}, fn dep, acc ->
      Map.update(acc, dep.from, [dep.to], &[dep.to | &1])
    end)
  end

  defp calculate_node_level(node, graph, visited) do
    if Map.has_key?(visited, node) do
      0
    else
      deps = Map.get(graph, node, [])
      if deps == [] do
        0
      else
        visited = Map.put(visited, node, true)
        1 + Enum.max(Enum.map(deps, &calculate_node_level(&1, graph, visited)))
      end
    end
  end

  defp get_position(cte_or_name, layout) do
    name = if is_map(cte_or_name), do: cte_or_name.name, else: cte_or_name
    Map.get(layout, name, %{x: 0, y: 0})
  end

  defp calculate_edge_path(from_pos, to_pos) do
    # Bezier curve for smooth edges
    ctrl1_x = from_pos.x + (to_pos.x - from_pos.x) * 0.5
    ctrl1_y = from_pos.y
    ctrl2_x = from_pos.x + (to_pos.x - from_pos.x) * 0.5
    ctrl2_y = to_pos.y
    
    "M #{from_pos.x} #{from_pos.y} C #{ctrl1_x} #{ctrl1_y}, #{ctrl2_x} #{ctrl2_y}, #{to_pos.x} #{to_pos.y}"
  end

  defp cte_color("recursive"), do: "#DC2626"
  defp cte_color("materialized"), do: "#059669"
  defp cte_color("standard"), do: "#2563EB"
  defp cte_color(_), do: "#6B7280"

  defp calculate_max_depth(ctes, dependencies) do
    levels = calculate_levels(ctes, dependencies)
    if map_size(levels) > 0 do
      Enum.max(Map.values(levels))
    else
      0
    end
  end

  defp get_cte_dependencies(cte_name, dependencies) do
    dependencies
    |> Enum.filter(&(&1.from == cte_name))
    |> Enum.map(&(&1.to))
  end

  defp format_sql(sql) when is_binary(sql) do
    sql
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.join("\n")
  end
  defp format_sql(_), do: ""

  defp format_duration(ms) when is_number(ms), do: "#{ms}ms"
  defp format_duration(_), do: "N/A"

  defp format_number(num) when is_number(num) do
    num
    |> to_string()
    |> String.replace(~r/(\d)(?=(\d{3})+(?!\d))/, "\\1,")
  end
  defp format_number(_), do: "N/A"

  defp format_bytes(bytes) when is_number(bytes) do
    cond do
      bytes < 1024 -> "#{bytes} B"
      bytes < 1024 * 1024 -> "#{Float.round(bytes / 1024, 1)} KB"
      bytes < 1024 * 1024 * 1024 -> "#{Float.round(bytes / (1024 * 1024), 1)} MB"
      true -> "#{Float.round(bytes / (1024 * 1024 * 1024), 1)} GB"
    end
  end
  defp format_bytes(_), do: "N/A"

  defp icon(assigns) do
    ~H"""
    <svg class={@class} fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <%= case @name do %>
        <% "hero-magnifying-glass-plus" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0zM10 7v6m3-3H7" />
        <% "hero-magnifying-glass-minus" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0zM13 10H7" />
        <% "hero-arrow-path" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
        <% _ -> %>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
      <% end %>
    </svg>
    """
  end

  @doc """
  JavaScript hooks for CTE graph rendering.
  """
  def __hooks__() do
    """
    export const CTEGraphRenderer = {
      mounted() {
        this.zoom = 1;
        this.panX = 0;
        this.panY = 0;
        
        this.initializeGraph();
        this.setupInteractions();
      },
      
      initializeGraph() {
        const ctes = JSON.parse(this.el.dataset.ctes || '[]');
        const dependencies = JSON.parse(this.el.dataset.dependencies || '[]');
        
        // Additional D3.js or custom graph rendering logic would go here
        console.log('Initializing CTE graph with', ctes.length, 'CTEs');
      },
      
      setupInteractions() {
        // Pan and zoom functionality
        this.el.addEventListener('wheel', (e) => {
          e.preventDefault();
          const delta = e.deltaY > 0 ? 0.9 : 1.1;
          this.zoom *= delta;
          this.updateTransform();
        });
        
        let isPanning = false;
        let startX = 0;
        let startY = 0;
        
        this.el.addEventListener('mousedown', (e) => {
          isPanning = true;
          startX = e.clientX - this.panX;
          startY = e.clientY - this.panY;
        });
        
        document.addEventListener('mousemove', (e) => {
          if (!isPanning) return;
          this.panX = e.clientX - startX;
          this.panY = e.clientY - startY;
          this.updateTransform();
        });
        
        document.addEventListener('mouseup', () => {
          isPanning = false;
        });
      },
      
      updateTransform() {
        const svg = this.el.querySelector('svg');
        if (svg) {
          const g = svg.querySelector('g') || svg;
          g.style.transform = `translate(${this.panX}px, ${this.panY}px) scale(${this.zoom})`;
        }
      }
    };
    """
  end
end