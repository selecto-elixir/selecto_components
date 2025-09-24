# Component Customization Plan for SelectoComponents

## Problem Statement

Integrators using SelectoComponents need flexibility to:
1. Change visual styling (colors, spacing, etc.)
2. **Replace entire components** with their own implementations
3. Use their preferred UI component libraries (DaisyUI, Tailwind UI, Material, etc.)
4. Mix and match components from different sources

Currently, SelectoComponents uses hardcoded components like `sc_input`, which doesn't allow for this flexibility.

## Proposed Solution: Component Registry Pattern

### Core Architecture

#### 1. Component Interface Definition

Define a behavior that specifies what each component must implement:

```elixir
defmodule SelectoComponents.ComponentInterface do
  @doc "Render an input field"
  @callback input(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render a button"
  @callback button(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render a select dropdown"
  @callback select(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render a table"
  @callback table(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render a modal"
  @callback modal(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render a card"
  @callback card(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render a checkbox"
  @callback checkbox(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render a radio button"
  @callback radio(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render a textarea"
  @callback textarea(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render an alert/notification"
  @callback alert(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render a badge/tag"
  @callback badge(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Render a loading spinner"
  @callback spinner(assigns :: map()) :: Phoenix.LiveView.Rendered.t()
end
```

#### 2. Default Component Implementation

Provide a default implementation that works out of the box:

```elixir
defmodule SelectoComponents.DefaultComponents do
  @behaviour SelectoComponents.ComponentInterface
  use Phoenix.Component

  @impl true
  def input(assigns) do
    assigns = assign_new(assigns, :class, fn -> "sc-input" end)
    assigns = assign_new(assigns, :type, fn -> "text" end)

    ~H"""
    <input
      type={@type}
      name={@name}
      value={@value}
      class={"px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 #{@class}"}
      {@rest}
    />
    """
  end

  @impl true
  def button(assigns) do
    assigns = assign_new(assigns, :variant, fn -> "primary" end)

    ~H"""
    <button
      type={assigns[:type] || "button"}
      class={button_classes(@variant)}
      {@rest}
    >
      <%= render_slot(@inner_block) || @label %>
    </button>
    """
  end

  # ... other component implementations
end
```

#### 3. Component Registry

Central registry to manage component providers:

```elixir
defmodule SelectoComponents.Registry do
  @moduledoc """
  Registry for component providers. Allows runtime swapping of components.
  """

  # Store provider in process dictionary or ETS for performance
  def set_provider(provider) do
    Process.put(:selecto_component_provider, provider)
  end

  def get_provider do
    Process.get(:selecto_component_provider) ||
      Application.get_env(:selecto_components, :provider) ||
      SelectoComponents.DefaultComponents
  end

  @doc """
  Get a specific component function from the current provider
  """
  def get_component(type) when is_atom(type) do
    provider = get_provider()

    cond do
      is_map(provider) ->
        Map.get(provider, type) || fallback_component(type)

      is_atom(provider) and function_exported?(provider, type, 1) ->
        &provider.type/1

      true ->
        fallback_component(type)
    end
  end

  @doc """
  Render a component with the current provider
  """
  def render(type, assigns) do
    component = get_component(type)

    case component do
      fun when is_function(fun, 1) -> fun.(assigns)
      mod when is_atom(mod) -> apply(mod, type, [assigns])
      _ -> fallback_component(type).(assigns)
    end
  end

  defp fallback_component(type) do
    &SelectoComponents.DefaultComponents.unquote(type)/1
  end
end
```

#### 4. Theme Provider Module

Allow developers to create their own theme providers:

```elixir
defmodule SelectoComponents.ThemeProvider do
  @doc """
  Define the components to use
  """
  @callback components() :: map() | module()

  @doc """
  Define custom styles/classes (optional)
  """
  @callback styles() :: map()

  @doc """
  Define theme configuration (optional)
  """
  @callback config() :: map()

  defmacro __using__(_opts) do
    quote do
      @behaviour SelectoComponents.ThemeProvider

      def styles, do: %{}
      def config, do: %{}

      defoverridable styles: 0, config: 0
    end
  end
end
```

