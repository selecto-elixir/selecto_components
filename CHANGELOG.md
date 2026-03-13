
CHANGES
=======

V NEXT
------

V 0.3.21
--------

- Added configurable detail row actions with support for overlay-defined
  `iframe_modal` and `live_component` behaviors.
- Fixed row-click action state handling and stabilized popup/detail interactions
  across LiveView updates.
- Improved item picker configuration and editor stability for compact selected
  item workflows.
- Raised the minimum supported Elixir version to `1.18`.
- Bump package version to `0.3.21`.

V 0.3.20
--------

- Redesigned the item picker selected-list UI to use compact one-line summaries,
  inline edit panels, outside-click close behavior, and drag/drop reordering
  while keeping available items on the left and selected items on the right.
- Fixed item-picker drag/drop reordering so drops work consistently in both
  directions and selected-row editor state remains stable across LiveView
  updates while editing.
- Updated Detail, Aggregate, and Graph picker summaries to show
  `alias / field-name` when an alias is present, followed by lighter-weight
  format/status text for faster scanning.
- Changed Graph view queries to use plain grouped dimensions instead of SQL
  `ROLLUP`, preventing subtotal/grand-total rows from appearing as chart data.
- Moved active SelectoComponents runtime hooks to Phoenix LiveView colocated
  hooks, including picker, modal, theme, table, and dashboard interactions, so
  host apps no longer need copied SelectoComponents hook bundles.
- Updated compact picker summaries to show human-readable datetime format labels
  like `day of week` instead of raw format tokens such as `D`.
- Bump package version to `0.3.20`.

V 0.3.19
--------

- Fixed URL serialization to compact raw submitted form params before push-patch,
  so filters and view-item sections use short outer keys (`k0`, `k1`, ...)
  instead of UUID keys in the browser URL.
- Preserved UUID identity inside each serialized payload while shortening URL
  query strings for filters, group-by, aggregate, selected, and graph params.
- Added regression coverage for compacting raw UUID-keyed form params.
- Bump package version to `0.3.19`.

V 0.3.18
--------

- Added optional Aggregate Grid mode (toggle in aggregate form) that renders a
  2D table when exactly 2 group-by fields and 1 aggregate are configured.
- Wired aggregate grid state through params/view meta so the setting persists
  across form updates and URL/view-config round-trips.
- Added aggregate date/filter alignment for grouped datetime formats
  (`YYYY-WW`, `D`, `MM`, `DD`, `HH24`) plus weekday shortcuts
  (`weekdays`, `weekends`, `monday`...`sunday`).
- Unified datetime formatting options across Aggregate, Detail, and Graph
  configuration UIs (including week/quarter/day-of-week and bucket formats),
  and aligned Graph/Detail processing to support the same format set.
- Fixed datetime filter comparator switching so filter rows remount when the
  input shape changes and grouped datetime controls render consistently.
- Fixed quick-select filter persistence through validate/apply flow so selected
  shortcuts like `This Week` survive submit and continue to apply correctly.
- Fixed aggregate grid drill-down to disambiguate repeated datetime fields by
  group index, sort numeric headers like hour-of-day correctly, and allow cell
  click-through filtering on both dimensions.
- Shortened serialized URL params for filters and view item lists by using
  compact outer keys while preserving UUID identity inside each payload.
- Added regression tests for aggregate grid rendering/validation and grouped
  date-drilldown filter mapping.
- Bump package version to `0.3.18`.

V 0.3.17
--------

- Fixed aggregate drill-down date filtering so datetime-backed fields (including
  year and quarter groupings) produce valid date-range filters without
  `NaiveDateTime`/`DateTime` encode mismatches.
- Added quarter (`YYYY-Q`) drill-down parsing and regression coverage for year
  and quarter date-group filter generation.
- Fixed aggregate view NULL-group rendering so data buckets display as
  clickable `[NULL]` values and drill down to `IS_EMPTY` filters instead of
  being treated as grand totals.
- Reduced URL bloat by using compact per-row param keys in detail form
  serialization while preserving stable UUID identity in the payload.
- Bump package version to `0.3.17`.

V 0.3.16
--------

