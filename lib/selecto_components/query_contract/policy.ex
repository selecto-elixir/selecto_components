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

    if capability_resolver?(resolver) do
      {fields, field_decisions} =
        contract
        |> map_value(:fields, [])
        |> list_or_empty()
        |> project_entries(:field, opts)

      {choice_sources, choice_source_decisions} =
        contract
        |> map_value(:choice_sources, [])
        |> list_or_empty()
        |> project_entries(:choice_source, opts)

      {fields, field_choice_source_decisions, hidden_choice_source_field_ids} =
        project_field_choice_sources(fields, choice_source_decisions, opts)

      hidden_field_ids =
        field_decisions
        |> Enum.filter(&(map_value(&1, :status) == "hidden"))
        |> Enum.map(&map_value(&1, :id))
        |> Enum.concat(hidden_choice_source_field_ids)
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

      decisions =
        field_decisions ++
          choice_source_decisions ++ field_choice_source_decisions ++ filter_decisions

      {functions, function_decisions} =
        contract
        |> map_value(:functions, [])
        |> list_or_empty()
        |> project_entries(:function, opts)

      {query_members, query_member_decisions} =
        contract
        |> map_value(:query_members, %{})
        |> project_query_members(opts)

      {published_views, published_view_decisions} =
        contract
        |> map_value(:published_views, [])
        |> list_or_empty()
        |> project_entries(:published_view, opts)

      {context, context_decisions} =
        contract
        |> map_value(:context, %{})
        |> project_context(opts)

      decisions =
        decisions ++
          function_decisions ++
          query_member_decisions ++
          published_view_decisions ++
          context_decisions

      contract
      |> Map.put(:fields, fields)
      |> Map.put(:filters, filters)
      |> Map.put(:functions, functions)
      |> Map.put(:query_members, query_members)
      |> Map.put(:choice_sources, choice_sources)
      |> Map.put(:published_views, published_views)
      |> Map.put(:context, context)
      |> prune_field_choice_bindings(hidden_field_ids)
      |> prune_defaults(hidden_field_ids, hidden_filter_ids)
      |> put_policy_summary(decisions, opts)
    else
      contract
    end
  end

  def apply(contract, _opts), do: contract

  defp capability_resolver?(nil), do: false
  defp capability_resolver?(_resolver), do: true

  defp project_query_members(query_members, opts) when is_map(query_members) do
    Enum.reduce(query_members, {%{}, []}, fn {group, members}, {projected, decisions} ->
      {projected_members, member_decisions} =
        members
        |> list_or_empty()
        |> Enum.map(&put_entry_value(&1, :group, normalize_id(group)))
        |> project_entries(:query_member, opts)

      {put_entry_value(projected, group, projected_members), decisions ++ member_decisions}
    end)
  end

  defp project_query_members(_query_members, _opts), do: {%{}, []}

  defp project_entries(entries, kind, opts) do
    resolver = Keyword.get(opts, :capability_resolver)

    items =
      Enum.map(entries, fn entry ->
        capability = entry |> map_value(:capability) |> normalize_optional_id()

        if is_nil(capability) do
          {:plain, entry}
        else
          {:governed, entry, capability, entry_request(entry, kind, capability, opts)}
        end
      end)

    capability_decisions =
      resolver
      |> Selecto.Capabilities.decide_many(governed_requests(items),
        resolver_context: Keyword.get(opts, :resolver_context, %{})
      )
      |> Enum.map(&normalize_decision/1)

    Enum.reduce(items, {[], [], capability_decisions}, fn
      {:plain, entry}, {projected, decisions, remaining_decisions} ->
        {[entry | projected], decisions, remaining_decisions}

      {:governed, entry, capability, _request},
      {projected, decisions,
       [
         decision | remaining_decisions
       ]} ->
        decision_entry = decision_entry(entry, kind, capability, decision)

        case map_value(decision_entry, :status) do
          "hidden" ->
            {projected, [decision_entry | decisions], remaining_decisions}

          "disabled" ->
            {[disable_entry(entry, kind, decision_entry) | projected],
             [decision_entry | decisions], remaining_decisions}

          _enabled ->
            {[put_decision(entry, decision_entry) | projected], [decision_entry | decisions],
             remaining_decisions}
        end

      {:governed, entry, capability, _request}, {projected, decisions, []} ->
        decision_entry =
          decision_entry(entry, kind, capability, Selecto.Capabilities.deny(:missing_decision))

        {[disable_entry(entry, kind, decision_entry) | projected], [decision_entry | decisions],
         []}
    end)
    |> then(fn {projected, decisions, _remaining_decisions} ->
      {Enum.reverse(projected), Enum.reverse(decisions)}
    end)
  end

  defp governed_requests(items) do
    Enum.flat_map(items, fn
      {:governed, _entry, _capability, request} -> [request]
      {:plain, _entry} -> []
    end)
  end

  defp entry_decision(entry, kind, capability, opts) do
    opts
    |> Keyword.get(:capability_resolver)
    |> Selecto.Capabilities.decide(entry_request(entry, kind, capability, opts),
      resolver_context: Keyword.get(opts, :resolver_context, %{})
    )
    |> normalize_decision()
  end

  defp entry_request(entry, kind, capability, opts) do
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
  end

  defp project_field_choice_sources(fields, choice_source_decisions, opts) do
    choice_source_decisions_by_id =
      Map.new(choice_source_decisions, fn decision -> {map_value(decision, :id), decision} end)

    Enum.reduce(fields, {[], [], []}, fn field, {projected, decisions, hidden_field_ids} ->
      metadata = field |> map_value(:choice_source_metadata, %{}) |> map_or_empty()
      choice_source_id = choice_source_id(field, metadata)
      capability = metadata |> map_value(:capability) |> normalize_optional_id()

      if is_nil(capability) and is_nil(choice_source_id) do
        {[field | projected], decisions, hidden_field_ids}
      else
        {decision_entry, decisions} =
          case Map.fetch(choice_source_decisions_by_id, choice_source_id) do
            {:ok, decision_entry} ->
              {decision_entry, decisions}

            :error ->
              if is_nil(capability) do
                {nil, decisions}
              else
                decision =
                  entry_decision(
                    choice_source_entry(field, metadata, choice_source_id),
                    :choice_source,
                    capability,
                    opts
                  )

                decision_entry = decision_entry(metadata, :choice_source, capability, decision)
                {decision_entry, [decision_entry | decisions]}
              end
          end

        case map_value(decision_entry, :status, "enabled") do
          "hidden" ->
            {projected, decisions, [field |> map_value(:id) |> normalize_id() | hidden_field_ids]}

          "disabled" ->
            field =
              field
              |> disable_entry(:field, decision_entry)
              |> put_choice_source_decision(decision_entry, true)

            {[field | projected], decisions, hidden_field_ids}

          _enabled ->
            field = put_choice_source_decision(field, decision_entry, false)
            {[field | projected], decisions, hidden_field_ids}
        end
      end
    end)
    |> then(fn {projected, decisions, hidden_field_ids} ->
      {Enum.reverse(projected), Enum.reverse(decisions), Enum.reverse(hidden_field_ids)}
    end)
  end

  defp choice_source_id(field, metadata) do
    metadata
    |> map_value(:id)
    |> case do
      nil -> map_value(field, :choice_source)
      value -> value
    end
    |> normalize_optional_id()
  end

  defp choice_source_entry(field, metadata, choice_source_id) do
    metadata
    |> Map.put_new(:id, choice_source_id)
    |> Map.put_new("id", choice_source_id)
    |> Map.put_new(:field, map_value(field, :id))
    |> Map.put_new("field", map_value(field, :id))
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
  defp operation_for(:function, _entry), do: :query_function
  defp operation_for(:query_member, _entry), do: :query_member
  defp operation_for(:published_view, _entry), do: :published_view
  defp operation_for(:choice_source, _entry), do: :choice_source

  defp target_for(entry, kind) do
    entry_target =
      entry
      |> map_value(:capability_target, %{})
      |> map_or_empty()

    %{
      kind: kind,
      id: entry |> map_value(:id) |> normalize_id(),
      group: entry |> map_value(:group) |> normalize_optional_id(),
      field: entry |> map_value(:field) |> normalize_optional_id(),
      capability: entry |> map_value(:capability) |> normalize_optional_id()
    }
    |> Map.merge(entry_target)
    |> compact_map()
  end

  defp project_context(context, opts) do
    context = map_or_empty(context)

    {exports, export_decisions} =
      context
      |> map_value(:exports, [])
      |> list_or_empty()
      |> project_export_formats(opts)

    {context, exported_view_decisions} =
      project_context_toggle(
        Map.put(context, context_key(context, :exports), exports),
        :exported_views_enabled,
        "selecto.exported_views.manage",
        :create,
        opts
      )

    {context, scheduled_export_decisions} =
      project_context_toggle(
        context,
        :scheduled_exports_enabled,
        "selecto.scheduled_exports.manage",
        :create,
        opts
      )

    {context, export_decisions ++ exported_view_decisions ++ scheduled_export_decisions}
  end

  defp project_export_formats(formats, opts) do
    Enum.reduce(formats, {[], []}, fn format, {projected, decisions} ->
      format_id = normalize_id(format)

      decision =
        context_decision("selecto.exports.download", :export, %{format: format_id}, opts)

      decision_entry =
        context_decision_entry("exports", format_id, "selecto.exports.download", decision)

      case map_value(decision_entry, :status) do
        status when status in ["hidden", "disabled"] ->
          {projected, [decision_entry | decisions]}

        _enabled ->
          {[format | projected], [decision_entry | decisions]}
      end
    end)
    |> then(fn {projected, decisions} -> {Enum.reverse(projected), Enum.reverse(decisions)} end)
  end

  defp project_context_toggle(context, key, capability, operation, opts) do
    if truthy?(map_value(context, key, false)) do
      decision = context_decision(capability, operation, %{feature: normalize_id(key)}, opts)
      decision_entry = context_decision_entry("context", normalize_id(key), capability, decision)

      case map_value(decision_entry, :status) do
        status when status in ["hidden", "disabled"] ->
          {Map.put(context, context_key(context, key), false), [decision_entry]}

        _enabled ->
          {context, [decision_entry]}
      end
    else
      {context, []}
    end
  end

  defp context_decision(capability, operation, target, opts) do
    request =
      Selecto.Capabilities.request(
        actor: Keyword.get(opts, :actor),
        tenant: Keyword.get(opts, :tenant),
        domain: Keyword.get(opts, :domain),
        capability: capability,
        operation: operation,
        target: Map.put(target, :capability, capability),
        context:
          opts
          |> Keyword.get(:context, %{})
          |> map_or_empty()
          |> Map.merge(%{
            surface: Keyword.get(opts, :surface, :query_contract),
            kind: :context,
            id: Map.get(target, :format) || Map.get(target, :feature)
          }),
        metadata:
          opts
          |> Keyword.get(:metadata, %{})
          |> map_or_empty()
      )

    opts
    |> Keyword.get(:capability_resolver)
    |> Selecto.Capabilities.decide(request,
      resolver_context: Keyword.get(opts, :resolver_context, %{})
    )
    |> normalize_decision()
  end

  defp context_decision_entry(kind, id, capability, decision) do
    %{
      "kind" => kind,
      "id" => id,
      "capability" => capability,
      "status" => map_value(decision, :status, "enabled"),
      "reason" => map_value(decision, :reason),
      "code" => map_value(decision, :code)
    }
    |> compact_map()
  end

  defp context_key(context, key) do
    string_key = Atom.to_string(key)

    cond do
      Map.has_key?(context, key) -> key
      Map.has_key?(context, string_key) -> string_key
      true -> key
    end
  end

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
      "group" => entry |> map_value(:group) |> normalize_optional_id(),
      "capability" => capability,
      "status" => map_value(decision, :status, "enabled"),
      "reason" => map_value(decision, :reason),
      "code" => map_value(decision, :code)
    }
    |> compact_map()
  end

  defp put_decision(entry, decision_entry) do
    put_entry_value(entry, :capability_decision, decision_entry)
  end

  defp disable_entry(entry, :field, decision_entry) do
    entry
    |> put_decision(decision_entry)
    |> put_entry_value(:disabled, true)
    |> put_entry_value(:comparators, [])
    |> put_entry_value(:aggregate_functions, [])
    |> then(fn entry ->
      Enum.reduce(@field_surface_keys, entry, &put_entry_value(&2, String.to_atom(&1), false))
    end)
  end

  defp disable_entry(entry, :filter, decision_entry) do
    entry
    |> put_decision(decision_entry)
    |> put_entry_value(:disabled, true)
    |> put_entry_value(:comparators, [])
  end

  defp disable_entry(entry, :function, decision_entry) do
    entry
    |> put_decision(decision_entry)
    |> put_entry_value(:disabled, true)
    |> put_entry_value(:allowed_in, [])
  end

  defp disable_entry(entry, :query_member, decision_entry) do
    entry
    |> put_decision(decision_entry)
    |> put_entry_value(:disabled, true)
  end

  defp disable_entry(entry, :published_view, decision_entry) do
    entry
    |> put_decision(decision_entry)
    |> put_entry_value(:disabled, true)
  end

  defp disable_entry(entry, :choice_source, decision_entry) do
    entry
    |> put_decision(decision_entry)
    |> put_entry_value(:disabled, true)
  end

  defp put_choice_source_decision(field, decision_entry, disabled?) do
    metadata =
      field
      |> map_value(:choice_source_metadata, %{})
      |> map_or_empty()
      |> put_entry_value(:capability_decision, decision_entry)
      |> put_entry_value(:disabled, disabled?)

    put_entry_value(field, :choice_source_metadata, metadata)
  end

  defp put_entry_value(entry, key, value) when is_atom(key) do
    string_key = Atom.to_string(key)

    cond do
      Map.has_key?(entry, key) -> Map.put(entry, key, value)
      Map.has_key?(entry, string_key) -> Map.put(entry, string_key, value)
      string_keyed_entry?(entry) -> Map.put(entry, string_key, value)
      true -> Map.put(entry, key, value)
    end
  end

  defp string_keyed_entry?(entry) do
    Enum.any?(entry, fn {key, _value} -> is_binary(key) end)
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
