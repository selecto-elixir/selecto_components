# SelectoComponents

> ⚠️ **Alpha Quality Software**
>
> `selecto_components` is under active development. Expect breaking changes,
> behavior changes, incomplete features, and potentially major bugs.

Phoenix LiveView components for building interactive data query interfaces with [Selecto](https://github.com/selecto-elixir/selecto).

## Overview

SelectoComponents provides a suite of Phoenix LiveView components that enable users to build complex queries, visualize data, and interact with Ecto-based schemas through a visual interface. The library includes:

- **Query Builder**: Drag-and-drop interface for building complex filter queries
- **Data Views**: Built-in visualization options (Detail, Aggregate, Graph) and extension views (for example Map via `selecto_postgis`)
- **Colocated JavaScript**: Phoenix LiveView 1.1+ colocated hooks for drag-and-drop and charts
- **Tailwind CSS**: Pre-styled components using Tailwind CSS

## Livebooks, Tutorials, and Demo

- [selecto-elixir/selecto_livebooks](https://github.com/selecto-elixir/selecto_livebooks) contains a Livebook that walks through many Selecto query features.
- [seeken/selecto_northwind](https://github.com/seeken/selecto_northwind) contains tutorials for building Selecto queries and workflows.
- [testselecto.fly.dev](https://testselecto.fly.dev) runs the `selecto_test` app as a hosted Selecto demo.

## Release Status (0.3.x)

- **Alpha**: Core query UI flows (`SelectoComponents.Form`, result rendering,
  built-in views) are usable but not yet stable.
- **High Risk / Experimental**: Graph/dashboard and advanced integration paths
  may change significantly and can require project-specific hardening.
- **Maintenance Note**: Unwired experimental modules were pruned in 0.3.x to
  reduce surface area; only documented core flows are kept.
- **Not Included**: Turnkey production analytics/data-backend integration is
  outside current package scope.

## Requirements

- Phoenix 1.7+ (includes Phoenix LiveView compiler and esbuild with NODE_PATH)
- Elixir ~> 1.14
- Selecto ~> 0.3.3 (core library)
- selecto_mix ~> 0.3.2 (for code generation and integration tasks)

## Installation

### 1. Add Dependencies

In your `mix.exs`:

```elixir
def deps do
  [
    {:selecto_components, "~> 0.3.5"},
    {:selecto, "~> 0.3.3"},
    # Optional extension package for map/spatial views
    {:selecto_postgis, "~> 0.1"},
    {:selecto_mix, "~> 0.3.2"}  # For generators and integration
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

### Extension-Provided Views (Map)

`selecto_components` can merge extension-provided views from your configured
Selecto domain. For PostGIS-backed map views:

1. Add `{:selecto_postgis, "~> 0.1"}` to your dependencies.
2. Add `Selecto.Extensions.PostGIS` in your domain `:extensions` list.
3. Keep your normal base `views` list (`detail`, `aggregate`, `graph`); the
   map view is merged automatically when the extension and spatial columns are
   present.
4. If your app validates saved-view types, include `map` in allowed view types.

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

## Recent 0.3.4+ Updates

### Filter Processing and Rendering

Filter processing has been expanded for more consistent operator support across
form inputs:

- String filters: `=`, `!=`, `<`, `<=`, `>`, `>=`, `BETWEEN`, `IN`, `NOT IN`,
  `STARTS`, `ENDS`, `CONTAINS`, `LIKE`, `NOT LIKE`, null checks.
- Numeric filters: `=`, `!=`, `<`, `<=`, `>`, `>=`, `BETWEEN`, `IN`, `NOT IN`,
  null checks.
- Datetime filters: richer support for `BETWEEN`, `DATE_BETWEEN`, shortcut and
  relative modes, and null checks.

### Aggregate Group-By Safety

Aggregate group-by display processing now applies `COALESCE('[NULL]')` only to
text-compatible selectors. This prevents SQL type mismatch errors when grouping
by numeric, enum, and other non-text fields.

### Custom Detail Modal Component

You can now provide a custom modal component instead of the built-in
`SelectoComponents.Modal.DetailModal`:

```elixir
<.live_component
  module={SelectoComponents.Form}
  id="product-form"
  detail_modal_component={MyAppWeb.ProductDetailModal}
  {assigns}
/>
```

Your custom modal receives `detail_data` and is rendered whenever
`enable_modal_detail` and `show_detail_modal` are true.

### Debug Information Panel (Opt-In)

Debug UI visibility is request-gated:

- Development/test: pass `selecto_debug=true` (or `debug=true`) in params or session.
- Production: requires both environment config and token validation:
  - `SELECTO_DEBUG_ENABLED=true`
  - `SELECTO_DEBUG_TOKEN=<secure-token>`
  - request/session includes `debug_token=<secure-token>`

If you want the debug panel always enabled in development, pass debug params to
`SelectoComponents.Results` from your LiveView.

## Available Components

### Views Module
- `SelectoComponents.Views` - Main component that provides tabbed interface for different view types

### View Types
- `SelectoComponents.Views.Detail` - Table view with sortable columns and pagination
- `SelectoComponents.Views.Aggregate` - Aggregated data view with grouping capabilities
- `SelectoComponents.Views.Graph` - Chart visualization using Chart.js
- `SelectoComponents.Views.Map` - Extension-driven map visualization (provided through `selecto_postgis` extension registration)

### Custom View Systems

SelectoComponents now supports a formal view-system contract via
`SelectoComponents.Views.System`.

You can publish external view packages (for example
`selecto_components_workflow` or `selecto_components_faceted_product`) by
exposing a top-level view module that implements the behavior.

```elixir
defmodule SelectoComponentsWorkflow.Views.Workflow do
  use SelectoComponents.Views.System,
    process: SelectoComponentsWorkflow.Views.Workflow.Process,
    form: SelectoComponentsWorkflow.Views.Workflow.Form,
    component: SelectoComponentsWorkflow.Views.Workflow.Component
end
```

Then register it like any built-in view:

```elixir
views = [
  SelectoComponents.Views.spec(
    :workflow,
    SelectoComponentsWorkflow.Views.Workflow,
    "Workflow",
    %{drill_down: :detail}
  ),
  SelectoComponents.Views.spec(
    :faceted_product,
    SelectoComponentsFacetedProduct.Views.FacetedProduct,
    "Faceted Product",
    %{}
  )
]
```

Legacy namespace-style modules (`MyView.Process`, `MyView.Form`,
`MyView.Component`) are still supported.

### Implementing A New View System

Use this process for any new view package (for example
`selecto_components_view_workflow_inbox` or
`selecto_components_view_faceted_product`).

1. Create a package with name `selecto_components_view_<slug>`.
2. Add dependency on `selecto_components` (path dep for local/vendor, Hex dep for published use).
3. Implement a top-level view module that `use`s `SelectoComponents.Views.System`.
4. Implement the three modules referenced by the top-level view:
   `Process`, `Form`, `Component`.
5. Register the view in your LiveView `views` list with
   `SelectoComponents.Views.spec/4`.
6. Add the new view type to saved-view validation in your host app
   (if your app validates allowed view types).
7. Compile and test the LiveView by switching to the new tab and submitting.

Expected package layout:

```text
vendor/selecto_components_view_<slug>/
  mix.exs
  lib/selecto_components_view_<slug>.ex
  lib/selecto_components_view_<slug>/views/<slug>.ex
  lib/selecto_components_view_<slug>/views/<slug>/process.ex
  lib/selecto_components_view_<slug>/views/<slug>/form.ex
  lib/selecto_components_view_<slug>/views/<slug>/component.ex
```

Top-level view module:

```elixir
defmodule SelectoComponentsViewWorkflowInbox.Views.WorkflowInbox do
  use SelectoComponents.Views.System,
    process: SelectoComponentsViewWorkflowInbox.Views.WorkflowInbox.Process,
    form: SelectoComponentsViewWorkflowInbox.Views.WorkflowInbox.Form,
    component: SelectoComponentsViewWorkflowInbox.Views.WorkflowInbox.Component
end
```

`Process` callback contract:

```elixir
@callback initial_state(selecto :: term(), options :: map()) :: map()
@callback param_to_state(params :: map(), options :: map()) :: map()
@callback view(
  options :: map(),
  params :: map(),
  columns_map :: map(),
  filtered :: term(),
  selecto :: term()
) :: {view_set :: map(), view_meta :: map()}
```

0.3.4 note: built-in views were further compartmentalized with optional
view-local helper modules (for example options normalization, drill-down
actions, query pagination helpers). This does **not** change the formal
`SelectoComponents.Views.System` callback contract above.

Minimal registration in a LiveView:

```elixir
views = [
  SelectoComponents.Views.spec(:detail, SelectoComponents.Views.Detail, "Detail View", %{}),
  SelectoComponents.Views.spec(
    :workflow_inbox,
    SelectoComponentsViewWorkflowInbox.Views.WorkflowInbox,
    "Workflow Inbox",
    %{}
  )
]
```

If your app persists saved views by type, include your new type. Example:

```elixir
@view_types ~w(detail aggregate graph workflow_inbox faceted_product)
```

Verification checklist:

1. `mix compile` succeeds after adding deps and modules.
2. Open the LiveView, toggle View Controller, confirm your tab appears.
3. Select the tab, submit config, confirm results render.
4. Save and reload a saved view for the new type.
5. Confirm invalid/missing config shows a user-visible error state.

### Core Components
- `SelectoComponents.Components.TreeBuilder` - Drag-and-drop query builder with colocated JavaScript hook
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

For local workspace development against an unreleased `selecto`, set:

```bash
SELECTO_ECOSYSTEM_USE_LOCAL=true
```

When enabled, `selecto_components` resolves `{:selecto, path: "../selecto"}`.
This is the same local-development switch used across Selecto ecosystem repos.

## License

MIT License - see LICENSE file for details.