- Fixed detail-header sorting to emit Selecto-compatible `order_by` terms for
  descending sorts (`{:desc, field}`) instead of appending `" DESC"` to field
  names.
- Added regression coverage for enhanced-table sorting expression generation.
- Bump package version to `0.3.16`.

V 0.3.15
--------

- Kept detail-mode rows positional through params-state normalization and detail
  rendering to prevent value loss when duplicate DB column names are returned.
- Updated detail modal row mapping to build collision-safe record maps with
  deterministic deduped keys (`field`, `field_2`, `field_3`, ...).
- Added regression coverage for duplicate-key modal mapping behavior.
- Bump package version to `0.3.15`.

V 0.3.14
--------

- Fixed detail-mode row mapping to preserve Selecto alias semantics when
  database-returned column names collide (for example, selecting multiple
  `co_name` fields from different joins).
- Fixed denormalization nested-table column ordering so subselect fields render
  in view-config selection order instead of map-key/alphabetical order.
- Added regression tests for detail alias-collision mapping and nested subselect
  key ordering.
- Bump package version to `0.3.14`.

V 0.3.13
--------

- Updated package metadata description to better communicate the LiveView query
  builder and data exploration focus.
- Added package links for SQL pattern references and the hosted demo
  (`https://seeken.github.io/selecto-sql-patterns`,
  `https://testselecto.fly.dev`).
- Bump package version to `0.3.13`.

V 0.3.12
--------

- Removed remaining legacy bracket field parsing helpers in table/detail helper
  paths so joined-field parsing consistently uses current syntax handling.
- Removed legacy view runtime/UI compatibility paths to keep view wiring
  aligned with the current runtime surface.
- Hardened drill-down routing by requiring indexed drill-down filter params and
  updating aggregate drill-down parameter handling accordingly.
- Added/expanded drill-down and SQL-injection test coverage for stricter param
  handling.
- Fixed debug-panel SQL highlighting by using the registered `makeup_sql`
  lexer and token-compatible style classes.
- Updated Selecto dependency expectation to `>= 0.3.10 and < 0.4.0`.
- Bump package version to `0.3.12`.

V 0.3.11
--------

- Added an OTP application runtime (`SelectoComponents.Application`) that boots
  a supervised task supervisor and metrics collector.
- Moved performance metrics storage from process state into bounded ETS tables
  with periodic retention cleanup and explicit query/error caps.
- Switched cache hit/miss tracking to `:counters` for better throughput under
  sustained UI query activity.
- Added/expanded tests for runtime supervision, metrics retention behavior,
  cache counter accuracy, timeline output, and cleanup paths.
- Bump package version to `0.3.11`.

V 0.3.10
--------

- Added configurable multi-layer map styling controls for map views.
- Added geometry-aware layer controls and generated map legends.
- Added map scale controls and generated scale legend rendering.
- Added categorical map mappings and breadcrumb track overlays.
- Added track start/end markers and optional direction arrows.
- Added optional breadcrumb arrow endpoint controls.
- Added map clustering support and saved-map roundtrip persistence handling.
- Hardened map rendering and set-shape compatibility handling.
- Hardened shared filter decoding paths and redacted filter-set debug logs.
- Added StreamData property roundtrip tests for shared filter decoding and
  params/filter-state processing.
- Bump package version to `0.3.10`.

V 0.3.9
-------

- Added server-side aggregate pagination flow that executes page-scoped queries
  (`LIMIT/OFFSET`) and aggregate total-row counting, instead of always loading
  full aggregate result sets into memory before paging.
- Updated aggregate page controls to request page changes through parent view
  query execution, including `aggregate_page` URL-state synchronization.
- Added aggregate rendering metadata and UI handling for server-paged results.
- Added aggregate pagination cache reuse for page-count metadata and previously
  fetched pages to reduce repeated query cost while navigating between pages.
- Stabilized server-side aggregate pager interactions by preventing optimistic
  page-number jumps and disabling controls while a page fetch is in flight.
- Added aggregate page-boundary context rows so parent group headers are shown
  at the top of continued pages with a `(continued)` marker.
