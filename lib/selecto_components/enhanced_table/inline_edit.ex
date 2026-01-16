defmodule SelectoComponents.EnhancedTable.InlineEdit do
  @moduledoc """
  Provides inline editing capabilities for table cells with validation and optimistic updates.
  """
  
  use Phoenix.Component
  
  @doc """
  Initialize inline editing state for a component.
  """
  def init_inline_edit(socket) do
    socket
    |> assign(
      editing_cells: %{},
      edit_history: [],
      edit_history_index: 0,
      pending_changes: %{},
      validation_errors: %{}
    )
  end
  
  @doc """
  Handle cell edit activation.
  """
  def activate_cell_edit(socket, cell_id, initial_value) do
    editing_cells = Map.put(socket.assigns.editing_cells, cell_id, %{
      original_value: initial_value,
      current_value: initial_value,
      started_at: System.system_time(:second)
    })
    
    assign(socket, editing_cells: editing_cells)
  end
  
  @doc """
  Handle cell value update.
  """
  def update_cell_value(socket, cell_id, new_value) do
    case validate_cell_value(socket, cell_id, new_value) do
      {:ok, validated_value} ->
        editing_cells =
          Map.update!(socket.assigns.editing_cells, cell_id, fn edit ->
            Map.put(edit, :current_value, validated_value)
          end)

        socket
        |> assign(editing_cells: editing_cells)
        |> assign(validation_errors: Map.delete(socket.assigns.validation_errors, cell_id))

      {:error, error_message} ->
        # Keep the raw value in editing_cells but mark as invalid
        editing_cells =
          Map.update!(socket.assigns.editing_cells, cell_id, fn edit ->
            Map.put(edit, :current_value, new_value)
          end)

        socket
        |> assign(editing_cells: editing_cells)
        |> assign(validation_errors: Map.put(socket.assigns.validation_errors, cell_id, error_message))
    end
  end
  
  @doc """
  Commit cell edit with optimistic update.
  """
  def commit_cell_edit(socket, cell_id) do
    case Map.get(socket.assigns.editing_cells, cell_id) do
      nil -> 
        socket
        
      edit_data ->
        # Add to history for undo/redo
        history_entry = %{
          cell_id: cell_id,
          old_value: edit_data.original_value,
          new_value: edit_data.current_value,
          timestamp: System.system_time(:second)
        }
        
        # Update history (truncate forward history if we're not at the end)
        history = Enum.take(socket.assigns.edit_history, socket.assigns.edit_history_index)
        new_history = history ++ [history_entry]
        
        # Add to pending changes for batch processing
        pending_changes = Map.put(
          socket.assigns.pending_changes,
          cell_id,
          edit_data.current_value
        )
        
        socket
        |> assign(
          editing_cells: Map.delete(socket.assigns.editing_cells, cell_id),
          edit_history: new_history,
          edit_history_index: length(new_history),
          pending_changes: pending_changes
        )
        |> apply_optimistic_update(cell_id, edit_data.current_value)
    end
  end
  
  @doc """
  Cancel cell edit.
  """
  def cancel_cell_edit(socket, cell_id) do
    socket
    |> assign(
      editing_cells: Map.delete(socket.assigns.editing_cells, cell_id),
      validation_errors: Map.delete(socket.assigns.validation_errors, cell_id)
    )
  end
  
  @doc """
  Undo last edit.
  """
  def undo_edit(socket) do
    if socket.assigns.edit_history_index > 0 do
      new_index = socket.assigns.edit_history_index - 1
      history_entry = Enum.at(socket.assigns.edit_history, new_index)
      
      socket
      |> assign(edit_history_index: new_index)
      |> rollback_change(history_entry)
    else
      socket
    end
  end
  
  @doc """
  Redo previously undone edit.
  """
  def redo_edit(socket) do
    if socket.assigns.edit_history_index < length(socket.assigns.edit_history) do
      history_entry = Enum.at(socket.assigns.edit_history, socket.assigns.edit_history_index)
      new_index = socket.assigns.edit_history_index + 1
      
      socket
      |> assign(edit_history_index: new_index)
      |> apply_change(history_entry)
    else
      socket
    end
  end
  
  @doc """
  Batch save all pending changes.
  """
  def save_pending_changes(socket) do
    if map_size(socket.assigns.pending_changes) > 0 do
      # Send batch update to server
      send(self(), {:batch_update, socket.assigns.pending_changes})
      
      assign(socket, pending_changes: %{})
    else
      socket
    end
  end
  
  @doc """
  Inline edit cell component.
  """
  def inline_edit_cell(assigns) do
    ~H"""
    <div 
      class="inline-edit-cell relative"
      phx-hook="InlineEditCell"
      id={@id}
      data-field={@field}
      data-row-id={@row_id}
      data-type={@type}
    >
      <%= if Map.has_key?(@editing_cells, @id) do %>
        <div class="edit-mode">
          <%= render_edit_input(assigns) %>
          <%= if Map.has_key?(@validation_errors, @id) do %>
            <div class="absolute z-10 mt-1 p-1 bg-red-100 border border-red-300 rounded text-xs text-red-700">
              <%= @validation_errors[@id] %>
            </div>
          <% end %>
        </div>
      <% else %>
        <div 
          class="view-mode cursor-pointer hover:bg-gray-50 px-2 py-1 rounded"
          phx-dblclick="activate_edit"
          phx-value-cell-id={@id}
          phx-value-value={@value}
          phx-target={@target}
        >
          <%= format_display_value(@value, @type) %>
          <%= if Map.has_key?(@pending_changes, @id) do %>
            <span class="ml-1 text-xs text-blue-600" title="Pending save">●</span>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
  
  # Render appropriate input based on data type
  defp render_edit_input(%{type: :boolean} = assigns) do
    ~H"""
    <select
      class="w-full px-2 py-1 text-sm border border-blue-500 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
      phx-blur="commit_edit"
      phx-change="update_edit"
      phx-value-cell-id={@id}
      phx-target={@target}
      autofocus
    >
      <option value="true" selected={@editing_cells[@id].current_value == true}>True</option>
      <option value="false" selected={@editing_cells[@id].current_value == false}>False</option>
    </select>
    """
  end
  
  defp render_edit_input(%{type: :number} = assigns) do
    ~H"""
    <input
      type="number"
      value={@editing_cells[@id].current_value}
      class="w-full px-2 py-1 text-sm border border-blue-500 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
      phx-blur="commit_edit"
      phx-keyup="handle_edit_key"
      phx-change="update_edit"
      phx-value-cell-id={@id}
      phx-target={@target}
      autofocus
    />
    """
  end
  
  defp render_edit_input(%{type: :date} = assigns) do
    ~H"""
    <input
      type="date"
      value={@editing_cells[@id].current_value}
      class="w-full px-2 py-1 text-sm border border-blue-500 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
      phx-blur="commit_edit"
      phx-change="update_edit"
      phx-value-cell-id={@id}
      phx-target={@target}
      autofocus
    />
    """
  end
  
  defp render_edit_input(assigns) do
    ~H"""
    <input
      type="text"
      value={@editing_cells[@id].current_value}
      class="w-full px-2 py-1 text-sm border border-blue-500 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
      phx-blur="commit_edit"
      phx-keyup="handle_edit_key"
      phx-change="update_edit"
      phx-value-cell-id={@id}
      phx-target={@target}
      autofocus
    />
    """
  end
  
  # Validation - validates cell value based on field configuration
  # Cell ID format is typically "row_id:field_name" or similar
  defp validate_cell_value(socket, cell_id, value) do
    # Extract field name from cell_id (assumes format "row_id:field_name")
    field_name = extract_field_name(cell_id)

    # Get field configuration from socket assigns
    field_config = get_field_config(socket, field_name)

    # Apply validation rules based on field configuration
    validate_by_config(value, field_config)
  end

  # Extract field name from cell_id
  defp extract_field_name(cell_id) when is_binary(cell_id) do
    case String.split(cell_id, ":") do
      [_row_id, field_name] -> String.to_existing_atom(field_name)
      [_row_id, field_name | _rest] -> String.to_existing_atom(field_name)
      _ -> nil
    end
  rescue
    ArgumentError -> nil
  end
  defp extract_field_name(_), do: nil

  # Get field configuration from socket assigns
  defp get_field_config(socket, field_name) when is_atom(field_name) do
    # Try to get field config from various sources
    cond do
      # Check inline_edit_fields config
      Map.has_key?(socket.assigns, :inline_edit_fields) ->
        Map.get(socket.assigns.inline_edit_fields, field_name, %{})

      # Check column definitions
      Map.has_key?(socket.assigns, :columns) ->
        find_column_config(socket.assigns.columns, field_name)

      # Check domain/schema for field type
      Map.has_key?(socket.assigns, :selecto) ->
        get_field_from_selecto(socket.assigns.selecto, field_name)

      true ->
        %{}
    end
  end
  defp get_field_config(_socket, _field_name), do: %{}

  defp find_column_config(columns, field_name) when is_list(columns) do
    Enum.find_value(columns, %{}, fn col ->
      if Map.get(col, :field) == field_name or Map.get(col, :name) == field_name do
        col
      end
    end)
  end
  defp find_column_config(_, _), do: %{}

  defp get_field_from_selecto(selecto, field_name) do
    case Map.get(selecto, :domain) do
      nil -> %{}
      domain ->
        columns = Map.get(domain, :columns, %{})
        Map.get(columns, field_name, %{})
    end
  end

  # Validate value based on field configuration
  defp validate_by_config(value, config) do
    type = Map.get(config, :type)
    required = Map.get(config, :required, false)
    validations = Map.get(config, :validations, [])

    with :ok <- validate_required(value, required),
         :ok <- validate_type(value, type),
         :ok <- run_custom_validations(value, validations) do
      {:ok, coerce_value(value, type)}
    end
  end

  # Required validation
  defp validate_required(nil, true), do: {:error, "This field is required"}
  defp validate_required("", true), do: {:error, "This field is required"}
  defp validate_required(_, _), do: :ok

  # Type validation
  defp validate_type(value, :integer) when is_binary(value) do
    case Integer.parse(value) do
      {_num, ""} -> :ok
      _ -> {:error, "Must be a valid integer"}
    end
  end
  defp validate_type(value, :float) when is_binary(value) do
    case Float.parse(value) do
      {_num, ""} -> :ok
      {_num, _} -> :ok  # Allow trailing characters for partial input
      _ -> {:error, "Must be a valid number"}
    end
  end
  defp validate_type(value, :decimal) when is_binary(value) do
    case Decimal.parse(value) do
      {%Decimal{}, ""} -> :ok
      {%Decimal{}, _} -> :ok  # Allow partial parse
      :error ->
        # Fall back to Float parsing
        case Float.parse(value) do
          {_num, _} -> :ok
          :error -> {:error, "Must be a valid decimal number"}
        end
    end
  rescue
    _ -> {:error, "Must be a valid decimal number"}
  end
  defp validate_type(value, :boolean) when is_binary(value) do
    if value in ~w(true false 1 0 yes no) do
      :ok
    else
      {:error, "Must be true or false"}
    end
  end
  defp validate_type(value, :date) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, _} -> :ok
      _ -> {:error, "Must be a valid date (YYYY-MM-DD)"}
    end
  end
  defp validate_type(value, :email) when is_binary(value) do
    if Regex.match?(~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/, value) do
      :ok
    else
      {:error, "Must be a valid email address"}
    end
  end
  defp validate_type(_value, _type), do: :ok  # No type validation for unknown types

  # Run custom validations from config
  defp run_custom_validations(value, validations) when is_list(validations) do
    Enum.reduce_while(validations, :ok, fn validation, _acc ->
      case run_validation(value, validation) do
        :ok -> {:cont, :ok}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end
  defp run_custom_validations(_, _), do: :ok

  defp run_validation(value, {:min_length, min}) when is_binary(value) do
    if String.length(value) >= min, do: :ok, else: {:error, "Must be at least #{min} characters"}
  end
  defp run_validation(value, {:max_length, max}) when is_binary(value) do
    if String.length(value) <= max, do: :ok, else: {:error, "Must be at most #{max} characters"}
  end
  defp run_validation(value, {:min, min}) when is_number(value) do
    if value >= min, do: :ok, else: {:error, "Must be at least #{min}"}
  end
  defp run_validation(value, {:max, max}) when is_number(value) do
    if value <= max, do: :ok, else: {:error, "Must be at most #{max}"}
  end
  defp run_validation(value, {:pattern, pattern}) when is_binary(value) do
    if Regex.match?(pattern, value), do: :ok, else: {:error, "Invalid format"}
  end
  defp run_validation(value, {:in, allowed}) when is_list(allowed) do
    if value in allowed, do: :ok, else: {:error, "Must be one of: #{Enum.join(allowed, ", ")}"}
  end
  defp run_validation(value, {:custom, func}) when is_function(func, 1) do
    func.(value)
  end
  defp run_validation(_, _), do: :ok

  # Coerce value to the appropriate type
  defp coerce_value(value, :integer) when is_binary(value) do
    case Integer.parse(value) do
      {num, _} -> num
      :error -> value
    end
  end
  defp coerce_value(value, :float) when is_binary(value) do
    case Float.parse(value) do
      {num, _} -> num
      :error -> value
    end
  end
  defp coerce_value(value, :decimal) when is_binary(value) do
    case Decimal.parse(value) do
      {%Decimal{} = dec, _} -> dec
      :error ->
        case Float.parse(value) do
          {num, _} -> Decimal.from_float(num)
          :error -> value
        end
    end
  rescue
    _ -> value
  end
  defp coerce_value(value, :boolean) when is_binary(value) do
    value in ~w(true 1 yes)
  end
  defp coerce_value(value, :date) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      _ -> value
    end
  end
  defp coerce_value(value, _type), do: value

  # Apply optimistic update to UI
  defp apply_optimistic_update(socket, cell_id, new_value) do
    # Extract row_id and field_name from cell_id
    case String.split(to_string(cell_id), ":") do
      [row_id, field_name] ->
        update_row_data(socket, row_id, field_name, new_value)

      _ ->
        # If cell_id format is unknown, just return socket unchanged
        socket
    end
  end

  # Update the row data in socket assigns
  defp update_row_data(socket, row_id, field_name, new_value) do
    field_atom = try do
      String.to_existing_atom(field_name)
    rescue
      ArgumentError -> String.to_atom(field_name)
    end

    # Check for different data storage patterns
    cond do
      # Stream-based data (Phoenix LiveView streams)
      Map.has_key?(socket.assigns, :streams) and Map.has_key?(socket.assigns.streams, :rows) ->
        # For streams, we need to update via stream_insert
        # The caller should handle this via the pending_changes
        socket

      # List-based data in :rows or :data
      Map.has_key?(socket.assigns, :rows) and is_list(socket.assigns.rows) ->
        updated_rows = update_rows_list(socket.assigns.rows, row_id, field_atom, new_value)
        assign(socket, :rows, updated_rows)

      Map.has_key?(socket.assigns, :data) and is_list(socket.assigns.data) ->
        updated_data = update_rows_list(socket.assigns.data, row_id, field_atom, new_value)
        assign(socket, :data, updated_data)

      true ->
        # No recognized data pattern, store in pending_changes for caller to handle
        socket
    end
  end

  defp update_rows_list(rows, row_id, field_atom, new_value) do
    Enum.map(rows, fn row ->
      row_id_str = get_row_id(row)
      if row_id_str == row_id do
        update_row_field(row, field_atom, new_value)
      else
        row
      end
    end)
  end

  defp get_row_id(%{id: id}), do: to_string(id)
  defp get_row_id(row) when is_map(row), do: to_string(Map.get(row, :id) || Map.get(row, "id"))
  defp get_row_id(_), do: nil

  defp update_row_field(row, field_atom, new_value) when is_struct(row) do
    if Map.has_key?(row, field_atom) do
      Map.put(row, field_atom, new_value)
    else
      row
    end
  end
  defp update_row_field(row, field_atom, new_value) when is_map(row) do
    cond do
      Map.has_key?(row, field_atom) -> Map.put(row, field_atom, new_value)
      Map.has_key?(row, to_string(field_atom)) -> Map.put(row, to_string(field_atom), new_value)
      true -> row
    end
  end
  defp update_row_field(row, _, _), do: row
  
  # Rollback a change (for undo)
  defp rollback_change(socket, %{cell_id: cell_id, old_value: old_value}) do
    apply_optimistic_update(socket, cell_id, old_value)
  end
  
  # Apply a change (for redo)
  defp apply_change(socket, %{cell_id: cell_id, new_value: new_value}) do
    apply_optimistic_update(socket, cell_id, new_value)
  end
  
  # Format value for display
  defp format_display_value(nil, _type), do: "-"
  defp format_display_value(value, :currency) do
    "$#{:erlang.float_to_binary(value / 1.0, decimals: 2)}"
  end
  defp format_display_value(value, :percentage) do
    "#{value}%"
  end
  defp format_display_value(value, :boolean) do
    if value, do: "✓", else: "✗"
  end
  defp format_display_value(%{__struct__: Date} = date, :date) do
    Calendar.strftime(date, "%Y-%m-%d")
  end
  defp format_display_value(value, _type) do
    to_string(value)
  end
  
  @doc """
  JavaScript hooks for inline editing.
  """
  def __hooks__() do
    %{
      "InlineEditCell" => %{
        mounted: """
        this.handleKeyPress = this.handleKeyPress.bind(this);
        this.handleDoubleClick = this.handleDoubleClick.bind(this);
        
        // Setup double-click handler
        const viewMode = this.el.querySelector('.view-mode');
        if (viewMode) {
          viewMode.addEventListener('dblclick', this.handleDoubleClick);
        }
        
        // Setup keyboard handler for edit mode
        const input = this.el.querySelector('input, select');
        if (input) {
          input.addEventListener('keydown', this.handleKeyPress);
          input.focus();
          // Select all text on focus for text inputs
          if (input.type === 'text' || input.type === 'number') {
            input.select();
          }
        }
        """,
        
        updated: """
        // Re-setup handlers after update
        this.mounted();
        """,
        
        handleKeyPress: """
        function(e) {
          const cellId = this.el.dataset.cellId || this.el.id;
          
          if (e.key === 'Enter') {
            e.preventDefault();
            this.pushEventTo(this.el.dataset.target || this.el, 'commit_edit', {
              cell_id: cellId
            });
          } else if (e.key === 'Escape') {
            e.preventDefault();
            this.pushEventTo(this.el.dataset.target || this.el, 'cancel_edit', {
              cell_id: cellId
            });
          } else if (e.key === 'Tab') {
            // Allow tab to move to next cell
            const direction = e.shiftKey ? 'prev' : 'next';
            this.pushEventTo(this.el.dataset.target || this.el, 'tab_to_cell', {
              cell_id: cellId,
              direction: direction
            });
          }
        }
        """,
        
        handleDoubleClick: """
        function(e) {
          // Double-click is handled by phx-dblclick attribute
          // This is here for any additional JS-side handling needed
        }
        """
      }
    }
  end
end