defmodule SelectoComponents.QueryContract do
  @moduledoc """
  Components-facing adapter for Selecto query contracts.

  This module keeps SelectoComponents from walking raw domain internals when it
  needs query metadata for tooling, documentation, or future AI-facing surfaces.
  It delegates the actual normalization and projection work to core Selecto.
  """

  alias Selecto.Domain

  @query_contract_version 1

  @type result :: {:ok, map(), Selecto.Diagnostics.t()} | {:error, Selecto.Diagnostics.t()}

  @doc """
  Builds a constrained query contract from a domain-shaped input.

  Accepted inputs are:

  - an authored Selecto domain map
  - an already-normalized Selecto domain
  - a configured `%Selecto{}` or selecto-like map containing `:domain`
  """
  @spec build(term()) :: result()
  def build(input) do
    input
    |> query_contract_input()
    |> Domain.query_contract()
  end

  @doc """
  Alias for `build/1`.
  """
  @spec query_contract(term()) :: result()
  def query_contract(input), do: build(input)

  @doc """
  Builds a JSON-ready query contract document.

  The returned map has string keys and JSON-compatible values so callers can
  serve it directly from a future `query_contract.json` endpoint without leaking
  Elixir atoms or structs into the public artifact.
  """
  @spec json_document(term()) :: result()
  def json_document(input) do
    with {:ok, contract, diagnostics} <- build(input) do
      document =
        contract
        |> Map.put(:query_contract_version, @query_contract_version)
        |> json_safe()

      {:ok, document, diagnostics}
    end
  end

  @doc """
  Encodes the JSON-ready query contract document.
  """
  @spec encode_json(term(), keyword()) ::
          {:ok, String.t(), Selecto.Diagnostics.t()} | {:error, Selecto.Diagnostics.t()}
  def encode_json(input, opts \\ []) do
    with {:ok, document, diagnostics} <- json_document(input) do
      {:ok, Jason.encode!(document, opts), diagnostics}
    end
  end

  defp query_contract_input(
         %{
           schema_version: _schema_version,
           domain: %{},
           query: %{},
           projection: %{},
           sections: _sections
         } = normalized
       ) do
    normalized
  end

  defp query_contract_input(%Selecto{domain: domain}) when is_map(domain), do: domain

  defp query_contract_input(%{domain: domain}) when is_map(domain), do: domain

  defp query_contract_input(%{"domain" => domain}) when is_map(domain), do: domain

  defp query_contract_input(input), do: input

  defp json_safe(value) when is_map(value) do
    Map.new(value, fn {key, value} -> {json_key(key), json_safe(value)} end)
  end

  defp json_safe(value) when is_list(value), do: Enum.map(value, &json_safe/1)

  defp json_safe(value) when is_tuple(value) do
    value
    |> Tuple.to_list()
    |> json_safe()
  end

  defp json_safe(value) when is_atom(value) and value in [nil, true, false], do: value
  defp json_safe(value) when is_atom(value), do: Atom.to_string(value)
  defp json_safe(value) when is_binary(value), do: value
  defp json_safe(value) when is_number(value), do: value

  defp json_safe(value), do: inspect(value)

  defp json_key(value) when is_atom(value), do: Atom.to_string(value)
  defp json_key(value) when is_binary(value), do: value
  defp json_key(value), do: inspect(value)
end
