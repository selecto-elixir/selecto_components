# Error Handling Conventions

Use the normalized error model for all new `selecto_components` failures.

## Core rule

- Build errors with `SelectoComponents.ErrorHandling.ErrorBuilder`.
- Prefer tagging `stage`, `category`, `code`, and `operation` at the failure source.
- Do not introduce new user-facing raw strings when the same failure can be expressed as a normalized error.

## Required concepts

### `stage`

Where the failure happened.

- `:input`
- `:configuration`
- `:normalization`
- `:query_build`
- `:sql_compile`
- `:db_execute`
- `:timeout`
- `:result_process`
- `:render`
- `:export`
- `:persistence`
- `:lifecycle`
- `:unknown`

### `category`

What kind of failure it was.

- `:validation`
- `:configuration`
- `:query`
- `:sql`
- `:database`
- `:timeout`
- `:connection`
- `:processing`
- `:rendering`
- `:authorization`
- `:persistence`
- `:runtime`
- `:unknown`

### `code`

Use stable machine-readable identifiers.

Examples:

- `:invalid_view_config`
- `:view_processing_failed`
- `:db_query_failed`
- `:query_timed_out`
- `:save_view_config_failed`
- `:export_failed`

## Preferred usage

```elixir
ErrorBuilder.build(reason,
  stage: :persistence,
  category: :persistence,
  code: :save_view_config_failed,
  operation: "do_save_view_config"
)
```

For flash messages, convert the normalized error into:

```elixir
error.summary <> ": " <> error.user_message
```

## Stage selection guidance

- Use `:configuration` for invalid view shape or unsupported combinations.
- Use `:sql_compile` when Selecto state cannot become valid SQL.
- Use `:db_execute` when SQL reached the database and failed there.
- Use `:timeout` when execution stopped because it took too long.
- Use `:result_process` when the query succeeded but shaping/display preparation failed.
- Use `:render` when rendering the final component failed.
- Use `:export` for export build/download/delivery failures.
- Use `:persistence` for saved views, exported views, filter sets, and saved configs.

## Message rules

- Let the builder generate `summary`, `user_message`, and `suggestion` whenever possible.
- Keep `user_message` concise and user-facing.
- Put sensitive or verbose data under debug details, not the main message.
- Prefer one clear next step over multiple vague suggestions.

## Migration guidance

- If you find an old `put_flash(..., :error, "...")`, consider replacing it with a normalized error message helper.
- If you find a raw `execution_error`, wrap it with `ErrorBuilder.build/2` at the source.
- If the exact stage is known, pass it explicitly instead of relying on inference.

## Testing expectations

For new error paths, prefer assertions on:

- `stage`
- `category`
- `code`
- `summary`
- `user_message`

When rendering UI, assert the visible stage-aware summary appears.
