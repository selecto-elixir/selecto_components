defmodule SelectoComponents.Form.ChoiceSourceMetadata do
  @moduledoc """
  Projects query-contract choice-source links into form-friendly field metadata.

  Query contracts expose raw `fields`, `field_choice_bindings`, and
  `choice_sources`. This module stitches those pieces together so form and UI
  code can ask for annotated fields instead of hand-walking the contract.
  """

  alias SelectoComponents.QueryContract
  alias SelectoComponents.QueryContract.ChoiceSource.Client
  alias SelectoComponents.QueryContract.ChoiceSource.Request

  @value_placeholder "$value"
  @choice_source_keys ~w(
    id
    domain
    source_relationship
    value_field
    label_field
    source_path
    value_source
    caption_source
    filters_count
    order_by_count
    presentation
    constraint_policy
    capability
    links
  )

  @type contract :: map()
  @type field_id :: atom() | String.t()

  @doc """
  Returns every query-contract field with choice-source metadata attached when present.

  Bound fields keep their original `"choice_source"` scalar and receive a
  sibling `"choice_source_metadata"` map.
  """
  @spec fields(contract(), keyword()) :: [map()]
  def fields(contract, opts \\ [])

  def fields(contract, opts) when is_map(contract) do
    bindings_by_field = bindings_by_field(contract)
    choice_sources_by_id = choice_sources_by_id(contract)

    contract
    |> get_value(:fields, [])
    |> list_or_empty()
    |> Enum.filter(&is_map/1)
    |> Enum.map(&annotate_field(&1, contract, bindings_by_field, choice_sources_by_id, opts))
  end

  def fields(_contract, _opts), do: []

  @doc """
  Returns only fields that are backed by choice sources.
  """
  @spec choice_source_fields(contract(), keyword()) :: [map()]
  def choice_source_fields(contract, opts \\ []) do
    contract
    |> fields(opts)
    |> Enum.filter(&Map.has_key?(&1, "choice_source_metadata"))
  end

  @doc """
  Looks up one field from the annotated metadata projection.
  """
  @spec field(contract(), field_id(), keyword()) :: {:ok, map()} | {:error, map()}
  def field(contract, field_id, opts \\ []) do
    contract
    |> fields(opts)
    |> Enum.find(&same_id?(get_value(&1, :id), field_id))
    |> case do
      nil ->
        {:error,
         error(
           :field_not_found,
           "field #{inspect(field_id)} is not exposed by the query contract",
           [:fields, field_id]
         )}

      field ->
        {:ok, field}
    end
  end

  defp annotate_field(field, contract, bindings_by_field, choice_sources_by_id, opts) do
    field = QueryContract.json_safe(field)
    field_id = get_value(field, :id)
    binding = binding_for_field(field, field_id, bindings_by_field)

    case binding do
      nil ->
        field

      binding ->
        metadata = metadata_for_binding(contract, field_id, binding, choice_sources_by_id, opts)
        Map.put(field, "choice_source_metadata", metadata)
    end
  end

  defp metadata_for_binding(contract, field_id, binding, choice_sources_by_id, opts) do
    choice_source_id = get_value(binding, :choice_source)
    choice_source = Map.get(choice_sources_by_id, string_id(choice_source_id))

    if is_map(choice_source) do
      choice_source
      |> choice_source_base_metadata()
      |> Map.merge(%{
        "id" => string_id(choice_source_id),
        "field" => string_id(field_id),
        "status" => "linked",
        "transport" => choice_source_transport(opts)
      })
      |> put_async_options(contract, choice_source_id, opts)
      |> put_membership_validation(contract, choice_source_id, field_id, opts)
      |> QueryContract.json_safe()
    else
      %{
        "id" => string_id(choice_source_id),
        "field" => string_id(field_id),
        "status" => "unresolved",
        "async_options" => false,
        "validates_membership" => false,
        "errors" => [
          error(
            :choice_source_not_found,
            "choice source #{inspect(choice_source_id)} is not advertised by the query contract",
            [:choice_sources, choice_source_id]
          )
        ]
      }
    end
  end

  defp put_async_options(metadata, contract, choice_source_id, opts) do
    case Client.options_request(contract, choice_source_id, request_opts(opts)) do
      {:ok, %Request{} = request} ->
        metadata
        |> Map.put("async_options", true)
        |> Map.put("options_request", request_document(request))

      {:error, _error} ->
        Map.put(metadata, "async_options", false)
    end
  end

  defp put_membership_validation(metadata, contract, choice_source_id, field_id, opts) do
    placeholder = Keyword.get(opts, :validation_value_placeholder, @value_placeholder)

    request_opts =
      opts
      |> request_opts()
      |> Keyword.put(:field, field_id)

    case Client.validate_request(contract, choice_source_id, placeholder, request_opts) do
      {:ok, %Request{} = request} ->
        metadata
        |> Map.put("validates_membership", true)
        |> Map.put("validate_request_template", request_document(request))

      {:error, _error} ->
        Map.put(metadata, "validates_membership", false)
    end
  end

  defp choice_source_base_metadata(choice_source) do
    choice_source = QueryContract.json_safe(choice_source)

    choice_source
    |> Map.take(@choice_source_keys)
    |> Map.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp request_document(%Request{} = request) do
    %{
      method: request.method,
      url: request.url,
      headers: Map.new(request.headers),
      body: request.body
    }
    |> compact()
    |> QueryContract.json_safe()
  end

  defp request_opts(opts) do
    opts
    |> Keyword.take([:base_url, :headers, :params, :search, :limit, :offset])
    |> Keyword.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp choice_source_transport(opts) do
    opts
    |> Keyword.get(:transport, Keyword.get(opts, :choice_source_transport, :http))
    |> to_string()
  end

  defp binding_for_field(field, field_id, bindings_by_field) do
    Map.get(bindings_by_field, string_id(field_id)) || binding_from_field(field, field_id)
  end

  defp binding_from_field(field, field_id) do
    case get_value(field, :choice_source) do
      nil -> nil
      choice_source -> %{"field" => string_id(field_id), "choice_source" => choice_source}
    end
  end

  defp bindings_by_field(contract) do
    contract
    |> get_value(:field_choice_bindings, [])
    |> list_or_empty()
    |> Enum.reduce(%{}, fn
      binding, acc when is_map(binding) ->
        case get_value(binding, :field) do
          nil -> acc
          field -> Map.put_new(acc, string_id(field), binding)
        end

      _binding, acc ->
        acc
    end)
  end

  defp choice_sources_by_id(contract) do
    contract
    |> Client.choice_sources()
    |> Enum.reduce(%{}, fn choice_source, acc ->
      case get_value(choice_source, :id) do
        nil -> acc
        id -> Map.put_new(acc, string_id(id), choice_source)
      end
    end)
  end

  defp compact(map) do
    map
    |> Enum.reject(fn {_key, value} -> is_nil(value) or value == %{} end)
    |> Map.new()
  end

  defp list_or_empty(value) when is_list(value), do: value
  defp list_or_empty(_value), do: []

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

  defp same_id?(left, right), do: string_id(left) == string_id(right)

  defp string_id(value) when is_atom(value), do: Atom.to_string(value)
  defp string_id(value), do: to_string(value)

  defp error(code, message, path) do
    %{
      code: code,
      message: message,
      path: Enum.map(path, &QueryContract.json_safe/1)
    }
    |> QueryContract.json_safe()
  end
end
