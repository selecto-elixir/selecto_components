defmodule SelectoComponents.EnhancedTable.EditCell do
  @moduledoc """
  Individual cell editing component with validation and type-specific inputs.
  """
  
  use Phoenix.LiveComponent
  
  @impl true
  def mount(socket) do
    {:ok, assign(socket,
      editing: false,
      original_value: nil,
      current_value: nil,
      validation_error: nil,
      field_config: %{}
    )}
  end
  
  @impl true
  def update(assigns, socket) do
    socket = 
      socket
      |> assign(assigns)
      |> configure_field_type()
      
    {:ok, socket}
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <div 
      id={@id}
      class={cell_class(@editing, @validation_error, @pending_save)}
      phx-hook="EditableCell"
      data-type={@field_config.type}
      data-field={@field}
      data-row-id={@row_id}
    >
      <%= if @editing do %>
        <%= render_edit_mode(assigns) %>
      <% else %>
        <div 
          class="editable-cell-content"
          phx-dblclick="activate_edit"
          phx-target={@myself}
          tabindex="0"
          phx-keydown="cell_keydown"
          phx-key="Enter"
        >
          <span class="cell-value"><%= format_value(@value, @field_config) %></span>
          <%= if @pending_save do %>
            <span class="pending-indicator" title="Saving...">
              <svg class="animate-spin h-3 w-3 text-blue-600" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
            </span>
          <% end %>
          <%= if @recently_saved do %>
            <span class="saved-indicator" title="Saved">
              <svg class="h-3 w-3 text-green-600" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
              </svg>
            </span>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
  
  defp render_edit_mode(assigns) do
    ~H"""
    <div class="edit-container relative">
      <%= case @field_config.type do %>
        <% :select -> %>
          <%= render_select_input(assigns) %>
        
        <% :multiselect -> %>
          <%= render_multiselect_input(assigns) %>
        
        <% :boolean -> %>
          <%= render_boolean_input(assigns) %>
        
        <% :date -> %>
          <%= render_date_input(assigns) %>
        
        <% :datetime -> %>
          <%= render_datetime_input(assigns) %>
        
        <% :number -> %>
          <%= render_number_input(assigns) %>
        
        <% :currency -> %>
          <%= render_currency_input(assigns) %>
        
        <% :email -> %>
          <%= render_email_input(assigns) %>
        
        <% :url -> %>
          <%= render_url_input(assigns) %>
        
        <% :textarea -> %>
          <%= render_textarea_input(assigns) %>
        
        <% _ -> %>
          <%= render_text_input(assigns) %>
      <% end %>
      
      <%= if @validation_error do %>
        <div class="absolute z-20 left-0 top-full mt-1 p-2 bg-red-50 border border-red-200 rounded shadow-lg">
          <div class="flex items-start space-x-1">
            <svg class="w-4 h-4 text-red-600 flex-shrink-0 mt-0.5" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
            </svg>
            <span class="text-sm text-red-700"><%= @validation_error %></span>
          </div>
        </div>
      <% end %>
      
      <div class="edit-actions absolute -right-2 top-0 flex space-x-1">
        <button
          type="button"
          class="p-1 bg-green-500 text-white rounded hover:bg-green-600"
          phx-click="commit_edit"
          phx-target={@myself}
          title="Save (Enter)"
        >
          <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
          </svg>
        </button>
        <button
          type="button"
          class="p-1 bg-red-500 text-white rounded hover:bg-red-600"
          phx-click="cancel_edit"
          phx-target={@myself}
          title="Cancel (Esc)"
        >
          <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
          </svg>
        </button>
      </div>
    </div>
    """
  end
  
  # Input renderers for different types
  
  defp render_text_input(assigns) do
    ~H"""
    <input
      type="text"
      value={@current_value}
      class={input_class(@validation_error)}
      phx-change="update_value"
      phx-target={@myself}
      phx-keyup="handle_key"
      phx-key="Enter Escape Tab"
      autofocus
      maxlength={@field_config[:max_length]}
    />
    """
  end
  
  defp render_number_input(assigns) do
    ~H"""
    <input
      type="number"
      value={@current_value}
      class={input_class(@validation_error)}
      phx-change="update_value"
      phx-target={@myself}
      phx-keyup="handle_key"
      phx-key="Enter Escape Tab"
      min={@field_config[:min]}
      max={@field_config[:max]}
      step={@field_config[:step] || "any"}
      autofocus
    />
    """
  end
  
  defp render_currency_input(assigns) do
    ~H"""
    <div class="relative">
      <span class="absolute left-2 top-1/2 -translate-y-1/2 text-gray-500">$</span>
      <input
        type="number"
        value={@current_value}
        class={currency_input_class(@validation_error)}
        phx-change="update_value"
        phx-target={@myself}
        phx-keyup="handle_key"
        phx-key="Enter Escape Tab"
        min="0"
        step="0.01"
        autofocus
      />
    </div>
    """
  end
  
  defp render_boolean_input(assigns) do
    ~H"""
    <div class="flex items-center space-x-2">
      <button
        type="button"
        class={boolean_button_class(@current_value == true)}
        phx-click="set_boolean"
        phx-value-value="true"
        phx-target={@myself}
      >
        Yes
      </button>
      <button
        type="button"
        class={boolean_button_class(@current_value == false)}
        phx-click="set_boolean"
        phx-value-value="false"
        phx-target={@myself}
      >
        No
      </button>
    </div>
    """
  end
  
  defp render_select_input(assigns) do
    ~H"""
    <select
      class={input_class(@validation_error)}
      phx-change="update_value"
      phx-target={@myself}
      autofocus
    >
      <option value="">-- Select --</option>
      <%= for {label, value} <- @field_config.options do %>
        <option value={value} selected={@current_value == value}><%= label %></option>
      <% end %>
    </select>
    """
  end
  
  defp render_date_input(assigns) do
    ~H"""
    <input
      type="date"
      value={@current_value}
      class={input_class(@validation_error)}
      phx-change="update_value"
      phx-target={@myself}
      phx-keyup="handle_key"
      phx-key="Enter Escape Tab"
      min={@field_config[:min_date]}
      max={@field_config[:max_date]}
      autofocus
    />
    """
  end
  
  defp render_email_input(assigns) do
    ~H"""
    <input
      type="email"
      value={@current_value}
      class={input_class(@validation_error)}
      phx-change="update_value"
      phx-target={@myself}
      phx-keyup="handle_key"
      phx-key="Enter Escape Tab"
      placeholder="email@example.com"
      autofocus
    />
    """
  end
  
  defp render_url_input(assigns) do
    ~H"""
    <input
      type="url"
      value={@current_value}
      class={input_class(@validation_error)}
      phx-change="update_value"
      phx-target={@myself}
      phx-keyup="handle_key"
      phx-key="Enter Escape Tab"
      placeholder="https://..."
      autofocus
    />
    """
  end
  
  defp render_textarea_input(assigns) do
    ~H"""
    <textarea
      class={input_class(@validation_error) <> " resize-y"}
      phx-change="update_value"
      phx-target={@myself}
      phx-keyup="handle_key"
      phx-key="Escape Tab"
      rows="3"
      autofocus
    ><%= @current_value %></textarea>
    """
  end
  
  defp render_datetime_input(assigns) do
    ~H"""
    <input
      type="datetime-local"
      value={@current_value}
      class={input_class(@validation_error)}
      phx-change="update_value"
      phx-target={@myself}
      phx-keyup="handle_key"
      phx-key="Enter Escape Tab"
      autofocus
    />
    """
  end
  
  defp render_multiselect_input(assigns) do
    ~H"""
    <div class="space-y-1">
      <%= for {label, value} <- @field_config.options do %>
        <label class="flex items-center space-x-1">
          <input
            type="checkbox"
            value={value}
            checked={value in (@current_value || [])}
            phx-change="toggle_multiselect"
            phx-value-value={value}
            phx-target={@myself}
            class="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
          />
          <span class="text-sm"><%= label %></span>
        </label>
      <% end %>
    </div>
    """
  end
  
  # Event handlers
  
  @impl true
  def handle_event("activate_edit", _params, socket) do
    {:noreply, 
      socket
      |> assign(
        editing: true,
        original_value: socket.assigns.value,
        current_value: socket.assigns.value
      )
    }
  end
  
  def handle_event("update_value", %{"value" => value}, socket) do
    validated = validate_value(value, socket.assigns.field_config)
    
    {:noreply,
      socket
      |> assign(current_value: value)
      |> assign(validation_error: validated[:error])
    }
  end
  
  def handle_event("set_boolean", %{"value" => value}, socket) do
    bool_value = value == "true"
    {:noreply, assign(socket, current_value: bool_value)}
  end
  
  def handle_event("toggle_multiselect", %{"value" => value}, socket) do
    current = socket.assigns.current_value || []
    updated = if value in current do
      List.delete(current, value)
    else
      current ++ [value]
    end
    
    {:noreply, assign(socket, current_value: updated)}
  end
  
  def handle_event("commit_edit", _params, socket) do
    if socket.assigns.validation_error do
      {:noreply, socket}
    else
      send(self(), {:cell_updated, %{
        field: socket.assigns.field,
        row_id: socket.assigns.row_id,
        old_value: socket.assigns.original_value,
        new_value: socket.assigns.current_value
      }})
      
      {:noreply,
        socket
        |> assign(
          editing: false,
          value: socket.assigns.current_value,
          pending_save: true
        )
        |> schedule_save_indicator_removal()
      }
    end
  end
  
  def handle_event("cancel_edit", _params, socket) do
    {:noreply,
      socket
      |> assign(
        editing: false,
        current_value: socket.assigns.original_value,
        validation_error: nil
      )
    }
  end
  
  def handle_event("handle_key", %{"key" => "Enter"}, socket) do
    handle_event("commit_edit", %{}, socket)
  end
  
  def handle_event("handle_key", %{"key" => "Escape"}, socket) do
    handle_event("cancel_edit", %{}, socket)
  end
  
  def handle_event("handle_key", %{"key" => "Tab"} = params, socket) do
    direction = if params["shiftKey"], do: :previous, else: :next
    send(self(), {:navigate_cell, direction, socket.assigns.id})
    handle_event("commit_edit", %{}, socket)
  end
  
  def handle_event("cell_keydown", %{"key" => "Enter"}, socket) do
    handle_event("activate_edit", %{}, socket)
  end
  
  # Helper functions
  
  defp configure_field_type(socket) do
    field_config = Map.merge(
      %{type: :text},
      socket.assigns[:field_config] || %{}
    )
    
    assign(socket, field_config: field_config)
  end
  
  defp validate_value(value, config) do
    cond do
      config[:required] && (value == nil || value == "") ->
        %{error: "This field is required"}
        
      config[:type] == :email && !valid_email?(value) ->
        %{error: "Invalid email format"}
        
      config[:type] == :url && !valid_url?(value) ->
        %{error: "Invalid URL format"}
        
      config[:min_length] && String.length(value) < config[:min_length] ->
        %{error: "Minimum #{config[:min_length]} characters required"}
        
      config[:max_length] && String.length(value) > config[:max_length] ->
        %{error: "Maximum #{config[:max_length]} characters allowed"}
        
      config[:min] && is_number(value) && value < config[:min] ->
        %{error: "Minimum value is #{config[:min]}"}
        
      config[:max] && is_number(value) && value > config[:max] ->
        %{error: "Maximum value is #{config[:max]}"}
        
      true ->
        %{valid: true}
    end
  end
  
  defp valid_email?(email) do
    Regex.match?(~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/, email)
  end
  
  defp valid_url?(url) do
    Regex.match?(~r/^https?:\/\//, url)
  end
  
  defp schedule_save_indicator_removal(socket) do
    Process.send_after(self(), {:remove_save_indicator, socket.assigns.id}, 2000)
    socket
  end
  
  defp format_value(nil, _), do: "-"
  defp format_value(value, %{type: :currency}) do
    "$#{:erlang.float_to_binary(value / 1.0, decimals: 2)}"
  end
  defp format_value(value, %{type: :percentage}) do
    "#{value}%"
  end
  defp format_value(true, %{type: :boolean}), do: "Yes"
  defp format_value(false, %{type: :boolean}), do: "No"
  defp format_value(value, %{type: :date}) when is_binary(value) do
    value
  end
  defp format_value(values, %{type: :multiselect}) when is_list(values) do
    Enum.join(values, ", ")
  end
  defp format_value(value, _), do: to_string(value)
  
  # CSS classes
  
  defp cell_class(editing, validation_error, pending_save) do
    base = "editable-cell relative"
    
    classes = [base]
    classes = if editing, do: ["editing" | classes], else: classes
    classes = if validation_error, do: ["error" | classes], else: classes
    classes = if pending_save, do: ["pending" | classes], else: classes
    
    Enum.join(classes, " ")
  end
  
  defp input_class(validation_error) do
    base = "w-full px-2 py-1 text-sm border rounded focus:outline-none focus:ring-2"
    
    if validation_error do
      "#{base} border-red-500 focus:ring-red-500"
    else
      "#{base} border-blue-500 focus:ring-blue-500"
    end
  end
  
  defp currency_input_class(validation_error) do
    base = "w-full pl-6 pr-2 py-1 text-sm border rounded focus:outline-none focus:ring-2"
    
    if validation_error do
      "#{base} border-red-500 focus:ring-red-500"
    else
      "#{base} border-blue-500 focus:ring-blue-500"
    end
  end
  
  defp boolean_button_class(selected) do
    base = "px-3 py-1 text-sm rounded transition-colors"
    
    if selected do
      "#{base} bg-blue-500 text-white"
    else
      "#{base} bg-gray-200 text-gray-700 hover:bg-gray-300"
    end
  end
end