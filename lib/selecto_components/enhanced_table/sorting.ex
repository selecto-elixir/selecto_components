defmodule SelectoComponents.EnhancedTable.Sorting do
  @moduledoc """
  Provides sorting functionality for SelectoComponents tables.
  Supports single and multi-column sorting with visual indicators.
  """

  use Phoenix.Component
  alias SelectoComponents.SafeAtom

  @doc """
  Initialize sort state in the socket assigns.
  """
  def init_sort_state(socket) do
    Phoenix.Component.assign(socket,
      sort_by: [],  # List of {column, direction} tuples
      sort_mode: :single  # :single or :multi
    )
  end

  @doc """
  Handle sort column click event.
  
  ## Parameters
    - column: The column identifier to sort by
    - socket: The LiveView socket
    - multi: Boolean indicating if multi-column sort (shift-click)
  """
  def handle_sort_click(column, socket, multi \\ false) do
    current_sort = socket.assigns[:sort_by] || []
    
    new_sort = if multi && socket.assigns[:sort_mode] == :multi do
      # Multi-column sorting
      update_multi_sort(current_sort, column)
    else
      # Single column sorting
      update_single_sort(current_sort, column)
    end
    
    Phoenix.Component.assign(socket, :sort_by, new_sort)
  end

  @doc """
  Apply sorting to Selecto query.
  Column-based sorting takes priority over query-based sorting.
  """
  def apply_sort_to_query(selecto, sort_by) when is_list(sort_by) and length(sort_by) > 0 do
    # Build the new order expressions
    order_expressions = Enum.map(sort_by, fn {column, direction} ->
      case direction do
        :asc -> "#{column}"
        :desc -> "#{column} DESC"
        _ -> "#{column}"
      end
    end)
    
    # Replace the order_by entirely with column-based sorting
    # This ensures column sorting takes priority
    put_in(selecto.set.order_by, order_expressions)
  end
  def apply_sort_to_query(selecto, _), do: selecto

  @doc """
  Get sort indicator for a column.
  Returns :asc, :desc, or nil
  """
  def get_sort_indicator(column, sort_by) do
    case List.keyfind(sort_by || [], column, 0) do
      {^column, direction} -> direction
      _ -> nil
    end
  end

  @doc """
  Get sort position for multi-column sorting.
  Returns the position number or nil.
  """
  def get_sort_position(column, sort_by) do
    sort_by = sort_by || []
    case Enum.find_index(sort_by, fn {col, _} -> col == column end) do
      nil -> nil
      index -> index + 1
    end
  end

  @doc """
  Render sort indicator component.
  """
  def sort_indicator(assigns) do
    indicator = get_sort_indicator(assigns.column, assigns[:sort_by])
    position = if assigns[:show_position] do
      get_sort_position(assigns.column, assigns[:sort_by])
    else
      nil
    end
    
    assigns = Phoenix.Component.assign(assigns, indicator: indicator, position: position)
    
    ~H"""
    <span class="inline-flex items-center ml-1">
      <%= if @position do %>
        <span class="text-xs text-gray-500 mr-1"><%= @position %></span>
      <% end %>
      <%= case @indicator do %>
        <% :asc -> %>
          <svg class="w-4 h-4 text-blue-600" fill="currentColor" viewBox="0 0 20 20">
            <path d="M7 10l5-5 5 5H7z"/>
          </svg>
        <% :desc -> %>
          <svg class="w-4 h-4 text-blue-600" fill="currentColor" viewBox="0 0 20 20">
            <path d="M7 10l5 5 5-5H7z"/>
          </svg>
        <% _ -> %>
          <svg class="w-4 h-4 text-gray-400 opacity-50" fill="currentColor" viewBox="0 0 20 20">
            <path d="M10 3l-7 7h4v7h6v-7h4L10 3z" opacity="0.3"/>
            <path d="M10 17l7-7h-4V3H7v7H3l7 7z" opacity="0.3"/>
          </svg>
      <% end %>
    </span>
    """
  end

  @doc """
  Render sortable column header.
  """
  def sortable_header(assigns) do
    # Check if resizable is enabled
    if Map.get(assigns, :resizable, false) && Map.get(assigns, :column_config) do
      column_config = Map.get(assigns.column_config, assigns.column, %{
        width: 150,
        min_width: 50,
        max_width: 500
      })
      
      assigns = Phoenix.Component.assign(assigns, :col_config, column_config)
      
      ~H"""
      <th
        class={"relative px-2 py-3 text-xs font-medium tracking-wider text-left text-gray-700 uppercase bg-gray-50 select-none #{if get_sort_indicator(@column, @sort_by), do: "font-bold", else: ""}"}
        style={"width: #{@col_config.width}px; min-width: #{@col_config.min_width}px; max-width: #{@col_config.max_width}px;"}
        data-column-id={@column}
      >
        <div 
          class="flex items-center justify-between cursor-pointer hover:bg-gray-100 px-2 rounded"
          phx-click="sort_column"
          phx-value-column={@column}
          phx-value-multi={@multi || false}
          phx-target={@target}
          title={"Click to sort by #{@label}#{if @multi, do: " (Shift+Click for multi-column sort)", else: ""}"}
          draggable={if Map.get(assigns, :reorderable, false), do: "true", else: "false"}
          phx-hook={if Map.get(assigns, :reorderable, false), do: "ColumnReorder", else: nil}
          id={"col-header-#{@column}"}
          data-column-id={@column}
        >
          <span class="truncate"><%= @label %></span>
          <.sort_indicator column={@column} sort_by={@sort_by} show_position={@multi} />
        </div>
        
        <%!-- Resize handle --%>
        <%= if Map.get(assigns, :resizable, false) do %>
          <div
            class="absolute top-0 right-0 bottom-0 w-1 cursor-col-resize hover:bg-blue-500 transition-colors"
            phx-hook="ColumnResize"
            id={"resize-#{@column}"}
            data-column-id={@column}
          >
            <div class="absolute inset-y-0 -left-1 -right-1 z-10"></div>
          </div>
        <% end %>
      </th>
      """
    else
      # Original non-resizable header
      ~H"""
      <th
        class={"px-6 py-3 text-xs font-medium tracking-wider text-left text-gray-700 uppercase bg-gray-50 cursor-pointer hover:bg-gray-100 select-none #{if get_sort_indicator(@column, @sort_by), do: "font-bold", else: ""}"}
        phx-click="sort_column"
        phx-value-column={@column}
        phx-value-multi={@multi || false}
        phx-target={@target}
        title={"Click to sort by #{@label}#{if @multi, do: " (Shift+Click for multi-column sort)", else: ""}"}
      >
        <div class="flex items-center justify-between">
          <span><%= @label %></span>
          <.sort_indicator column={@column} sort_by={@sort_by} show_position={@multi} />
        </div>
      </th>
      """
    end
  end

  # Private functions

  defp update_single_sort(current_sort, column) do
    case List.keyfind(current_sort, column, 0) do
      {^column, :asc} -> [{column, :desc}]
      {^column, :desc} -> []  # Remove sort
      _ -> [{column, :asc}]
    end
  end

  defp update_multi_sort(current_sort, column) do
    case List.keyfind(current_sort, column, 0) do
      {^column, :asc} ->
        # Change to desc
        List.keyreplace(current_sort, column, 0, {column, :desc})
      {^column, :desc} ->
        # Remove from sort
        List.keydelete(current_sort, column, 0)
      nil ->
        # Add to sort
        current_sort ++ [{column, :asc}]
    end
  end

  @doc """
  Serialize sort state for URL or storage.
  """
  def serialize_sort(sort_by) do
    Enum.map(sort_by, fn {col, dir} -> 
      %{"column" => to_string(col), "direction" => to_string(dir)}
    end)
  end

  @doc """
  Deserialize sort state from URL or storage.
  """
  def deserialize_sort(nil), do: []
  def deserialize_sort(sort_data) when is_list(sort_data) do
    Enum.map(sort_data, fn
      %{"column" => col, "direction" => dir} ->
        # Use SafeAtom to prevent atom table exhaustion from user input
        col_atom = SafeAtom.to_existing(col)
        dir_atom = SafeAtom.to_sort_direction(dir)

        if col_atom do
          {col_atom, dir_atom}
        else
          nil
        end

      _ ->
        nil
    end)
    |> Enum.reject(&is_nil/1)
  end
  def deserialize_sort(_), do: []

end