defmodule SelectoComponents.ExportSnapshots do
  @moduledoc """
  Shared snapshot and persistence helpers for export-oriented features.

  Exported views and scheduled exports both need the same persisted Selecto view
  snapshot shape. This module keeps that logic in one place so the query/view
  reconstruction contract stays consistent across features.
  """

  alias SelectoComponents.Form.ParamsState

  @snapshot_version 1

  @doc """
  Build a persisted snapshot payload from current SelectoComponents assigns.
  """
  @spec build_snapshot(map()) :: map()
  def build_snapshot(assigns) when is_map(assigns) do
    selecto = Map.fetch!(assigns, :selecto)

    %{
      version: @snapshot_version,
      params: ParamsState.view_config_to_params(Map.fetch!(assigns, :view_config)),
      views: Map.fetch!(assigns, :views),
      domain: Map.fetch!(selecto, :domain),
      postgrex_opts: sanitize_connection(Map.get(selecto, :postgrex_opts)),
      adapter: Map.get(selecto, :adapter),
      path: Map.get(assigns, :path) || Map.get(assigns, :my_path),
      context:
        Map.get(assigns, :scheduled_export_context) || Map.get(assigns, :exported_view_context) ||
          Map.get(assigns, :saved_view_context) || Map.get(assigns, :domain) ||
          Map.get(assigns, :path),
      current_user_id: Map.get(assigns, :current_user_id),
      tenant_context: Map.get(assigns, :tenant_context)
    }
  end

  @doc """
  Encode an arbitrary Elixir term for persistence.
  """
  @spec encode_term(term()) :: binary()
  def encode_term(term), do: :erlang.term_to_binary(term, compressed: 6)

  @doc """
  Decode a previously encoded persistence blob.
  """
  @spec decode_term(binary() | nil) :: {:ok, term()} | {:error, :invalid_blob | :missing}
  def decode_term(nil), do: {:error, :missing}

  def decode_term(blob) when is_binary(blob) do
    {:ok, :erlang.binary_to_term(blob, [:safe])}
  rescue
    _ -> {:error, :invalid_blob}
  end

  @doc false
  def sanitize_connection(opts) when is_list(opts) do
    Keyword.drop(opts, sensitive_keys())
  end

  def sanitize_connection(%{} = opts) do
    Map.drop(opts, sensitive_keys() ++ Enum.map(sensitive_keys(), &to_string/1))
  end

  def sanitize_connection(other), do: other

  defp sensitive_keys do
    [
      :password,
      :passfile,
      :ssl_key,
      :sslkey,
      :ssl_cert,
      :sslcert,
      :ssl_root_cert,
      :sslrootcert,
      :ssl_opts,
      :secret,
      :token,
      :api_key
    ]
  end
end
