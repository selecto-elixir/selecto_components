# SelectoComponents Developer Integration Guide

`selecto_components` turns Selecto domain metadata into interactive Phoenix
LiveView UX. It should own forms, previews, result presentation, query-contract
artifacts, export/schedule UI, and embedded-view surfaces. The host app should
own execution, authorization, persistence, delivery, telemetry, and reloads.

This guide covers the production integration path for generated action forms,
query contracts, exports, scheduled exports, published views, and capability
policy.

## Responsibilities

Components owns:

- rendering query builders and result views
- rendering generated row and bulk action forms
- normalizing action-form submit payloads
- showing preview/apply/result/error state
- building query-contract JSON and Markdown guide artifacts
- applying host capability decisions to query contracts
- rendering exported-view and scheduled-export configuration UX
- surfacing reload/result metadata from the host

The host owns:

- current actor, tenant, and policy context
- capability resolver decisions
- write/action preview and apply execution
- saved view, exported view, scheduled export, and run persistence
- email/export delivery adapters
- background runner scheduling
- telemetry handling
- rerunning Selecto queries after writes
- deciding whether to close, reset, or keep forms open after result

## Minimal LiveView Setup

```elixir
defmodule MyAppWeb.OrderLive do
  use MyAppWeb, :live_view
  use SelectoComponents.Form

  alias SelectoComponents.ActionFormHost
  alias MyApp.SelectoDomains.OrderDomain

  def mount(params, _session, socket) do
    current_user = socket.assigns.current_scope.user
    tenant_id = to_string(current_user.account_id)
    path = "/orders"
    scoped_context = SelectoComponents.Tenant.scoped_context(path, %{tenant_id: tenant_id})

    selecto = Selecto.configure(OrderDomain.domain(), MyApp.Repo)

    views = [
      {:detail, SelectoComponents.Views.Detail, "Detail", %{}},
      {:aggregate, SelectoComponents.Views.Aggregate, "Aggregate", %{drill_down: :detail}},
      {:graph, SelectoComponents.Views.Graph, "Graph", %{}}
    ]

    socket =
      assign(socket,
        views: views,
        path: path,
        my_path: path,
        domain: scoped_context,
        exported_view_module: MyApp.ExportedViews,
        exported_view_context: scoped_context,
        scheduled_export_module: MyApp.ScheduledExports,
        scheduled_export_context: scoped_context,
        export_delivery_module: MyApp.ExportDelivery,
        capability_actor: current_user,
        capability_tenant: tenant_id,
        capability_domain: :orders,
        capability_context: %{surface: :selecto_components, path: path},
        capability_resolver: &component_capability_decision/1,
        row_action_availability_opts: [
          actor: current_user,
          tenant: tenant_id,
          domain: :orders,
          surface: :selecto_components,
          capability_resolver: &component_capability_decision/1
        ]
      )

    {:ok, assign(socket, get_initial_state(views, selecto))}
  end
end
```

## Capability Resolution

Components uses `Selecto.Capabilities.Request` for host policy. A resolver may
return `Selecto.Capabilities.allow/1`, `deny/2`, `hidden/2`, booleans, or a
compatible map.

```elixir
defp component_capability_decision(%Selecto.Capabilities.Request{} = request) do
  case {request.actor.role, request.capability, request.operation} do
    {:analyst, "orders.approve", _operation} ->
      Selecto.Capabilities.deny(:manager_required,
        user_message: "Managers must approve orders."
      )

    {:analyst, "orders.internal_margin", _operation} ->
      Selecto.Capabilities.hidden(:manager_required,
        user_message: "Internal margin is hidden from analysts."
      )

    _allowed ->
      Selecto.Capabilities.allow(:allowed)
  end
end
```

Policy is evaluated in several places:

- generated row and bulk action availability
- generated action preview/apply authorization through the host handler
- query-contract fields, filters, published views, exports, exported views,
  scheduled exports, and choice sources
- exported-view embed access when the host passes a resolver
- scheduled-export run execution when the host runner passes a resolver

