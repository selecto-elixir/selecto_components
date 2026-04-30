defmodule SelectoComponents.QueryContract do
  @moduledoc """
  Components-facing adapter for Selecto query contracts.

  This module keeps SelectoComponents from walking raw domain internals when it
  needs query metadata for tooling, documentation, or future AI-facing surfaces.
  It delegates the actual normalization and projection work to core Selecto.
  """

  alias Selecto.Domain

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
end