### Integration Examples

#### Example 1: DaisyUI Integration

```elixir
defmodule MyApp.DaisyUIProvider do
  use SelectoComponents.ThemeProvider

  @impl true
  def components do
    %{
      input: &daisy_input/1,
      button: &daisy_button/1,
      select: &daisy_select/1,
      table: &daisy_table/1,
      modal: &daisy_modal/1,
      card: &daisy_card/1,
      alert: &daisy_alert/1,
      badge: &daisy_badge/1
    }
  end

  defp daisy_input(assigns) do
    ~H"""
    <input
      type={@type}
      name={@name}
      value={@value}
      class={"input input-bordered w-full #{assigns[:size] && "input-#{@size}"}"}
      {@rest}
    />
    """
  end

  defp daisy_button(assigns) do
    ~H"""
    <button class={"btn #{button_variant(@variant)}"} {@rest}>
      <%= render_slot(@inner_block) || @label %>
    </button>
    """
  end

  defp button_variant("primary"), do: "btn-primary"
  defp button_variant("secondary"), do: "btn-secondary"
  defp button_variant("accent"), do: "btn-accent"
  defp button_variant(_), do: ""

  # ... other component implementations
end
```

#### Example 2: Tailwind UI Integration

```elixir
defmodule MyApp.TailwindUIProvider do
  use SelectoComponents.ThemeProvider

  @impl true
  def components do
    %{
      # Use existing Tailwind UI components directly
      input: &TailwindUI.Form.Input.render/1,
      button: &TailwindUI.Button.render/1,
      select: &TailwindUI.Form.Select.render/1,
      table: &TailwindUI.Table.render/1,

      # Mix with custom components
      modal: &MyApp.Components.modal/1,

      # Use defaults for some
      card: :default,
      alert: :default
    }
  end
end
```

#### Example 3: Material Design Integration

```elixir
defmodule MyApp.MaterialProvider do
  use SelectoComponents.ThemeProvider

  @impl true
  def components do
    %{
      input: &material_text_field/1,
      button: &material_button/1,
      select: &material_select/1,
      card: &material_card/1
    }
  end

  defp material_text_field(assigns) do
    ~H"""
    <div class="mdc-text-field mdc-text-field--filled">
      <span class="mdc-text-field__ripple"></span>
      <input
        class="mdc-text-field__input"
        type={@type}
        name={@name}
        value={@value}
        {@rest}
      />
      <label class="mdc-floating-label"><%= @label %></label>
      <span class="mdc-line-ripple"></span>
    </div>
    """
  end

  # ... other Material Design components
end
```

### Usage in SelectoComponents

Update all SelectoComponents to use the registry:

```elixir
# Before:
defp render_input(assigns) do
  ~H"""
  <.sc_input name={@name} value={@value} />
  """
end

# After:
defp render_input(assigns) do
  ~H"""
  <%= SelectoComponents.Registry.render(:input, assigns) %>
  """
end

# Or with a helper:
import SelectoComponents.Registry, only: [component: 2]

defp render_form_field(assigns) do
  ~H"""
  <div class="form-field">
    <%= component(:label, %{for: @name, text: @label}) %>
    <%= component(:input, %{name: @name, value: @value, type: @type}) %>
    <%= if @error do %>
      <%= component(:alert, %{type: :error, message: @error}) %>
    <% end %>
  </div>
  """
end
```

### Configuration Options

#### Application Config

```elixir
# config/config.exs
config :selecto_components,
  provider: MyApp.DaisyUIProvider,
  default_theme: :light,
  component_overrides: %{
    # Override specific components
    table: MyApp.CustomTable,
    input: MyApp.SpecialInput
  }
```

#### Runtime Configuration