Denied decisions usually keep the item visible but disabled. Hidden decisions
remove it from generated contracts and option lists where possible.

## Generated Action Forms

Domain actions under `domain[:actions]` become generated modal actions. Detail
row actions use ids such as `domain_action_form_approve`. Bulk actions are
projected separately when `bulk: %{enabled: true}` is present.

The modal sends:

```elixir
%{
  intent: "preview" | "apply",
  action_id: "approve",
  request: %{
    "action" => "approve",
    "target" => %{"id" => 42},
    "inputs" => %{"note" => "Ready"},
    "confirmed" => true
  }
}
```

The parent LiveView handles it:

```elixir
@impl true
def handle_info({:selecto_action_form_submit, payload}, socket) do
  ActionFormHost.handle_submit(socket, payload,
    authorize: &authorize_action_form/4,
    preview: &preview_action_form/3,
    apply: &apply_action_form/3,
    after_apply: &after_action_form_apply/2,
    format_error: &action_error_message/1
  )
end
```

Host callbacks should be deterministic and side-effect aware:

- `authorize` runs before preview or apply.
- `preview` must not mutate data.
- `apply` owns the write.
- `after_apply` owns reload behavior and final result shape.
- `format_error` maps host errors to clear messages.

## Preview, Apply, Result, Reload

Action forms should treat preview/apply as contracts, not ad hoc button events.

Recommended preview result:

```elixir
%{
  ok: true,
  summary: "1 order will be approved.",
  changes: [%{field: "status", from: "pending", to: "approved"}],
  requires_confirmation: true
}
```

Recommended apply result:

```elixir
%{
  ok: true,
  summary: "Order approved.",
  record: %{id: 42, status: "approved"},
  reload: %{
    status: "refreshed",
    surface: "selecto_results",
    message: "Current results were rerun after the action."
  }
}
```

If the host cannot reload, return that explicitly:

```elixir
reload: %{status: "not_refreshed", reason: "query_not_running"}
```

This lets Components own the result UX while the host remains responsible for
actual execution and state refresh.

## Input Types

Generated forms should preserve typed values from UI to intent payload:

- booleans should submit as booleans, not `"true"` or `"false"` strings
- datetime inputs should submit ISO8601 datetimes
- enum inputs should submit one declared value
- collection/patch inputs should preserve add/update/remove/reorder operations
- defaults such as `{:system, :now}` should be materialized consistently

Host action adapters should still validate and coerce values. UI correctness is
not a substitute for server-side validation.

## Query Contracts

Mount JSON, Markdown, and validation endpoints for clients and generated tools:

```elixir
forward "/selecto/orders/query-contract.json",
        SelectoComponents.QueryContract.Plug,
        resolver: &MyAppWeb.QueryContractDomains.orders/1,
        domain_id: "orders",
        domain_path: "/orders",
        query_contract_url: "/api/selecto/orders/query-contract.json",
        query_guide_url: "/api/selecto/orders/query-guide.md",
        form_metadata: true,
        context: %{
          view_modes: [:detail, :aggregate, :graph],
          exports: [:csv, :json, :xlsx],
          exported_views_enabled: true,
          scheduled_exports_enabled: true
        }

forward "/selecto/orders/query-intent/validate",
        SelectoComponents.QueryContract.IntentValidator.Plug,
        resolver: &MyAppWeb.QueryContractDomains.orders/1
```

The resolver can return policy opts:

```elixir
def orders(conn) do
  {:ok, MyApp.SelectoDomains.OrderDomain.domain(),
   [
     actor: policy_actor(conn),
     tenant: tenant_id(conn),
     domain: :orders,
     surface: :query_contract,
     capability_resolver: &query_contract_capability_decision/1
   ]}
end
```

Contracts project policy for:

- fields and filters
- choice sources and choice-source-backed fields
- published views
- export formats
- exported view creation
- scheduled export creation

Intent validation reports policy-aware diagnostics such as
`choice_source_disabled`, `published_view_disabled`,
`exported_views_disabled`, and `scheduled_exports_disabled`.

## Choice Sources

