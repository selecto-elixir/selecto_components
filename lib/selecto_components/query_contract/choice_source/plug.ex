defmodule SelectoComponents.QueryContract.ChoiceSource.Plug do
  @moduledoc """
  Plug endpoint for Selecto choice-source option and membership requests.

  Host applications mount this plug under a choice-source collection path and
  provide a domain plus resolver functions. The plug serves:

  - `GET /:choice_source/options`
  - `POST /:choice_source/validate`

  The domain may be supplied directly with `:domain` or lazily with `:resolver`.
  Option and membership lookups use `:options_resolver` and
  `:membership_resolver`, each receiving the corresponding
  `Selecto.Domain.Choices` request struct.
  """

  import Plug.Conn

  alias Selecto.Domain.Choices
  alias Selecto.Domain.Choices.{OptionsResult, Result}
  alias SelectoComponents.QueryContract

  @behaviour Plug

  @default_limit 25
  @max_limit 100

  @impl Plug
  def init(opts) do
    if Keyword.has_key?(opts, :domain) or Keyword.has_key?(opts, :resolver) do
      opts
    else
      raise ArgumentError, "expected :domain or :resolver for #{inspect(__MODULE__)}"
    end
  end

  @impl Plug
  def call(conn, opts) do
    case choice_endpoint(conn) do
      {:options, choice_source_id} when conn.method == "GET" ->
        send_options(conn, choice_source_id, opts)

      {:options, _choice_source_id} ->
        conn
        |> put_resp_header("allow", "GET")
        |> send_error(405, :method_not_allowed, "choice-source options accepts GET requests only")

      {:validate, choice_source_id} when conn.method == "POST" ->
        send_membership(conn, choice_source_id, opts)

      {:validate, _choice_source_id} ->
        conn
        |> put_resp_header("allow", "POST")
        |> send_error(
          405,
          :method_not_allowed,
          "choice-source membership validation accepts POST requests only"
        )

      :unknown ->
        send_error(
          conn,
          404,
          :choice_source_endpoint_not_found,
          "expected /:choice_source/options or /:choice_source/validate"
        )
    end
  end

  defp send_options(conn, choice_source_id, opts) do
    conn = fetch_query_params(conn)

    with {:ok, input} <- contract_input(conn, opts) do
      attrs = options_request_attrs(conn, opts)

      case safe_list_options(input, choice_source_id, attrs) do
        {:ok, %OptionsResult{} = result} ->
          send_options_json(conn, 200, result_json(result), opts)

        {:error, %OptionsResult{} = result} ->
          send_options_json(conn, 422, result_json(result), opts)

        {:error, error} ->
          send_error(conn, error_status(error), error)
      end
    else
      {:error, status, code, message} ->
        send_error(conn, status, code, message)
    end
  end

  defp send_membership(conn, choice_source_id, opts) do
    request_attrs = membership_request_attrs(conn, opts)

    with {:ok, params, conn} <- request_body_params(conn),
         {:ok, raw_value} <- choice_value(params),
         {:ok, field} <- choice_field(params, choice_source_id, opts),
         {:ok, value} <- parse_choice_value(raw_value, field, choice_source_id, conn, opts),
         {:ok, input} <- contract_input(conn, opts),
         :ok <- ensure_choice_source_exists(input, choice_source_id),
         :ok <-
           ensure_field_matches_choice_source(
             input,
             field,
             value,
             choice_source_id,
             request_attrs
           ) do
      attrs = Keyword.put(request_attrs, :resolver, Keyword.get(opts, :membership_resolver))

      case safe_validate_choice(input, field, value, attrs) do
        {:ok, %Result{} = result} ->
          send_json(conn, 200, membership_json(result))

        {:error, %Result{} = result} ->
          send_json(conn, 200, membership_json(result))

        {:error, error} ->
          send_error(conn, error_status(error), error)
      end
    else
      {:error, status, code, message} ->
        send_error(conn, status, code, message)

      {:error, %{code: _code} = error} ->
        send_error(conn, error_status(error), error)
    end
  end

  defp contract_input(conn, opts) do
    case Keyword.fetch(opts, :domain) do
      {:ok, domain} ->
        {:ok, domain}

      :error ->
        opts
        |> Keyword.fetch!(:resolver)
        |> resolve_domain(conn)
    end
  end

  defp resolve_domain(resolver, conn) do
    result =
      cond do
        is_function(resolver, 1) ->
          resolver.(conn)

        is_function(resolver, 2) ->
          resolver.(domain_id(conn), conn)

        true ->
          {:error, :invalid_resolver}
      end

    normalize_resolver_result(result)
  rescue
    exception ->
      {:error, 500, :resolver_failed, Exception.message(exception)}
  end

  defp normalize_resolver_result({:ok, input}), do: {:ok, input}

  defp normalize_resolver_result({:error, :invalid_resolver}) do
    {:error, 500, :invalid_resolver,
     "choice-source resolver must be a one- or two-arity function"}
  end

  defp normalize_resolver_result({:error, reason}) do
    {:error, 404, :not_found, "choice-source domain not found: #{inspect(reason)}"}
  end

  defp normalize_resolver_result(nil) do
    {:error, 404, :not_found, "choice-source domain not found"}
  end

  defp normalize_resolver_result(input), do: {:ok, input}

  defp options_request_attrs(conn, opts) do
    [
      by: :choice_source,
      search: clean_search(param_value(conn.params, :search)),
      limit: request_limit(param_value(conn.params, :limit), opts),
      offset: request_offset(param_value(conn.params, :offset)),
      resolver: Keyword.get(opts, :options_resolver),
      context: endpoint_context(opts, :options)
    ]
  end

  defp membership_request_attrs(_conn, opts) do
    [
      context: endpoint_context(opts, :validate)
    ]
  end

  defp safe_list_options(input, choice_source_id, attrs) do
    Choices.list_options(input, choice_source_id, attrs)
  rescue
    exception ->
      {:error,
       %{
         code: :choice_source_resolver_failed,
         message: Exception.message(exception),
         path: [:resolver]
       }}
  end

  defp safe_validate_choice(input, field, value, attrs) do
    Choices.validate_choice(input, field, value, attrs)
  rescue
    exception ->
      {:error,
       %{
         code: :choice_source_resolver_failed,
         message: Exception.message(exception),
         path: [:resolver]
       }}
  end

  defp ensure_choice_source_exists(input, choice_source_id) do
    case Choices.choice_source_options_request(input, choice_source_id, by: :choice_source) do
      {:ok, _request} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  defp ensure_field_matches_choice_source(input, field, value, choice_source_id, request_attrs) do
    case Choices.request(input, field, value, request_attrs) do
      {:ok, request} ->
        if same_id?(request.choice_source, choice_source_id) do
          :ok
        else
          {:error,
           %{
             code: :choice_source_field_mismatch,
             message:
               "field #{inspect(field)} is bound to choice source #{inspect(request.choice_source)}",
             path: [:field],
             choice_source: choice_source_id,
             field_choice_source: request.choice_source
           }}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  defp request_body_params(%Plug.Conn{body_params: %Plug.Conn.Unfetched{}} = conn) do
    read_json_body(conn)
  end

  defp request_body_params(%Plug.Conn{body_params: body_params} = conn)
       when is_map(body_params) do
    {:ok, body_params, conn}
  end

  defp request_body_params(%Plug.Conn{params: params} = conn) when is_map(params) do
    {:ok, params, conn}
  end

  defp read_json_body(conn) do
    case read_body(conn) do
      {:ok, "", _conn} ->
        {:error, 400, :missing_choice_body, "expected a JSON choice validation body"}

      {:ok, body, conn} ->
        case Jason.decode(body) do
          {:ok, decoded} when is_map(decoded) ->
            {:ok, decoded, conn}

          {:ok, _decoded} ->
            {:error, 400, :invalid_choice_body, "choice validation body must be a JSON object"}

          {:error, _error} ->
            {:error, 400, :invalid_json, "request body must be valid JSON"}
        end

      {:more, _partial, _conn} ->
        {:error, 413, :payload_too_large, "choice validation body is too large"}

      {:error, reason} ->
        {:error, 400, :invalid_body, "could not read choice validation body: #{inspect(reason)}"}
    end
  end

  defp choice_value(params) do
    case fetch_param(params, :value) do
      {:ok, value} ->
        {:ok, value}

      :error ->
        {:error,
         %{
           code: :missing_choice_value,
           message: "choice validation requires a value",
           path: [:value]
         }}
    end
  end

  defp choice_field(params, choice_source_id, opts) do
    field =
      case fetch_param(params, :field) do
        {:ok, value} -> value
        :error -> configured_field(choice_source_id, opts)
      end

    cond do
      is_atom(field) and not is_nil(field) ->
        {:ok, field}

      is_binary(field) and field != "" ->
        {:ok, field}

      is_nil(field) ->
        {:error,
         %{
           code: :missing_choice_field,
           message: "choice validation requires a field",
           path: [:field]
         }}

      true ->
        {:error,
         %{
           code: :invalid_choice_field,
           message: "choice validation field must be an atom or string",
           path: [:field]
         }}
    end
  end

  defp parse_choice_value(value, field, choice_source_id, conn, opts) do
    case Keyword.get(opts, :value_parser) do
      nil ->
        {:ok, value}

      parser when is_function(parser, 1) ->
        parser
        |> apply_value_parser([value])
        |> normalize_value_parser_result()

      parser when is_function(parser, 2) ->
        context = %{choice_source: choice_source_id, field: field, conn: conn}

        parser
        |> apply_value_parser([value, context])
        |> normalize_value_parser_result()

      parser ->
        {:error,
         %{
           code: :invalid_value_parser,
           message: "choice-source value parser must be a one- or two-arity function",
           path: [:value],
           parser: inspect(parser)
         }}
    end
  rescue
    exception ->
      {:error,
       %{
         code: :value_parser_failed,
         message: Exception.message(exception),
         path: [:value]
       }}
  end

  defp apply_value_parser(parser, args), do: apply(parser, args)

  defp normalize_value_parser_result({:ok, value}), do: {:ok, value}
  defp normalize_value_parser_result({:error, %{code: _code} = error}), do: {:error, error}

  defp normalize_value_parser_result({:error, reason}) do
    {:error,
     %{
       code: :invalid_choice_value,
       message: "choice validation value is invalid: #{inspect(reason)}",
       path: [:value]
     }}
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

  defp error_json(error) when is_map(error) do
    QueryContract.json_safe(%{
      code: map_value(error, :code),
      message: map_value(error, :message),
      path: list_values(map_value(error, :path))
    })
  end

  defp error_json(error), do: %{code: "choice_source_error", message: inspect(error)}

  defp send_options_json(conn, status, payload, opts) do
    conn
    |> put_collection_link_header(opts)
    |> send_json(status, payload)
  end

  defp send_json(conn, status, payload) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(QueryContract.json_safe(payload)))
    |> halt()
  end

  defp send_error(conn, status, code, message) do
    payload = %{error: %{code: code, message: message}}

    send_json(conn, status, payload)
  end

  defp send_error(conn, status, error) do
    send_json(conn, status, %{error: error_json(error)})
  end

  defp put_collection_link_header(conn, opts) do
    case Keyword.get(opts, :collection_url) || Keyword.get(opts, :artifacts_url) do
      nil ->
        conn

      "" ->
        conn

      collection_url ->
        put_resp_header(
          conn,
          "link",
          ~s(<#{escape_link_target(collection_url)}>; rel="collection"; type="text/html")
        )
    end
  end

  defp error_status(error) when is_map(error) do
    case map_value(error, :code) do
      :choice_source_not_found -> 404
      "choice_source_not_found" -> 404
      :not_found -> 404
      "not_found" -> 404
      :choice_source_resolver_failed -> 500
      "choice_source_resolver_failed" -> 500
      :invalid_value_parser -> 500
      "invalid_value_parser" -> 500
      :value_parser_failed -> 500
      "value_parser_failed" -> 500
      _code -> 422
    end
  end

  defp error_status(_error), do: 422

  defp choice_endpoint(conn) do
    segments = conn.path_info || []
    operation = List.last(segments)
    choice_source_id = path_choice_source(conn) || previous_segment(segments)

    cond do
      operation == "options" and choice_source_id?(choice_source_id) ->
        {:options, choice_source_id}

      operation == "validate" and choice_source_id?(choice_source_id) ->
        {:validate, choice_source_id}

      true ->
        :unknown
    end
  end

  defp path_choice_source(conn) do
    fetch_conn_value(conn.path_params, "choice_source") ||
      fetch_conn_value(conn.path_params, :choice_source) ||
      fetch_conn_value(conn.path_params, "id") ||
      fetch_conn_value(conn.path_params, :id)
  end

  defp previous_segment(segments) do
    case Enum.reverse(segments) do
      [_operation, choice_source_id | _rest] -> choice_source_id
      _other -> nil
    end
  end

  defp choice_source_id?(value),
    do: (is_atom(value) and not is_nil(value)) or value not in [nil, ""]

  defp configured_field(choice_source_id, opts) do
    field_by_choice_source =
      opts
      |> Keyword.get(:field_by_choice_source, %{})
      |> option_map()
      |> fetch_choice_source_entry(choice_source_id)

    field_by_choice_source || Keyword.get(opts, :default_field) || Keyword.get(opts, :field)
  end

  defp endpoint_context(opts, endpoint) do
    base_context = opts |> Keyword.get(:context, %{}) |> option_map()

    endpoint_context =
      case endpoint do
        :options ->
          Keyword.get(opts, :options_context, %{})

        :validate ->
          Keyword.get(opts, :membership_context) || Keyword.get(opts, :validate_context, %{})
      end
      |> option_map()

    Map.merge(base_context, endpoint_context)
  end

  defp request_limit(nil, opts), do: default_limit(opts)

  defp request_limit(value, opts) when is_integer(value) and value > 0 do
    min(value, max_limit(opts))
  end

  defp request_limit(value, opts) when is_binary(value) do
    case Integer.parse(value) do
      {limit, ""} when limit > 0 -> min(limit, max_limit(opts))
      _ -> default_limit(opts)
    end
  end

  defp request_limit(_value, opts), do: default_limit(opts)

  defp request_offset(value) when is_integer(value) and value >= 0, do: value

  defp request_offset(value) when is_binary(value) do
    case Integer.parse(value) do
      {offset, ""} when offset >= 0 -> offset
      _ -> 0
    end
  end

  defp request_offset(_value), do: 0

  defp default_limit(opts), do: Keyword.get(opts, :default_limit, @default_limit)
  defp max_limit(opts), do: Keyword.get(opts, :max_limit, @max_limit)

  defp clean_search(value) when is_binary(value) do
    value
    |> String.trim()
    |> case do
      "" -> nil
      search -> search
    end
  end

  defp clean_search(_value), do: nil

  defp list_values(nil), do: nil
  defp list_values(values) when is_list(values), do: values
  defp list_values(value), do: value

  defp same_id?(left, right), do: to_string(left) == to_string(right)

  defp fetch_choice_source_entry(map, choice_source_id) when is_map(map) do
    Map.get(map, choice_source_id) ||
      Map.get(map, to_string(choice_source_id)) ||
      Enum.find_value(map, fn
        {key, value} when is_atom(key) or is_binary(key) ->
          if to_string(key) == to_string(choice_source_id), do: value

        _entry ->
          nil
      end)
  end

  defp fetch_choice_source_entry(_map, _choice_source_id), do: nil

  defp fetch_param(map, key) when is_map(map) and is_atom(key) do
    string_key = Atom.to_string(key)

    cond do
      Map.has_key?(map, key) -> {:ok, Map.fetch!(map, key)}
      Map.has_key?(map, string_key) -> {:ok, Map.fetch!(map, string_key)}
      true -> :error
    end
  end

  defp fetch_param(_map, _key), do: :error

  defp param_value(map, key, default \\ nil) do
    case fetch_param(map, key) do
      {:ok, value} -> value
      :error -> default
    end
  end

  defp map_value(map, key) when is_map(map) and is_atom(key) do
    case Map.fetch(map, key) do
      {:ok, value} -> value
      :error -> Map.get(map, Atom.to_string(key))
    end
  end

  defp map_value(_map, _key), do: nil

  defp option_map(value) when is_map(value), do: value
  defp option_map(value) when is_list(value), do: Map.new(value)
  defp option_map(_value), do: %{}

  defp escape_link_target(value) do
    value
    |> to_string()
    |> String.replace(">", "%3E")
  end

  defp domain_id(conn) do
    fetch_conn_value(conn.path_params, "domain") ||
      fetch_conn_value(conn.path_params, :domain) ||
      fetch_conn_value(conn.params, "domain") ||
      fetch_conn_value(conn.params, :domain) ||
      fetch_conn_value(conn.assigns, :selecto_domain) ||
      fetch_conn_value(conn.assigns, :domain)
  end

  defp fetch_conn_value(map, key) when is_map(map), do: Map.get(map, key)
  defp fetch_conn_value(_map, _key), do: nil
end
