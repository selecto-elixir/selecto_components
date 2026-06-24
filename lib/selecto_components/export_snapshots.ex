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
  Encode a safe Elixir term for persistence.
  """
  @spec encode_term(term()) :: binary()
  def encode_term(term) do
    blob = :erlang.term_to_binary(term, compressed: 6)

    case decode_term(blob) do
      {:ok, _term} ->
        blob

      {:error, :invalid_blob} ->
        raise ArgumentError,
              "cannot persist snapshot terms that require unsafe deserialization"
    end
  end

  @doc """
  Decode a previously encoded persistence blob.
  """
  @spec decode_term(binary() | nil) :: {:ok, term()} | {:error, :invalid_blob | :missing}
  def decode_term(nil), do: {:error, :missing}

  def decode_term(blob) when is_binary(blob) do
    term = :erlang.binary_to_term(blob, [:safe])

    case persistable_term?(term) do
      true -> {:ok, term}
      false -> {:error, :invalid_blob}
    end
  rescue
    _ -> {:error, :invalid_blob}
  end

  defp persistable_term?(term)
       when is_function(term) or is_pid(term) or is_port(term) or is_reference(term),
       do: false

  defp persistable_term?(term) when is_list(term), do: Enum.all?(term, &persistable_term?/1)

  defp persistable_term?(term) when is_tuple(term) do
    term
    |> Tuple.to_list()
    |> Enum.all?(&persistable_term?/1)
  end

  defp persistable_term?(term) when is_map(term) do
    Enum.all?(term, fn {key, value} -> persistable_term?(key) and persistable_term?(value) end)
  end

  defp persistable_term?(_term), do: true

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
