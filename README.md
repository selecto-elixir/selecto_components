# ListableComponentsTailwind

Tailwind based UI for listable

Provides 2 main components: ListableComponentsTailwind.ViewSelector and ListableComponentsTailwind.Results

ViewSelector is a live component that creates a control panel to build a query.

Results is a live component to display the results of that query.



## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `listable_components_tailwind` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:listable_components_tailwind, "~> 0.1.0"}
  ]
end
```

Additionally:

You will need to add alpinejs and Tailwind to your app, and configure tailwind to look at *ex files in listable_components_tailwind.

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
be found at <https://hexdocs.pm/listable_components_tailwind>.

