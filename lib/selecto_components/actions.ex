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
          required(:inputs) => [map()],
          required(:input_template) => map(),
          required(:required_inputs) => [String.t()],
          required(:variants) => [map()],
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
  - `:capability_resolver` supplies a host-owned resolver function invoked with a
    `%Selecto.Capabilities.Request{}` for actions that declare a capability
  - `:actor`, `:tenant`, `:domain`, and `:context` are copied into resolver requests
  - `:default_status` defaults to `"enabled"`
  """
  @spec available(term(), keyword()) :: [action_item()]
  def available(contract, opts \\ []) do
    scope = opts |> Keyword.get(:scope) |> normalize_optional_id()
    decisions = Keyword.get(opts, :decisions, %{})
    default_status = opts |> Keyword.get(:default_status, "enabled") |> normalize_status()

    contract
    |> action_entries()
    |> Enum.map(&action_item(&1, decisions, default_status, opts))
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
    inputs = Keyword.get(opts, :inputs, action_input_template(action))

    %{
      "action" => action |> map_value(:id) |> normalize_id(),
      "target" => SelectoComponents.QueryContract.json_safe(target)
    }
    |> maybe_put("inputs", empty_to_nil(SelectoComponents.QueryContract.json_safe(inputs)))
    |> maybe_put("dry_run", Keyword.get(opts, :dry_run))
    |> maybe_put("confirmed", Keyword.get(opts, :confirmed))
  end

  @doc """
  Normalizes one domain action for use by `ActionFormModal`.

  This is the bridge for host apps that already have a domain action contract
  and only need a Selecto Components form shell. `:endpoint_base` can be passed
  to derive standard preview/apply endpoints from the action id.
  """
  @spec form_action(map(), keyword()) :: action_item() | nil
  def form_action(action, opts \\ [])

  def form_action(action, opts) when is_map(action) do
    action =
      action
      |> map_or_empty()
      |> maybe_put_new_id(Keyword.get(opts, :id))
      |> put_endpoint_base(Keyword.get(opts, :endpoint_base))
      |> put_links(Keyword.get(opts, :links))

    decisions =
      case Keyword.get(opts, :decision) do
        nil -> %{}
        decision -> %{(action |> map_value(:id) |> normalize_id()) => decision}
      end

    available_opts =
      opts
      |> Keyword.put(:decisions, Keyword.get(opts, :decisions, decisions))
      |> Keyword.put(:default_status, Keyword.get(opts, :default_status, "enabled"))

    %{"actions" => [action]}
    |> available(available_opts)
    |> List.first()
  end

  def form_action(_action, _opts), do: nil

  @doc """
  Builds assign data for `SelectoComponents.Modal.ActionFormModal`.
  """
  @spec form_assigns(map(), keyword()) :: map()
  def form_assigns(action, opts \\ []) when is_map(action) do
    %{
      target: Keyword.get(opts, :target, %{id: {:field, "id"}}),
      action: form_action(action, opts)
    }
  end

  @doc """
  Builds a detail-action config that opens a domain action as an action form.
  """
  @spec detail_action(map(), keyword()) :: map()
  def detail_action(action, opts \\ []) when is_map(action) do
    form_action = form_action(action, opts) || %{}
    label = map_value(form_action, :label, "Action")

    %{
      name: Keyword.get(opts, :name, map_value(form_action, :label)),
      description:
        Keyword.get(
          opts,
          :description,
          "Open #{map_value(form_action, :label, "this action")} as a Selecto Components form."
        ),
      type: :live_component,
      required_fields: Keyword.get(opts, :required_fields, [:id]),
      payload: %{
        title: Keyword.get(opts, :title, label <> " #" <> "{{id}}"),
        module: Keyword.get(opts, :module, SelectoComponents.Modal.ActionFormModal),
        size: Keyword.get(opts, :size, :lg),
        navigation_enabled: Keyword.get(opts, :navigation_enabled, true),
        assigns: %{
          target: Keyword.get(opts, :target, %{id: {:field, "id"}}),
          action: form_action
        }
      }
    }
  end

  @doc """
  Builds a map of generated detail-action configs for all visible actions.
  """
  @spec detail_actions(term(), keyword()) :: map()
  def detail_actions(contract, opts \\ []) do
    prefix = opts |> Keyword.get(:id_prefix, "action_form_") |> normalize_id()

    contract
    |> action_entries()
    |> Enum.flat_map(fn action ->
      case form_action(action, opts) do
        nil -> []
        form_action -> [{prefix <> form_action.id, detail_action(form_action.contract, opts)}]
      end
    end)
    |> Enum.reject(fn {_id, config} -> is_nil(get_in(config, [:payload, :assigns, :action])) end)
    |> Map.new()
  end

  @doc """
  Builds generated action-form configs for bulk action surfaces.

  This mirrors `detail_actions/2`, but filters to domain actions whose
  normalized scope is `"bulk"` or whose row action contract explicitly opts
  into batching with `bulk: true` or `bulk: %{enabled: true}`. It defaults the
  target template to selected row ids. The returned configs intentionally use
  the same modal payload shape so hosts can route bulk preview/apply through
  `ActionFormHost`.
  """
  @spec bulk_actions(term(), keyword()) :: map()
  def bulk_actions(contract, opts \\ []) do
    opts =
      opts
      |> Keyword.put_new(:id_prefix, "bulk_action_form_")
      |> Keyword.put_new(:required_fields, [])
      |> Keyword.put_new(:target, %{ids: {:selection, "ids"}})

    prefix = opts |> Keyword.fetch!(:id_prefix) |> normalize_id()

    contract
    |> action_entries()
    |> Enum.flat_map(fn action ->
      action
      |> action_for_bulk_surface()
      |> case do
        nil ->
          []

        action ->
          case form_action(action, opts) do
            %{scope: "bulk"} = form_action ->
              config_opts = Keyword.put_new(opts, :title, form_action.label)
              [{prefix <> form_action.id, detail_action(form_action.contract, config_opts)}]

            _other ->
              []
          end
      end
    end)
    |> Enum.reject(fn {_id, config} -> is_nil(get_in(config, [:payload, :assigns, :action])) end)
    |> Map.new()
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

  defp action_for_bulk_surface(action) do
    scope =
      action
      |> map_value(:scope)
      |> normalize_optional_id()

    cond do
      scope == "bulk" ->
        action

      bulk_enabled?(map_value(action, :bulk)) ->
        action
        |> map_or_empty()
        |> Map.put(:scope, :bulk)
        |> Map.put("scope", "bulk")

      true ->
        nil
    end
  end

  defp bulk_enabled?(true), do: true
  defp bulk_enabled?("true"), do: true
  defp bulk_enabled?(1), do: true
  defp bulk_enabled?("1"), do: true

  defp bulk_enabled?(%{} = bulk_config) do
    bulk_config
    |> map_value(:enabled)
    |> bulk_enabled?()
  end

  defp bulk_enabled?(_bulk_config), do: false

  defp maybe_put_new_id(action, nil), do: action
  defp maybe_put_new_id(action, id), do: Map.put_new(action, "id", normalize_id(id))

  defp put_endpoint_base(action, nil), do: action

  defp put_endpoint_base(action, endpoint_base) do
    action_id = action |> map_value(:id) |> normalize_id()
    endpoint_base = endpoint_base |> normalize_id() |> String.trim_trailing("/")

    generated_links =
      if action_id == "" or endpoint_base == "" do
        %{}
      else
        %{
          "preview" => "#{endpoint_base}/#{action_id}/preview",
          "apply" => "#{endpoint_base}/#{action_id}/apply"
        }
      end

    put_links(action, generated_links)
  end

  defp put_links(action, nil), do: action

  defp put_links(action, links) when is_map(links) do
    current_links =
      action
      |> map_value(:links, %{})
      |> map_or_empty()
      |> stringify_map_keys()

    Map.put(action, "links", Map.merge(links, current_links))
  end

  defp put_links(action, _links), do: action

  defp action_item(action, decisions, default_status, opts) do
    action = SelectoComponents.QueryContract.json_safe(map_or_empty(action))
    decision = availability_decision(action, decisions, default_status, opts)
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
      inputs: action_inputs(action),
      input_template: action_input_template(action),
      required_inputs: action_required_inputs(action),
      variants: action_variants(action),
      reason: map_value(decision, :reason),
      links: action_links(action),
      endpoints: action_endpoints(action),
      preview_link: action_link(action, "preview"),
      apply_link: action_link(action, "apply"),
      attrs: action_attrs(action, status),
      contract: action
    }
  end

  defp availability_decision(action, decisions, default_status, opts) do
    explicit_decision = explicit_decision_for(action, decisions)
    resolver_decision = resolver_decision_for(action, opts)

    explicit_decision
    |> merge_resolver_decision(resolver_decision)
    |> normalize_decision(default_status)
  end

  defp explicit_decision_for(action, decisions) do
    action_id = action |> map_value(:id) |> normalize_id()
    capability = action |> map_value(:capability) |> normalize_optional_id()

    map_lookup(decisions, action_id) ||
      map_lookup(decisions, capability) ||
      map_value(action, :capability_decision)
  end

  defp resolver_decision_for(action, opts) do
    capability = action |> map_value(:capability) |> normalize_optional_id()
    resolver = Keyword.get(opts, :capability_resolver)

    cond do
      is_nil(capability) ->
        nil

      is_nil(resolver) ->
        nil

      true ->
        Selecto.Capabilities.decide(resolver, capability_request(action, opts),
          resolver_context: Keyword.get(opts, :resolver_context, %{})
        )
    end
  end

  defp capability_request(action, opts) do
    capability = action |> map_value(:capability) |> normalize_id()

    Selecto.Capabilities.request(
      actor: Keyword.get(opts, :actor),
      tenant: Keyword.get(opts, :tenant),
      domain: Keyword.get(opts, :domain),
      capability: capability,
      operation:
        Keyword.get(opts, :operation) ||
          action_operation(action) ||
          :execute_action,
      target: Keyword.get(opts, :target, %{}),
      context:
        opts
        |> Keyword.get(:context, %{})
        |> map_or_empty()
        |> Map.merge(%{
          action_id: action |> map_value(:id) |> normalize_id(),
          action_scope: action |> map_value(:scope) |> normalize_optional_id(),
          surface: Keyword.get(opts, :surface, :components)
        }),
      metadata:
        opts
        |> Keyword.get(:metadata, %{})
        |> map_or_empty()
    )
  end

  defp merge_resolver_decision(nil, nil), do: nil
  defp merge_resolver_decision(explicit_decision, nil), do: explicit_decision
  defp merge_resolver_decision(nil, resolver_decision), do: resolver_decision

  defp merge_resolver_decision(explicit_decision, resolver_decision) do
    explicit = normalize_decision(explicit_decision, "enabled")
    resolver = normalize_decision(resolver_decision, "enabled")

    case normalize_status(map_value(resolver, :status)) do
      "enabled" -> explicit
      _status -> Map.merge(explicit, resolver)
    end
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

  defp action_inputs(action) do
    action
    |> map_value(:inputs, [])
    |> normalize_input_entries()
  end

  defp action_variants(action) do
    action
    |> map_value(:variants, [])
    |> normalize_variant_entries()
  end

  defp normalize_input_entries(inputs) when is_list(inputs) do
    inputs
    |> Enum.map(&map_or_empty/1)
    |> Enum.reject(&(&1 == %{}))
  end

  defp normalize_input_entries(inputs) when is_map(inputs) do
    inputs
    |> Enum.map(fn {id, input} ->
      input
      |> map_or_empty()
      |> Map.put_new("id", normalize_id(id))
    end)
  end

  defp normalize_input_entries(_inputs), do: []

  defp normalize_variant_entries(variants) when is_list(variants) do
    variants
    |> Enum.map(fn variant ->
      variant = map_or_empty(variant)
      Map.update(variant, "inputs", [], &normalize_input_entries/1)
    end)
    |> Enum.reject(&(&1 == %{}))
  end

  defp normalize_variant_entries(variants) when is_map(variants) do
    variants
    |> Enum.map(fn {id, variant} ->
      variant
      |> map_or_empty()
      |> Map.put_new("id", normalize_id(id))
      |> Map.update("inputs", [], &normalize_input_entries/1)
    end)
  end

  defp normalize_variant_entries(_variants), do: []

  defp action_input_template(action) do
    action
    |> action_inputs()
    |> input_template()
  end

  defp input_template(inputs) do
    inputs
    |> Enum.map(fn input ->
      {input |> map_value(:id) |> normalize_id(), input_default(input)}
    end)
    |> Enum.reject(fn {id, _value} -> id == "" end)
    |> Map.new()
  end

  defp input_default(input) do
    cond do
      present?(map_value(input, :default)) ->
        map_value(input, :default)

      input |> map_value(:type) |> normalize_id() == "collection" ->
        []

      true ->
        ""
    end
  end

  defp action_required_inputs(action) do
    action
    |> action_inputs()
    |> Enum.filter(&(map_value(&1, :required) |> truthy?()))
    |> Enum.map(&(map_value(&1, :id) |> normalize_id()))
    |> Enum.reject(&(&1 == ""))
  end

  defp normalize_decision(nil, default_status),
    do: %{"status" => normalize_status(default_status)}

  defp normalize_decision(status, _default_status) when is_atom(status) or is_binary(status) do
    %{"status" => normalize_status(status)}
  end

  defp normalize_decision(%Selecto.Capabilities.Decision{} = decision, _default_status) do
    %{
      "status" => decision_status(decision),
      "reason" => decision.user_message || decision.audit_reason,
      "code" => decision.reason_code,
      "effects" => decision.effects,
      "obligations" => decision.obligations,
      "metadata" => decision.metadata
    }
    |> compact_decision()
    |> SelectoComponents.QueryContract.json_safe()
  end

  defp normalize_decision(decision, default_status) when is_map(decision) do
    decision
    |> SelectoComponents.QueryContract.json_safe()
    |> normalize_capability_decision_map(default_status)
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
  defp normalize_status(status) when status in [:allow, "allow"], do: "enabled"
  defp normalize_status(status) when status in [:disabled, "disabled"], do: "disabled"
  defp normalize_status(status) when status in [:deny, "deny"], do: "disabled"
  defp normalize_status(status) when status in [:conditional, "conditional"], do: "disabled"
  defp normalize_status(status) when status in [:preview_only, "preview_only"], do: "disabled"
  defp normalize_status(status) when status in [:hidden, "hidden"], do: "hidden"
  defp normalize_status(status) when status in [:not_applicable, "not_applicable"], do: "hidden"
  defp normalize_status(_status), do: "enabled"

  defp decision_status(%Selecto.Capabilities.Decision{visibility: :hidden}), do: "hidden"
  defp decision_status(%Selecto.Capabilities.Decision{visibility: :disabled}), do: "disabled"
  defp decision_status(%Selecto.Capabilities.Decision{visibility: :preview_only}), do: "disabled"

  defp decision_status(%Selecto.Capabilities.Decision{status: status}),
    do: normalize_status(status)

  defp normalize_capability_decision_map(decision, default_status) do
    decision
    |> Map.update("status", normalize_status(default_status), &normalize_status/1)
    |> put_reason_from_capability_message()
  end

  defp put_reason_from_capability_message(decision) do
    reason =
      map_value(decision, :reason) ||
        map_value(decision, :user_message) ||
        map_value(decision, :audit_reason)

    maybe_put(decision, "reason", reason)
  end

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

  defp stringify_map_keys(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {normalize_id(key), value} end)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp empty_to_nil(value) when value in [%{}, []], do: nil
  defp empty_to_nil(value), do: value

  defp present?(value), do: not is_nil(value)

  defp truthy?(value) when value in [true, "true", "1", 1, true, :yes], do: true
  defp truthy?(_value), do: false
end
