defmodule SelectoComponents.SavedViews do
  @moduledoc """
  Behavior for implementing persistent saved views in SelectoComponents.

  This behavior defines a contract for saving and retrieving component view configurations
  to persistent storage, typically a database. It enables users to save their customized
  filters, column selections, aggregations, and other view settings for later use.

  ## Overview

  The SavedViews behavior supports:
  - **Context-based organization**: Views are organized by context (e.g., URL path, user ID)
  - **Named view persistence**: Each saved view has a unique name within its context
  - **Flexible parameter storage**: View configurations stored as maps/JSON
  - **CRUD operations**: Create, read, update, list, rename, and delete saved views

  ## Typical Implementation Pattern

  Most implementations will:
  1. Create an Ecto schema for the `saved_views` table
  2. Create a context module that implements this behavior
  3. Use the context in domains via `use YourApp.SavedViewContext`

  ## Database Schema

  The typical database structure includes:
  - `name`: String identifier for the saved view
  - `context`: String context identifier (often URL path or user-specific)
  - `params`: Map/JSON containing the view configuration
  - `timestamps`: Created/updated timestamps

  A unique constraint on `[:name, :context]` ensures no duplicate view names per context.

  ## Integration with SelectoComponents

  SelectoComponents automatically integrates with saved views when:
  1. A module implementing this behavior is provided
  2. The `saved_view_context` assign is set in the LiveView
  3. Users can then save/load views through the component UI

  ## Example Implementation

      # Schema
      defmodule MyApp.SavedView do
        use Ecto.Schema
        import Ecto.Changeset

        schema "saved_views" do
          field :context, :string
          field :name, :string
          field :params, :map
          timestamps()
        end

        def changeset(saved_view, attrs) do
          saved_view
          |> cast(attrs, [:name, :context, :params])
          |> validate_required([:name, :context, :params])
          |> unique_constraint([:name, :context])
        end
      end

      # Context implementation
      defmodule MyApp.SavedViewContext do
        @behaviour SelectoComponents.SavedViews
        import Ecto.Query

        def get_view(name, context) do
          from(v in MyApp.SavedView,
            where: v.context == ^context and v.name == ^name
          )
          |> MyApp.Repo.one()
        end

        def save_view(name, context, params) do
          case get_view(name, context) do
            nil ->
              %MyApp.SavedView{name: name, context: context, params: params}
              |> MyApp.Repo.insert!()
            view ->
              MyApp.SavedView.changeset(view, %{params: params})
              |> MyApp.Repo.update!()
          end
        end

        def get_view_names(context) do
          from(v in MyApp.SavedView,
            where: v.context == ^context,
            select: v.name,
            order_by: v.name
          )
          |> MyApp.Repo.all()
        end

        def decode_view(view) do
          view.params
        end
      end

      # Usage in domain
      defmodule MyApp.Domains.BlogDomain do
        use MyApp.SavedViewContext  # Includes the behavior implementation

        # ... rest of domain configuration
      end

  ## Generator Support

  Use the Mix generator to create the boilerplate:

      mix selecto.gen.saved_views MyApp --context-module MyApp.SavedViewContext

  This generates:
  - Migration for `saved_views` table
  - Ecto schema for saved views
  - Context module implementing this behavior

  ## Error Handling

  Implementations should handle common error scenarios:
  - Missing views (return `nil` from `get_view/2`)
  - Invalid parameters (validate in `save_view/3`)
  - Database constraints (handle unique constraint violations)
  - Malformed view data (validate in `decode_view/1`)
  """

  @doc """
  Retrieves all saved view names for a given context.

  ## Parameters
  - `context`: Context identifier (typically URL path, user ID, or similar)

  ## Returns
  List of view names as strings, typically sorted alphabetically.

  ## Example
      iex> MyApp.SavedViewContext.get_view_names("/admin/users")
      ["active_users", "recent_signups", "power_users"]
  """
  @callback get_view_names(context :: any()) :: [String.t()]

  @doc """
  Retrieves a specific saved view by name and context.

  ## Parameters
  - `name`: Name of the saved view
  - `context`: Context identifier

  ## Returns
  - The saved view record/struct if found
  - `nil` if no view exists with the given name and context

  ## Example
      iex> MyApp.SavedViewContext.get_view("active_users", "/admin/users")
      %MyApp.SavedView{
        name: "active_users",
        context: "/admin/users",
        params: %{"filters" => [%{"field" => "active", "value" => true}]}
      }
  """
  @callback get_view(name :: String.t(), context :: any()) :: map() | nil

  @doc """
  Saves a view configuration with the given name and context.

  This function should handle both creating new views and updating existing ones.
  If a view with the same name and context already exists, it should be updated.

  ## Parameters
  - `name`: Name for the saved view
  - `context`: Context identifier
  - `params`: Map containing the view configuration (filters, columns, etc.)

  ## Returns
  The saved view record/struct after persistence.

  ## Example
      iex> params = %{
      ...>   "filters" => [%{"field" => "status", "value" => "active"}],
      ...>   "columns" => ["name", "email", "created_at"]
      ...> }
      iex> MyApp.SavedViewContext.save_view("active_users", "/admin/users", params)
      %MyApp.SavedView{
        name: "active_users",
        context: "/admin/users", 
        params: %{"filters" => [...], "columns" => [...]}
      }
  """
  @callback save_view(name :: String.t(), context :: any(), params :: map()) :: map()

  @doc """
  Decodes a saved view record into parameters usable by SelectoComponents.

  This function extracts the view configuration from the saved view record
  and returns it in a format that can be applied to SelectoComponents.

  ## Parameters
  - `view`: The saved view record/struct retrieved from storage

  ## Returns
  Map of parameters that can be used to restore the component state.

  ## Example
      iex> view = %MyApp.SavedView{
      ...>   params: %{"filters" => [%{"field" => "active", "value" => true}]}
      ...> }
      iex> MyApp.SavedViewContext.decode_view(view)
      %{"filters" => [%{"field" => "active", "value" => true}]}
  """
  @callback decode_view(view :: map()) :: map()

  @doc """
  Optional callback that returns richer saved view records for management UIs.

  Unlike `get_view_names/1`, this may return structs or maps with metadata such as
  `updated_at`, `inserted_at`, and ownership fields.
  """
  @callback list_views(context :: any()) :: [map()]

  @doc """
  Optional callback for deleting a saved view by name and context.
  """
  @callback delete_view(name :: String.t(), context :: any()) ::
              {:ok, map()} | {:error, term()}

  @doc """
  Optional callback for renaming a saved view within the same context.
  """
  @callback rename_view(old_name :: String.t(), new_name :: String.t(), context :: any()) ::
              {:ok, map()} | {:error, term()}

  @optional_callbacks list_views: 1, delete_view: 2, rename_view: 3
end
