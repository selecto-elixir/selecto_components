# ListableComponentsTailwind

Tailwind based UI for listable

Provides 2 main components: ListableComponentsTailwind.ViewSelector and ListableComponentsTailwind.Results

ViewSelector is a live component that creates a control panel to build a query.

Results is a live component to display the results of that query.

Plans for '0.5.0': 
 - finish various TODOs in the code
 - update URL so users can bookmark views
 - ability to save view configuration
 - multi level filter section 
 - support custom filters and columns
 - special aggregate table, clicing on the group-by will link to the configured detail view with the group-by value applied as a filter
 - Forms - line forms & column forms
 - cleanup liveviews and make it look nice
 - error handing

Plans for later: 
 - generate a token that can be used to generate a specific view, optionally allowing the token holder to access the forms
 - Export results, email results, POST/PUT results
 - Use a column in the results as email address and send that email address all the rows they are in
 - results as XML, JSON, TXT, CSV, PDF, Excel if there's a module...
 - show generated SQL and show Ecto command
 - pagination
 - Caching
 - Dashboard components - save or code a view and drop it into another page
 - graphing 
 - pub sub to trigger updating view
 - infinite scroll
 
This system is inspired by a system I wrote starting in 2004 and currently has all the features listed above except pub-sub and infinite scroll. 


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