Choice-source metadata can be used both by query clients and generated action
forms. The contract advertises links and request templates; the host endpoint
validates membership.

Recommended router shape:

```elixir
forward "/selecto/orders/choice-sources",
        SelectoComponents.QueryContract.ChoiceSource.Plug,
        resolver: &MyApp.SelectoDomains.OrderChoiceSources.domain/1,
        options_resolver: &MyApp.SelectoDomains.OrderChoiceSources.resolve_options/1,
        membership_resolver: &MyApp.SelectoDomains.OrderChoiceSources.resolve_membership/1,
        value_parser: &MyApp.SelectoDomains.OrderChoiceSources.parse_value/2,
        scope_resolver: &MyApp.SelectoDomains.OrderChoiceSources.scope/1,
        field_by_choice_source: %{customer_choices: "customer_id"}
```

When policy disables a choice source, Components disables the bound field in the
contract and returns a `choice_source_disabled` diagnostic when clients try to
use it.

## Exports

The Export tab may support immediate downloads, delivered email exports,
exported views, and scheduled exports. Components owns UI and form state; the
host owns payload delivery and persistence.

Host assignments:

```elixir
assign(socket,
  export_delivery_module: MyApp.ExportDelivery,
  exported_view_module: MyApp.ExportedViews,
  exported_view_context: scoped_context,
  scheduled_export_module: MyApp.ScheduledExports,
  scheduled_export_context: scoped_context
)
```

Capability ids:

- `selecto.exports.download`
- `selecto.exports.email`
- `selecto.exported_views.manage`
- `selecto.scheduled_exports.manage`

Use the query-contract context to disable whole surfaces when the actor cannot
use them.

## Exported Views

Exported views are signed, host-persisted snapshots for iframe/embed use.

Host responsibilities:

- persist exported view records and cache blobs
- rotate signatures
- regenerate caches
- enforce tenant and IP restrictions
- provide optional `capability_resolver` for embed access
- choose public URL/base URL and endpoint

Embed access can be denied by host policy and is rendered as an authorization
error rather than a generic load failure.

## Scheduled Exports

Components renders schedule forms, current schedule state, run history, and
manual run results. The host owns due-run execution.

Recommended runner shape:

```elixir
MyApp.ScheduledExportRunner.run_due(DateTime.utc_now(),
  adapter_opts: [user_id: current_user_id],
  actor: current_user,
  tenant: current_user_id,
  domain: :orders,
  context: %{surface: :exported_views_live},
  capability_resolver: &component_capability_decision/1,
  delivery_adapter: MyApp.ExportDelivery
)
```

The runner should:

- list due schedules through the host adapter
- authorize each run with `selecto.scheduled_exports.run`
- record `:ok`, `:skipped`, and `:failed` runs
- continue after failures
- emit telemetry with totals and duration
- return result entries that Components or host dashboards can render

Skipped capability denials should preserve the policy reason so the operator UI
can show why nothing was delivered.

## Error And Result Semantics

Prefer structured errors and result maps over raw strings.

For Components-originated failures, follow `docs/error-handling-conventions.md`.
For host-originated action errors, return details that include:

- `type`
- `code`
- `message`
- `path` when tied to an input
- `capability` and `capability_decision` for policy failures
- transport/status code when the failure crossed HTTP

Stable machine codes are more important than exact prose. UI copy can change;
client behavior should key off codes.

## Integration Checklist

- Query-contract JSON, guide, and intent validator routes exist.
- Resolver returns actor, tenant, domain, surface, and capability resolver.
- Choice-source options and membership endpoints are mounted.
- Generated row actions open stable action forms.
- Bulk actions only appear for `bulk.enabled` actions.
- `ActionFormHost.handle_submit/3` is wired with authorize, preview, apply, and
  after_apply callbacks.
- Preview is non-mutating.
- Apply refreshes active results or returns an explicit reload status.
- Exported views and scheduled exports have host persistence adapters.
- Manual scheduled-export run UX reports ok/skipped/failed counts.
- Embed access and scheduled-export runs pass capability resolvers.
- Tests cover at least one non-work-item domain so the flow is not a one-off.
