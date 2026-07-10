# Code Review: SelectoComponents

Review of **code smells**, **non-idiomatic Elixir**, and **potential security problems** in this repository.

Overall this is a mature LiveView library with real security work already in place (`SafeAtom`, URL sanitization, debug gating, exported-view signatures, LIKE escaping, error sanitization). The biggest remaining risks are **string-built SQL**, a few **trust-boundary gaps**, and **maintainability smells** from very large modules and duplicated helpers.

---

## Security (ordered by severity)

### 1. High — SQL string interpolation for datetime format / timezone

User-influenced values are interpolated into SQL string literals in aggregate/graph process paths:

```elixir
# lib/selecto_components/views/aggregate/process.ex
defp timezone_aware_to_char_sql(col, field_ref, format, presentation_context) do
  "to_char(#{timezone_grouping_expression(col, field_ref, presentation_context)}, '#{format}')"
end

defp timezone_grouping_expression(col, field_ref, presentation_context) do
  timezone = runtime_timezone(presentation_context)
  storage_timezone = storage_timezone(col)

  case Selecto.Temporal.epoch_storage(col) do
    :unix_seconds -> "to_timestamp(#{field_ref}) AT TIME ZONE '#{timezone}'"
    :unix_milliseconds -> "to_timestamp((#{field_ref}) / 1000.0) AT TIME ZONE '#{timezone}'"
    _ -> "(#{field_ref} AT TIME ZONE '#{storage_timezone}') AT TIME ZONE '#{timezone}'"
  end
end
```

The same pattern exists in `lib/selecto_components/views/graph/process.ex`.

**Why it matters**

- Group-by `"format"` comes from form params and is **not** validated against `Helpers.datetime_grouping_format_options/0` before SQL build.
- Timezone comes from presentation context; `Presentation.normalize_timezone/1` only trims — it does **not** validate IANA zones:

```elixir
# lib/selecto_components/presentation.ex
defp normalize_timezone(nil), do: "Etc/UTC"

defp normalize_timezone(timezone) when is_binary(timezone) do
  case String.trim(timezone) do
    "" -> "Etc/UTC"
    trimmed -> trimmed
  end
end
```

A payload like `'); DROP ... --` in `format`, or a quote-breaking timezone string, can break out of the literal.

**Fix direction**

- Whitelist formats against known options before building SQL.
- Validate timezones with `Tzdata` / `Timex.Timezone.exists?/1` (or equivalent).
- Prefer parameterized SQL / Selecto AST over string assembly; if you must interpolate, escape single quotes and reject anything outside a safe character class (e.g. `[A-Za-z0-9_/\-+ ]`).

---

### 2. High — SQL injection tests do not test injection

`test/security/sql_injection_test.exs` mostly asserts that malicious strings remain binaries in maps. That proves nothing about Selecto SQL generation or the raw SQL paths above.

**Fix direction:** generate SQL (or assert Selecto filter AST) for malicious filters/formats and assert parameterization / rejection.

---

### 3. Medium — `{:safe, _}` cell values are trusted HTML

```elixir
# lib/selecto_components/views/aggregate/component.ex (and detail component)
defp safe_cell_value(value, column_def, presentation_context) do
  case value do
    {:safe, _} = safe_value ->
      safe_value
```

If a domain formatter or unexpected DB/driver shape yields `{:safe, html}`, LiveView will render it unescaped → XSS.

**Fix direction:** only accept `{:safe, _}` from known formatter callbacks you control; otherwise always `html_escape`.

---

### 4. Medium — Exported view tokens live ~10 years

```elixir
# lib/selecto_components/exported_views/token.ex
@salt "selecto_components_exported_view"
@max_age 315_360_000
```

`315_360_000` ≈ 10 years. Signature rotation helps, but a leaked URL remains valid for a very long time by default.

Also: embed access with only signature is open unless the host supplies `capability_resolver` (`lib/selecto_components/exported_views/service.ex`). Document that clearly; consider default-deny for sensitive domains.

---

### 5. Medium — IP allowlist uses raw peer address only

```elixir
# lib/selecto_components/exported_views/service.ex
def request_ip(socket) do
  case Phoenix.LiveView.get_connect_info(socket, :peer_data) do
    %{address: address} -> address
    _ -> nil
  end
rescue
  _ -> nil
end
```

Behind a reverse proxy, this is the proxy IP, not the client. Empty allowlist = allow all (by design), so a misconfigured “restrict by IP” setup may silently fail open or block everyone incorrectly.

**Fix direction:** support configurable remote-IP extraction (`x_headers` / `Plug.Conn` peer + trusted proxies). Treat missing IP as deny when allowlist is non-empty (already done).

---

### 6. Medium — Iframe sandbox default enables escape

```elixir
# lib/selecto_components/views/detail/row_actions.ex
iframe_sandbox:
  normalize_optional_string(map_get(payload, :sandbox)) ||
    "allow-scripts allow-same-origin"
```

`allow-scripts` + `allow-same-origin` together often lets framed content remove sandboxing. Prefer stricter defaults (`allow-scripts` alone, or no sandbox privileges) and document that host apps must opt into same-origin.

URL sanitization for `javascript:` / `data:` is good; keep that.

---

### 7. Medium — Debug env detection is brittle

```elixir
# lib/selecto_components/debug/production_config.ex
defp dev_or_test_env? do
  Application.get_env(:selecto_components, :env) in [:dev, :test] ||
    Application.get_env(:phoenix, :serve_endpoints) == false ||
    System.get_env("MIX_ENV") in ["dev", "test"] ||
    check_mix_env_if_available()
end
```

