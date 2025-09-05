# SelectoComponents

Phoenix LiveView components for building interactive data query interfaces with [Selecto](https://github.com/selecto-elixir/selecto).

## Overview

SelectoComponents provides a suite of Phoenix LiveView components that enable users to build complex queries, visualize data, and interact with Ecto-based schemas through a visual interface. The library includes:

- **Query Builder**: Drag-and-drop interface for building complex filter queries
- **Data Views**: Multiple visualization options (Detail, Aggregate, Graph)
- **Colocated JavaScript**: Modern Phoenix LiveView 1.1+ colocated hooks for interactive functionality
- **Tailwind CSS**: Pre-styled components using Tailwind CSS

## Requirements

- Elixir ~> 1.14
- Phoenix ~> 1.8.0
- Phoenix LiveView ~> 1.1.4
- Ecto ~> 3.11
- Selecto (core library)

## Installation

### 1. Add Dependency

Add `selecto_components` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:selecto_components, "~> 0.3.0"},
    {:selecto, "~> 0.3.0"}  # Core selecto library
  ]
end
```

### 2. Configure Tailwind CSS

Update your `tailwind.config.js` to include SelectoComponents classes:

```javascript
module.exports = {
  content: [
    './js/**/*.js',
    '../lib/**/*.{ex,heex}',
    // Add this line for SelectoComponents
    '../deps/selecto_components/lib/**/*.{ex,heex}'
  ],
  // ... rest of config
}
```

### 3. Configure Colocated Hooks (Phoenix LiveView 1.1+)

SelectoComponents uses Phoenix LiveView's colocated hooks feature for JavaScript functionality.

#### Step 1: Ensure Phoenix LiveView compiler is enabled

In `mix.exs`:

```elixir
def project do
  [
    # ... other config ...
    compilers: [:phoenix_live_view] ++ Mix.compilers(),
    # ... other config ...
  ]
end
```

#### Step 2: Configure esbuild with NODE_PATH

In `config/config.exs`:

```elixir
config :esbuild,
  version: "0.25.4",
  default: [
    args: ~w(
      js/app.js 
      --bundle 
      --target=es2022 
      --outdir=../priv/static/assets
    ),
    cd: Path.expand("../assets", __DIR__),
    env: %{
      "NODE_PATH" => [
        Path.expand("../deps", __DIR__),
        Mix.Project.build_path()  # Required for colocated hooks
      ]
    }
  ]
```

#### Step 3: Import colocated hooks in app.js

In `assets/js/app.js`:

```javascript
import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

// Import SelectoComponents colocated hooks
import {hooks as selectoHooks} from "phoenix-colocated/selecto_components"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {
    ...selectoHooks  // Include SelectoComponents hooks
  }
})

// ... rest of your app.js configuration
```

#### Step 4: Compile to extract hooks

```bash
mix compile --force
mix assets.build
```

## Usage

### Basic Setup

1. **Generate a Selecto Domain**

First, generate a domain from your Ecto schema:

```bash
mix selecto.gen.domain MyApp.Catalog.Product
```

This creates a domain module that defines your data structure:

```elixir
defmodule MyApp.SelectoDomains.ProductDomain do
  @moduledoc """
  Selecto domain configuration for MyApp.Catalog.Product.
  """

  def domain do
    %{
      source: %{
        source_table: "products",
        primary_key: :id,
        fields: [:id, :name, :price, :in_stock, :category_id, :inserted_at, :updated_at],
        columns: %{
          id: %{type: :integer},
          name: %{type: :string},
          price: %{type: :decimal},
          in_stock: %{type: :boolean},
          category_id: %{type: :integer},
          inserted_at: %{type: :datetime},
          updated_at: %{type: :datetime}
        }
      },
      name: "Product Domain",
      default_selected: ["id", "name", "price", "in_stock"],
      filters: %{
        "in_stock" => %{name: "In Stock", type: :boolean},
        "category_id" => %{name: "Category", type: :integer}
      }
    }
  end

  def new(repo, opts \\ []) do
    Selecto.configure(domain(), repo, opts)
  end
end
```

2. **Use Components in LiveView**

```elixir
defmodule MyAppWeb.ProductLive do
  use MyAppWeb, :live_view
  
  alias MyApp.SelectoDomains.ProductDomain
  alias MyApp.Repo
  
  def mount(_params, _session, socket) do
    # Configure Selecto with the domain
    selecto = ProductDomain.new(Repo)
    
    {:ok, 
     socket
     |> assign(:selecto, selecto)
     |> assign(:domain, ProductDomain.domain())}
  end
  
  def render(assigns) do
    ~H"""
    <.live_component
      module={SelectoComponents.Views}
      id="product-query"
      selecto={@selecto}
      domain={@domain}
    />
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

SelectoComponents includes two main colocated JavaScript hooks:

1. **`.TreeBuilder`** - Enables drag-and-drop functionality in the query builder
2. **`.GraphComponent`** - Provides interactive charting capabilities

These hooks are automatically registered when you import the colocated hooks in your app.js.

## Troubleshooting

### Hooks Not Working

1. **Verify Phoenix LiveView version**:
```bash
mix deps | grep phoenix_live_view
# Should be 1.1.0 or higher
```

2. **Check hook extraction**:
```bash
ls -la _build/dev/phoenix-colocated/selecto_components/
# Should show extracted JavaScript files
```

3. **Enable debug logging** (in browser console):
```javascript
window.liveSocket.enableDebug()
```

### Styles Not Applied

Ensure your Tailwind configuration includes the SelectoComponents path and rebuild:
```bash
mix assets.build
```

## Development

This library is part of the Selecto ecosystem and is typically developed alongside:
- [selecto](https://github.com/selecto-elixir/selecto) - Core query building library
- [selecto_mix](https://github.com/selecto-elixir/selecto_mix) - Mix tasks and generators

## License

MIT License - see LICENSE file for details.