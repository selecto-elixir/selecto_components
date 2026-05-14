defmodule SelectoComponents.QueryContract do
  @moduledoc """
  Components-facing adapter for Selecto query contracts.

  This module keeps SelectoComponents from walking raw domain internals when it
  needs query metadata for tooling, documentation, or future AI-facing surfaces.
  It delegates the actual normalization and projection work to core Selecto.
  """

  alias Selecto.Domain
  alias SelectoComponents.Form.ChoiceSourceMetadata
  alias SelectoComponents.QueryContract.IntentValidator
  alias SelectoComponents.QueryContract.Links

  @query_contract_version 1
  @default_context %{
    view_modes: [:detail, :aggregate, :graph],
    default_view_mode: :detail,
    exports: [],
    saved_views_enabled: false,
    exported_views_enabled: false,
    ai_actions_enabled: false
  }
  @default_params_schema %{
    view_mode: %{type: :enum, values: [:detail, :aggregate, :graph], default: :detail},
    detail: %{
      selected: %{type: :array, items: :field_id},
      filters: %{type: :array, items: :filter},
      order_by: %{type: :array, items: :order_by}
    },
    aggregate: %{
      selected: %{type: :array, items: :field_id},
      group_by: %{type: :array, items: :field_id},
      filters: %{type: :array, items: :filter}
    },
    graph: %{
      x_axis: %{type: :array, items: :field_id},
      y_axis: %{type: :array, items: :metric},
      series: %{type: :array, items: :field_id},
      filters: %{type: :array, items: :filter}
    }
  }
  @default_errors %{
    codes: [
      %{code: :invalid_view_mode, message: "Requested view mode is not exposed by this contract"},
      %{code: :invalid_field, message: "Requested field id is not exposed by this contract"},
      %{code: :invalid_filter, message: "Requested filter id or comparator is not valid"},
      %{code: :invalid_params, message: "Requested query state does not match params_schema"}
    ]
  }

  @type diagnostics :: Selecto.Domain.Diagnostics.t()
  @type result :: {:ok, map(), diagnostics()} | {:error, diagnostics()}

  @doc """
  Builds a constrained query contract from a domain-shaped input.

  Accepted inputs are:

  - an authored Selecto domain map
  - an already-normalized Selecto domain
  - a configured `%Selecto{}` or selecto-like map containing `:domain`
  """
  @spec build(term()) :: result()
  def build(input) do
    input
    |> query_contract_input()
    |> Domain.query_contract()
  end

  @doc """
  Alias for `build/1`.
  """
  @spec query_contract(term()) :: result()
  def query_contract(input), do: build(input)

  @doc """
  Builds a JSON-ready query contract document.

  The returned map has string keys and JSON-compatible values so callers can
  serve it directly from a future `query_contract.json` endpoint without leaking
  Elixir atoms or structs into the public artifact.
  """
  @spec json_document(term(), keyword()) :: result()
  def json_document(input, opts \\ []) do
    with {:ok, contract, diagnostics} <- build(input) do
      document =
        contract
        |> Map.put(:query_contract_version, @query_contract_version)
        |> put_contract_envelope(opts)
        |> maybe_put_form_metadata(opts)
        |> json_safe()

      {:ok, document, diagnostics}
    end
  end

  @doc """
  Encodes the JSON-ready query contract document.
  """
  @spec encode_json(term(), keyword()) ::
          {:ok, String.t(), diagnostics()} | {:error, diagnostics()}
  def encode_json(input, opts \\ []) do
    with {:ok, document, diagnostics} <- json_document(input, opts) do
      {:ok, Jason.encode!(document, json_encode_opts(opts)), diagnostics}
    end
  end

  @doc """
  Validates a generated query intent against a query contract.

  The validator is deliberately non-executing. It accepts either an existing
  query contract artifact or a domain-shaped input that can be projected into a
  query contract, then checks that the intent only references exposed detail
  fields, filter comparators, and sort fields.
  """
  @spec validate_intent(term(), map(), keyword()) :: IntentValidator.result()
  def validate_intent(input, intent, opts \\ []) do
    case query_contract_document(input, opts) do
      {:ok, document} ->
        IntentValidator.validate(document, intent, opts)

      {:error, diagnostics} ->
        %{
          valid?: false,
          errors: [
            %{
              code: :invalid_query_contract,
              path: "",
              message: "query contract input is invalid",
              diagnostics: diagnostics.errors
            }
          ],
          warnings: diagnostics.warnings
        }
    end
  end

  defp put_contract_envelope(contract, opts) do
    contract
    |> Map.put(:generated_at, generated_at(opts))
    |> Map.put(:domain, domain_document(contract, opts))
    |> put_choice_source_links(opts)
    |> maybe_put_links(opts)
    |> Map.put(:context, context_document(opts))
    |> Map.put(:params_schema, params_schema_document(opts))
    |> Map.put(:examples, Keyword.get(opts, :examples, []))
    |> Map.put(:errors, Keyword.get(opts, :errors, @default_errors))
  end

  defp maybe_put_form_metadata(contract, opts) do
    if form_metadata_enabled?(opts) do
      Map.update(contract, :fields, [], fn _fields ->
        ChoiceSourceMetadata.fields(contract, opts)
      end)
    else
      contract
    end
  end

  defp form_metadata_enabled?(opts) do
    Keyword.get(opts, :form_metadata, false) ||
      Keyword.get(opts, :choice_source_field_metadata, false)
  end

  defp generated_at(opts) do
    case Keyword.get(opts, :generated_at) do
      nil ->
        DateTime.utc_now()
        |> DateTime.truncate(:second)
        |> DateTime.to_iso8601()

      %DateTime{} = datetime ->
        DateTime.to_iso8601(datetime)

      generated_at ->
        generated_at
    end
  end

  defp domain_document(contract, opts) do
    %{
      id: Keyword.get(opts, :domain_id),
      name: Keyword.get(opts, :domain_name) || Map.get(contract, :name),
      description: Keyword.get(opts, :domain_description),
      path: Keyword.get(opts, :domain_path) || Keyword.get(opts, :path)
    }
  end

  defp maybe_put_links(contract, opts) do
    case Links.document(opts) do
      links when links == %{} -> contract
      links -> Map.put(contract, :links, links)
    end
  end

  defp put_choice_source_links(contract, opts) do
    choice_source_links = option_map(Keyword.get(opts, :choice_source_links, %{}))

    if choice_source_links == %{} do
      contract
    else
      Map.update(contract, :choice_sources, [], fn choice_sources ->
        Enum.map(choice_sources, &put_choice_source_link(&1, choice_source_links))
      end)
    end
  end

  defp put_choice_source_link(choice_source, choice_source_links) when is_map(choice_source) do
    id = Map.get(choice_source, :id) || Map.get(choice_source, "id")

    case choice_source_link_entry(choice_source_links, id) do
      links when links == %{} ->
        choice_source

      links ->
        Map.put(choice_source, :links, links)
    end
  end

  defp put_choice_source_link(choice_source, _choice_source_links), do: choice_source

  defp choice_source_link_entry(choice_source_links, id) do
    choice_source_links
    |> fetch_choice_source_link(id)
    |> option_map()
    |> Enum.reject(fn {_key, value} -> is_nil(value) or value == "" end)
    |> Map.new()
  end

  defp fetch_choice_source_link(_choice_source_links, nil), do: %{}

  defp fetch_choice_source_link(choice_source_links, id) when is_map(choice_source_links) do
    Map.get(choice_source_links, id) ||
      Map.get(choice_source_links, to_string(id)) ||
      string_key_lookup(choice_source_links, id) ||
      %{}
  end

  defp string_key_lookup(choice_source_links, id) do
    Enum.find_value(choice_source_links, fn
      {key, value} when is_atom(key) or is_binary(key) ->
        if to_string(key) == to_string(id), do: value

      _entry ->
        nil
    end)
  end

  defp context_document(opts) do
    context = Map.merge(@default_context, option_map(Keyword.get(opts, :context, %{})))

    Enum.reduce(
      [
        :view_modes,
        :default_view_mode,
        :exports,
        :saved_views_enabled,
        :exported_views_enabled,
        :ai_actions_enabled
      ],
      context,
      fn key, acc ->
        if Keyword.has_key?(opts, key),
          do: Map.put(acc, key, Keyword.fetch!(opts, key)),
          else: acc
      end
    )
  end

  defp params_schema_document(opts) do
    Map.merge(@default_params_schema, option_map(Keyword.get(opts, :params_schema, %{})))
  end

  defp option_map(value) when is_map(value), do: value
  defp option_map(value) when is_list(value), do: Map.new(value)
  defp option_map(_value), do: %{}

  defp json_encode_opts(opts), do: Keyword.take(opts, [:pretty, :escape])

  defp query_contract_document(input, opts) when is_map(input) do
    if query_contract_document?(input) do
      {:ok, input}
    else
      json_document(input, opts)
      |> case do
        {:ok, document, _diagnostics} -> {:ok, document}
        {:error, diagnostics} -> {:error, diagnostics}
      end
    end
  end

  defp query_contract_document(input, opts) do
    case json_document(input, opts) do
      {:ok, document, _diagnostics} -> {:ok, document}
      {:error, diagnostics} -> {:error, diagnostics}
    end
  end

  defp query_contract_document?(input) do
    projection = document_get(input, :projection)
    version = document_get(input, :query_contract_version)

    (projection in [:query_contract, "query_contract"] or not is_nil(version)) and
      is_list(document_get(input, :fields, []))
  end

  defp document_get(map, key, default \\ nil) when is_map(map) and is_atom(key) do
    string_key = Atom.to_string(key)

    cond do
      Map.has_key?(map, key) -> Map.get(map, key)
      Map.has_key?(map, string_key) -> Map.get(map, string_key)
      true -> default
    end
  end

  defp query_contract_input(
         %{
           schema_version: _schema_version,
           domain: %{},
           query: %{},
           projection: %{},
           sections: _sections
         } = normalized
       ) do
    normalized
  end

  defp query_contract_input(%Selecto{domain: domain}) when is_map(domain), do: domain

  defp query_contract_input(%{domain: domain}) when is_map(domain), do: domain

  defp query_contract_input(%{"domain" => domain}) when is_map(domain), do: domain

  defp query_contract_input(input), do: input

  @doc false
  @spec json_safe(term()) :: term()
  def json_safe(%DateTime{} = value), do: DateTime.to_iso8601(value)
  def json_safe(%NaiveDateTime{} = value), do: NaiveDateTime.to_iso8601(value)
  def json_safe(%Date{} = value), do: Date.to_iso8601(value)
  def json_safe(%Time{} = value), do: Time.to_iso8601(value)

  def json_safe(value) when is_map(value) do
    Enum.reduce(value, %{}, fn {key, value}, acc ->
      case json_safe(value) do
        nil -> acc
        safe_value -> Map.put(acc, json_key(key), safe_value)
      end
    end)
  end

  def json_safe(value) when is_list(value), do: Enum.map(value, &json_safe/1)

  def json_safe(value) when is_tuple(value) do
    value
    |> Tuple.to_list()
    |> json_safe()
  end

  def json_safe(value) when is_atom(value) and value in [nil, true, false], do: value
  def json_safe(value) when is_atom(value), do: Atom.to_string(value)
  def json_safe(value) when is_binary(value), do: value
  def json_safe(value) when is_number(value), do: value

  def json_safe(value), do: inspect(value)

  defp json_key(value) when is_atom(value), do: Atom.to_string(value)
  defp json_key(value) when is_binary(value), do: value
  defp json_key(value), do: inspect(value)
end