`:serve_endpoints == false` is treated as “dev/test”, which can disable production debug token checks in odd deployments. Prefer a single authoritative `Application.get_env(:selecto_components, :env)` set by the host (the `Env` module is better — use it consistently).

Custom `secure_compare/2` should be `Plug.Crypto.secure_compare/2` (already a transitive dep via Phoenix).

---

### 8. Low / defense-in-depth

| Item | Notes |
|------|--------|
| CSS injection via theme tokens | `Theme.style_attr/1` interpolates token values into `style=`; untrusted theme resolvers can inject CSS. Sanitize color/length values. |
| Error sanitizer is heuristic | Regex strip of SQL is incomplete; prefer never putting SQL into user-facing errors in prod (partly already done). |
| Metrics store full query text in ETS | `lib/selecto_components/performance/metrics_collector.ex` — PII / secrets risk; redact params. |
| Field names in raw SQL | `date_filter_field_expr` / `qualify_field_name` assume schema-trusted identifiers; keep enforcing “column must exist in Selecto schema” before raw SQL. |
| Atom safety | Mostly good (`SafeAtom`, `to_existing_atom`). Policy’s `String.to_atom/1` over compile-time keys is fine. |

---

## Code smells

### God modules

Largest files:

| Lines (approx.) | Module |
|----------------:|--------|
| ~3125 | `form/filter_rendering.ex` |
| ~2124 | `form.ex` |
| ~2003 | `components/list_picker.ex` |
| ~1968 | `views/aggregate/component.ex` |
| ~1935 | `helpers/filters.ex` |
| ~1865 | `form/params_state.ex` |

These concentrate UI, event handling, SQL-ish construction, and validation. Hard to review and easy to reintroduce bugs.

### Duplicated utilities

`map_get` / `get_map_value` / `string_id` / `list_or_empty` / atom-or-string key access is copy-pasted across dozens of modules. Centralize once (`Access` helpers + normalize maps to string keys at the boundary).

### `acc ++ [item]` list building

Appears in filters, views, router-style code. Quadratic on large lists; prefer `[item | acc]` + `Enum.reverse/1` or `Enum.map/2`.

### Bare `String.to_integer/1` on user params

Examples:

```elixir
# lib/selecto_components/form/params_state.ex
String.to_integer(Map.get(f1, "index", "0")) <= String.to_integer(Map.get(f2, "index", "0"))

# lib/selecto_components/views/detail/process.ex
page: String.to_integer(Map.get(params, "detail_page", "0")),
```

Malformed indexes crash the LiveView process. Elsewhere the code correctly uses `Integer.parse` + defaults — standardize on that.

### Debug leftovers in library code

- `IO.puts("Handling filter_remove event")` in `lib/selecto_components/router.ex`
- `IO.puts("[theme-debug]...")` in aggregate/graph components

These should be `Logger.debug` behind config or removed.

### Dead / backup artifacts under `lib/`

- `performance_monitor.ex.backup`
- `views/aggregate/component.ex.backup`
- empty `filter_sets.ex.bak`

Not compiled (usually), but noise and risk of accidental reuse. Delete them.

### Incomplete `case` / assumed success

```elixir
# lib/selecto_components/router.ex
def handle_event("view-apply", params, %{active_tab: "save"} = state) do
  case handle_save_view(params, state) do
    {:ok, updated_state} -> {:ok, updated_state}
  end
end
```

Missing error clauses → `CaseClauseError` on failure. Non-idiomatic and fragile.

### Compatibility dual-key maps

Heavy `Map.get(m, :x) || Map.get(m, "x")` is a tax paid everywhere. Normalize at inbound boundaries (params → internal struct/map with atom or string keys only).

---

## Non-idiomatic Elixir

1. **Prefer `with` / pattern-matched success paths** over `try/rescue` for control flow (many `to_existing_atom` rescues are fine; broader `rescue _` is not).
2. **Use `Enum.sort_by/2`** instead of `Enum.sort` with manual comparators and fragile integer parsing.
3. **`@moduledoc false` on large public surface** — fine for internals, but many integration-facing modules are undocumented for a published Hex library.
4. **Custom crypto** (`ProductionConfig.secure_compare`) instead of `Plug.Crypto.secure_compare/2`.
5. **Process messaging via `send(self(), ...)`** from LiveComponents is common here; consider `send_update` / explicit parent callbacks where possible to reduce “message soup.”
6. **GenServer + ETS metrics** started always from the application supervisor — hosts may not want always-on metrics; make optional via config.

---

## What’s in good shape

- **Atom exhaustion:** whitelist helpers + `to_existing_atom` are the right model.
- **LIKE wildcards:** escaped before use.
- **External URLs:** scheme checks block `javascript:` / `data:` / protocol-relative.
- **Debug panel:** opt-in + token model is thoughtful (env detection aside).
- **Export connection sanitization:** sensitive keys dropped.
- **Query contract / intent validator / capability hooks:** good security architecture for host apps when used.
- **Multi-tenant docs:** correctly stress server-side scope, not client filters.

---

## Recommended priority

1. Whitelist + validate **datetime formats** and **timezones** in aggregate and graph raw SQL builders.
2. Replace fake SQL-injection tests with AST/SQL assertions for filters, formats, and timezone paths.
3. Stop trusting arbitrary `{:safe, _}` in cell rendering.
4. Fix `String.to_integer` on user input; remove `IO.puts`; delete `*.backup` files.
5. Harden exported views: shorter default token TTL, documented capability requirements, proxy-aware IP.
6. Longer term: split god modules and consolidate map/key helpers.
