defmodule SelectoComponents.Form.ChoiceSourceLive do
  @moduledoc """
  LiveView-backed choice-source resolver support.

  The browser hook only supplies the choice-source id, field/value/search text,
  and paging hints. This module builds `Selecto.Domain.Choices` requests from
  socket-owned assigns so tenant, actor, and current Domain of Interest filters
  cannot be spoofed by API parameters.
  """

  alias Phoenix.LiveView.Socket
  alias Selecto.Domain.Choices
  alias Selecto.Domain.Choices.{OptionsResult, Result}
  alias SelectoComponents.QueryContract

  @default_limit 25
  @max_limit 100

  @scope_keys [:actor, :tenant, :record, :context, :metadata]
  @options_scope_keys @scope_keys ++ [:filters, :order_by]
  @membership_scope_keys @scope_keys ++ [:filters]

  @doc false
  @spec options_reply(map(), Socket.t()) :: map()
  def options_reply(params, %Socket{} = socket) when is_map(params) do
    with {:ok, choice_source_id} <- required_param(params, :choice_source),
         {:ok, input} <- domain_input(socket),
         {:ok, request_attrs} <- options_request_attrs(params, socket) do
      case safe_list_options(input, choice_source_id, request_attrs) do
        {:ok, %OptionsResult{} = result} ->
          result_json(result)

        {:error, %OptionsResult{} = result} ->
          result_json(result)

        {:error, error} ->
          error_reply(error)
      end
    else
      {:error, error} -> error_reply(error)
    end
  end

  @doc false
  @spec validate_reply(map(), Socket.t()) :: map()
  def validate_reply(params, %Socket{} = socket) when is_map(params) do
    with {:ok, choice_source_id} <- required_param(params, :choice_source),
         {:ok, field} <- required_param(params, :field),
         {:ok, raw_value} <- required_param(params, :value),
         {:ok, input} <- domain_input(socket),
         {:ok, value} <- parse_choice_value(raw_value, field, choice_source_id, socket),
         {:ok, request_attrs} <- membership_request_attrs(params, socket),
         :ok <-
           ensure_field_matches_choice_source(
             input,
             field,
             value,
             choice_source_id,
             request_attrs
           ) do
      request_attrs =
        Keyword.put(request_attrs, :resolver, assign(socket, :choice_source_membership_resolver))

      case safe_validate_choice(input, field, value, request_attrs) do
        {:ok, %Result{} = result} ->
          membership_json(result)

        {:error, %Result{} = result} ->
          membership_json(result)

        {:error, error} ->
          error_reply(error)
      end
    else
      {:error, error} -> error_reply(error)
    end
  end

  defp options_request_attrs(params, socket) do
    with {:ok, scope_attrs} <- scope_attrs(socket, :options) do
      base_attrs = [
        by: :choice_source,
        search: clean_search(param_value(params, :search)),
        limit: request_limit(param_value(params, :limit)),
        offset: request_offset(param_value(params, :offset)),
        resolver: assign(socket, :choice_source_options_resolver),
        filters: domain_of_interest_filters(socket),
        context: request_context(socket, :options, params),
        metadata: %{transport: :live_view}
      ]

      {:ok, merge_request_attrs(base_attrs, scope_attrs, @options_scope_keys)}
    end
  end

  defp membership_request_attrs(params, socket) do
    with {:ok, scope_attrs} <- scope_attrs(socket, :validate) do
      base_attrs = [
        filters: domain_of_interest_filters(socket),
        context: request_context(socket, :validate, params),
        metadata: %{transport: :live_view}
      ]

      {:ok, merge_request_attrs(base_attrs, scope_attrs, @membership_scope_keys)}
    end
  end

  defp domain_input(socket) do
    cond do
      is_map(assign(socket, :choice_source_domain)) ->
        {:ok, assign(socket, :choice_source_domain)}

      match?(%Selecto{}, assign(socket, :selecto)) ->
        {:ok, Selecto.domain(assign(socket, :selecto))}

      authored_domain?(assign(socket, :selecto)) ->
        {:ok, assign(socket, :selecto)}

      is_map(assign(socket, :selecto)) and is_map(map_value(assign(socket, :selecto), :domain)) ->
        {:ok, map_value(assign(socket, :selecto), :domain)}

      true ->
        {:error,
         error(
           :choice_source_domain_missing,
           "choice-source LiveView resolution requires :choice_source_domain or :selecto assign",
           [:selecto]
         )}
    end
  end

  defp authored_domain?(value) when is_map(value) do
    is_map(map_value(value, :source)) or is_map(map_value(value, :choice_sources))
  end

  defp authored_domain?(_value), do: false

  defp scope_attrs(socket, operation) do
    explicit_scope = assign(socket, :choice_source_scope)

    defaults =
      [
        actor: assign(socket, :choice_source_actor) || current_actor(socket),
        tenant: assign(socket, :choice_source_tenant) || current_tenant(socket)
      ]
      |> Keyword.reject(fn {_key, value} -> is_nil(value) end)

    with {:ok, resolved_scope} <- resolve_scope(explicit_scope, socket, operation) do
      {:ok, merge_request_attrs(defaults, resolved_scope, @options_scope_keys)}
    end
  end

  defp resolve_scope(nil, _socket, _operation), do: {:ok, []}

  defp resolve_scope(scope, _socket, _operation) when is_map(scope) or is_list(scope),
    do: {:ok, scope}

  defp resolve_scope(resolver, socket, operation) when is_function(resolver, 2) do
    resolver
    |> apply_scope_resolver([socket, operation])
    |> normalize_scope_result()
  end

  defp resolve_scope(resolver, socket, _operation) when is_function(resolver, 1) do
    resolver
    |> apply_scope_resolver([socket])
    |> normalize_scope_result()
  end

  defp resolve_scope(resolver, _socket, _operation) when is_function(resolver, 0) do
    resolver
    |> apply_scope_resolver([])
    |> normalize_scope_result()
  end

  defp resolve_scope(scope, _socket, _operation) do
    {:error,
     error(
       :invalid_choice_source_scope,
       "choice-source scope must be a map, keyword list, or resolver function",
       [:choice_source_scope],
       %{scope: inspect(scope)}
     )}
  end

  defp apply_scope_resolver(resolver, args), do: apply(resolver, args)

  defp normalize_scope_result({:ok, attrs}), do: normalize_scope_result(attrs)

  defp normalize_scope_result({:error, %{code: _code} = error}), do: {:error, error}

  defp normalize_scope_result({:error, reason}) do
    {:error,
     error(
       :choice_source_scope_failed,
       "choice-source scope resolver failed: #{inspect(reason)}",
       [:choice_source_scope]
     )}
  end

  defp normalize_scope_result(nil), do: {:ok, []}
  defp normalize_scope_result(attrs) when is_map(attrs) or is_list(attrs), do: {:ok, attrs}

  defp normalize_scope_result(attrs) do
    {:error,
     error(
       :invalid_choice_source_scope_result,
       "choice-source scope resolver must return a map, keyword list, {:ok, attrs}, or {:error, reason}",
       [:choice_source_scope],
       %{scope: inspect(attrs)}
     )}
  end

  defp domain_of_interest_filters(socket) do
    case assign(socket, :view_config) do
      %{filters: filters} when is_list(filters) -> filters
      %{"filters" => filters} when is_list(filters) -> filters
      _ -> []
    end
  end

  defp request_context(socket, operation, params) do
    base_context =
      socket
      |> assign(:choice_source_context)
      |> map_or_empty()

    operation_context =
      socket
      |> assign(:"choice_source_#{operation}_context")
      |> map_or_empty()

    runtime_context =
      %{
        transport: :live_view,
        operation: operation,
        choice_source: param_value(params, :choice_source),
        field: param_value(params, :field)
      }
      |> compact()

    base_context
    |> Map.merge(operation_context)
    |> Map.merge(runtime_context)
  end

  defp current_actor(socket) do
    current_scope = assign(socket, :current_scope)

    cond do
      not is_nil(assign(socket, :current_user)) ->
        assign(socket, :current_user)

      not is_nil(map_value(current_scope, :user)) ->
        map_value(current_scope, :user)

      not is_nil(assign(socket, :current_user_id)) ->
        assign(socket, :current_user_id)

      true ->
        nil
    end
  end

  defp current_tenant(socket) do
    current_scope = assign(socket, :current_scope)

    assign(socket, :current_tenant) ||
      assign(socket, :tenant) ||
      assign(socket, :tenant_id) ||
      map_value(current_scope, :tenant) ||
      map_value(current_scope, :tenant_id)
  end

  defp safe_list_options(input, choice_source_id, attrs) do
    Choices.list_options(input, choice_source_id, attrs)
  rescue
    exception ->
      {:error, error(:choice_source_resolver_failed, Exception.message(exception), [:resolver])}
  end

  defp safe_validate_choice(input, field, value, attrs) do
    Choices.validate_choice(input, field, value, attrs)
  rescue
    exception ->
      {:error, error(:choice_source_resolver_failed, Exception.message(exception), [:resolver])}
  end

  defp ensure_field_matches_choice_source(input, field, value, choice_source_id, request_attrs) do
    case Choices.request(input, field, value, request_attrs) do
      {:ok, request} ->
        if same_id?(request.choice_source, choice_source_id) do
          :ok
        else
          {:error,
           error(
             :choice_source_field_mismatch,
             "field #{inspect(field)} is bound to choice source #{inspect(request.choice_source)}",
             [:field],
             %{choice_source: choice_source_id, field_choice_source: request.choice_source}
           )}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  defp parse_choice_value(value, field, choice_source_id, socket) do
    case assign(socket, :choice_source_value_parser) do
      nil ->
        {:ok, value}

      parser when is_function(parser, 2) ->
        parser
        |> apply_value_parser([
          value,
          %{choice_source: choice_source_id, field: field, socket: socket}
        ])
        |> normalize_value_parser_result()

      parser when is_function(parser, 1) ->
        parser
        |> apply_value_parser([value])
        |> normalize_value_parser_result()

      parser ->
        {:error,
         error(
           :invalid_value_parser,
           "choice-source value parser must be a one- or two-arity function",
           [:value_parser],
           %{parser: inspect(parser)}
         )}
    end
  rescue
    exception ->
      {:error, error(:value_parser_failed, Exception.message(exception), [:value])}
  end

  defp apply_value_parser(parser, args), do: apply(parser, args)

  defp normalize_value_parser_result({:ok, value}), do: {:ok, value}
  defp normalize_value_parser_result({:error, %{code: _code} = error}), do: {:error, error}

  defp normalize_value_parser_result({:error, reason}) do
    {:error,
     error(
       :invalid_choice_value,
       "choice validation value is invalid: #{inspect(reason)}",
       [:value]
     )}
  end

  defp normalize_value_parser_result(value), do: {:ok, value}

  defp result_json(%OptionsResult{} = result) do
    request = result.request

    QueryContract.json_safe(%{
      status: result.status,
      reason_code: result.reason_code,
      choice_source: request && request.choice_source,
      domain: request && request.domain,
      field: request && request.field,
      search: request && request.search,
      limit: request && request.limit,
      offset: request && request.offset,
      total_count: result.total_count,
      next_cursor: result.next_cursor,
      options: result.options,
      metadata: result.metadata
    })
  end

  defp membership_json(%Result{} = result) do
    request = result.request

    QueryContract.json_safe(%{
      status: result.status,
      valid: result.status == :valid,
      reason_code: result.reason_code,
      choice_source: request && request.choice_source,
      domain: request && request.domain,
      field: request && request.field,
      value: request && request.value,
      label: membership_label(result),
      user_message: result.user_message,
      metadata: result.metadata
    })
  end

  defp membership_label(%Result{metadata: metadata}) when is_map(metadata) do
    map_value(metadata, :label) ||
      map_value(metadata, :display_label) ||
      map_value(metadata, :choice_label)
  end

  defp membership_label(_result), do: nil

  defp error_reply(error) when is_map(error) do
    QueryContract.json_safe(%{
      status: :error,
      error: %{
        code: map_value(error, :code) || :choice_source_error,
        message: map_value(error, :message) || inspect(error),
        path: list_values(map_value(error, :path))
      }
    })
  end

  defp error_reply(error), do: error_reply(error(:choice_source_error, inspect(error), []))

  defp required_param(params, key) do
    case param_value(params, key) do
      value when is_binary(value) and value != "" ->
        {:ok, value}

      value when is_atom(value) and not is_nil(value) ->
        {:ok, value}

      value when key == :value and not is_nil(value) ->
        {:ok, value}

      _ ->
        {:error,
         error(
           :"missing_#{key}",
           "choice-source LiveView request requires #{inspect(key)}",
           [key]
         )}
    end
  end

  defp clean_search(value) when is_binary(value) do
    value = String.trim(value)
    if value == "", do: nil, else: String.slice(value, 0, 200)
  end

  defp clean_search(_value), do: nil

  defp request_limit(value) when is_integer(value), do: clamp(value, 1, @max_limit)

  defp request_limit(value) when is_binary(value) do
    case Integer.parse(value) do
      {limit, ""} -> request_limit(limit)
      _ -> @default_limit
    end
  end

  defp request_limit(_value), do: @default_limit

  defp request_offset(value) when is_integer(value) and value >= 0, do: value

  defp request_offset(value) when is_binary(value) do
    case Integer.parse(value) do
      {offset, ""} when offset >= 0 -> offset
      _ -> 0
    end
  end

  defp request_offset(_value), do: 0

  defp clamp(value, min, max), do: value |> max(min) |> min(max)

  defp merge_request_attrs(base_attrs, override_attrs, allowed_keys) do
    base = attrs_to_map(base_attrs)

    override =
      override_attrs
      |> attrs_to_map()
      |> Map.take(allowed_keys)

    context =
      Map.merge(map_or_empty(Map.get(base, :context)), map_or_empty(Map.get(override, :context)))

    metadata =
      Map.merge(
        map_or_empty(Map.get(base, :metadata)),
        map_or_empty(Map.get(override, :metadata))
      )

    base
    |> Map.merge(override)
    |> Map.put(:context, context)
    |> Map.put(:metadata, metadata)
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp attrs_to_map(attrs) when is_map(attrs) do
    attrs
    |> Enum.map(fn {key, value} -> {request_attr_key(key), value} end)
    |> Enum.into(%{})
  end

  defp attrs_to_map(attrs) when is_list(attrs), do: attrs |> Enum.into(%{}) |> attrs_to_map()
  defp attrs_to_map(_attrs), do: %{}

  defp request_attr_key(key) when is_atom(key), do: key

  defp request_attr_key(key) when is_binary(key) do
    case key do
      "actor" -> :actor
      "tenant" -> :tenant
      "record" -> :record
      "context" -> :context
      "metadata" -> :metadata
      "filters" -> :filters
      "order_by" -> :order_by
      other -> other
    end
  end

  defp request_attr_key(key), do: key

  defp compact(map) when is_map(map) do
    Map.reject(map, fn {_key, value} -> is_nil(value) end)
  end

  defp map_or_empty(value) when is_map(value), do: value
  defp map_or_empty(_value), do: %{}

  defp param_value(params, key) when is_map(params) and is_atom(key) do
    Map.get(params, key) || Map.get(params, Atom.to_string(key))
  end

  defp map_value(map, key) when is_map(map) and is_atom(key) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp map_value(_map, _key), do: nil

  defp list_values(value) when is_list(value), do: value
  defp list_values(_value), do: []

  defp same_id?(left, right), do: to_string(left) == to_string(right)

  defp assign(%Socket{assigns: assigns}, key), do: Map.get(assigns, key)

  defp error(code, message, path, extra \\ %{}) do
    %{code: code, message: message, path: path}
    |> Map.merge(extra)
  end
end
