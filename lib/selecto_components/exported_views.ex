defmodule SelectoComponents.ExportedViews do
  @moduledoc """
  Behavior and helpers for persisted exported views.

  Exported views are signed, iframe-friendly snapshots of a SelectoComponents
  view that can be embedded into dashboard-like environments.

  The persistence layer is intentionally app-owned. Host applications provide a
  module that implements this behavior, while SelectoComponents handles snapshot
  building, cache payload generation, signature verification, and management UI.
  """

  alias SelectoComponents.Form.ParamsState

  @typedoc "Persisted exported view record/struct"
  @type exported_view :: map()

  @typedoc "Opaque term blob persisted by the host app"
  @type term_blob :: binary()

  @callback list_exported_views(context :: term(), opts :: keyword()) :: [exported_view()]
  @callback get_exported_view_by_public_id(public_id :: String.t(), opts :: keyword()) ::
              exported_view() | nil
  @callback create_exported_view(attrs :: map(), opts :: keyword()) ::
              {:ok, exported_view()} | {:error, term()}
  @callback update_exported_view(exported_view(), attrs :: map(), opts :: keyword()) ::
              {:ok, exported_view()} | {:error, term()}
  @callback delete_exported_view(exported_view(), opts :: keyword()) ::
              {:ok, exported_view()} | {:error, term()}

  @snapshot_version 1
  @default_embed_path "/selecto/exported"

  @doc """
  Build the persisted snapshot payload from current SelectoComponents assigns.
  """
  @spec build_snapshot(map()) :: map()
  def build_snapshot(assigns) when is_map(assigns) do
    selecto = Map.fetch!(assigns, :selecto)

    %{
      version: @snapshot_version,
      params: ParamsState.view_config_to_params(Map.fetch!(assigns, :view_config)),
      views: Map.fetch!(assigns, :views),
      domain: Map.fetch!(selecto, :domain),
      postgrex_opts: Map.get(selecto, :postgrex_opts),
      adapter: Map.get(selecto, :adapter),
      path: Map.get(assigns, :path) || Map.get(assigns, :my_path),
      context:
        Map.get(assigns, :exported_view_context) || Map.get(assigns, :saved_view_context) ||
          Map.get(assigns, :domain) || Map.get(assigns, :path),
      current_user_id: Map.get(assigns, :current_user_id),
      tenant_context: Map.get(assigns, :tenant_context)
    }
  end

  @doc """
  Build attributes for `create_exported_view/2` from current assigns.
  """
  @spec build_create_attrs(map(), map()) :: map()
  def build_create_attrs(assigns, attrs) when is_map(assigns) and is_map(attrs) do
    snapshot = build_snapshot(assigns)

    ttl_hours =
      normalize_ttl_hours(Map.get(attrs, :cache_ttl_hours) || Map.get(attrs, "cache_ttl_hours"))

    name = normalize_name(Map.get(attrs, :name) || Map.get(attrs, "name"))

    ip_allowlist_text =
      normalize_optional_text(
        Map.get(attrs, :ip_allowlist_text) || Map.get(attrs, "ip_allowlist_text")
      )

    public_id = Map.get(attrs, :public_id) || Map.get(attrs, "public_id") || generate_public_id()

    %{
      name: name,
      context: snapshot.context,
      path: snapshot.path,
      view_type: Map.get(snapshot.params, "view_mode", "detail"),
      public_id: public_id,
      signature_version: 1,
      cache_ttl_hours: ttl_hours,
      ip_allowlist_text: ip_allowlist_text,
      snapshot_blob: encode_term(snapshot),
      cache_blob: nil,
      cache_generated_at: nil,
      cache_expires_at: nil,
      last_execution_time_ms: nil,
      last_row_count: nil,
      last_payload_bytes: nil,
      access_count: 0,
      last_accessed_at: nil,
      last_error: nil,
      disabled_at: nil,
      user_id: Map.get(assigns, :current_user_id)
    }
  end

  @doc """
  Encode an arbitrary Elixir term for persistence.
  """
  @spec encode_term(term()) :: term_blob()
  def encode_term(term), do: :erlang.term_to_binary(term, compressed: 6)

  @doc """
  Decode a previously encoded persistence blob.
  """
  @spec decode_term(term_blob() | nil) :: {:ok, term()} | {:error, :invalid_blob | :missing}
  def decode_term(nil), do: {:error, :missing}

  def decode_term(blob) when is_binary(blob) do
    {:ok, :erlang.binary_to_term(blob)}
  rescue
    _ -> {:error, :invalid_blob}
  end

  @doc """
  Fetch a field from a map/struct, supporting atom and string keys.
  """
  @spec field(map() | nil, atom(), term()) :: term()
  def field(record, key, default \\ nil)

  def field(nil, _key, default), do: default

  def field(record, key, default) when is_map(record) do
    Map.get(record, key, Map.get(record, Atom.to_string(key), default))
  end

  @doc """
  Return the configured cache TTL in seconds.
  """
  @spec ttl_seconds(map()) :: pos_integer()
  def ttl_seconds(view) do
    view
    |> field(:cache_ttl_hours, 3)
    |> normalize_ttl_hours()
    |> Kernel.*(3600)
  end

  @doc """
  Compute cache status from persisted timestamps.
  """
  @spec cache_status(map(), DateTime.t()) :: :disabled | :missing | :fresh | :stale | :error
  def cache_status(view, now \\ DateTime.utc_now()) do
    cond do
      not is_nil(field(view, :disabled_at)) ->
        :disabled

      is_binary(field(view, :last_error)) and is_nil(field(view, :cache_blob)) ->
        :error

      is_nil(field(view, :cache_blob)) or is_nil(field(view, :cache_expires_at)) ->
        :missing

      DateTime.compare(normalize_datetime(field(view, :cache_expires_at)), now) == :gt ->
        :fresh

      true ->
        :stale
    end
  end

  @doc """
  Return true when the exported view is disabled.
  """
  @spec disabled?(map()) :: boolean()
  def disabled?(view), do: not is_nil(field(view, :disabled_at))

  @doc """
  Extract and decode the persisted render cache payload.
  """
  @spec decode_cache_payload(map()) :: {:ok, map()} | {:error, :invalid_blob | :missing}
  def decode_cache_payload(view) do
    view
    |> field(:cache_blob)
    |> decode_term()
  end

  @doc """
  Extract and decode the persisted snapshot payload.
  """
  @spec decode_snapshot(map()) :: {:ok, map()} | {:error, :invalid_blob | :missing}
  def decode_snapshot(view) do
    view
    |> field(:snapshot_blob)
    |> decode_term()
  end

  @doc """
  Default mount path used by generated embed snippets.
  """
  @spec default_embed_path() :: String.t()
  def default_embed_path, do: @default_embed_path

  @doc """
  Generate a URL-safe public id.
  """
  @spec generate_public_id() :: String.t()
  def generate_public_id do
    18
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end

  @doc false
  def normalize_ttl_hours(value) when value in [3, 6, 12], do: value

  def normalize_ttl_hours(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {parsed, ""} -> normalize_ttl_hours(parsed)
      _ -> 3
    end
  end

  def normalize_ttl_hours(_value), do: 3

  @doc false
  def normalize_name(name) when is_binary(name) do
    name
    |> String.trim()
  end

  def normalize_name(_name), do: ""

  @doc false
  def normalize_optional_text(nil), do: nil

  def normalize_optional_text(value) when is_binary(value) do
    trimmed = String.trim(value)
    if trimmed == "", do: nil, else: trimmed
  end

  def normalize_optional_text(value), do: to_string(value) |> normalize_optional_text()

  @doc false
  def normalize_datetime(%DateTime{} = value), do: value

  def normalize_datetime(%NaiveDateTime{} = value) do
    DateTime.from_naive!(value, "Etc/UTC")
  end

  def normalize_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _offset} -> dt
      _ -> DateTime.utc_now()
    end
  end

  def normalize_datetime(_value), do: DateTime.utc_now()
end
