defmodule SelectoComponents.QueryContract.Guide.Plug do
  @moduledoc """
  Plug endpoint for serving a Markdown Selecto query guide.

  Host applications can mount this beside `SelectoComponents.QueryContract.Plug`
  to expose a readable companion to `query_contract.json`.
  """

  import Plug.Conn

  alias SelectoComponents.QueryContract
  alias SelectoComponents.QueryContract.Guide
  alias SelectoComponents.QueryContract.Links

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
        send_guide(conn, input, opts)

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
    {:error, 500, :invalid_resolver, "query guide resolver must be a one- or two-arity function"}
  end

  defp normalize_resolver_result({:error, reason}) do
    {:error, 404, :not_found, "query guide domain not found: #{inspect(reason)}"}
  end

  defp normalize_resolver_result(nil) do
    {:error, 404, :not_found, "query guide domain not found"}
  end

  defp normalize_resolver_result(input), do: {:ok, input}

  defp send_guide(conn, input, opts) do
    opts = Links.with_request_defaults(conn, opts, :query_guide)

    case Guide.markdown(input, opts) do
      {:ok, markdown, _diagnostics} ->
        conn
        |> put_resp_content_type("text/markdown")
        |> put_link_header(opts)
        |> send_resp(200, markdown)
        |> halt()

      {:error, diagnostics} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(422, Jason.encode!(diagnostics_document(diagnostics)))
        |> halt()
    end
  end

  defp put_link_header(conn, opts) do
    case Links.header(opts, :query_guide) do
      nil -> conn
      header -> put_resp_header(conn, "link", header)
    end
  end

  defp send_error(conn, status, code, message) do
    payload = QueryContract.json_safe(%{error: %{code: code, message: message}})

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(payload))
    |> halt()
  end

  defp diagnostics_document(diagnostics) do
    QueryContract.json_safe(%{
      error: %{code: :invalid_query_contract_domain, message: "query guide input is invalid"},
      diagnostics: %{
        errors: diagnostics.errors,
        warnings: diagnostics.warnings,
        schema_version: diagnostics.schema_version,
        schema_version_inferred: diagnostics.schema_version_inferred
      }
    })
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
