defmodule SelectoComponents.CapabilityGate do
  @moduledoc """
  Small host-owned capability gate for component-managed actions.

  Components own UX and event routing, but hosts own policy truth. This helper
  normalizes the common resolver call shape so exports, schedules, published
  views, and other component writes can refuse work before side effects happen.
  """

  alias SelectoComponents.QueryContract

  @doc """
  Authorizes a component operation.

  If no resolver is assigned, the operation is allowed for backwards
  compatibility. Hosts can pass `:resolver`, `:actor`, `:tenant`, `:domain`,
  `:target`, `:context`, or `:metadata` in opts, or assign matching
  `:capability_*` values on the socket.
  """
  def authorize(socket, capability, operation, opts \\ []) do
    case resolver(socket, opts) do
      nil ->
        :ok

      resolver ->
        socket
        |> request(capability, operation, opts)
        |> call_resolver(resolver, opts)
        |> normalize_decision(capability, operation)
    end
  end

  defp request(socket, capability, operation, opts) do
    Selecto.Capabilities.request(
      actor: option_or_assign(socket, opts, :actor, :capability_actor),
      tenant: option_or_assign(socket, opts, :tenant, :capability_tenant),
      domain: option_or_assign(socket, opts, :domain, :capability_domain),
      capability: capability,
      operation: operation,
      target: Keyword.get(opts, :target, %{}),
      context: context(socket, opts),
      metadata: Keyword.get(opts, :metadata, %{})
    )
  end

  defp resolver(socket, opts) do
    Keyword.get(opts, :resolver) ||
      assign(socket, :capability_resolver) ||
      nested_resolver(assign(socket, :row_action_availability_opts)) ||
      nested_resolver(assign(socket, :export_capability_opts))
  end

  defp nested_resolver(opts) when is_list(opts), do: Keyword.get(opts, :capability_resolver)
  defp nested_resolver(_opts), do: nil

  defp option_or_assign(socket, opts, option_key, assign_key) do
    Keyword.get(opts, option_key, assign(socket, assign_key))
  end

  defp context(socket, opts) do
    socket
    |> assign(:capability_context, %{})
    |> map_or_empty()
    |> Map.merge(%{
      surface: Keyword.get(opts, :surface, :selecto_components),
      path: assign(socket, :path) || assign(socket, :my_path),
      view_mode: view_mode(socket)
    })
    |> Map.merge(Keyword.get(opts, :context, %{}))
  end

  defp view_mode(socket) do
    case assign(socket, :view_config) do
      %{view_mode: view_mode} -> view_mode
      %{"view_mode" => view_mode} -> view_mode
      _view_config -> assign(socket, :applied_view)
    end
  end

  defp call_resolver(request, resolver, _opts) when is_function(resolver, 1) do
    resolver.(request)
  rescue
    error -> {:error, error}
  end

  defp call_resolver(request, resolver, opts) when is_function(resolver, 2) do
    resolver_context = Keyword.get(opts, :resolver_context, %{})
    resolver.(request, resolver_context)
  rescue
    error -> {:error, error}
  end

  defp call_resolver(_request, _resolver, _opts), do: :ok

  defp normalize_decision({:ok, decision}, capability, operation),
    do: normalize_decision(decision, capability, operation)

  defp normalize_decision({:error, reason}, capability, operation) do
    denied("Capability check failed.", %{
      capability: capability,
      operation: operation,
      reason: inspect(reason)
    })
  end

  defp normalize_decision(
         %Selecto.Capabilities.Decision{status: :allow},
         _capability,
         _operation
       ),
       do: :ok

  defp normalize_decision(%Selecto.Capabilities.Decision{} = decision, capability, operation) do
    denied(decision.user_message || "Operation is not allowed.", %{
      capability: capability,
      operation: operation,
      code: decision.reason_code,
      status: decision.status,
      visibility: decision.visibility,
      audit_reason: decision.audit_reason,
      metadata: decision.metadata
    })
  end

  defp normalize_decision(decision, capability, operation) when is_map(decision) do
    status = map_value(decision, :status)
    visibility = map_value(decision, :visibility)

    if status in [:allow, "allow", :enabled, "enabled"] or
         (is_nil(status) and visibility in [:enabled, "enabled"]) do
      :ok
    else
      denied(
        map_value(decision, :reason) || map_value(decision, :user_message) ||
          "Operation is not allowed.",
        %{
          capability: map_value(decision, :capability, capability),
          operation: operation,
          code: map_value(decision, :code) || map_value(decision, :reason_code),
          status: status,
          visibility: visibility,
          reason: map_value(decision, :reason),
          audit: map_value(decision, :audit),
          metadata: map_value(decision, :metadata, %{})
        }
      )
    end
  end

  defp normalize_decision(false, capability, operation) do
    denied("Operation is not allowed.", %{capability: capability, operation: operation})
  end

  defp normalize_decision(_decision, _capability, _operation), do: :ok

  defp denied(message, details) do
    {:error,
     {:capability_denied, message,
      details
      |> QueryContract.json_safe()
      |> map_or_empty()}}
  end

  defp assign(socket, key, default \\ nil) do
    socket
    |> Map.get(:assigns, %{})
    |> Map.get(key, default)
  end

  defp map_value(map, key, default \\ nil)

  defp map_value(map, key, default) when is_map(map),
    do: Map.get(map, key, Map.get(map, to_string(key), default))

  defp map_value(_map, _key, default), do: default

  defp map_or_empty(value) when is_map(value), do: value
  defp map_or_empty(_value), do: %{}
end
