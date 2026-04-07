# SelectoComponents

> Alpha software. Expect API and behavior changes while the core LiveView package continues to settle.

`selecto_components` provides Phoenix LiveView components for building interactive query UIs on top of `selecto`.

It is the package you use when you want users to:

- build filters visually
- choose fields for detail and aggregate views
- switch between built-in result views
- save/export/share views
- email or schedule exports through host-app integrations

## What It Includes

- `SelectoComponents.Form` for query-building and view configuration
- `SelectoComponents.Results` for result rendering
- built-in views:
  - `Detail`
  - `Aggregate`
  - `Graph`
- extension-driven view support such as map views via `selecto_postgis`
- exported-view, email-export, and scheduled-export integration points

## Requirements

- Phoenix 1.7+
- Elixir ~> 1.18
- `selecto >= 0.4.3 and < 0.5.0`
- an adapter package such as `selecto_db_postgresql >= 0.4.2 and < 0.5.0`
- `selecto_mix >= 0.4.2 and < 0.5.0` if you want generators and installation helpers

## Installation

```elixir
def deps do
  [
    {:selecto_components, ">= 0.4.5 and < 0.5.0"},
    {:selecto, ">= 0.4.3 and < 0.5.0"},
    {:selecto_db_postgresql, ">= 0.4.2 and < 0.5.0"},
    {:selecto_mix, ">= 0.4.2 and < 0.5.0"}
  ]
end
```

Then run the recommended integration task:

```bash
mix deps.get
mix selecto.components.integrate
mix assets.build
```

That wires:

- colocated SelectoComponents hooks into your LiveSocket config
- Tailwind `@source` coverage for component templates

## Minimal Usage

```elixir
defmodule MyAppWeb.ProductLive do
  use MyAppWeb, :live_view
  use SelectoComponents.Form

  alias MyApp.SelectoDomains.ProductDomain
  alias MyApp.Repo

  def mount(_params, _session, socket) do
    selecto = ProductDomain.new(Repo)

    views = [
      {:detail, SelectoComponents.Views.Detail, "Detail", %{}},
      {:aggregate, SelectoComponents.Views.Aggregate, "Aggregate", %{}},
      {:graph, SelectoComponents.Views.Graph, "Graph", %{}}
    ]

    {:ok, assign(socket, get_initial_state(views, selecto))}
  end

  def render(assigns) do
    ~H"""
    <.live_component module={SelectoComponents.Form} id="product-form" {assigns} />
    <.live_component module={SelectoComponents.Results} id="product-results" {assigns} />
    """
  end
end
```

## Common Add-Ons

You can keep the basic `Form` + `Results` pairing and progressively add host-app integrations.

### Saved Views

Use a host module that persists saved views and assign it to the LiveView.

Typical generation path:

```bash
mix selecto.gen.saved_views MyApp.SavedView MyApp.SavedViewContext
```

### Exported Views

Use `SelectoComponents.ExportedViews` when you want signed iframe/embed snapshots of current views.

### Email And Scheduled Exports

Assign these modules when you want the Export tab to send or manage exports:

```elixir
assign(socket,
  export_delivery_module: MyApp.ExportDelivery,
  scheduled_export_module: MyApp.ScheduledExports,
  scheduled_export_context: scoped_context
)
```

The host app owns actual delivery and scheduling. `selecto_components` stays scheduler-neutral.

Recommended execution model: use Oban (or another worker system) to run due scheduled exports via `SelectoComponents.ScheduledExports.Service.run_scheduled_export/3`.

### Extension Views

Map views and other extension-provided view systems are merged from domain extensions rather than hard-coded into the package.

## Custom View Systems

`selecto_components` supports external view packages through `SelectoComponents.Views.System`.

That is the contract used when you want to publish a package like:

- `selecto_components_view_<slug>`

and register it into a host LiveView with `SelectoComponents.Views.spec/4`.

## Status

Current `0.4.x` scope:

- core query UI flows are usable but still alpha
- exported views, one-off email export, and scheduled export management are available
- custom and extension view support exists, but host apps still own persistence and delivery concerns
- advanced graph/dashboard integrations still need real-world hardening

## Demos And Tutorials

- `selecto_livebooks`
- `selecto_northwind`
- hosted demo: `testselecto.fly.dev`
- runnable example app: `selecto_example`
