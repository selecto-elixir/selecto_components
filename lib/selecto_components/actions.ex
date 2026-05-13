defmodule SelectoComponents.Actions do
  @moduledoc """
  Components-facing helpers for domain action contracts.

  This module adapts Updato-style write contract `actions` into stable UI items
  without depending on `selecto_updato`. Callers can pass a write contract
  document and optional capability decisions from preview/apply responses.
  Hidden actions are removed, disabled actions are retained with reason
  metadata, and enabled actions carry their preview/apply links.
  """

  @type action_item :: %{
          required(:id) => String.t(),
          required(:label) => String.t(),
          required(:scope) => String.t() | nil,
          required(:operation) => String.t() | nil,
          required(:capability) => String.t() | nil,
          required(:status) => String.t(),
          required(:disabled?) => boolean(),
          required(:hidden?) => boolean(),
          required(:reason) => String.t() | nil,
          required(:links) => map(),
          required(:contract) => map()
        }

  @doc """
  Returns action items suitable for row/global/bulk action renderers.

  Options:

  - `:scope` filters actions to a scope such as `:row` or `"bulk"`
  - `:decisions` supplies `%{"action_id" => decision}` or `%{"capability" => decision}`
  - `:default_status` defaults to `"enabled"`
  """
  @spec available(term(), keyword()) :: [action_item()]
  def available(contract, opts \\ []) do
    scope = opts |> Keyword.get(:scope) |> normalize_optional_id()
    decisions = Keyword.get(opts, :decisions, %{})
    default_status = opts |> Keyword.get(:default_status, "enabled") |> normalize_status()

    contract
    |> action_entries()
    |> Enum.map(&action_item(&1, decisions, default_status))
    |> Enum.reject(& &1.hidden?)
    |> Enum.filter(fn item -> is_nil(scope) or item.scope == scope end)
  end

  @doc """
  Merges a new preview/apply capability decision into an existing decision map.
  """
  @spec put_decision(map(), term(), map()) :: map()
  def put_decision(decisions, action_id, decision) when is_map(decisions) and is_map(decision) do
    Map.put(decisions, normalize_id(action_id), normalize_decision(decision, "enabled"))
  end

  @doc """
  Returns the decision for an action entry from action id or capability id.
  """
  @spec decision_for(map(), map(), String.t()) :: map()
  def decision_for(action, decisions, default_status \\ "enabled") do
    action_id = action |> map_value(:id) |> normalize_id()
    capability = action |> map_value(:capability) |> normalize_optional_id()

    decision =
      map_lookup(decisions, action_id) ||
        map_lookup(decisions, capability) ||
        map_value(action, :capability_decision)

    normalize_decision(decision, default_status)
  end

  defp action_entries(contract) when is_map(contract) do
    case map_value(contract, :actions) do
      actions when is_list(actions) -> actions
      actions when is_map(actions) -> map_actions(actions)
      _ -> []
    end
  end

  defp action_entries(_contract), do: []

  defp map_actions(actions) do
    actions
    |> Enum.map(fn {id, action} ->
      action
      |> map_or_empty()
      |> Map.put_new(:id, id)
    end)
  end

  defp action_item(action, decisions, default_status) do
    action = SelectoComponents.QueryContract.json_safe(map_or_empty(action))
    decision = decision_for(action, decisions, default_status)
    status = normalize_status(map_value(decision, :status))

    %{
      id: action |> map_value(:id) |> normalize_id(),
      label: action_label(action),
      scope: action |> map_value(:scope) |> normalize_optional_id(),
      operation: action_operation(action),
      capability: action |> map_value(:capability) |> normalize_optional_id(),
      status: status,
      disabled?: status == "disabled",
      hidden?: status == "hidden",
      reason: map_value(decision, :reason),
      links: action_links(action),
      contract: action
    }
  end

  defp action_label(action) do
    map_value(action, :label) ||
      map_value(action, :name) ||
      action
      |> map_value(:id)
      |> normalize_id()
      |> String.replace("_", " ")
      |> String.capitalize()
  end

  defp action_operation(action) do
    action
    |> map_value(:execution, %{})
    |> map_value(:operation)
    |> normalize_optional_id()
  end

  defp action_links(action) do
    action
    |> map_value(:links, %{})
    |> map_or_empty()
  end

  defp normalize_decision(nil, default_status),
    do: %{"status" => normalize_status(default_status)}

  defp normalize_decision(status, _default_status) when is_atom(status) or is_binary(status) do
    %{"status" => normalize_status(status)}
  end

  defp normalize_decision(decision, default_status) when is_map(decision) do
    decision
    |> SelectoComponents.QueryContract.json_safe()
    |> Map.put_new("status", normalize_status(default_status))
  end

  defp normalize_decision(_decision, default_status), do: normalize_decision(nil, default_status)

  defp normalize_status(status) when status in [:enabled, "enabled"], do: "enabled"
  defp normalize_status(status) when status in [:disabled, "disabled"], do: "disabled"
  defp normalize_status(status) when status in [:hidden, "hidden"], do: "hidden"
  defp normalize_status(_status), do: "enabled"

  defp normalize_id(nil), do: ""
  defp normalize_id(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_id(value) when is_binary(value), do: value
  defp normalize_id(value), do: to_string(value)

  defp normalize_optional_id(nil), do: nil
  defp normalize_optional_id(""), do: nil
  defp normalize_optional_id(value), do: normalize_id(value)

  defp map_lookup(_map, nil), do: nil
  defp map_lookup(_map, ""), do: nil
  defp map_lookup(map, key) when is_map(map), do: Map.get(map, key, Map.get(map, to_string(key)))
  defp map_lookup(_map, _key), do: nil

  defp map_value(map, key, default \\ nil)

  defp map_value(map, key, default) when is_map(map) and is_atom(key),
    do: Map.get(map, key, Map.get(map, Atom.to_string(key), default))

  defp map_value(_map, _key, default), do: default

  defp map_or_empty(map) when is_map(map), do: map
  defp map_or_empty(_value), do: %{}
end
