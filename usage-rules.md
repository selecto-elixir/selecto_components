# SelectoComponents Usage Rules

## LiveView Integration
- Prefer `use SelectoComponents.Form` and initialize state via `get_initial_state/2`.
- Register views with `SelectoComponents.Views.spec/4` for clarity and consistency.
- Keep IDs stable for LiveComponents and view tabs.

## Assets and Hooks
- Use `mix selecto.components.integrate` for JS hook and CSS source integration.
- Rebuild assets after integration or hook changes (`mix assets.build`).
- Preserve colocated hook behavior when refactoring component modules.

## View Systems
- Built-in views are `detail`, `aggregate`, and `graph`; extension views (for example `map`) may be auto-merged.
- For custom view packages, implement `SelectoComponents.Views.System` callbacks (`Process`, `Form`, `Component`).
- If your app validates view types, update allowed types whenever adding a new view.

## Persistence Integrations
- Saved view and filter set adapters should implement the documented behavior callbacks.
- Keep saved-view decode/encode paths stable across UI form and reload flows.