- Updated submit/saved-view reload flows to clear detail and aggregate page
  caches before re-execution, ensuring explicit reloads use fresh query data.
- Added configurable aggregate client-row cap (`:aggregate_max_client_rows`,
  default `10_000`) to protect render responsiveness when aggregate mode uses
  `per_page = all`.
- Bump package version to `0.3.9`.

V 0.3.8
-------

- Added `usage-rules.md` with concise package guidance for agentic tooling and
  dependency rule aggregation workflows.
- Added `MULTI_TENANT_USAGE_PATTERNS.md` with package-specific guidance for
  tenant-scoped LiveView state, saved views, filter sets, and view wiring.
- Added `SelectoComponents.Tenant.scoped_context/3` for generating stable
  tenant-scoped context keys used by persistence adapters.
- Updated `SelectoComponents.Form` to tenant-scope saved view context and
  filter-set domain values when `tenant_context` is present in assigns.
- Added tenant helper tests for context pass-through and tenant-scoped key
  formatting.
- Expanded tenant helper tests to verify cross-tenant saved-view/filter-set key
  isolation and atom-context key normalization.
- Fixed detail-view row rendering when selected-column configs arrive in mixed
  legacy shapes (map/list/tuple) by normalizing selected entries and preserving
  UUID/field metadata.
- Added resilient detail-cell value lookup fallback (uuid -> field/alias ->
  positional index) to prevent blank rows when query result maps use atom/string
  key variants.
- Added detail-view `count_mode` options (`exact`, `bounded`, `none`) with
  normalization and form wiring for count strategy control.
- Optimized detail pagination with lightweight count projections, optional
  count-skipping mode, and keyset pagination fallback for deep sequential pages.
- Added detail query telemetry (`[:selecto_components, :detail, :query]`) with
  count timing, page fetch timing, and cache hit/miss measurements.
- Bump package version to `0.3.8`.

V 0.3.7
-------

- Added optional saved-view management callbacks to the
  `SelectoComponents.SavedViews` behavior (`list_views/1`, `rename_view/3`,
  `delete_view/2`) so host apps can provide richer saved-view UIs.
- Updated save-view lifecycle handling to emit a `{:saved_view_saved, name}`
  message after successful save, enabling parent LiveViews to refresh saved
  view lists immediately.
- Bump package version to `0.3.7`.

V 0.3.6
-------

- Added string aggregate/group-by bucketing format `text_prefix` with configurable
  prefix length (default 2) and optional leading-article removal (`a`, `an`,
  `the`) for grouping labels.
- Added aggregate drill-down handling for text-prefix buckets, including proper
  `Other` bucket behavior and filter metadata propagation.
- Added a new standard text filter operator, `Begins With` (`STARTS`), with an
  optional UI toggle to ignore leading articles during matching.
- Updated filter execution to support article-aware starts-with matching via
  normalized SQL expressions while preserving existing parameterized behavior.
- Added a case-insensitive mode for text filters, including starts-with and
  article-aware matching paths.
- Limited "ignore leading articles" controls to `=` and `STARTS`, and made
  text-prefix drill-down filters auto-enable case-insensitive matching when
  article stripping is active.
- Added test coverage for text-prefix SQL generation, aggregate processing,
  drill-down conversion, and begins-with filter execution paths.
- Bump package version to `0.3.6`.

V 0.3.5
-------

- Added extension-aware view registration through
  `SelectoComponents.Extensions.merge_views/2`, wired into form initial state
  setup so extension-provided views are available without manual view list edits.
- Added a built-in map view system (`Views.Map`) with form/process/component
  modules, including Leaflet + OpenStreetMap rendering via colocated hooks.
- Added map-view processing support for spatial projections
  (`ST_AsGeoJSON` selector generation), popup/color field options, and
  extension/domain map defaults.
- Decoupled map spatial type checks from direct PostGIS module calls by using
  `Selecto.TypeSystem` spatial category detection.
- Added extension/map test coverage for view merge behavior and map
  process/component rendering helpers.
- Added `map` as a valid saved-view label/type surface in supporting modules.
- Bump package version to `0.3.5`.
- Update Selecto dependency expectation to `>= 0.3.3 and < 0.4.0`.

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
