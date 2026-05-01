defmodule SelectoComponents.QueryContract.IntentValidator.Plug do
  @moduledoc """
  Plug endpoint for validating generated query intents against a Selecto query contract.

  The endpoint accepts a JSON object body. Hosts may post the intent directly or
  wrap it as `%{"intent" => intent}`. Validation is non-executing and returns
  structured diagnostics only.
  """

  import Plug.Conn

  alias SelectoComponents.QueryContract

  @behaviour Plug

  @impl Plug
  def init(opts) do
    if Keyword.has_key?(opts, :domain) or Keyword.has_key?(opts, :resolver) do
      opts
    else
      raise ArgumentError, "expected :domain or :resolver for #{inspect(__MODULE__)}"
    end
  end

  @impl Plug
  def call(%Plug.Conn{method: "POST"} = conn, opts) do
    with {:ok, input} <- contract_input(conn, opts),
         {:ok, intent, conn} <- request_intent(conn) do
      send_validation(conn, input, intent, opts)
    else
      {:error, status, code, message} ->
        send_error(conn, status, code, message)
    end
  end

  def call(conn, _opts) do
    conn
    |> put_resp_header("allow", "POST")
    |> send_error(405, :method_not_allowed, "query intent validation accepts POST requests only")
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
     "query intent validator resolver must be a one- or two-arity function"}
  end

  defp normalize_resolver_result({:error, reason}) do
    {:error, 404, :not_found, "query intent validator domain not found: #{inspect(reason)}"}
  end

  defp normalize_resolver_result(nil) do
    {:error, 404, :not_found, "query intent validator domain not found"}
  end

  defp normalize_resolver_result(input), do: {:ok, input}

  defp request_intent(%Plug.Conn{body_params: %Plug.Conn.Unfetched{}} = conn) do
    read_json_intent(conn)
  end

  defp request_intent(%Plug.Conn{body_params: body_params} = conn) do
    case extract_intent(body_params) do
      {:ok, intent} -> {:ok, intent, conn}
      {:error, status, code, message} -> {:error, status, code, message}
    end
  end

  defp read_json_intent(conn) do
    case read_body(conn) do
      {:ok, "", _conn} ->
        {:error, 400, :missing_intent, "expected a JSON query intent body"}

      {:ok, body, conn} ->
        case Jason.decode(body) do
          {:ok, decoded} ->
            case extract_intent(decoded) do
              {:ok, intent} -> {:ok, intent, conn}
              {:error, status, code, message} -> {:error, status, code, message}
            end

          {:error, _error} ->
            {:error, 400, :invalid_json, "request body must be valid JSON"}
        end

      {:more, _partial, _conn} ->
        {:error, 413, :payload_too_large, "query intent validation body is too large"}

      {:error, reason} ->
        {:error, 400, :invalid_body, "could not read query intent body: #{inspect(reason)}"}
    end
  end

  defp extract_intent(%{"intent" => intent}) when is_map(intent), do: {:ok, intent}
  defp extract_intent(%{intent: intent}) when is_map(intent), do: {:ok, intent}

  defp extract_intent(%{"intent" => _intent}) do
    {:error, 400, :invalid_intent, "intent must be a JSON object"}
  end

  defp extract_intent(%{intent: _intent}) do
    {:error, 400, :invalid_intent, "intent must be a JSON object"}
  end

  defp extract_intent(%{} = intent) when map_size(intent) > 0, do: {:ok, intent}

  defp extract_intent(_body) do
    {:error, 400, :missing_intent, "expected a JSON query intent object"}
  end

  defp send_validation(conn, input, intent, opts) do
    result = QueryContract.validate_intent(input, intent, opts)
    status = if invalid_contract?(result), do: 422, else: 200

    payload =
      QueryContract.json_safe(%{
        valid: Map.fetch!(result, :valid?),
        errors: Map.get(result, :errors, []),
        warnings: Map.get(result, :warnings, [])
      })

    send_json(conn, status, payload)
  end

  defp invalid_contract?(%{errors: errors}) do
    Enum.any?(errors, &match?(%{code: :invalid_query_contract}, &1))
  end

  defp invalid_contract?(_result), do: false

  defp send_error(conn, status, code, message) do
    payload = QueryContract.json_safe(%{error: %{code: code, message: message}})

    send_json(conn, status, payload)
  end

  defp send_json(conn, status, payload) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(payload))
    |> halt()
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
