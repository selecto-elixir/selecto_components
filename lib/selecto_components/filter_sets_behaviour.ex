defmodule SelectoComponents.FilterSetsBehaviour do
  @moduledoc """
  Behavior for implementing persistent filter sets in SelectoComponents.

  This behavior defines a contract for saving, loading, and managing filter sets
  to persistent storage. It enables users to save complex filter combinations,
  share them with others, and quickly apply commonly used filters.

  ## Overview

  The FilterSets behavior supports:
  - **Personal filter sets**: User-specific saved filters
  - **Shared filter sets**: Filters shared across users in a domain
  - **System filter sets**: Admin-configured default filters
  - **Default filter sets**: User's preferred default filter per domain
  - **Usage tracking**: Analytics on filter set usage

  ## Database Schema

  The typical database structure includes:
  - `id`: UUID primary key
  - `name`: String identifier for the filter set
  - `description`: Optional description
  - `domain`: String domain/context identifier
  - `filters`: Map/JSON containing the filter configuration
  - `user_id`: Owner of the filter set
  - `is_default`: Boolean flag for user's default
  - `is_shared`: Boolean flag for shared sets
  - `is_system`: Boolean flag for system sets
  - `usage_count`: Integer tracking usage
  - `timestamps`: Created/updated timestamps

  ## Integration with SelectoComponents

  SelectoComponents automatically integrates with filter sets when:
  1. A module implementing this behavior is configured
  2. The `filter_sets_adapter` is set in the component assigns
  3. Users can then save/load filter sets through the UI

  ## Example Implementation

      defmodule MyApp.FilterSets do
        @behaviour SelectoComponents.FilterSetsBehaviour
        
        def list_personal_filter_sets(user_id, domain) do
          # Return user's personal filter sets for domain
        end
        
        def list_shared_filter_sets(user_id, domain) do
          # Return shared filter sets for domain
        end
        
        def list_system_filter_sets(domain) do
          # Return system filter sets for domain
        end
        
        # ... other callbacks
      end

  ## Generator Support

  Use the Mix generator to create the implementation:

      mix selecto.gen.filter_sets MyApp

  This generates:
  - Migration for `filter_sets` table
  - Ecto schema for filter sets
  - Context module implementing this behavior
  """

  @doc """
  Lists personal filter sets for a user and domain.

  ## Parameters
  - `user_id`: User identifier
  - `domain`: Domain/context identifier

  ## Returns
  List of filter set records owned by the user for the domain.
  """
  @callback list_personal_filter_sets(user_id :: String.t(), domain :: String.t()) :: [map()]

  @doc """
  Lists shared filter sets accessible to a user in a domain.

  ## Parameters
  - `user_id`: User identifier (for access control)
  - `domain`: Domain/context identifier

  ## Returns
  List of shared filter set records for the domain.
  """
  @callback list_shared_filter_sets(user_id :: String.t(), domain :: String.t()) :: [map()]

  @doc """
  Lists system-provided filter sets for a domain.

  ## Parameters
  - `domain`: Domain/context identifier

  ## Returns
  List of system filter set records for the domain.
  """
  @callback list_system_filter_sets(domain :: String.t()) :: [map()]

  @doc """
  Gets a specific filter set by ID.

  ## Parameters
  - `id`: Filter set ID
  - `user_id`: User requesting the filter set (for access control)

  ## Returns
  - `{:ok, filter_set}` if found and accessible
  - `{:error, :not_found}` if not found
  - `{:error, :unauthorized}` if user lacks access
  """
  @callback get_filter_set(id :: String.t(), user_id :: String.t()) :: {:ok, map()} | {:error, atom()}

  @doc """
  Creates a new filter set.

  ## Parameters
  - `attrs`: Map containing filter set attributes
    - `:name` - Required string name
    - `:description` - Optional description
    - `:domain` - Required domain identifier
    - `:filters` - Required map of filter configuration
    - `:user_id` - Required owner ID
    - `:is_default` - Optional boolean (default: false)
    - `:is_shared` - Optional boolean (default: false)

  ## Returns
  - `{:ok, filter_set}` on success
  - `{:error, changeset}` on validation failure
  """
  @callback create_filter_set(attrs :: map()) :: {:ok, map()} | {:error, any()}

  @doc """
  Updates an existing filter set.

  ## Parameters
  - `id`: Filter set ID
  - `attrs`: Map of attributes to update
  - `user_id`: User performing the update (for access control)

  ## Returns
  - `{:ok, filter_set}` on success
  - `{:error, :not_found}` if not found
  - `{:error, :unauthorized}` if user lacks permission
  - `{:error, changeset}` on validation failure
  """
  @callback update_filter_set(id :: String.t(), attrs :: map(), user_id :: String.t()) :: 
    {:ok, map()} | {:error, atom() | any()}

  @doc """
  Deletes a filter set.

  ## Parameters
  - `id`: Filter set ID
  - `user_id`: User performing the deletion (for access control)

  ## Returns
  - `{:ok, filter_set}` on success
  - `{:error, :not_found}` if not found
  - `{:error, :unauthorized}` if user lacks permission
  """
  @callback delete_filter_set(id :: String.t(), user_id :: String.t()) :: 
    {:ok, map()} | {:error, atom()}

  @doc """
  Sets a filter set as the user's default for a domain.

  ## Parameters
  - `id`: Filter set ID to make default
  - `user_id`: User setting the default

  ## Returns
  - `{:ok, filter_set}` on success
  - `{:error, :not_found}` if not found
  - `{:error, :unauthorized}` if user lacks permission
  """
  @callback set_default_filter_set(id :: String.t(), user_id :: String.t()) :: 
    {:ok, map()} | {:error, atom()}

  @doc """
  Gets the user's default filter set for a domain.

  ## Parameters
  - `user_id`: User identifier
  - `domain`: Domain/context identifier

  ## Returns
  - The default filter set if one exists
  - `nil` if no default is set
  """
  @callback get_default_filter_set(user_id :: String.t(), domain :: String.t()) :: map() | nil

  @doc """
  Increments the usage count for a filter set.

  ## Parameters
  - `id`: Filter set ID

  ## Returns
  - `:ok` on success
  """
  @callback increment_usage_count(id :: String.t()) :: :ok

  @doc """
  Duplicates a filter set with a new name.

  ## Parameters
  - `id`: Source filter set ID
  - `new_name`: Name for the duplicate
  - `user_id`: User creating the duplicate

  ## Returns
  - `{:ok, filter_set}` on success
  - `{:error, :not_found}` if source not found
  - `{:error, :unauthorized}` if user lacks access to source
  """
  @callback duplicate_filter_set(id :: String.t(), new_name :: String.t(), user_id :: String.t()) :: 
    {:ok, map()} | {:error, atom()}
end