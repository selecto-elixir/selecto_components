# SelectoComponents Setup Example

A complete, working example of setting up SelectoComponents in a Phoenix LiveView application.

## Prerequisites

- Phoenix 1.7+ (includes everything needed for colocated hooks)
- Elixir 1.14+
- Node.js (for asset compilation)

**Note:** Phoenix 1.7+ apps already have Phoenix LiveView compiler and esbuild NODE_PATH configured by default!

## Step 1: Update Dependencies

### `mix.exs`

```elixir
defmodule MyApp.MixProject do
  use Mix.Project

  def project do
    [
      app: :my_app,
      version: "0.1.0",
      elixir: "~> 1.14",
      # Add Phoenix LiveView compiler for colocated hooks
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      deps: deps()
    ]
  end

  defp deps do
    [
      {:phoenix, "~> 1.8.0"},
      {:phoenix_live_view, "~> 1.1.0"},  # Required for colocated hooks
      {:selecto, "~> 0.3.0"},             # Core query library
      {:selecto_components, "~> 0.3.0"},  # UI components
      # ... other dependencies
    ]
  end
end
```

## Step 2: Configure Styles

### `assets/css/app.css`

```css
/* Import Tailwind base styles */
@import "tailwindcss/base";
@import "tailwindcss/components";
@import "tailwindcss/utilities";

/* Configure Tailwind content sources */
@config "../../assets/tailwind.config.js";
@source "../../lib/my_app_web/**/*.{ex,heex}";
@source "../../deps/selecto_components/lib/**/*.{ex,heex}";

/* Your custom styles */
.custom-class {
  /* ... */
}
```

### `assets/tailwind.config.js` (optional, for theme customization)

```javascript
// This file is now optional and only needed for theme customization
// Content sources are defined in app.css with @source directives
module.exports = {
  theme: {
    extend: {
      // Add custom colors, fonts, etc.
    },
  },
  plugins: []
}
```

## Step 3: Add SelectoComponents Hooks

### `assets/js/app.js`

Just add two lines to your existing app.js:

```javascript
// Add this import at the top with your other imports
import {hooks as selectoHooks} from "phoenix-colocated/selecto_components"

// Then in your existing liveSocket configuration, add the hooks:
const liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken},
  hooks: {
    ...selectoHooks,  // Add this line
    // any other hooks you already have
  }
})
```

## Step 4: Create Your Ecto Schema and Generate Domain

### `lib/my_app/catalog/product.ex`

First, create your standard Ecto schema:

```elixir
defmodule MyApp.Catalog.Product do
  use Ecto.Schema
  import Ecto.Changeset

  schema "products" do
    field :name, :string
    field :price, :decimal
    field :in_stock, :boolean
    field :description, :string
    belongs_to :category, MyApp.Catalog.Category
    
    timestamps()
  end

  def changeset(product, attrs) do
    product
    |> cast(attrs, [:name, :price, :in_stock, :description, :category_id])
    |> validate_required([:name, :price])
  end
end
```

### Generate the Selecto Domain

Use the selecto_mix task to generate a domain from your schema:

```bash
# Generate domain configuration
mix selecto.gen.domain MyApp.Catalog.Product

# Generate with LiveView support
mix selecto.gen.domain MyApp.Catalog.Product --live

# Generate with saved views support
mix selecto.gen.domain MyApp.Catalog.Product --live --saved-views

# Expand associated schemas
mix selecto.gen.domain MyApp.Catalog.Product --expand-schemas category
```

This creates `lib/my_app/selecto_domains/product_domain.ex`:

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
        fields: [:id, :name, :price, :in_stock, :description, :category_id, :inserted_at, :updated_at],
        columns: %{
          id: %{type: :integer},
          name: %{type: :string},
          price: %{type: :decimal},
          in_stock: %{type: :boolean},
          description: %{type: :string},
          category_id: %{type: :integer},
          inserted_at: %{type: :naive_datetime},
          updated_at: %{type: :naive_datetime}
        }
      },
      name: "Product Domain",
      default_selected: ["id", "name", "price", "in_stock"],
      filters: %{
        "in_stock" => %{name: "In Stock", type: :boolean},
        "category_id" => %{name: "Category", type: :integer}
      },
      joins: %{
        category: %{
          name: "Category",
          type: :left
        }
      }
    }
  end

  def new(repo, opts \\ []) do
    Selecto.configure(domain(), repo, opts)
  end
end
```

## Step 5: Create the LiveView

### `lib/my_app_web/live/products_live.ex`

```elixir
defmodule MyAppWeb.ProductsLive do
  use MyAppWeb, :live_view
  
  alias MyApp.SelectoDomains.ProductDomain
  alias MyApp.Repo

  @impl true
  def mount(_params, _session, socket) do
    # Initialize Selecto with the domain
    selecto = ProductDomain.new(Repo)
    domain = ProductDomain.domain()
    
    # Configure available views
    views = [
      {:detail, SelectoComponents.Views.Detail, "Table View", %{
        per_page: 25,
        columns: ["name", "price", "in_stock", "category_id"]
      }},
      {:aggregate, SelectoComponents.Views.Aggregate, "Summary", %{
        group_by: ["category_id"],
        aggregates: [{:count, "id"}, {:avg, "price"}]
      }},
      {:graph, SelectoComponents.Views.Graph, "Charts", %{
        chart_type: "bar",
        x_axis: "category_id",
        y_axis: {:count, "id"}
      }}
    ]
    
    {:ok,
     socket
     |> assign(:selecto, selecto)
     |> assign(:domain, domain)
     |> assign(:views, views)
     |> assign(:current_view, :detail)
     |> assign(:results, nil)
     |> assign(:loading, false)}
  end

  @impl true
  def handle_event("execute_query", params, socket) do
    # Build and execute query with Selecto
    query = socket.assigns.selecto
            |> Selecto.select(params["select"] || socket.assigns.domain.default_selected)
            |> Selecto.filter(params["filters"] || [])
    
    case Selecto.execute(query) do
      {:ok, {rows, columns, _aliases}} ->
        {:noreply, assign(socket, results: %{rows: rows, columns: columns}, loading: false)}
      
      {:error, reason} ->
        {:noreply, 
         socket
         |> put_flash(:error, "Query failed: #{inspect(reason)}")
         |> assign(loading: false)}
    end
  end

  @impl true
  def handle_event("change_view", %{"view" => view}, socket) do
    {:noreply, assign(socket, current_view: String.to_atom(view))}
  end
