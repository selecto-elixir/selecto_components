defmodule SelectoComponents.Slots.SlotProvider do
  @moduledoc """
  Provides slot-based customization system for SelectoComponents.
  Allows developers to inject custom content into predefined areas of components.
  """
  
  use Phoenix.Component
  import Phoenix.LiveView
  
  @doc """
  Defines a slot area that can accept custom content.
  """
  attr :name, :atom, required: true
  attr :component, :atom, required: true
  attr :default_content, :any, default: nil
  attr :validation, :any, default: nil
  attr :class, :string, default: ""
  slot :inner_block
  
  def slot_area(assigns) do
    assigns = 
      assigns
      |> assign(:slot_id, generate_slot_id(assigns.component, assigns.name))
      |> assign(:has_content, assigns.inner_block != [])
    
    ~H"""
    <div
      id={@slot_id}
      class={["slot-area", "slot-#{@name}", @class]}
      data-slot-name={@name}
      data-component={@component}
    >
      <%= if @has_content do %>
        <%= render_slot(@inner_block) %>
      <% else %>
        <%= render_default_content(@default_content) %>
      <% end %>
    </div>
    """
  end
  
  @doc """
  Wraps a component with slot support.
  """
  attr :component, :atom, required: true
  attr :id, :string, required: true
  attr :slots, :map, default: %{}
  attr :class, :string, default: ""
  slot :inner_block, required: true
  
  def with_slots(assigns) do
    assigns = 
      assigns
      |> assign(:slot_context, build_slot_context(assigns))
      |> assign(:registered_slots, get_registered_slots(assigns.component))
    
    ~H"""
    <div
      id={"#{@id}-slot-wrapper"}
      class={["slot-wrapper", @class]}
      phx-hook="SlotManager"
      data-component={@component}
      data-slots={Jason.encode!(@registered_slots)}
    >
      <%= render_slot(@inner_block, @slot_context) %>
    </div>
    """
  end
  
  @doc """
  Defines multiple slot areas for a component.
  """
  def define_slots(component, slot_definitions) when is_atom(component) and is_list(slot_definitions) do
    Enum.each(slot_definitions, fn slot_def ->
      register_slot(component, slot_def)
    end)
  end
  
  @doc """
  Injects content into a specific slot.
  """
  attr :component, :atom, required: true
  attr :slot_name, :atom, required: true
  attr :priority, :integer, default: 0
  slot :content, required: true
  
  def inject_slot(assigns) do
    ~H"""
    <div
      class="slot-injection"
      data-component={@component}
      data-slot={@slot_name}
      data-priority={@priority}
    >
      <%= render_slot(@content) %>
    </div>
    """
  end
  
  @doc """
  Creates a slot template that can be reused.
  """
  attr :name, :atom, required: true
  attr :description, :string, default: ""
  attr :params, :map, default: %{}
  slot :template, required: true
  
  def slot_template(assigns) do
    ~H"""
    <template
      id={"slot-template-#{@name}"}
      data-slot-template={@name}
      data-params={Jason.encode!(@params)}
    >
      <%= render_slot(@template, @params) %>
    </template>
    """
  end
  
  @doc """
  Conditional slot rendering based on context.
  """
  attr :component, :atom, required: true
  attr :slot_name, :atom, required: true
  attr :condition, :any, required: true
  slot :when_true
  slot :when_false
  
  def conditional_slot(assigns) do
    ~H"""
    <%= if @condition do %>
      <%= if @when_true != [] do %>
        <.slot_area name={@slot_name} component={@component}>
          <%= render_slot(@when_true) %>
        </.slot_area>
      <% end %>
    <% else %>
      <%= if @when_false != [] do %>
        <.slot_area name={@slot_name} component={@component}>
          <%= render_slot(@when_false) %>
        </.slot_area>
      <% end %>
    <% end %>
    """
  end
  
  @doc """
  Slot group for organizing multiple related slots.
  """
  attr :name, :atom, required: true
  attr :component, :atom, required: true
  attr :layout, :atom, default: :vertical
  attr :class, :string, default: ""
  slot :slots, required: true
  
  def slot_group(assigns) do
    ~H"""
    <div
      class={[
        "slot-group",
        "slot-group-#{@name}",
        "layout-#{@layout}",
        @class
      ]}
      data-group={@name}
      data-component={@component}
    >
      <%= for slot <- @slots do %>
        <%= render_slot(slot) %>
      <% end %>
    </div>
    """
  end
  
  # Slot Registry Functions
  
  @doc """
  Registers a slot for a component.
  """
  def register_slot(component, slot_definition) do
    # In a real implementation, this would store in ETS or similar
    # For now, we'll use module attributes or process dictionary
    Process.put({:slot, component, slot_definition.name}, slot_definition)
    :ok
  end
  
  @doc """
  Gets all registered slots for a component.
  """
  def get_registered_slots(component) do
    # In a real implementation, this would retrieve from storage
    # For now, return default slots
    default_slots_for(component)
  end
  
  @doc """
  Validates slot content.
  """
  def validate_slot_content(component, slot_name, content) do
    case get_slot_definition(component, slot_name) do
      nil -> 
        {:error, "Unknown slot: #{slot_name}"}
      
      slot_def ->
        if slot_def[:validation] do
          apply_validation(slot_def.validation, content)
        else
          {:ok, content}
        end
    end
  end
  
  @doc """
  Merges custom slots with default slots.
  """
  def merge_slots(default_slots, custom_slots) do
    Map.merge(default_slots, custom_slots, fn _key, default, custom ->
      merge_slot_content(default, custom)
    end)
  end
  
  # Private Functions
  
  defp generate_slot_id(component, name) do
    "slot-#{component}-#{name}-#{System.unique_integer([:positive])}"
  end
  
  defp build_slot_context(assigns) do
    %{
      component: assigns.component,
      slots: assigns.slots,
      id: assigns.id
    }
  end
  
  defp render_default_content(nil), do: nil
  defp render_default_content(content) when is_function(content), do: content.()
  defp render_default_content(content), do: content
  
  defp get_slot_definition(component, slot_name) do
    Process.get({:slot, component, slot_name})
  end
  
  defp apply_validation(validation_fn, content) when is_function(validation_fn) do
    validation_fn.(content)
  end
  defp apply_validation(_, content), do: {:ok, content}
  
  defp merge_slot_content(default, custom) when is_list(custom) do
    custom
  end
  defp merge_slot_content(default, custom) when is_function(custom) do
    custom.()
  end
  defp merge_slot_content(default, _), do: default
  
  defp default_slots_for(component) do
    case component do
      :table ->
        %{
          header: %{name: :header, position: :top, required: false},
          footer: %{name: :footer, position: :bottom, required: false},
          toolbar: %{name: :toolbar, position: :top, required: false},
          empty_state: %{name: :empty_state, position: :center, required: false}
        }
      
      :form ->
        %{
          header: %{name: :header, position: :top, required: false},
          footer: %{name: :footer, position: :bottom, required: false},
          actions: %{name: :actions, position: :bottom, required: false},
          help_text: %{name: :help_text, position: :inline, required: false}
        }
      
      :card ->
        %{
          header: %{name: :header, position: :top, required: false},
          body: %{name: :body, position: :center, required: true},
          footer: %{name: :footer, position: :bottom, required: false},
          actions: %{name: :actions, position: :bottom_right, required: false}
        }
      
      _ ->
        %{
          content: %{name: :content, position: :center, required: true}
        }
    end
  end
  
  def __hooks__ do
    """
    export const SlotManager = {
      mounted() {
        this.initSlotManager();
        this.observeSlotChanges();
      },
      
      initSlotManager() {
        this.component = this.el.dataset.component;
        this.slots = JSON.parse(this.el.dataset.slots || '{}');
        this.injections = new Map();
        
        this.collectInjections();
        this.applyInjections();
      },
      
      collectInjections() {
        const injections = this.el.querySelectorAll('.slot-injection');
        
        injections.forEach(injection => {
          const slotName = injection.dataset.slot;
          const priority = parseInt(injection.dataset.priority || '0');
          
          if (!this.injections.has(slotName)) {
            this.injections.set(slotName, []);
          }
          
          this.injections.get(slotName).push({
            element: injection,
            priority: priority
          });
        });
        
        // Sort by priority
        this.injections.forEach((items, slotName) => {
          items.sort((a, b) => b.priority - a.priority);
        });
      },
      
      applyInjections() {
        this.injections.forEach((items, slotName) => {
          const slotArea = this.el.querySelector(`.slot-${slotName}`);
          
          if (slotArea) {
            // Clear existing content if replacing
            if (items.length > 0 && items[0].priority > 0) {
              slotArea.innerHTML = '';
            }
            
            // Apply injections
            items.forEach(item => {
              slotArea.appendChild(item.element);
            });
          }
        });
      },
      
      observeSlotChanges() {
        const observer = new MutationObserver((mutations) => {
          mutations.forEach(mutation => {
            if (mutation.type === 'childList') {
              this.handleSlotChange(mutation);
            }
          });
        });
        
        const slotAreas = this.el.querySelectorAll('.slot-area');
        slotAreas.forEach(area => {
          observer.observe(area, {
            childList: true,
            subtree: true
          });
        });
      },
      
      handleSlotChange(mutation) {
        const slotArea = mutation.target.closest('.slot-area');
        if (slotArea) {
          const slotName = slotArea.dataset.slotName;
          this.pushEvent('slot_changed', {
            component: this.component,
            slot: slotName,
            has_content: slotArea.children.length > 0
          });
        }
      },
      
      destroyed() {
        // Cleanup if needed
      }
    };
    """
  end
end