```elixir
# In your LiveView mount
def mount(_params, _session, socket) do
  # Set provider for this process
  SelectoComponents.Registry.set_provider(MyApp.CustomProvider)

  {:ok, socket}
end
```

#### Component-Level Configuration

```elixir
# Pass provider as prop
<SelectoComponents.Form
  selecto={@selecto}
  provider={MyApp.DaisyUIProvider}
/>

# Or with inline components
<SelectoComponents.Form
  selecto={@selecto}
  components={%{
    input: fn assigns -> ~H"<custom-input {...assigns} />" end,
    button: &MyApp.button/1
  }}
/>
```

## Implementation Steps

### Phase 1: Core Infrastructure (Week 1)
1. Create `ComponentInterface` behaviour
2. Implement `DefaultComponents` module
3. Build `Registry` module
4. Create `ThemeProvider` behaviour

### Phase 2: Component Migration (Week 2)
1. Identify all hardcoded components in SelectoComponents
2. Extract component rendering into registry calls
3. Ensure backward compatibility
4. Add tests for component swapping

### Phase 3: Provider Libraries (Week 3)
1. Create example DaisyUI provider
2. Create example Tailwind UI provider
3. Create example Bootstrap provider
4. Document integration patterns

### Phase 4: Advanced Features (Week 4)
1. Add component composition helpers
2. Implement style merging utilities
3. Add component validation
4. Create migration guide

## Benefits

1. **Flexibility**: Complete control over component rendering
2. **Compatibility**: Works with any UI library
3. **Gradual Adoption**: Can migrate components one at a time
4. **Type Safety**: Behaviors ensure correct implementation
5. **Testing**: Easy to swap in test components
6. **Performance**: No runtime overhead with compile-time resolution
7. **Documentation**: Clear contracts for components

## Migration Guide

For existing SelectoComponents users:

```elixir
# Step 1: No change needed - defaults work
<SelectoComponents.Form selecto={@selecto} />

# Step 2: Override specific components
<SelectoComponents.Form
  selecto={@selecto}
  components={%{input: &MyApp.custom_input/1}}
/>

# Step 3: Use a full provider
config :selecto_components, provider: MyApp.UIProvider
```

## Testing Strategy

```elixir
defmodule SelectoComponents.RegistryTest do
  use ExUnit.Case

  test "uses default components when no provider set" do
    assert SelectoComponents.Registry.get_provider() ==
           SelectoComponents.DefaultComponents
  end

  test "allows runtime provider switching" do
    SelectoComponents.Registry.set_provider(CustomProvider)
    assert SelectoComponents.Registry.get_provider() == CustomProvider
  end

  test "renders with custom component" do
    SelectoComponents.Registry.set_provider(%{
      input: fn assigns -> ~H"<custom-input />" end
    })

    rendered = SelectoComponents.Registry.render(:input, %{})
    assert rendered =~ "custom-input"
  end
end
```

## Considerations

1. **Breaking Changes**: Need to maintain backward compatibility
2. **Performance**: Registry lookups should be fast (compile-time when possible)
3. **Documentation**: Each component's expected assigns must be well-documented
4. **Validation**: Consider runtime validation of component contracts
5. **Versioning**: Provider interface may need versioning for future changes

## Alternative Approaches Considered

1. **Protocol-based**: More Elixir-idiomatic but less flexible
2. **Macro-based**: Could generate components at compile-time but harder to debug
3. **Module attributes**: Simple but not runtime-configurable
4. **ETS-based**: Good for global state but adds complexity

## Decision

Proceed with the **Component Registry Pattern** as it provides the best balance of:
- Flexibility (runtime and compile-time configuration)
- Performance (minimal overhead)
- Developer experience (clear, simple API)
- Compatibility (works with existing code)

## Next Steps

1. Review and approve this plan
2. Create proof of concept with 2-3 components
3. Get feedback from potential users
4. Implement full solution
5. Create provider packages for popular UI libraries