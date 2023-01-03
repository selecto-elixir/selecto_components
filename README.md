
# SelectoComponents

Tailwind based UI for selecto

See the live views in [selecto_test](https://github.com/selecto-elixir/selecto_test) for an example of how to setup. Documentaiton will be added once the API is stabilized.

## Plans for '0.5.0' which will be first 'stable' release

- Make gb rollup an option
- finish various TODOs in the code
- Forms - line forms & column forms
- cleanup liveviews / refactor
- make it look nice
- cleanup the event handlers
- error handing on view form
- results as XML, JSON, TXT, CSV, PDF, Excel.
- Export results, email results, POST/PUT results
- rename to Selecto.Phoenix
- show generated SQL
- Documentation
- Tests

## Plans for later

- better pagination in detail view, paginate by value, select All
- ability to save view configuration
- generate a token that can be used to generate a specific view, optionally allowing the token holder to access the forms
- Use a column in the results as email address and send that email address all the rows they are in
- Caching
- Dashboard components - save or code a view and drop it into another page
- graphing
- pub sub to trigger updating view
- infinite scroll
- update to work with improved planned selecto interface

This system is inspired by a system I wrote starting in 2004 and currently has all the features listed above except pub-sub and infinite scroll.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `selecto_components` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:selecto_components, "~> 0.2.8"}
  ]
end
```

Additionally:

You will need to add alpinejs and Tailwind to your app, and configure tailwind to look at *ex files in selecto_components.

You will need to include a Hook in your app.js for the drag and drop

```javascript
const PushEventHook = {
  mounted() {
    window.PushEventHook = this
  },
  destroyed() {
    window.PushEventHook = null
  }
};
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/selecto_components>.
