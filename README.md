# SelectoComponents

Phoenix LiveView components for building interactive data query interfaces with [Selecto](https://github.com/selecto-elixir/selecto).

## Overview

SelectoComponents provides a suite of Phoenix LiveView components that enable users to build complex queries, visualize data, and interact with Ecto-based schemas through a visual interface. The library includes:

- **Query Builder**: Drag-and-drop interface for building complex filter queries
- **Data Views**: Multiple visualization options (Detail, Aggregate, Graph)
- **Colocated JavaScript**: Phoenix LiveView 1.1+ colocated hooks for drag-and-drop and charts
- **Tailwind CSS**: Pre-styled components using Tailwind CSS

## Requirements

- Phoenix 1.7+ (includes Phoenix LiveView compiler and esbuild with NODE_PATH)
- Elixir ~> 1.14
- Selecto ~> 0.3.0 (core library)
- selecto_mix ~> 0.3.0 (for code generation and integration tasks)

## Installation

### 1. Add Dependencies

In your `mix.exs`:

```elixir
def deps do
  [
    {:selecto_components, "~> 0.3.0"},
    {:selecto, "~> 0.3.0"},
    {:selecto_mix, "~> 0.3.0"}  # For generators and integration
  ]
end
```

Then install:
```bash
mix deps.get
```

### 2. Quick Setup (Recommended)

```bash
# Automatically integrate hooks and styles
mix selecto.components.integrate

# Build assets
mix assets.build
```

That's it! The integration task automatically:
- Adds SelectoComponents hooks to your app.js
- Adds Tailwind @source directive to your app.css

### 3. Manual Setup (Alternative)

If you prefer to configure manually or the integration task doesn't work:

#### In `assets/css/app.css`:
```css
/* Add this @source directive for SelectoComponents styles */
@source "../../deps/selecto_components/lib/**/*.{ex,heex}";
```

#### In `assets/js/app.js`:
```javascript
// Add this import at the top
import {hooks as selectoHooks} from "phoenix-colocated/selecto_components"

// In your LiveSocket configuration, spread the hooks:
const liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken},
  hooks: {
    ...selectoHooks,  // Add this line
    // your other hooks...
  }
})
```

Then build assets:
```bash
mix assets.build
```

## Usage

### Step 1: Generate a Domain

Use `selecto_mix` to generate a domain from your Ecto schema:

```bash
# Generate domain configuration only
mix selecto.gen.domain MyApp.Catalog.Product

# Generate with LiveView (recommended - includes integration)
mix selecto.gen.domain MyApp.Catalog.Product --live

# Generate with saved views support
mix selecto.gen.domain MyApp.Catalog.Product --live --saved-views
```

This creates:
- `lib/my_app/selecto_domains/product_domain.ex` - Domain configuration
- `lib/my_app_web/live/product_live.ex` - LiveView with SelectoComponents (if --live)
- Automatically runs `mix selecto.components.integrate` (if --live)

### Step 2: Use in LiveView

If you generated with `--live`, a LiveView is created for you. Otherwise, create one:

```elixir
defmodule MyAppWeb.ProductLive do
  use MyAppWeb, :live_view
  use SelectoComponents.Form  # Adds form handling utilities
  
  alias MyApp.SelectoDomains.ProductDomain
  alias MyApp.Repo
  
  @impl true
  def mount(_params, _session, socket) do
    # Initialize domain and selecto
    selecto = ProductDomain.new(Repo)
    domain = ProductDomain.domain()
    
    # Configure available views
    views = [
      {:detail, SelectoComponents.Views.Detail, "Table View", %{}},
      {:aggregate, SelectoComponents.Views.Aggregate, "Summary", %{}},
      {:graph, SelectoComponents.Views.Graph, "Charts", %{}}
    ]
    
    # Initialize state (from SelectoComponents.Form)
    state = get_initial_state(views, selecto)
    
    {:ok, assign(socket, state)}
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-4">
      <h1 class="text-2xl mb-4">Product Explorer</h1>
      
      <.live_component
        module={SelectoComponents.Form}
        id="product-form"
        {assigns}
      />
      
      <.live_component
        module={SelectoComponents.Results}
        id="product-results"
        {assigns}
      />
    </div>
    """
  end
end
```

## Available Components

### Views Module
- `SelectoComponents.Views` - Main component that provides tabbed interface for different view types

### View Types
- `SelectoComponents.Views.Detail` - Table view with sortable columns and pagination
- `SelectoComponents.Views.Aggregate` - Aggregated data view with grouping capabilities
- `SelectoComponents.Views.Graph` - Chart visualization using Chart.js

### Core Components
- `SelectoComponents.Components.TreeBuilder` - Drag-and-drop query builder with colocated JavaScript hook
- `SelectoComponents.Components.FilterForms` - Dynamic filter forms for different field types
- `SelectoComponents.Components.ListPicker` - Reorderable list selection component
- `SelectoComponents.Components.Tabs` - Tab navigation component
- `SelectoComponents.Components.RadioTabs` - Radio-style tab selection

### Support Modules
- `SelectoComponents.State` - State management for components
- `SelectoComponents.Router` - Event routing and business logic
- `SelectoComponents.Form` - Form handling utilities
- `SelectoComponents.Results` - Result processing and formatting

## JavaScript Hooks

SelectoComponents uses Phoenix LiveView's colocated JavaScript feature. The hooks are embedded directly in the components and extracted during compilation:

1. **`.TreeBuilder`** - Drag-and-drop functionality for the query builder
2. **`.GraphComponent`** - Interactive charting with Chart.js

These hooks are automatically available after running `mix selecto.components.integrate` or manually adding the import to your app.js.

## Troubleshooting

### Hooks Not Working

1. **Run the integration task**:
```bash
mix selecto.components.integrate --check  # Check if integrated
mix selecto.components.integrate          # Apply integration
```

2. **Verify app.js has the import**:
```javascript
import {hooks as selectoHooks} from "phoenix-colocated/selecto_components"
// ...
hooks: { ...selectoHooks }
```

3. **Rebuild assets**:
```bash
mix assets.build
```

4. **Check browser console** for JavaScript errors

### Styles Not Applied

1. **Verify app.css has the @source directive**:
```css
@source "../../deps/selecto_components/lib/**/*.{ex,heex}";
```

2. **Rebuild Tailwind**:
```bash
mix assets.build
```

### Integration Task Issues

If `mix selecto.components.integrate` fails:
- Check that `assets/js/app.js` and `assets/css/app.css` exist
- Use `--force` to re-apply integration: `mix selecto.components.integrate --force`
- Follow the manual setup steps above

## Development

This library is part of the Selecto ecosystem and is typically developed alongside:
- [selecto](https://github.com/selecto-elixir/selecto) - Core query building library
- [selecto_mix](https://github.com/selecto-elixir/selecto_mix) - Mix tasks and generators

## License

MIT License - see LICENSE file for details.