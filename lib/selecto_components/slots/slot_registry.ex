defmodule SelectoComponents.Slots.SlotRegistry do
  @moduledoc """
  Registry for managing component slots and their configurations.
  Provides centralized storage and retrieval of slot definitions.
  """
  
  use GenServer
  require Logger
  
  @table_name :selecto_slot_registry
  
  # Client API
  
  @doc """
  Starts the slot registry.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Registers a slot definition for a component.
  """
  def register(component, slot_name, definition) when is_atom(component) and is_atom(slot_name) do
    GenServer.call(__MODULE__, {:register, component, slot_name, definition})
  end
  
  @doc """
  Registers multiple slots for a component.
  """
  def register_many(component, slot_definitions) when is_atom(component) and is_map(slot_definitions) do
    GenServer.call(__MODULE__, {:register_many, component, slot_definitions})
  end
  
  @doc """
  Gets a specific slot definition.
  """
  def get(component, slot_name) when is_atom(component) and is_atom(slot_name) do
    case :ets.lookup(@table_name, {component, slot_name}) do
      [{_, definition}] -> {:ok, definition}
      [] -> {:error, :not_found}
    end
  end
  
  @doc """
  Gets all slots for a component.
  """
  def get_all(component) when is_atom(component) do
    :ets.match(@table_name, {{component, :"$1"}, :"$2"})
    |> Enum.map(fn [name, definition] -> {name, definition} end)
    |> Map.new()
  end
  
  @doc """
  Checks if a slot exists.
  """
  def exists?(component, slot_name) when is_atom(component) and is_atom(slot_name) do
    :ets.member(@table_name, {component, slot_name})
  end
  
  @doc """
  Updates a slot definition.
  """
  def update(component, slot_name, updates) when is_atom(component) and is_atom(slot_name) do
    GenServer.call(__MODULE__, {:update, component, slot_name, updates})
  end
  
  @doc """
  Removes a slot definition.
  """
  def unregister(component, slot_name) when is_atom(component) and is_atom(slot_name) do
    GenServer.call(__MODULE__, {:unregister, component, slot_name})
  end
  
  @doc """
  Lists all registered components.
  """
  def list_components do
    :ets.match(@table_name, {:"$1", :"$2"})
    |> Enum.map(fn [{component, _}] -> component end)
    |> Enum.uniq()
    |> Enum.sort()
  end
  
  @doc """
  Validates slot content against its definition.
  """
  def validate(component, slot_name, content) do
    case get(component, slot_name) do
      {:ok, definition} ->
        validate_content(definition, content)
      
      {:error, :not_found} ->
        {:error, "Slot #{slot_name} not found for component #{component}"}
    end
  end
  
  @doc """
  Gets the default content for a slot.
  """
  def get_default(component, slot_name) do
    case get(component, slot_name) do
      {:ok, definition} ->
        {:ok, definition[:default_content]}
      
      error ->
        error
    end
  end
  
  @doc """
  Registers default slots for common components.
  """
  def register_defaults do
    # Table component slots
    register_many(:table, %{
      header: %{
        position: :top,
        required: false,
        validation: &validate_renderable/1,
        description: "Table header content"
      },
      toolbar: %{
        position: :top,
        required: false,
        validation: &validate_renderable/1,
        description: "Table toolbar with actions and filters"
      },
      footer: %{
        position: :bottom,
        required: false,
        validation: &validate_renderable/1,
        description: "Table footer content"
      },
      empty_state: %{
        position: :center,
        required: false,
        validation: &validate_renderable/1,
        default_content: "No data available",
        description: "Content shown when table is empty"
      },
      row_actions: %{
        position: :inline,
        required: false,
        validation: &validate_function/1,
        description: "Actions for each table row"
      }
    })
    
    # Form component slots
    register_many(:form, %{
      header: %{
        position: :top,
        required: false,
        validation: &validate_renderable/1,
        description: "Form header content"
      },
      footer: %{
        position: :bottom,
        required: false,
        validation: &validate_renderable/1,
        description: "Form footer content"
      },
      actions: %{
        position: :bottom,
        required: false,
        validation: &validate_renderable/1,
        default_content: default_form_actions(),
        description: "Form action buttons"
      },
      field_help: %{
        position: :inline,
        required: false,
        validation: &validate_function/1,
        description: "Help text for form fields"
      },
      validation_summary: %{
        position: :top,
        required: false,
        validation: &validate_renderable/1,
        description: "Validation error summary"
      }
    })
    
    # Card component slots
    register_many(:card, %{
      header: %{
        position: :top,
        required: false,
        validation: &validate_renderable/1,
        description: "Card header content"
      },
      body: %{
        position: :center,
        required: true,
        validation: &validate_renderable/1,
        description: "Card body content"
      },
      footer: %{
        position: :bottom,
        required: false,
        validation: &validate_renderable/1,
        description: "Card footer content"
      },
      actions: %{
        position: :bottom_right,
        required: false,
        validation: &validate_renderable/1,
        description: "Card action buttons"
      },
      badge: %{
        position: :top_right,
        required: false,
        validation: &validate_renderable/1,
        description: "Card badge or status indicator"
      }
    })
    
    # Modal component slots
    register_many(:modal, %{
      title: %{
        position: :header,
        required: true,
        validation: &validate_string/1,
        description: "Modal title"
      },
      body: %{
        position: :center,
        required: true,
        validation: &validate_renderable/1,
        description: "Modal body content"
      },
      footer: %{
        position: :bottom,
        required: false,
        validation: &validate_renderable/1,
        default_content: default_modal_footer(),
        description: "Modal footer with actions"
      }
    })
    
    # Dashboard widget slots
    register_many(:widget, %{
      header: %{
        position: :top,
        required: false,
        validation: &validate_renderable/1,
        description: "Widget header"
      },
      content: %{
        position: :center,
        required: true,
        validation: &validate_renderable/1,
        description: "Widget main content"
      },
      footer: %{
        position: :bottom,
        required: false,
        validation: &validate_renderable/1,
        description: "Widget footer"
      },
      controls: %{
        position: :top_right,
        required: false,
        validation: &validate_renderable/1,
        description: "Widget control buttons"
      }
    })
    
    :ok
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    :ets.new(@table_name, [:named_table, :public, read_concurrency: true])
    
    # Register default slots on startup
    Process.send_after(self(), :register_defaults, 100)
    
    {:ok, %{}}
  end
  
  @impl true
  def handle_call({:register, component, slot_name, definition}, _from, state) do
    key = {component, slot_name}
    definition = normalize_definition(definition)
    
    if valid_definition?(definition) do
      :ets.insert(@table_name, {key, definition})
      Logger.debug("Registered slot #{slot_name} for component #{component}")
      {:reply, :ok, state}
    else
      {:reply, {:error, :invalid_definition}, state}
    end
  end
  
  @impl true
  def handle_call({:register_many, component, slot_definitions}, _from, state) do
    results = Enum.map(slot_definitions, fn {slot_name, definition} ->
      key = {component, slot_name}
      definition = normalize_definition(definition)
      
      if valid_definition?(definition) do
        :ets.insert(@table_name, {key, definition})
        {:ok, slot_name}
      else
        {:error, slot_name}
      end
    end)
    
    failed = Enum.filter(results, &match?({:error, _}, &1))
    
    if Enum.empty?(failed) do
      Logger.debug("Registered #{map_size(slot_definitions)} slots for component #{component}")
      {:reply, :ok, state}
    else
      {:reply, {:error, {:partial_failure, failed}}, state}
    end
  end
  
  @impl true
  def handle_call({:update, component, slot_name, updates}, _from, state) do
    key = {component, slot_name}
    
    case :ets.lookup(@table_name, key) do
      [{^key, existing}] ->
        updated = Map.merge(existing, updates)
        :ets.insert(@table_name, {key, updated})
        {:reply, :ok, state}
      
      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end
  
  @impl true
  def handle_call({:unregister, component, slot_name}, _from, state) do
    key = {component, slot_name}
    :ets.delete(@table_name, key)
    {:reply, :ok, state}
  end
  
  @impl true
  def handle_info(:register_defaults, state) do
    register_defaults()
    {:noreply, state}
  end
  
  # Private Functions
  
  defp normalize_definition(definition) when is_map(definition) do
    Map.merge(default_definition(), definition)
  end
  defp normalize_definition(_), do: default_definition()
  
  defp default_definition do
    %{
      position: :center,
      required: false,
      validation: nil,
      default_content: nil,
      description: "",
      accepts: :any,
      max_items: nil,
      min_items: nil
    }
  end
  
  defp valid_definition?(definition) do
    is_map(definition) and
    Map.has_key?(definition, :position) and
    Map.has_key?(definition, :required)
  end
  
  defp validate_content(definition, content) do
    cond do
      definition[:validation] && is_function(definition[:validation]) ->
        definition[:validation].(content)
      
      definition[:required] && is_nil(content) ->
        {:error, "Required slot cannot be empty"}
      
      true ->
        {:ok, content}
    end
  end
  
  # Validation Functions
  
  defp validate_renderable(content) do
    if renderable?(content) do
      {:ok, content}
    else
      {:error, "Content must be renderable"}
    end
  end
  
  defp validate_string(content) when is_binary(content), do: {:ok, content}
  defp validate_string(_), do: {:error, "Content must be a string"}
  
  defp validate_function(content) when is_function(content), do: {:ok, content}
  defp validate_function(_), do: {:error, "Content must be a function"}
  
  defp renderable?(content) do
    is_binary(content) or
    is_function(content) or
    is_tuple(content) or
    (is_list(content) and Enum.all?(content, &renderable?/1))
  end
  
  # Default Content Functions
  
  defp default_form_actions do
    fn ->
      """
      <div class="flex gap-2">
        <button type="submit" class="btn btn-primary">Save</button>
        <button type="button" class="btn btn-secondary">Cancel</button>
      </div>
      """
    end
  end
  
  defp default_modal_footer do
    fn ->
      """
      <div class="flex justify-end gap-2">
        <button type="button" class="btn btn-secondary" phx-click="close">Close</button>
        <button type="button" class="btn btn-primary" phx-click="confirm">Confirm</button>
      </div>
      """
    end
  end
end