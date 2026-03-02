# Multi-Tenant Usage Patterns for SelectoComponents

## Purpose

Define practical multi-tenant integration patterns for SelectoComponents
LiveView workflows so tenant boundaries remain enforced in UI-driven query,
saved-view, and filter-set interactions.

## Tenant Context Model

At LiveView mount, establish tenant context once and keep it in assigns:

```elixir
tenant_context = %{
  tenant_id: "acme",
  tenant_mode: :shared_rls,
  prefix: nil
}
```

Recommended state layout:

1. `:tenant_context` in root assigns.
2. `:selecto` preconfigured with server-side tenant scope.
3. Saved-view/filter-set adapters that accept tenant-aware context keys.

## Tenant-Safe UI Patterns

### 1) Server-Enforced Query Scope

- Do not rely on client-submitted filters for tenant isolation.
- Apply required tenant filters in server-built Selecto state before rendering
  any form/result component.

### 2) Saved Views and Filter Sets

- Namespace persisted objects by tenant context (for example
  `"tenant:acme:/pagila"`).
- Keep list/rename/delete operations tenant-scoped in adapter callbacks.

### 3) View Types and Extensions

- Tenant policy may restrict allowed view types (for example map or graph).
- Resolve allowed views server-side before building initial state.

### 4) Pagination and Caching

- Include tenant identity in any page-cache keys.
- Reset or invalidate local caches on tenant switch events.

## Recommended LiveView Flow

1. Resolve tenant context from session/request.
2. Build tenant-scoped Selecto instance.
3. Build views list allowed for that tenant.
4. Initialize form state.
5. Pass tenant context into saved-view/filter-set adapter operations.

## Failure Modes to Guard Against

1. Cross-tenant saved-view visibility.
2. Cross-tenant cache reuse in detail/aggregate pagination.
3. Tenant switch without form-state reset.
4. UI-only tenant filtering with no server enforcement.

## Implementation Checklist

- [ ] tenant context assign included in mount.
- [ ] required tenant filters applied server-side.
- [ ] saved views adapter tenant-namespaced.
- [ ] filter sets adapter tenant-namespaced.
- [ ] test coverage for tenant A/B isolation in LiveView events.
