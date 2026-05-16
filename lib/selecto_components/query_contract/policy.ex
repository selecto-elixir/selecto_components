defmodule SelectoComponents.QueryContract.Policy do
  @moduledoc """
  Applies host-owned capability decisions to query contract documents.

  Core Selecto describes which fields and filters exist. Host applications can
  then use this module to project actor-specific policy into that contract
  without teaching Selecto about roles or a particular authorization engine.
  """

  @field_surface_keys ~w(detail_selectable filterable sortable groupable aggregatable)

  @doc """
  Applies a capability resolver to field and filter entries in a query contract.

  Entries without a declared capability are left alone. Hidden decisions remove
  entries from the contract. Disabled decisions keep entries visible but remove
  the operations that would let a consumer use them.
  """
  @spec apply(map(), keyword()) :: map()
  def apply(contract, opts \\ [])

  def apply(contract, opts) when is_map(contract) do
    resolver = Keyword.get(opts, :capability_resolver)

    if is_function(resolver, 1) or is_function(resolver, 2) do
      {fields, field_decisions} =
        contract
        |> map_value(:fields, [])
        |> list_or_empty()
        |> project_entries(:field, opts)

      hidden_field_ids =
        field_decisions
        |> Enum.filter(&(map_value(&1, :status) == "hidden"))
        |> Enum.map(&map_value(&1, :id))
        |> MapSet.new()

      {filters, filter_decisions} =
        contract
        |> map_value(:filters, [])
        |> list_or_empty()
        |> project_entries(:filter, opts)

      hidden_filter_ids =
        filter_decisions
        |> Enum.filter(&(map_value(&1, :status) == "hidden"))
        |> Enum.map(&map_value(&1, :id))
        |> MapSet.new()

      decisions = field_decisions ++ filter_decisions

      contract
      |> Map.put(:fields, fields)
      |> Map.put(:filters, filters)
      |> prune_field_choice_bindings(hidden_field_ids)
      |> prune_defaults(hidden_field_ids, hidden_filter_ids)
      |> put_policy_summary(decisions, opts)
    else
      contract
    end
  end

  def apply(contract, _opts), do: contract

  defp project_entries(entries, kind, opts) do
    Enum.reduce(entries, {[], []}, fn entry, {projected, decisions} ->
      capability = entry |> map_value(:capability) |> normalize_optional_id()

      if is_nil(capability) do
        {[entry | projected], decisions}
      else
        decision = entry_decision(entry, kind, capability, opts)
        decision_entry = decision_entry(entry, kind, capability, decision)

        case map_value(decision_entry, :status) do
          "hidden" ->
            {projected, [decision_entry | decisions]}

          "disabled" ->
            {[disable_entry(entry, kind, decision_entry) | projected],
             [decision_entry | decisions]}

          _enabled ->
            {[put_decision(entry, decision_entry) | projected], [decision_entry | decisions]}
        end
      end
    end)
    |> then(fn {projected, decisions} ->
      {Enum.reverse(projected), Enum.reverse(decisions)}
    end)
  end

  defp entry_decision(entry, kind, capability, opts) do
    request =
      Selecto.Capabilities.request(
        actor: Keyword.get(opts, :actor),
        tenant: Keyword.get(opts, :tenant),
        domain: Keyword.get(opts, :domain),
        capability: capability,
        operation: operation_for(kind, entry),
        target: target_for(entry, kind),
        context:
          opts
          |> Keyword.get(:context, %{})
          |> map_or_empty()
          |> Map.merge(%{
            surface: Keyword.get(opts, :surface, :query_contract),
            kind: kind,
            id: entry |> map_value(:id) |> normalize_id()
          }),
        metadata:
          opts
          |> Keyword.get(:metadata, %{})
          |> map_or_empty()
      )

    case Keyword.get(opts, :capability_resolver) do
      resolver when is_function(resolver, 1) ->
        resolver.(request)

      resolver when is_function(resolver, 2) ->
        resolver.(request, Keyword.get(opts, :resolver_context, %{}))
    end
    |> unwrap_decision()
    |> normalize_decision()
  end

  defp operation_for(:field, entry) do
    cond do
      truthy?(map_value(entry, :aggregatable)) -> :query_aggregate_field
      truthy?(map_value(entry, :groupable)) -> :query_group_field
      truthy?(map_value(entry, :filterable)) -> :query_filter_field
      true -> :query_select_field
    end
  end

  defp operation_for(:filter, _entry), do: :query_filter

  defp target_for(entry, kind) do
    %{
      kind: kind,
      id: entry |> map_value(:id) |> normalize_id(),
      field: entry |> map_value(:field) |> normalize_optional_id(),
      capability: entry |> map_value(:capability) |> normalize_optional_id()
    }
  end

  defp unwrap_decision({:ok, decision}), do: decision
  defp unwrap_decision({:error, reason}), do: %{status: :disabled, reason: inspect(reason)}
  defp unwrap_decision(decision), do: decision

  defp normalize_decision(%Selecto.Capabilities.Decision{} = decision) do
    %{
      "status" => decision_status(decision),
      "reason" => decision.user_message,
      "code" => decision.reason_code,
      "metadata" => decision.metadata
    }
    |> compact_map()
  end

  defp normalize_decision(%{} = decision) do
    status =
      decision
      |> map_value(:status, map_value(decision, :visibility, "enabled"))
      |> normalize_status()

    %{
      "status" => status,
      "reason" => map_value(decision, :reason) || map_value(decision, :user_message),
      "code" => map_value(decision, :code) || map_value(decision, :reason_code),
      "metadata" => map_value(decision, :metadata)
    }
    |> compact_map()
  end

  defp normalize_decision(true), do: %{"status" => "enabled"}
  defp normalize_decision(false), do: %{"status" => "disabled"}
  defp normalize_decision(:allow), do: %{"status" => "enabled"}
  defp normalize_decision(:deny), do: %{"status" => "disabled"}
  defp normalize_decision(:hidden), do: %{"status" => "hidden"}
  defp normalize_decision(nil), do: %{"status" => "enabled"}
  defp normalize_decision(_decision), do: %{"status" => "disabled"}

  defp decision_status(%Selecto.Capabilities.Decision{status: :allow}), do: "enabled"
  defp decision_status(%Selecto.Capabilities.Decision{visibility: :hidden}), do: "hidden"
  defp decision_status(%Selecto.Capabilities.Decision{status: :not_applicable}), do: "hidden"
  defp decision_status(%Selecto.Capabilities.Decision{}), do: "disabled"

  defp normalize_status(status) when status in [:enabled, :allow], do: "enabled"
  defp normalize_status(status) when status in [:disabled, :deny], do: "disabled"
  defp normalize_status(status) when status in [:hidden, :not_applicable], do: "hidden"
  defp normalize_status("allow"), do: "enabled"
  defp normalize_status("deny"), do: "disabled"
  defp normalize_status("not_applicable"), do: "hidden"
  defp normalize_status(status) when status in ["enabled", "disabled", "hidden"], do: status
  defp normalize_status(_status), do: "enabled"

  defp decision_entry(entry, kind, capability, decision) do
    %{
      "kind" => Atom.to_string(kind),
      "id" => entry |> map_value(:id) |> normalize_id(),
      "capability" => capability,
      "status" => map_value(decision, :status, "enabled"),
      "reason" => map_value(decision, :reason),
      "code" => map_value(decision, :code)
    }
    |> compact_map()
  end

  defp put_decision(entry, decision_entry) do
    Map.put(entry, :capability_decision, decision_entry)
  end

  defp disable_entry(entry, :field, decision_entry) do
    entry
    |> put_decision(decision_entry)
    |> Map.put(:disabled, true)
    |> Map.put(:comparators, [])
    |> Map.put(:aggregate_functions, [])
    |> then(fn entry ->
      Enum.reduce(@field_surface_keys, entry, &Map.put(&2, String.to_atom(&1), false))
    end)
  end

  defp disable_entry(entry, :filter, decision_entry) do
    entry
    |> put_decision(decision_entry)
    |> Map.put(:disabled, true)
    |> Map.put(:comparators, [])
  end

  defp prune_field_choice_bindings(contract, hidden_field_ids) do
    Map.update(contract, :field_choice_bindings, [], fn bindings ->
      bindings
      |> list_or_empty()
      |> Enum.reject(fn binding ->
        hidden_field_ids |> MapSet.member?(binding |> map_value(:field) |> normalize_id())
      end)
    end)
  end

  defp prune_defaults(contract, hidden_field_ids, hidden_filter_ids) do
    Map.update(contract, :defaults, %{}, fn defaults ->
      defaults
      |> map_or_empty()
      |> Map.update(:default_selected, [], &reject_ids(&1, hidden_field_ids))
      |> Map.update(:required_selected, [], &reject_ids(&1, hidden_field_ids))
      |> Map.update(:required_group_by, [], &reject_ids(&1, hidden_field_ids))
      |> Map.update(:required_order_by, [], &reject_order_by(&1, hidden_field_ids))
      |> Map.update(:required_filters, [], &reject_filters(&1, hidden_filter_ids))
    end)
  end

  defp reject_ids(values, hidden_ids) do
    values
    |> list_or_empty()
    |> Enum.reject(&MapSet.member?(hidden_ids, normalize_id(&1)))
  end

  defp reject_order_by(values, hidden_ids) do
    values
    |> list_or_empty()
    |> Enum.reject(fn
      {field, _dir} -> MapSet.member?(hidden_ids, normalize_id(field))
      %{} = item -> MapSet.member?(hidden_ids, item |> map_value(:field) |> normalize_id())
      field -> MapSet.member?(hidden_ids, normalize_id(field))
    end)
  end

  defp reject_filters(values, hidden_ids) do
    values
    |> list_or_empty()
    |> Enum.reject(fn
      %{} = item -> MapSet.member?(hidden_ids, item |> map_value(:filter) |> normalize_id())
      filter -> MapSet.member?(hidden_ids, normalize_id(filter))
    end)
  end

  defp put_policy_summary(contract, decisions, opts) do
    summary = %{
      applied: true,
      resolver: resolver_name(Keyword.get(opts, :capability_resolver)),
      decisions: decisions,
      counts:
        Enum.reduce(decisions, %{"enabled" => 0, "disabled" => 0, "hidden" => 0}, fn decision,
                                                                                     counts ->
          Map.update(counts, map_value(decision, :status, "enabled"), 1, &(&1 + 1))
        end)
    }

    Map.put(contract, :capability_policy, summary)
  end

  defp resolver_name({module, function}) when is_atom(module) and is_atom(function),
    do: "#{inspect(module)}.#{function}/2"

  defp resolver_name(fun) when is_function(fun),
    do: "function/#{:erlang.fun_info(fun, :arity) |> elem(1)}"

  defp resolver_name(_resolver), do: nil

  defp map_value(map, key, default \\ nil)

  defp map_value(map, key, default) when is_map(map) and is_atom(key) do
    Map.get(map, key, Map.get(map, Atom.to_string(key), default))
  end

  defp map_value(map, key, default) when is_map(map), do: Map.get(map, key, default)
  defp map_value(_map, _key, default), do: default

  defp map_or_empty(value) when is_map(value), do: value
  defp map_or_empty(_value), do: %{}

  defp list_or_empty(value) when is_list(value), do: value
  defp list_or_empty(_value), do: []

  defp normalize_optional_id(nil), do: nil
  defp normalize_optional_id(""), do: nil
  defp normalize_optional_id(value), do: normalize_id(value)

  defp normalize_id(value) when is_binary(value), do: value
  defp normalize_id(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_id(value), do: to_string(value)

  defp truthy?(value) when value in [true, "true", 1, "1"], do: true
  defp truthy?(_value), do: false

  defp compact_map(map) do
    map
    |> Enum.reject(fn {_key, value} -> is_nil(value) or value == %{} or value == [] end)
    |> Map.new()
  end
end
