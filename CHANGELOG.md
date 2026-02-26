
CHANGES
=======

V 0.3.4
-------

- Refactored detail-view query pagination/count/cache behavior into
  `SelectoComponents.Views.Detail.QueryPagination` to reduce view-specific
  logic in form state plumbing.
- Added view-scoped options helpers (`Views.Detail.Options`,
  `Views.Aggregate.Options`) and routed detail/aggregate option normalization
  through those modules.
- Simplified `SelectoComponents.Form.ParamsState` by delegating view-specific
  mode checks and option handling to the corresponding view modules.
- Delegated remaining view-specific form event behavior to view modules:
  detail page updates now route through `Views.Detail.Pagination`, and
  aggregate drill-down filter application routes through
  `Views.Aggregate.DrillDown`.
- Moved graph chart drill-down filter application/mode switching into
  `Views.Graph.DrillDown`, leaving form event handlers as dispatch/orchestration
  wrappers.
- Fixed aggregate-to-detail drill-down transitions by normalizing drill-down
  target view mode handling and hardening drill-down param building when
  `used_params` is missing.
- Fixed delegated view handlers to call `ParamsState.view_from_params/2` with
  correct argument ordering (restores aggregate drill-down transitions and
  detail/graph delegated view updates).
- Refreshed formal view-interface docs to clarify that 0.3.4 helper-module
  compartmentalization is additive and does not change
  `SelectoComponents.Views.System` callbacks.
- Implemented export-tab downloads for JSON/CSV from current query results,
  including browser download hook wiring and export payload formatting helpers.
- Bump package version to `0.3.4`.

V 0.3.3
-------

- Added numeric bucket increment shorthand support (`*/N`, e.g. `*/10`) for
  aggregate/group-by bucket formatting, producing fixed-width ranges such as
  `0-9`, `10-19`, etc.
- Updated detail view pagination to execute with `LIMIT/OFFSET`, run a total
  count query, cache the first three pages, and prefetch later pages in
  multi-page chunks while navigating.
- Fixed detail pagination count-query generation to preserve an explicit empty
  `order_by` list, preventing `KeyError` crashes in Selecto SQL builder.
- Improved error reporting for view execution failures with development-time
  debug details shown in the main results error panel.
- Added detail-page cache memory metrics to the debug panel (bytes, cached
  pages, cached rows).
- Fixed debug SQL display to persist the most recent executed query when detail
  pagination serves results from cache.
- Refreshed detail pagination UI with first/last buttons, clearer range text
  (`X-Y of N rows`), improved navigation icons, and strict boundary clamping.
- Added aggregate-result pagination with default 100 rows/page, selectable page
  sizes (`30`, `100`, `200`, `300`, `all`) from aggregate view configuration,
  first/last navigation controls, and hard boundary clamping.
- Aggregate views now keep full result sets in memory for paging and expose
  cache memory usage in the debug panel.
- Fixed aggregate next/prev paging interactions so page changes apply correctly
  from component events even when max-page metadata is computed at render time.
- Added detail view `max_rows` control (default `1000`, options: `100`,
  `1000`, `10000`, `all`) and enforced max-row limits in detail query/count
  pagination flow.
- Bump package version to `0.3.3`.

V 0.3.2
-------

- Added debug-panel access hardening with explicit request flags and secure
  token validation in production mode.
- Added support for rendering a custom detail modal component via
  `detail_modal_component`.
- Improved aggregate processing for group-by selectors by limiting COALESCE
  wrapping to text-compatible fields, preventing SQL type mismatches.
- Improved filter rendering/processing with broader operator handling and
  better enum-oriented behavior in form pipelines.
- Added aggregate drill-down test coverage for bucketed group-by behavior.
- Bump package version to `0.3.2`.
- Update Selecto dependency expectation to `>= 0.3.2 and < 0.4.0`.
- Keep documented/core flows and strict test compilation passing.
- Cleanup release artifacts and non-package roadmap files.

V 0.3.1
-------

- Bump package version to `0.3.1`.
- Update Selecto dependency expectation to `>= 0.3.1 and < 0.4.0`.
- Prune unwired experimental modules to reduce alpha surface area.
- Keep documented/core flows and strict test compilation passing.
- Many improvements and fixes

V 0.2.8
-------

- Fixes for saved views

V 0.2.6
-------

- Saved View Module support
- Filter form features & fixes TODO

V 0.2.5
-------

- refactor view selection system / modularize views
- cleanup agg & detail view forms/proc/comp
- add date filters to form from agg

V 0.2.4
-------

- use heroicons
- bug fix
- only add filters to state on validate

V 0.2.3
-------

- Fix bugs in filters and active tab

V 0.2.2
-------

- add filters to tree builder and list pickers
- results & form components
- cleanup & refactor view_selector
- Update look and feel of view selector form
  
V 0.2.1
-------

- Update URL on view
- group by updates
- support defaults

V 0.2.0
-------

- Support custom filters
- aggregate views/filters

V 0.1.3
-------

- move handle_params into view selector
- support for components columns
- support for enum filters

V 0.1.2
-------

- Support for link columns
- Use columns selected rather than aliases to build view
- bug fixes

V 0.1.1
-------

- Add simple pagination on detail views
- fix filter persistance in liveview

V 0.1.0
-------

- Initial Release