end
```

### `lib/my_app_web/live/products_live.html.heex`

```heex
<div class="container mx-auto px-4 py-8">
  <h1 class="text-3xl font-bold mb-6">Product Explorer</h1>
  
  <!-- View Selector -->
  <div class="mb-6">
    <div class="flex gap-2">
      <button 
        :for={{key, _module, label, _opts} <- @views}
        phx-click="change_view" 
        phx-value-view={key}
        class={[
          "px-4 py-2 rounded",
          @current_view == key && "bg-blue-500 text-white",
          @current_view != key && "bg-gray-200 hover:bg-gray-300"
        ]}
      >
        <%= label %>
      </button>
    </div>
  </div>
  
  <!-- Query Builder with TreeBuilder Hook -->
  <div class="mb-8 p-4 border rounded-lg">
    <h2 class="text-xl font-semibold mb-4">Query Builder</h2>
    <.live_component
      module={SelectoComponents.Components.TreeBuilder}
      id="query-builder"
      selecto={@selecto}
      on_change={fn filters -> send(self(), {:filters_updated, filters}) end}
    />
  </div>
  
  <!-- Results Display -->
  <div class="border rounded-lg p-4">
    <h2 class="text-xl font-semibold mb-4">Results</h2>
    
    <%= if @loading do %>
      <div class="text-center py-8">
        <div class="spinner">Loading...</div>
      </div>
    <% else %>
      <.live_component
        :if={@results}
        module={elem(Enum.find(@views, fn {k, _, _, _} -> k == @current_view end), 1)}
        id="results-view"
        results={@results}
        selecto={@selecto}
      />
      
      <div :if={!@results} class="text-gray-500 text-center py-8">
        Build a query and click "Execute" to see results
      </div>
    <% end %>
  </div>
  
  <!-- Execute Button -->
  <div class="mt-6 flex justify-end">
    <button 
      phx-click="execute_query"
      disabled={@loading}
      class="px-6 py-2 bg-green-500 text-white rounded hover:bg-green-600 disabled:opacity-50"
    >
      <%= if @loading, do: "Executing...", else: "Execute Query" %>
    </button>
  </div>
</div>
```

## Step 6: Add Routes

### `lib/my_app_web/router.ex`

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router

  # ... other pipelines and routes

  scope "/", MyAppWeb do
    pipe_through :browser

    # Add the products explorer route
    live "/products", ProductsLive
  end
end
```

## Step 7: Build and Run

```bash
# Install dependencies
mix deps.get

# Setup database
mix ecto.setup

# Build assets (this automatically extracts and bundles hooks)
mix assets.build

# Start the server
mix phx.server
```

## Step 8: Verify Setup

1. **Navigate to** `http://localhost:4000/products`

2. **Check browser console** for hook initialization:
   ```javascript
   // In browser console:
   console.log(Object.keys(window.liveSocket.hooks))
   // Should output: [".TreeBuilder", ".GraphComponent"]
   ```

3. **Test functionality**:
   - Drag fields from "Available" to "Build Area" in the query builder
   - Switch between Table, Summary, and Charts views
   - Execute queries and verify results display

## Troubleshooting

### Hooks Not Loading

Check that you've added the import and hooks to your app.js:
```javascript
import {hooks as selectoHooks} from "phoenix-colocated/selecto_components"
// ...
hooks: { ...selectoHooks }
```

Then rebuild: `mix assets.build`

### Styles Not Applied

```bash
# Rebuild Tailwind CSS
mix assets.build

# Check that app.css includes SelectoComponents @source directive
grep "@source.*selecto_components" assets/css/app.css

# If missing, add to app.css:
# @source "../../deps/selecto_components/lib/**/*.{ex,heex}";
```

### JavaScript Errors

```javascript
// Enable debug mode in browser console
window.liveSocket.enableDebug()

// Check for hook registration
document.querySelectorAll('[phx-hook]').forEach(el => {
  console.log('Hook:', el.getAttribute('phx-hook'), 'ID:', el.id)
})
```

## Next Steps

- Customize views with additional options
- Add more queryable domains
- Implement saved queries functionality
- Add export capabilities for results
- Customize styling to match your brand

## Resources

- [SelectoComponents Documentation](https://github.com/selecto-elixir/selecto_components)
- [Selecto Core Library](https://github.com/selecto-elixir/selecto)
- [Phoenix LiveView Colocated Hooks](https://hexdocs.pm/phoenix_live_view/js-interop.html#colocated-hooks)