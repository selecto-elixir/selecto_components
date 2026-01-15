defmodule SelectoComponents.Forms.QuickAdd do
  @moduledoc """
  Quick add forms for adding new records inline or in modals without leaving the current view.
  """

  use Phoenix.LiveComponent
  alias SelectoComponents.SafeAtom
  
  @impl true
  def mount(socket) do
    {:ok, assign(socket,
      mode: :collapsed,  # :collapsed, :inline, :modal
      form_data: %{},
      validation_errors: %{},
      submitting: false,
      success_message: nil,
      error_message: nil,
      fields: []
    )}
  end
  
  @impl true
  def update(assigns, socket) do
    fields = assigns[:fields] || build_fields_from_schema(assigns[:schema])
    
    socket = 
      socket
      |> assign(assigns)
      |> assign(fields: fields)
      |> reset_form()
    
    {:ok, socket}
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class="quick-add-container">
      <%= case @mode do %>
        <% :collapsed -> %>
          <%= render_collapsed_view(assigns) %>
          
        <% :inline -> %>
          <%= render_inline_form(assigns) %>
          
        <% :modal -> %>
          <%= render_modal_form(assigns) %>
      <% end %>
      
      <%!-- Success/Error Messages --%>
      <%= if @success_message do %>
        <div class="mt-2 p-3 bg-green-50 border border-green-200 rounded-lg flex items-start">
          <svg class="w-5 h-5 text-green-600 mr-2 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
          </svg>
          <div class="flex-1">
            <p class="text-sm text-green-800"><%= @success_message %></p>
          </div>
          <button
            type="button"
            class="text-green-600 hover:text-green-800"
            phx-click="dismiss_message"
            phx-value-type="success"
            phx-target={@myself}
          >
            <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
            </svg>
          </button>
        </div>
      <% end %>
      
      <%= if @error_message do %>
        <div class="mt-2 p-3 bg-red-50 border border-red-200 rounded-lg flex items-start">
          <svg class="w-5 h-5 text-red-600 mr-2 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
          </svg>
          <div class="flex-1">
            <p class="text-sm text-red-800"><%= @error_message %></p>
          </div>
          <button
            type="button"
            class="text-red-600 hover:text-red-800"
            phx-click="dismiss_message"
            phx-value-type="error"
            phx-target={@myself}
          >
            <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
            </svg>
          </button>
        </div>
      <% end %>
    </div>
    """
  end
  
  defp render_collapsed_view(assigns) do
    ~H"""
    <div class="flex items-center space-x-2">
      <button
        type="button"
        class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 flex items-center space-x-2"
        phx-click="expand_form"
        phx-value-mode="inline"
        phx-target={@myself}
      >
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
        </svg>
        <span>Quick Add</span>
      </button>
      
      <button
        type="button"
        class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 flex items-center space-x-2"
        phx-click="expand_form"
        phx-value-mode="modal"
        phx-target={@myself}
      >
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 13h6m-3-3v6m5 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
        </svg>
        <span>Add in Modal</span>
      </button>
      
      <%!-- Keyboard shortcut hint --%>
      <span class="text-xs text-gray-500">
        Press <kbd class="px-1 py-0.5 bg-gray-100 border border-gray-300 rounded text-xs">Ctrl+N</kbd> for quick add
      </span>
    </div>
    """
  end
  
  defp render_inline_form(assigns) do
    ~H"""
    <div class="mt-4 p-4 bg-gray-50 border border-gray-200 rounded-lg">
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-lg font-medium text-gray-900">Add New Record</h3>
        <button
          type="button"
          class="text-gray-400 hover:text-gray-600"
          phx-click="collapse_form"
          phx-target={@myself}
        >
          <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
          </svg>
        </button>
      </div>
      
      <form phx-submit="submit_form" phx-target={@myself}>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          <%= for field <- @fields do %>
            <%= render_field(assigns, field) %>
          <% end %>
        </div>
        
        <div class="mt-4 flex items-center justify-end space-x-2">
          <button
            type="button"
            class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
            phx-click="reset_form"
            phx-target={@myself}
          >
            Reset
          </button>
          
          <button
            type="submit"
            class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed flex items-center space-x-2"
            disabled={@submitting}
          >
            <%= if @submitting do %>
              <svg class="animate-spin h-4 w-4" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
              <span>Saving...</span>
            <% else %>
              <span>Save</span>
            <% end %>
          </button>
        </div>
      </form>
    </div>
    """
  end
  
  defp render_modal_form(assigns) do
    ~H"""
    <div
      id={"#{@id}-modal"}
      class="fixed inset-0 z-50 overflow-y-auto"
      phx-hook="QuickAddModal"
    >
      <div class="flex items-center justify-center min-h-screen px-4">
        <%!-- Backdrop --%>
        <div 
          class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity"
          phx-click="collapse_form"
          phx-target={@myself}
        ></div>
        
        <%!-- Modal --%>
        <div class="relative bg-white rounded-lg shadow-xl max-w-2xl w-full">
          <div class="px-6 py-4 border-b border-gray-200">
            <div class="flex items-center justify-between">
              <h3 class="text-lg font-medium text-gray-900">Add New Record</h3>
              <button
                type="button"
                class="text-gray-400 hover:text-gray-600"
                phx-click="collapse_form"
                phx-target={@myself}
              >
                <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
                </svg>
              </button>
            </div>
          </div>
          
          <form phx-submit="submit_form" phx-target={@myself}>
            <div class="px-6 py-4 max-h-[60vh] overflow-y-auto">
              <div class="space-y-4">
                <%= for field <- @fields do %>
                  <%= render_field(assigns, field) %>
                <% end %>
              </div>
            </div>
            
            <div class="px-6 py-4 border-t border-gray-200 flex items-center justify-end space-x-2">
              <button
                type="button"
                class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
                phx-click="collapse_form"
                phx-target={@myself}
              >
                Cancel
              </button>
              
              <button
                type="submit"
                class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed flex items-center space-x-2"
                disabled={@submitting}
              >
                <%= if @submitting do %>
                  <svg class="animate-spin h-4 w-4" fill="none" viewBox="0 0 24 24">
                    <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                    <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                  </svg>
                  <span>Saving...</span>
                <% else %>
                  <span>Save</span>
                <% end %>
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end
  
  defp render_field(assigns, field) do
    assigns = assign(assigns, :field, field)
    
    ~H"""
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-1">
        <%= @field.label %>
        <%= if @field.required do %>
          <span class="text-red-500">*</span>
        <% end %>
      </label>
      
      <%= case @field.type do %>
        <% :text -> %>
          <input
            type="text"
            name={@field.name}
            value={@form_data[@field.name]}
            class={field_class(@validation_errors[@field.name])}
            placeholder={@field.placeholder}
            phx-change="validate_field"
            phx-value-field={@field.name}
            phx-target={@myself}
            required={@field.required}
          />
          
        <% :email -> %>
          <input
            type="email"
            name={@field.name}
            value={@form_data[@field.name]}
            class={field_class(@validation_errors[@field.name])}
            placeholder="email@example.com"
            phx-change="validate_field"
            phx-value-field={@field.name}
            phx-target={@myself}
            required={@field.required}
          />
          
        <% :number -> %>
          <input
            type="number"
            name={@field.name}
            value={@form_data[@field.name]}
            class={field_class(@validation_errors[@field.name])}
            min={@field.min}
            max={@field.max}
            step={@field.step || "any"}
            phx-change="validate_field"
            phx-value-field={@field.name}
            phx-target={@myself}
            required={@field.required}
          />
          
        <% :date -> %>
          <input
            type="date"
            name={@field.name}
            value={@form_data[@field.name]}
            class={field_class(@validation_errors[@field.name])}
            phx-change="validate_field"
            phx-value-field={@field.name}
            phx-target={@myself}
            required={@field.required}
          />
          
        <% :select -> %>
          <select
            name={@field.name}
            class={field_class(@validation_errors[@field.name])}
            phx-change="validate_field"
            phx-value-field={@field.name}
            phx-target={@myself}
            required={@field.required}
          >
            <option value="">-- Select --</option>
            <%= for {label, value} <- @field.options do %>
              <option value={value} selected={@form_data[@field.name] == value}>
                <%= label %>
              </option>
            <% end %>
          </select>
          
        <% :textarea -> %>
          <textarea
            name={@field.name}
            class={field_class(@validation_errors[@field.name]) <> " resize-y"}
            rows="3"
            placeholder={@field.placeholder}
            phx-change="validate_field"
            phx-value-field={@field.name}
            phx-target={@myself}
            required={@field.required}
          ><%= @form_data[@field.name] %></textarea>
          
        <% :boolean -> %>
          <label class="flex items-center">
            <input
              type="checkbox"
              name={@field.name}
              checked={@form_data[@field.name] == true}
              class="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
              phx-change="validate_field"
              phx-value-field={@field.name}
              phx-target={@myself}
            />
            <span class="ml-2 text-sm text-gray-700"><%= @field.description %></span>
          </label>
      <% end %>
      
      <%= if @validation_errors[@field.name] do %>
        <p class="mt-1 text-sm text-red-600"><%= @validation_errors[@field.name] %></p>
      <% end %>
    </div>
    """
  end
  
  # Event handlers
  
  @impl true
  def handle_event("expand_form", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, mode: SafeAtom.to_form_mode(mode))}
  end
  
  def handle_event("collapse_form", _params, socket) do
    {:noreply, 
      socket
      |> assign(mode: :collapsed)
      |> reset_form()
    }
  end
  
  def handle_event("validate_field", %{"field" => field_name, "value" => value}, socket) do
    form_data = Map.put(socket.assigns.form_data, field_name, value)
    field = Enum.find(socket.assigns.fields, & &1.name == field_name)
    
    validation_errors = 
      case validate_field(field, value) do
        {:ok, _} -> Map.delete(socket.assigns.validation_errors, field_name)
        {:error, message} -> Map.put(socket.assigns.validation_errors, field_name, message)
      end
    
    {:noreply, assign(socket, form_data: form_data, validation_errors: validation_errors)}
  end
  
  def handle_event("submit_form", params, socket) do
    if map_size(socket.assigns.validation_errors) > 0 do
      {:noreply, assign(socket, error_message: "Please fix validation errors before submitting")}
    else
      {:noreply,
        socket
        |> assign(submitting: true)
        |> submit_data(params)
      }
    end
  end
  
  def handle_event("reset_form", _params, socket) do
    {:noreply, reset_form(socket)}
  end
  
  def handle_event("dismiss_message", %{"type" => type}, socket) do
    case type do
      "success" -> {:noreply, assign(socket, success_message: nil)}
      "error" -> {:noreply, assign(socket, error_message: nil)}
    end
  end
  
  # Helper functions
  
  defp reset_form(socket) do
    default_values = 
      socket.assigns.fields
      |> Enum.map(fn field -> {field.name, field.default} end)
      |> Map.new()
    
    socket
    |> assign(
      form_data: default_values,
      validation_errors: %{},
      success_message: nil,
      error_message: nil
    )
  end
  
  defp submit_data(socket, params) do
    # Send data to parent for processing
    send(self(), {:quick_add_submit, params})
    
    # Simulate async save
    Process.send_after(self(), {:save_complete, socket.assigns.id}, 1000)
    
    socket
  end
  
  defp validate_field(%{required: true}, value) when value in [nil, ""] do
    {:error, "This field is required"}
  end
  
  defp validate_field(%{type: :email} = _field, value) do
    if Regex.match?(~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/, value) do
      {:ok, value}
    else
      {:error, "Invalid email format"}
    end
  end
  
  defp validate_field(%{type: :number, min: min}, value) when is_binary(value) do
    case Float.parse(value) do
      {num, _} when num < min -> {:error, "Minimum value is #{min}"}
      {num, _} -> {:ok, num}
      _ -> {:error, "Invalid number"}
    end
  end
  
  defp validate_field(_field, value) do
    {:ok, value}
  end
  
  defp build_fields_from_schema(nil), do: []
  defp build_fields_from_schema(schema) when is_atom(schema) do
    # Extract fields from an Ecto schema module
    if Code.ensure_loaded?(schema) and function_exported?(schema, :__schema__, 1) do
      # Get all fields except primary key and timestamps
      primary_key = schema.__schema__(:primary_key) |> List.wrap()
      autogen_fields = [:inserted_at, :updated_at]

      schema.__schema__(:fields)
      |> Enum.reject(fn field -> field in primary_key or field in autogen_fields end)
      |> Enum.map(fn field ->
        field_type = schema.__schema__(:type, field)
        build_field_config(field, field_type, schema)
      end)
    else
      []
    end
  end
  defp build_fields_from_schema(%{columns: columns}) when is_map(columns) do
    # Build fields from Selecto domain column configuration
    columns
    |> Enum.reject(fn {name, _config} ->
      # Skip id and timestamp fields
      name in [:id, :inserted_at, :updated_at] or
      to_string(name) in ["id", "inserted_at", "updated_at"]
    end)
    |> Enum.map(fn {name, config} ->
      build_field_from_column(name, config)
    end)
  end
  defp build_fields_from_schema(_), do: []

  defp build_field_config(field, field_type, schema) do
    name = to_string(field)
    label = humanize_field_name(name)

    # Determine if field is required by checking associations or constraints
    required = is_required_field?(field, schema)

    # Map Ecto type to form field type
    {form_type, extra_opts} = ecto_type_to_form_type(field_type)

    base_config = %{
      name: name,
      label: label,
      type: form_type,
      required: required,
      default: nil,
      placeholder: "Enter #{String.downcase(label)}"
    }

    Map.merge(base_config, extra_opts)
  end

  defp build_field_from_column(name, config) do
    name_str = to_string(name)
    label = Map.get(config, :label) || Map.get(config, :name) || humanize_field_name(name_str)
    field_type = Map.get(config, :type, :string)

    # Map Selecto column type to form field type
    {form_type, extra_opts} = selecto_type_to_form_type(field_type)

    base_config = %{
      name: name_str,
      label: label,
      type: form_type,
      required: false,
      default: nil,
      placeholder: "Enter #{String.downcase(to_string(label))}"
    }

    Map.merge(base_config, extra_opts)
  end

  defp ecto_type_to_form_type(:string), do: {:text, %{}}
  defp ecto_type_to_form_type(:integer), do: {:number, %{step: 1}}
  defp ecto_type_to_form_type(:float), do: {:number, %{step: "any"}}
  defp ecto_type_to_form_type(:decimal), do: {:number, %{step: "any"}}
  defp ecto_type_to_form_type(:boolean), do: {:boolean, %{description: ""}}
  defp ecto_type_to_form_type(:date), do: {:date, %{}}
  defp ecto_type_to_form_type(:time), do: {:text, %{placeholder: "HH:MM:SS"}}
  defp ecto_type_to_form_type(:naive_datetime), do: {:text, %{placeholder: "YYYY-MM-DD HH:MM:SS"}}
  defp ecto_type_to_form_type(:utc_datetime), do: {:text, %{placeholder: "YYYY-MM-DD HH:MM:SS"}}
  defp ecto_type_to_form_type(:utc_datetime_usec), do: {:text, %{placeholder: "YYYY-MM-DD HH:MM:SS"}}
  defp ecto_type_to_form_type(:naive_datetime_usec), do: {:text, %{placeholder: "YYYY-MM-DD HH:MM:SS"}}
  defp ecto_type_to_form_type({:array, _}), do: {:textarea, %{placeholder: "Enter values (one per line)"}}
  defp ecto_type_to_form_type(:map), do: {:textarea, %{placeholder: "Enter JSON"}}
  defp ecto_type_to_form_type(:binary), do: {:textarea, %{}}
  defp ecto_type_to_form_type({:parameterized, Ecto.Enum, opts}) do
    values = Keyword.get(opts, :values, [])
    options = Enum.map(values, fn v -> {humanize_field_name(to_string(v)), v} end)
    {:select, %{options: options}}
  end
  defp ecto_type_to_form_type(_), do: {:text, %{}}

  defp selecto_type_to_form_type(:string), do: {:text, %{}}
  defp selecto_type_to_form_type(:integer), do: {:number, %{step: 1}}
  defp selecto_type_to_form_type(:float), do: {:number, %{step: "any"}}
  defp selecto_type_to_form_type(:decimal), do: {:number, %{step: "any"}}
  defp selecto_type_to_form_type(:boolean), do: {:boolean, %{description: ""}}
  defp selecto_type_to_form_type(:date), do: {:date, %{}}
  defp selecto_type_to_form_type(:datetime), do: {:text, %{placeholder: "YYYY-MM-DD HH:MM:SS"}}
  defp selecto_type_to_form_type(:naive_datetime), do: {:text, %{placeholder: "YYYY-MM-DD HH:MM:SS"}}
  defp selecto_type_to_form_type(:binary), do: {:textarea, %{}}
  defp selecto_type_to_form_type(_), do: {:text, %{}}

  defp is_required_field?(field, schema) do
    # Check if field is a foreign key (usually required)
    associations = schema.__schema__(:associations)
    foreign_keys = Enum.flat_map(associations, fn assoc_name ->
      case schema.__schema__(:association, assoc_name) do
        %{owner_key: key} -> [key]
        _ -> []
      end
    end)

    field in foreign_keys
  end

  defp humanize_field_name(name) when is_binary(name) do
    name
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
  defp humanize_field_name(name) when is_atom(name), do: humanize_field_name(to_string(name))
  
  defp field_class(error) do
    base = "w-full px-3 py-2 border rounded-lg focus:outline-none focus:ring-2"
    
    if error do
      "#{base} border-red-300 focus:ring-red-500"
    else
      "#{base} border-gray-300 focus:ring-blue-500"
    end
  end
  
  def handle_info({:save_complete, _id}, socket) do
    {:noreply,
      socket
      |> assign(
        submitting: false,
        success_message: "Record added successfully!",
        mode: :collapsed
      )
      |> reset_form()
      |> schedule_message_dismiss()
    }
  end

  def handle_info({:auto_dismiss_message, _id}, socket) do
    {:noreply, assign(socket, success_message: nil, error_message: nil)}
  end

  defp schedule_message_dismiss(socket) do
    Process.send_after(self(), {:auto_dismiss_message, socket.assigns.id}, 5000)
    socket
  end
  
  @doc """
  JavaScript hooks for quick add functionality.
  """
  def __hooks__() do
    %{
      "QuickAddModal" => %{
        mounted: """
        // Handle ESC key to close modal
        this.handleKeyPress = (e) => {
          if (e.key === 'Escape') {
            this.pushEventTo(this.el, 'collapse_form', {});
          }
        };
        
        document.addEventListener('keydown', this.handleKeyPress);
        
        // Handle Ctrl+N shortcut
        this.handleShortcut = (e) => {
          if ((e.ctrlKey || e.metaKey) && e.key === 'n') {
            e.preventDefault();
            this.pushEventTo(this.el, 'expand_form', {mode: 'inline'});
          }
        };
        
        document.addEventListener('keydown', this.handleShortcut);
        
        // Focus first input
        const firstInput = this.el.querySelector('input:not([type="hidden"]), select, textarea');
        if (firstInput) {
          firstInput.focus();
        }
        """,
        
        destroyed: """
        document.removeEventListener('keydown', this.handleKeyPress);
        document.removeEventListener('keydown', this.handleShortcut);
        """
      }
    }
  end
end