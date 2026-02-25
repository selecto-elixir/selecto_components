
CHANGES
=======

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
