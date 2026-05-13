defmodule SelectoComponents.QueryContract.ChoiceSource.Client do
  @moduledoc """
  Consumer helpers for query-contract choice-source links.

  The client reads `choice_sources[].links` from a JSON-ready query contract,
  builds transport-neutral requests for option lookup and membership validation,
  and can execute those requests through a caller-supplied transport function.

  A transport receives `%SelectoComponents.QueryContract.ChoiceSource.Request{}`
  and may return `%{status: status, body: body}`, `{:ok, response}`, or
  `{:error, reason}`. Bodies may already be decoded maps/lists or JSON strings.
  """

  alias SelectoComponents.QueryContract
  alias SelectoComponents.QueryContract.ChoiceSource.Request

  @default_headers [{"accept", "application/json"}]
  @json_headers @default_headers ++ [{"content-type", "application/json"}]

  @type contract :: map()
  @type choice_source_id :: atom() | String.t()
  @type result :: {:ok, map() | list()} | {:error, map()}

  @doc """
  Returns the choice-source entries advertised by a query contract.
  """
  @spec choice_sources(contract()) :: [map()]
  def choice_sources(contract) when is_map(contract) do
    contract
    |> get_value(:choice_sources, [])
    |> case do
      choice_sources when is_list(choice_sources) -> Enum.filter(choice_sources, &is_map/1)
      _other -> []
    end
  end

  def choice_sources(_contract), do: []

  @doc """
  Finds a choice-source entry by id.
  """
  @spec choice_source(contract(), choice_source_id()) :: {:ok, map()} | {:error, map()}
  def choice_source(contract, choice_source_id) when is_map(contract) do
    case Enum.find(choice_sources(contract), &same_id?(get_value(&1, :id), choice_source_id)) do
      nil ->
        {:error,
         error(
           :choice_source_not_found,
           "choice source #{inspect(choice_source_id)} is not advertised by the query contract",
           [:choice_sources, choice_source_id]
         )}

      choice_source ->
        {:ok, choice_source}
    end
  end

  def choice_source(_contract, choice_source_id) do
    {:error,
     error(
       :invalid_query_contract,
       "choice-source client expected a query contract map",
       [:choice_sources, choice_source_id]
     )}
  end

  @doc """
  Returns the advertised link map for a choice source.
  """
  @spec links(contract(), choice_source_id()) :: {:ok, map()} | {:error, map()}
  def links(contract, choice_source_id) do
    with {:ok, choice_source} <- choice_source(contract, choice_source_id) do
      case get_value(choice_source, :links, %{}) do
        links when is_map(links) ->
          {:ok, links}

        _other ->
          {:error,
           error(
             :choice_source_links_invalid,
             "choice source #{inspect(choice_source_id)} links must be a map",
             [:choice_sources, choice_source_id, :links]
           )}
      end
    end
  end

  @doc """
  Builds a `GET` request for a choice-source options endpoint.

  Supported options:

  - `:search`
  - `:limit`
  - `:offset`
  - `:params` for extra query parameters
  - `:headers` for transport headers
  - `:base_url` for resolving relative links
  """
  @spec options_request(contract(), choice_source_id(), keyword()) ::
          {:ok, Request.t()} | {:error, map()}
  def options_request(contract, choice_source_id, opts \\ []) do
    with {:ok, url} <- operation_url(contract, choice_source_id, :options, opts) do
      query =
        opts
        |> Keyword.get(:params, %{})
        |> option_map()
        |> Map.merge(
          compact(%{search: opts[:search], limit: opts[:limit], offset: opts[:offset]})
        )

      {:ok,
       %Request{
         method: :get,
         url: append_query(url, query),
         operation: :options,
         choice_source: string_id(choice_source_id),
         headers: request_headers(@default_headers, opts),
         metadata: request_metadata(contract, choice_source_id, opts)
       }}
    end
  end

  @doc """
  Builds a `POST` request for a choice-source membership endpoint.

  If `:field` is omitted and the query contract has exactly one
  `field_choice_bindings` entry for the choice source, that field is included in
  the request body.
  """
  @spec validate_request(contract(), choice_source_id(), term(), keyword()) ::
          {:ok, Request.t()} | {:error, map()}
  def validate_request(contract, choice_source_id, value, opts \\ []) do
    with {:ok, url} <- operation_url(contract, choice_source_id, :validate, opts) do
      field = Keyword.get(opts, :field) || inferred_field(contract, choice_source_id)

      body =
        %{field: field, value: value}
        |> compact()

      {:ok,
       %Request{
         method: :post,
         url: url,
         operation: :validate,
         choice_source: string_id(choice_source_id),
         headers: request_headers(@json_headers, opts),
         body: QueryContract.json_safe(body),
         metadata: request_metadata(contract, choice_source_id, opts)
       }}
    end
  end

  @doc """
  Fetches options through a configured transport.
  """
  @spec fetch_options(contract(), choice_source_id(), keyword()) :: result()
  def fetch_options(contract, choice_source_id, opts \\ []) do
    with {:ok, request} <- options_request(contract, choice_source_id, opts),
         {:ok, response} <- run_transport(request, opts) do
      normalize_response(response)
    end
  end

  @doc """
  Validates membership through a configured transport.
  """
  @spec validate_choice(contract(), choice_source_id(), term(), keyword()) :: result()
  def validate_choice(contract, choice_source_id, value, opts \\ []) do
    with {:ok, request} <- validate_request(contract, choice_source_id, value, opts),
         {:ok, response} <- run_transport(request, opts) do
      normalize_response(response)
    end
  end

  @doc """
  Infers the field bound to a choice source when the contract has one match.
  """
  @spec inferred_field(contract(), choice_source_id()) :: String.t() | nil
  def inferred_field(contract, choice_source_id) when is_map(contract) do
    matches =
      contract
      |> get_value(:field_choice_bindings, [])
      |> case do
        bindings when is_list(bindings) -> bindings
        _other -> []
      end
      |> Enum.filter(fn binding ->
        is_map(binding) and same_id?(get_value(binding, :choice_source), choice_source_id)
      end)
      |> Enum.map(&get_value(&1, :field))
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq_by(&to_string/1)

    case matches do
      [field] -> to_string(field)
      _other -> nil
    end
  end

  def inferred_field(_contract, _choice_source_id), do: nil

  defp operation_url(contract, choice_source_id, operation, opts) do
    with {:ok, links} <- links(contract, choice_source_id) do
      case get_value(links, operation) do
        url when is_binary(url) and url != "" ->
          {:ok, resolve_url(url, opts)}

        _missing ->
          {:error,
           error(
             :choice_source_link_not_found,
             "choice source #{inspect(choice_source_id)} does not advertise #{operation} link",
             [:choice_sources, choice_source_id, :links, operation]
           )}
      end
    end
  end

  defp run_transport(%Request{} = request, opts) do
    case transport(opts) do
      nil ->
        {:error,
         error(
           :transport_required,
           "choice-source client requires a :transport function to execute requests",
           [:transport]
         )}

      transport when is_function(transport, 1) ->
        transport
        |> apply_transport([request])
        |> normalize_transport_result()

      transport ->
        {:error,
         error(
           :invalid_transport,
           "choice-source transport must be a one-arity function",
           [:transport],
           transport: inspect(transport)
         )}
    end
  end

  defp transport(opts) do
    Keyword.get(opts, :transport) ||
      :selecto_components
      |> Application.get_env(__MODULE__, [])
      |> option_map()
      |> Map.get(:transport)
  end

  defp apply_transport(transport, args), do: apply(transport, args)

  defp normalize_transport_result({:ok, response}), do: {:ok, response}
  defp normalize_transport_result(%{} = response), do: {:ok, response}

  defp normalize_transport_result({:error, %{code: _code} = error}), do: {:error, error}

  defp normalize_transport_result({:error, reason}) do
    {:error, error(:transport_error, "choice-source transport failed: #{inspect(reason)}", [])}
  end

  defp normalize_transport_result(other) do
    {:error,
     error(
       :invalid_transport_result,
       "choice-source transport returned an unsupported result",
       [],
       result: inspect(other)
     )}
  end

  defp normalize_response(response) when is_map(response) do
    status = get_value(response, :status) || get_value(response, :status_code)
    body = get_value(response, :body, response)

    case normalize_body(body) do
      {:ok, decoded} when is_integer(status) and status >= 200 and status < 300 ->
        {:ok, decoded}

      {:ok, decoded} when is_nil(status) ->
        {:ok, decoded}

      {:ok, decoded} ->
        {:error,
         error(
           :choice_source_http_error,
           "choice-source endpoint returned HTTP #{inspect(status)}",
           [],
           status: status,
           body: decoded
         )}

      {:error, error} ->
        {:error, error}
    end
  end

  defp normalize_response(response), do: normalize_body(response)

  defp normalize_body(body) when is_map(body) or is_list(body),
    do: {:ok, QueryContract.json_safe(body)}

  defp normalize_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} ->
        {:ok, QueryContract.json_safe(decoded)}

      {:error, _error} ->
        {:error,
         error(:invalid_json_response, "choice-source response body must be valid JSON", [])}
    end
  end

  defp normalize_body(nil), do: {:ok, %{}}

  defp normalize_body(body) do
    {:error,
     error(
       :invalid_response_body,
       "choice-source response body must be a map, list, JSON string, or nil",
       [],
       body: inspect(body)
     )}
  end

  defp request_metadata(contract, choice_source_id, opts) do
    %{
      field: Keyword.get(opts, :field) || inferred_field(contract, choice_source_id)
    }
    |> compact()
    |> QueryContract.json_safe()
  end

  defp request_headers(default_headers, opts) do
    opts
    |> Keyword.get(:headers, [])
    |> normalize_headers()
    |> merge_headers(default_headers)
  end

  defp merge_headers(headers, defaults) do
    defaults
    |> normalize_headers()
    |> Enum.reduce(headers, fn {key, value}, acc ->
      if Enum.any?(acc, fn {header_key, _value} -> String.downcase(header_key) == key end) do
        acc
      else
        [{key, value} | acc]
      end
    end)
    |> Enum.reverse()
  end

  defp normalize_headers(headers) when is_map(headers) or is_list(headers) do
    headers
    |> Enum.map(fn {key, value} -> {String.downcase(to_string(key)), to_string(value)} end)
    |> Enum.reverse()
    |> Enum.uniq_by(fn {key, _value} -> key end)
    |> Enum.reverse()
  end

  defp normalize_headers(_headers), do: []

  defp append_query(url, query) when query == %{}, do: url

  defp append_query(url, query) do
    uri = URI.parse(url)

    existing_query =
      uri.query
      |> parse_query()
      |> Map.merge(QueryContract.json_safe(query))

    uri
    |> Map.put(:query, URI.encode_query(existing_query))
    |> URI.to_string()
  end

  defp parse_query(nil), do: %{}
  defp parse_query(""), do: %{}
  defp parse_query(query), do: URI.decode_query(query)

  defp resolve_url(url, opts) do
    base_url = Keyword.get(opts, :base_url)

    cond do
      absolute_url?(url) ->
        url

      is_binary(base_url) and base_url != "" ->
        base_url
        |> URI.parse()
        |> URI.merge(url)
        |> URI.to_string()

      true ->
        url
    end
  end

  defp absolute_url?(url) do
    url
    |> URI.parse()
    |> Map.get(:scheme)
    |> is_binary()
  end

  defp compact(map) do
    map
    |> Enum.reject(fn {_key, value} -> is_nil(value) or value == "" end)
    |> Map.new()
  end

  defp option_map(value) when is_map(value), do: value
  defp option_map(value) when is_list(value), do: Map.new(value)
  defp option_map(_value), do: %{}

  defp get_value(map, key, default \\ nil)

  defp get_value(map, key, default) when is_map(map) and is_atom(key) do
    string_key = Atom.to_string(key)

    cond do
      Map.has_key?(map, key) -> Map.get(map, key)
      Map.has_key?(map, string_key) -> Map.get(map, string_key)
      true -> default
    end
  end

  defp get_value(_map, _key, default), do: default

  defp same_id?(left, right), do: to_string(left) == to_string(right)

  defp string_id(value) when is_atom(value), do: Atom.to_string(value)
  defp string_id(value), do: to_string(value)

  defp error(code, message, path, attrs \\ []) do
    attrs
    |> Map.new()
    |> Map.merge(%{
      code: code,
      message: message,
      path: Enum.map(path, &QueryContract.json_safe/1)
    })
    |> QueryContract.json_safe()
  end
end
