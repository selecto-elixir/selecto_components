defmodule SelectoComponents.Tenant do
  @moduledoc """
  Tenant scoping helpers for saved views and filter sets contexts.

  This module provides a stable string key format that can be used to scope
  persistence adapters by tenant while preserving existing non-tenant behavior.
  """

  @default_namespace "tenant"

  @spec scoped_context(term(), map() | keyword() | String.t() | atom() | nil, keyword()) ::
          term()
  def scoped_context(context, tenant_context, opts \\ []) do
    case normalize_context(tenant_context) do
      nil ->
        context

      %{tenant_id: nil} ->
        context

      %{tenant_id: tenant_id} = normalized ->
        namespace =
          Keyword.get(opts, :namespace, Map.get(normalized, :namespace, @default_namespace))

        separator = Keyword.get(opts, :separator, ":")
        context_value = context_to_string(context)
        [to_string(namespace), to_string(tenant_id), context_value] |> Enum.join(separator)
    end
  end

  @spec normalize_context(map() | keyword() | String.t() | atom() | nil) :: map() | nil
  def normalize_context(nil), do: nil

  def normalize_context(tenant_id) when is_binary(tenant_id) or is_atom(tenant_id) do
    %{tenant_id: to_string(tenant_id), namespace: @default_namespace}
  end

  def normalize_context(context) when is_list(context) do
    context
    |> Enum.into(%{})
    |> normalize_context()
  end

  def normalize_context(context) when is_map(context) do
    %{
      tenant_id: map_get(context, :tenant_id) || map_get(context, :id),
      namespace: map_get(context, :namespace) || @default_namespace,
      prefix: map_get(context, :prefix)
    }
  end

  def normalize_context(_), do: nil

  defp map_get(map, key) when is_map(map) and is_atom(key) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp context_to_string(context) when is_binary(context), do: context
  defp context_to_string(context) when is_atom(context), do: Atom.to_string(context)
  defp context_to_string(context), do: inspect(context)
end
