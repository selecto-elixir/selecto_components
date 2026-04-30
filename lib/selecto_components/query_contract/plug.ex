defmodule SelectoComponents.QueryContract.Plug do
  @moduledoc """
  Plug endpoint for serving a Selecto query contract JSON document.

  Host applications can mount this plug at whatever route makes sense for their
  domain. The plug accepts either a direct `:domain` option or a `:resolver`
  function that returns the domain for the current connection.
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
  def call(conn, opts) do
    case contract_input(conn, opts) do
      {:ok, input} ->
        send_contract(conn, input, opts)

      {:error, status, code, message} ->
        send_error(conn, status, code, message)
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
     "query contract resolver must be a one- or two-arity function"}
  end

  defp normalize_resolver_result({:error, reason}) do
    {:error, 404, :not_found, "query contract domain not found: #{inspect(reason)}"}
  end

  defp normalize_resolver_result(nil) do
    {:error, 404, :not_found, "query contract domain not found"}
  end

  defp normalize_resolver_result(input), do: {:ok, input}

  defp send_contract(conn, input, opts) do
    case QueryContract.encode_json(input, encode_opts(opts)) do
      {:ok, json, _diagnostics} ->
        send_json(conn, 200, json)

      {:error, diagnostics} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(422, Jason.encode!(diagnostics_document(diagnostics)))
        |> halt()
    end
  end

  defp send_error(conn, status, code, message) do
    payload = QueryContract.json_safe(%{error: %{code: code, message: message}})

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(payload))
    |> halt()
  end

  defp send_json(conn, status, json) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, json)
    |> halt()
  end

  defp diagnostics_document(diagnostics) do
    QueryContract.json_safe(%{
      error: %{code: :invalid_query_contract_domain, message: "query contract input is invalid"},
      diagnostics: %{
        errors: diagnostics.errors,
        warnings: diagnostics.warnings,
        schema_version: diagnostics.schema_version,
        schema_version_inferred: diagnostics.schema_version_inferred
      }
    })
  end

  defp encode_opts(opts) do
    if Keyword.get(opts, :pretty, false), do: [pretty: true], else: []
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
