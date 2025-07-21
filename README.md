# SelectoComponents

Tailwind-based UI components for `selecto`. This library provides a pre-built LiveView interface for querying and displaying data.

## Installation

### 1. Add Dependencies

Add `selecto_components` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:selecto_components, "~> 0.2.8"}
  ]
end
```

### 2. Configure Your Router

In your `router.ex` file, import the `SelectoComponents.Router` and add the `selecto_live` routes to your desired scope.

```elixir
# lib/my_app_web/router.ex

defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  import SelectoComponents.Router
  ...

  scope "/", MyAppWeb do
    pipe_through :browser

    # Add this line to mount the Selecto UI
    selecto_live "/selecto"
  end
end
```

This will mount the component at `/selecto`.

### 3. Configure Tailwind CSS

Ensure Tailwind CSS is configured to scan the `selecto_components` library for classes. Update the `content` path in your `tailwind.config.js`:

```javascript
// assets/tailwind.config.js

module.exports = {
  content: [
    './js/**/*.js',
    '../lib/my_app_web/live/**/*.ex',
    '../lib/my_app_web/templates/**/*.eex',
    // Add this line to include selecto_components
    '../deps/selecto_components/lib/selecto_components/**/*.ex'
  ],
  theme: {
    extend: {},
  },
  plugins: []
}
```

### 4. Update Your `app.js`

Include the necessary JavaScript hooks from `selecto_components` in your `app.js` file.

```javascript
// assets/js/app.js

import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"
import selecto_components from "selecto_components"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

let hooks = {
    ...selecto_components
}

let liveSocket = new LiveSocket("/live", Socket, {
    params: {_csrf_token: csrfToken},
    hooks
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", info => topbar.show())
window.addEventListener("phx:page-loading-stop", info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket
```

## Usage

To use the component, you need a "queryable" module that implements the `Selecto.Queryable` behaviour. This module defines the Ecto schema and the fields that can be used for querying.

**Example Queryable:**

```elixir
# lib/my_app/accounts/user.ex

defmodule MyApp.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset
  alias MyApp.Repo

  @behaviour Selecto.Queryable

  schema "users" do
    field :name, :string
    field :email, :string
    field :inserted_at, :naive_datetime
  end

  @impl true
  def query do
    __MODULE__
  end

  @impl true
  def fields do
    %{
      name: %{type: :string, label: "Name"},
      email: %{type: :string, label: "Email"},
      inserted_at: %{type: :datetime, label: "Created At"}
    }
  end
end
```

Once you have a queryable module, you can render the component in any of your LiveViews:

```heex
# lib/my_app_web/live/user_live/index.html.heex

<.live_component
  module={SelectoComponents.View}
  id="user-view"
  queryable={MyApp.Accounts.User}
/>
```

Now, when you navigate to the page containing this LiveView, you will see the Selecto UI for your `User` schema.