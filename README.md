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

- `SelectoComponents.Explorer` as the preferred top-level exploration surface
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
- `selecto >= 0.4.5 and < 0.6.0`
- an adapter package such as `selecto_db_postgresql >= 0.4.3 and < 0.6.0`
- `selecto_mix >= 0.4.5 and < 0.6.0` if you want generators and installation helpers

## Installation

```elixir
def deps do
  [
    {:selecto_components, ">= 0.4.7 and < 0.6.0"},
    {:selecto, ">= 0.4.5 and < 0.6.0"},
    {:selecto_db_postgresql, ">= 0.4.3 and < 0.6.0"},
    {:selecto_mix, ">= 0.4.5 and < 0.6.0"}
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

`SelectoComponents.Explorer` is now the preferred render surface.

Current migration note:

- use `SelectoComponents.Form` in the parent LiveView for the existing event-handler and `get_initial_state/2` compatibility path
- render `SelectoComponents.Explorer` instead of rendering `Form` and `Results` separately

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
    <.live_component module={SelectoComponents.Explorer} id="product-explorer" {assigns} />
    """
  end
end
```

## Config-Driven Explorer

You can also hand `Explorer` a smaller config struct while keeping the current parent LiveView compatibility boot path:

```elixir
config = %SelectoComponents.Explorer.Config{
  id: "products",
  selecto: ProductDomain.new(Repo),
  views: [
    SelectoComponents.Views.spec(:detail, SelectoComponents.Views.Detail, "Detail", %{}),
    SelectoComponents.Views.spec(:aggregate, SelectoComponents.Views.Aggregate, "Aggregate", %{}),
    SelectoComponents.Views.spec(:graph, SelectoComponents.Views.Graph, "Graph", %{})
  ],
  title: "Products Explorer",
  presentation: %{timezone: "America/New_York"}
}
```

The current runtime still expects the parent LiveView to own state/event setup. `Explorer.Config` is the first host-facing config seam, not a full replacement for that compatibility path yet.

## Common Add-Ons

You can start from `Explorer` and progressively add host-app integrations.

Compatibility note:

- `Form` + `Results` still work
- new docs/examples should prefer `Explorer`

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

## Query Contracts

`SelectoComponents.QueryContract.build/1` returns the constrained
`Selecto.Domain.query_contract/1` projection for Components-facing tooling. It
accepts an authored domain, a normalized domain, or a configured Selecto struct
without changing the existing Explorer/Form runtime path.

Use `SelectoComponents.QueryContract.json_document/1` or `encode_json/2` when a
consumer needs a `query_contract.json`-ready artifact with string keys and
JSON-compatible values. Pass `query_contract_url` and `query_guide_url` to add
discovery links for tools that need to move between the JSON contract and its
Markdown guide. The JSON and Markdown Plugs also emit HTTP `Link` headers for
the same pair of artifacts, plus byte-accurate `ETag` headers with
`If-None-Match` support for conditional GETs.

Use `SelectoComponents.QueryContract.validate_intent/2` to check a generated
detail, aggregate, or graph query intent against a query contract before handing
it to runtime query code. Host apps can also mount
`SelectoComponents.QueryContract.IntentValidator.Plug` to expose the same
validation over an HTTP POST endpoint.

Host apps can mount `SelectoComponents.QueryContract.Plug` for a small JSON
endpoint:

```elixir
forward "/selecto/orders/query-contract.json",
        SelectoComponents.QueryContract.Plug,
        domain: MyApp.SelectoDomains.Orders.domain()
```

## Generated Domain Action Forms

Domains can expose write-contract actions under `:actions`. Selecto Components
projects those actions into the existing row-action modal path with generated
ids like `domain_action_form_archive`. A detail view can select one of those ids
as `row_click_action`; clicking a row opens `SelectoComponents.Modal.ActionFormModal`
with the normalized action metadata, target row, inputs, confirmation state, and
preview/apply request template.

The modal does not execute writes directly. The host LiveView handles
`{:selecto_action_form_submit, payload}` and calls its own preview/apply
adapter, usually through `SelectoComponents.ActionFormHost.handle_submit/3`.
After a successful apply, the host should refresh the active Selecto query so
the row state reflects the write result.

Bulk-scoped domain actions can be projected separately with
`SelectoComponents.Actions.bulk_actions/2`. That helper returns the same
live-component payload shape as generated row action forms, but defaults the
target template to selected row ids.

`SelectoComponents.EnhancedTable.BulkActions` can receive `:action_contract`,
`:write_contract`, `:domain`, or `:selecto` assigns. Bulk-scoped domain actions
from that contract are added to the bulk menu as generated action forms; opening
one sends the same detail-modal event with `target.ids` set to the current
selection.

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
