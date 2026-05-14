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
          required(:description) => String.t() | nil,
          required(:scope) => String.t() | nil,
          required(:operation) => String.t() | nil,
          required(:capability) => String.t() | nil,
          required(:icon) => String.t() | nil,
          required(:status) => String.t(),
          required(:disabled?) => boolean(),
          required(:hidden?) => boolean(),
          required(:destructive?) => boolean(),
          required(:requires_confirmation?) => boolean(),
          required(:confirmation) => map(),
          required(:confirmation_message) => String.t() | nil,
          required(:reason) => String.t() | nil,
          required(:links) => map(),
          required(:endpoints) => map(),
          required(:preview_link) => String.t() | nil,
          required(:apply_link) => String.t() | nil,
          required(:attrs) => map(),
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
  Merges a decision extracted from an action preview/apply result.

  Successful preview/apply payloads usually carry `capability_decision`; errors
  can be converted into disabled decisions with their validation reason.
  """
  @spec put_result_decision(map(), term(), term()) :: map()
  def put_result_decision(decisions, action_id, result) when is_map(decisions) do
    Map.put(decisions, normalize_id(action_id), decision_from_result(result))
  end

  @doc """
  Converts a preview/apply result into normalized decision metadata.
  """
  @spec decision_from_result(term()) :: map()
  def decision_from_result({:ok, payload}), do: decision_from_result(payload)

  def decision_from_result({:error, {:validation_error, message, details}}) do
    details = map_or_empty(details)

    %{
      "status" => "disabled",
      "reason" => message,
      "code" => map_value(details, :code),
      "metadata" => details
    }
    |> compact_decision()
  end

  def decision_from_result({:error, :not_found}) do
    %{
      "status" => "disabled",
      "reason" => "Action target was not found.",
      "code" => "not_found"
    }
  end

  def decision_from_result({:error, reason}) do
    %{
      "status" => "disabled",
      "reason" => inspect(reason)
    }
  end

  def decision_from_result(payload) when is_map(payload) do
    payload
    |> result_capability_decision()
    |> normalize_decision("enabled")
  end

  def decision_from_result(_payload), do: normalize_decision(:enabled, "enabled")

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

  @doc """
  Counts visible action items by normalized status.
  """
  @spec status_counts([action_item()]) :: map()
  def status_counts(actions) when is_list(actions) do
    actions
    |> Enum.reduce(%{"enabled" => 0, "disabled" => 0}, fn action, counts ->
      status =
        action
        |> map_value(:status, "enabled")
        |> normalize_status()

      Map.update(counts, status, 1, &(&1 + 1))
    end)
  end

  @doc """
  Groups visible action items by scope, using `"unscoped"` when no scope exists.
  """
  @spec by_scope([action_item()]) :: map()
  def by_scope(actions) when is_list(actions) do
    Enum.group_by(actions, fn action ->
      action
      |> map_value(:scope)
      |> normalize_optional_id()
      |> Kernel.||("unscoped")
    end)
  end

  @doc """
  Builds a portable action request template for preview/apply/availability calls.
  """
  @spec request_template(map(), keyword()) :: map()
  def request_template(action, opts \\ []) when is_map(action) do
    target = Keyword.get(opts, :target, %{"id" => ""})

    %{
      "action" => action |> map_value(:id) |> normalize_id(),
      "target" => SelectoComponents.QueryContract.json_safe(target)
    }
    |> maybe_put("dry_run", Keyword.get(opts, :dry_run))
    |> maybe_put("confirmed", Keyword.get(opts, :confirmed))
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
      description: action |> map_value(:description) |> normalize_optional_id(),
      scope: action |> map_value(:scope) |> normalize_optional_id(),
      operation: action_operation(action),
      capability: action |> map_value(:capability) |> normalize_optional_id(),
      icon: action |> map_value(:icon) |> normalize_optional_id(),
      status: status,
      disabled?: status == "disabled",
      hidden?: status == "hidden",
      destructive?: destructive_action?(action),
      requires_confirmation?: requires_confirmation?(action),
      confirmation: action_confirmation(action),
      confirmation_message: action_confirmation_message(action),
      reason: map_value(decision, :reason),
      links: action_links(action),
      endpoints: action_endpoints(action),
      preview_link: action_link(action, "preview"),
      apply_link: action_link(action, "apply"),
      attrs: action_attrs(action, status),
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

  defp action_link(action, rel) do
    action
    |> action_links()
    |> map_value(rel)
    |> link_href()
    |> normalize_optional_id()
  end

  defp action_endpoints(action) do
    action
    |> action_links()
    |> Enum.reduce(%{}, fn {rel, link}, endpoints ->
      rel = normalize_id(rel)

      case action_endpoint(rel, link) do
        nil -> endpoints
        endpoint -> Map.put(endpoints, rel, endpoint)
      end
    end)
  end

  defp action_endpoint(rel, link) do
    href = link_href(link) |> normalize_optional_id()

    if href do
      %{
        "href" => href,
        "method" => link_method(link),
        "rel" => rel
      }
    end
  end

  defp link_href(link) when is_map(link) do
    map_value(link, :href) ||
      map_value(link, :url) ||
      map_value(link, :path)
  end

  defp link_href(link), do: link

  defp link_method(link) when is_map(link) do
    link
    |> map_value(:method, "POST")
    |> normalize_id()
    |> String.upcase()
  end

  defp link_method(_link), do: "POST"

  defp action_attrs(action, status) do
    %{
      "data-action-id" => action |> map_value(:id) |> normalize_id(),
      "data-action-status" => status,
      "data-action-scope" => action |> map_value(:scope) |> normalize_optional_id(),
      "data-action-capability" => action |> map_value(:capability) |> normalize_optional_id(),
      "data-action-operation" => action_operation(action),
      "data-action-confirmation" => requires_confirmation?(action),
      "data-action-destructive" => destructive_action?(action)
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp destructive_action?(action) do
    presentation = action |> map_value(:presentation, %{}) |> map_or_empty()
    confirmation = action |> map_value(:confirmation, %{}) |> map_or_empty()

    truthy?(map_value(action, :destructive)) ||
      truthy?(map_value(presentation, :destructive)) ||
      truthy?(map_value(confirmation, :destructive)) ||
      action_operation(action) in ["delete", "soft_delete"]
  end

  defp requires_confirmation?(action) do
    confirmation = action_confirmation(action)

    truthy?(map_value(action, :requires_confirmation)) ||
      truthy?(map_value(confirmation, :required)) ||
      truthy?(map_value(confirmation, :enabled))
  end

  defp action_confirmation(action) do
    action
    |> map_value(:confirmation, %{})
    |> map_or_empty()
  end

  defp action_confirmation_message(action) do
    action
    |> action_confirmation()
    |> map_value(:message)
    |> normalize_optional_id()
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

  defp result_capability_decision(payload) do
    map_value(payload, :capability_decision) ||
      payload
      |> map_value(:preview, %{})
      |> map_value(:capability_decision) ||
      payload
      |> map_value(:result, %{})
      |> map_value(:capability_decision)
  end

  defp compact_decision(decision) do
    decision
    |> Enum.reject(fn {_key, value} -> is_nil(value) or value == %{} end)
    |> Map.new()
  end

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

  defp map_value(map, key, default) when is_map(map) and is_binary(key),
    do: Map.get(map, key, default)

  defp map_value(_map, _key, default), do: default

  defp map_or_empty(map) when is_map(map), do: map
  defp map_or_empty(_value), do: %{}

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp truthy?(value) when value in [true, "true", "1", 1, true, :yes], do: true
  defp truthy?(_value), do: false
end
