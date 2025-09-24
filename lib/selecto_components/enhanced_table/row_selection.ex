defmodule SelectoComponents.EnhancedTable.RowSelection do
  @moduledoc """
  Row selection management for tables with support for bulk operations.
  """
  
  use Phoenix.Component
  alias Phoenix.LiveView.JS
  
  @doc """
  Initialize row selection state.
  """
  def init_selection(socket) do
    socket
    |> assign(
      selected_rows: MapSet.new(),
      select_all: false,
      selection_count: 0,
      total_rows: 0,
      selection_mode: :none  # :none, :single, :multiple
    )
  end
  
  @doc """
  Toggle selection for a single row.
  """
  def toggle_row_selection(socket, row_id) do
    selected_rows = socket.assigns.selected_rows
    
    updated_rows = 
      if MapSet.member?(selected_rows, row_id) do
        MapSet.delete(selected_rows, row_id)
      else
        case socket.assigns.selection_mode do
          :single -> MapSet.new([row_id])
          _ -> MapSet.put(selected_rows, row_id)
        end
      end
    
    socket
    |> assign(
      selected_rows: updated_rows,
      selection_count: MapSet.size(updated_rows),
      select_all: false
    )
    |> broadcast_selection_change()
  end
  
  @doc """
  Select all rows.
  """
  def select_all_rows(socket, all_row_ids) do
    socket
    |> assign(
      selected_rows: MapSet.new(all_row_ids),
      selection_count: length(all_row_ids),
      select_all: true
    )
    |> broadcast_selection_change()
  end
  
  @doc """
  Clear all selections.
  """
  def clear_selection(socket) do
    socket
    |> assign(
      selected_rows: MapSet.new(),
      selection_count: 0,
      select_all: false
    )
    |> broadcast_selection_change()
  end
  
  @doc """
  Invert current selection.
  """
  def invert_selection(socket, all_row_ids) do
    current_selected = socket.assigns.selected_rows
    all_ids = MapSet.new(all_row_ids)
    inverted = MapSet.difference(all_ids, current_selected)
    
    socket
    |> assign(
      selected_rows: inverted,
      selection_count: MapSet.size(inverted),
      select_all: false
    )
    |> broadcast_selection_change()
  end
  
  @doc """
  Select rows in a range (shift-click).
  """
  def select_range(socket, from_id, to_id, all_row_ids) do
    from_index = Enum.find_index(all_row_ids, & &1 == from_id) || 0
    to_index = Enum.find_index(all_row_ids, & &1 == to_id) || 0
    
    {start_idx, end_idx} = if from_index <= to_index do
      {from_index, to_index}
    else
      {to_index, from_index}
    end
    
    range_ids = 
      all_row_ids
      |> Enum.slice(start_idx..end_idx)
      |> MapSet.new()
    
    updated_rows = MapSet.union(socket.assigns.selected_rows, range_ids)
    
    socket
    |> assign(
      selected_rows: updated_rows,
      selection_count: MapSet.size(updated_rows),
      select_all: false
    )
    |> broadcast_selection_change()
  end
  
  @doc """
  Selection checkbox component for table header.
  """
  def selection_header(assigns) do
    ~H"""
    <th class="w-12 px-3 py-3 text-left">
      <div class="flex items-center">
        <input
          type="checkbox"
          class="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
          checked={@select_all || (@selection_count > 0 && @selection_count == @total_rows)}
          indeterminate={@selection_count > 0 && @selection_count < @total_rows}
          phx-click="toggle_select_all"
          phx-target={@target}
          phx-hook="SelectAllCheckbox"
          id="select-all-checkbox"
        />
        <div class="ml-2 relative">
          <button
            type="button"
            class="text-gray-400 hover:text-gray-600"
            phx-click={toggle_selection_menu()}
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
            </svg>
          </button>
          
          <%!-- Selection dropdown menu --%>
          <div 
            id="selection-menu"
            class="hidden absolute left-0 mt-1 w-40 bg-white rounded-md shadow-lg z-10 border border-gray-200"
          >
            <button
              type="button"
              class="w-full text-left px-3 py-2 text-sm hover:bg-gray-100"
              phx-click="select_all"
              phx-target={@target}
            >
              Select All
            </button>
            <button
              type="button"
              class="w-full text-left px-3 py-2 text-sm hover:bg-gray-100"
              phx-click="select_none"
              phx-target={@target}
            >
              Select None
            </button>
            <button
              type="button"
              class="w-full text-left px-3 py-2 text-sm hover:bg-gray-100"
              phx-click="invert_selection"
              phx-target={@target}
            >
              Invert Selection
            </button>
            <hr class="my-1" />
            <button
              type="button"
              class="w-full text-left px-3 py-2 text-sm hover:bg-gray-100"
              phx-click="select_visible"
              phx-target={@target}
            >
              Select Visible
            </button>
            <%= if @selection_count > 0 do %>
              <div class="px-3 py-2 text-xs text-gray-500">
                <%= @selection_count %> selected
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </th>
    """
  end
  
  @doc """
  Selection checkbox component for table rows.
  """
  def row_checkbox(assigns) do
    ~H"""
    <td class="w-12 px-3 py-2">
      <input
        type="checkbox"
        class="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
        checked={MapSet.member?(@selected_rows, @row_id)}
        phx-click="toggle_row_selection"
        phx-value-id={@row_id}
        phx-target={@target}
        phx-hook="RowCheckbox"
        data-row-id={@row_id}
        id={"row-checkbox-#{@row_id}"}
      />
    </td>
    """
  end
  
  @doc """
  Selection indicator bar component.
  """
  def selection_bar(assigns) do
    ~H"""
    <div 
      class={"transition-all duration-300 #{if @selection_count > 0, do: "h-12 opacity-100", else: "h-0 opacity-0 overflow-hidden"}"}
      id="selection-bar"
    >
      <div class="bg-blue-50 border-b border-blue-200 px-4 py-2 flex items-center justify-between">
        <div class="flex items-center space-x-4">
          <span class="text-sm font-medium text-blue-900">
            <%= @selection_count %> <%= if @selection_count == 1, do: "item", else: "items" %> selected
          </span>
          
          <button
            type="button"
            class="text-sm text-blue-600 hover:text-blue-800"
            phx-click="clear_selection"
            phx-target={@target}
          >
            Clear selection
          </button>
        </div>
        
        <div class="flex items-center space-x-2">
          <%= render_slot(@inner_block) %>
        </div>
      </div>
    </div>
    """
  end
  
  @doc """
  Get selected row IDs as a list.
  """
  def get_selected_ids(socket) do
    MapSet.to_list(socket.assigns.selected_rows)
  end
  
  @doc """
  Check if any rows are selected.
  """
  def has_selection?(socket) do
    socket.assigns.selection_count > 0
  end
  
  @doc """
  Check if a specific row is selected.
  """
  def is_selected?(socket, row_id) do
    MapSet.member?(socket.assigns.selected_rows, row_id)
  end
  
  # Private functions
  
  defp broadcast_selection_change(socket) do
    send(self(), {:selection_changed, socket.assigns.selected_rows})
    socket
  end
  
  defp toggle_selection_menu do
    JS.toggle(
      to: "#selection-menu",
      in: {"ease-out duration-100", "opacity-0 scale-95", "opacity-100 scale-100"},
      out: {"ease-in duration-75", "opacity-100 scale-100", "opacity-0 scale-95"}
    )
  end
  
  @doc """
  JavaScript hooks for row selection.
  """
  def __hooks__() do
    %{
      "SelectAllCheckbox" => %{
        mounted: """
        // Handle indeterminate state
        this.updateIndeterminate = () => {
          const total = parseInt(this.el.dataset.total || '0');
          const selected = parseInt(this.el.dataset.selected || '0');
          this.el.indeterminate = selected > 0 && selected < total;
        };
        
        this.updateIndeterminate();
        """,
        
        updated: """
        this.updateIndeterminate();
        """
      },
      
      "RowCheckbox" => %{
        mounted: """
        this.lastChecked = null;
        
        // Handle shift-click for range selection
        this.handleClick = (e) => {
          const rowId = this.el.dataset.rowId;
          
          if (e.shiftKey && this.lastChecked) {
            e.preventDefault();
            this.pushEventTo(this.el, 'select_range', {
              from: this.lastChecked,
              to: rowId
            });
          }
          
          this.lastChecked = rowId;
        };
        
        this.el.addEventListener('click', this.handleClick);
        
        // Handle keyboard shortcuts
        this.handleKeydown = (e) => {
          if (e.key === ' ' && e.target === this.el) {
            e.preventDefault();
            this.el.click();
          }
        };
        
        this.el.addEventListener('keydown', this.handleKeydown);
        """,
        
        destroyed: """
        this.el.removeEventListener('click', this.handleClick);
        this.el.removeEventListener('keydown', this.handleKeydown);
        """
      },
      
      "SelectionKeyboardShortcuts" => %{
        mounted: """
        this.handleKeydown = (e) => {
          // Ctrl/Cmd + A: Select all
          if ((e.ctrlKey || e.metaKey) && e.key === 'a') {
            e.preventDefault();
            this.pushEvent('select_all', {});
          }
          
          // Ctrl/Cmd + Shift + A: Deselect all
          if ((e.ctrlKey || e.metaKey) && e.shiftKey && e.key === 'a') {
            e.preventDefault();
            this.pushEvent('select_none', {});
          }
          
          // Ctrl/Cmd + I: Invert selection
          if ((e.ctrlKey || e.metaKey) && e.key === 'i') {
            e.preventDefault();
            this.pushEvent('invert_selection', {});
          }
        };
        
        document.addEventListener('keydown', this.handleKeydown);
        """,
        
        destroyed: """
        document.removeEventListener('keydown', this.handleKeydown);
        """
      }
    }
  end
end