defmodule SelectoComponents.QueryContract.IntentValidator do
  @moduledoc """
  Validates generated query intents against a query contract artifact.

  This module is intentionally non-executing. It checks whether a proposed
  intent only references fields, comparators, and sort fields exposed by the
  contract, but it does not build or run a Selecto query.
  """

  @supported_view_modes ~w(detail aggregate)
  @sort_directions ~w(asc desc)

  @type diagnostic :: %{
          required(:code) => atom(),
          required(:path) => String.t(),
          required(:message) => String.t(),
          optional(:field) => String.t(),
          optional(:value) => term(),
          optional(:allowed) => [String.t()]
        }

  @type result :: %{valid?: boolean(), errors: [diagnostic()], warnings: [diagnostic()]}

  @spec validate(map(), map(), keyword()) :: result()
  def validate(contract, intent, opts \\ [])

  def validate(contract, intent, _opts) when is_map(contract) and is_map(intent) do
    indexes = indexes(contract)
    view_mode = intent_view_mode(intent)
    view_mode_errors = validate_view_mode(contract, view_mode)

    errors =
      view_mode_errors ++
        if view_mode_errors == [] do
          validate_mode_intent(view_mode, intent, indexes)
        else
          []
        end

    %{valid?: errors == [], errors: errors, warnings: []}
  end

  def validate(_contract, _intent, _opts) do
    %{
      valid?: false,
      errors: [
        error(
          :invalid_intent,
          "",
          "query intent must be a map"
        )
      ],
      warnings: []
    }
  end

  defp indexes(contract) do
    fields =
      contract
      |> map_get(:fields, [])
      |> list_or_empty()

    filters =
      contract
      |> map_get(:filters, [])
      |> list_or_empty()

    %{
      fields: Map.new(fields, &{string_id(map_get(&1, :id)), &1}),
      filters: Map.new(filters, &{string_id(map_get(&1, :id)), &1})
    }
  end

  defp intent_view_mode(intent) do
    intent
    |> map_get(:view_mode, "detail")
    |> string_id()
  end

  defp validate_view_mode(contract, view_mode) do
    allowed_view_modes = allowed_view_modes(contract)

    cond do
      view_mode not in allowed_view_modes ->
        [
          error(:invalid_view_mode, "view_mode", "view mode is not exposed by this contract",
            value: view_mode,
            allowed: allowed_view_modes
          )
        ]

      view_mode not in @supported_view_modes ->
        [
          error(
            :unsupported_view_mode,
            "view_mode",
            "view mode intent validation is not supported yet",
            value: view_mode,
            allowed: @supported_view_modes
          )
        ]

      true ->
        []
    end
  end

  defp allowed_view_modes(contract) do
    context_modes =
      contract
      |> map_get(:context, %{})
      |> map_get(:view_modes, [])
      |> list_or_empty()
      |> Enum.map(&string_id/1)

    params_modes =
      contract
      |> map_get(:params_schema, %{})
      |> map_get(:view_mode, %{})
      |> map_get(:values, [])
      |> list_or_empty()
      |> Enum.map(&string_id/1)

    case Enum.uniq(context_modes ++ params_modes) do
      [] -> @supported_view_modes
      modes -> modes
    end
  end

  defp validate_mode_intent("detail", intent, indexes) do
    validate_selected(intent, indexes) ++
      validate_filters(intent, indexes) ++
      validate_order_by(intent, indexes)
  end

  defp validate_mode_intent("aggregate", intent, indexes) do
    validate_group_by(intent, indexes) ++
      validate_metrics(intent, indexes) ++
      validate_filters(intent, indexes) ++
      validate_order_by(intent, indexes)
  end

  defp validate_mode_intent(_view_mode, _intent, _indexes), do: []

  defp validate_selected(intent, indexes) do
    {selected, base_path} = intent_list(intent, [:select, :selected])

    Enum.flat_map(selected, fn {item, path} ->
      case item_field_id(item) do
        nil ->
          [error(:invalid_field_reference, path, "selected item must include a field id")]

        field_id ->
          validate_field_capability(
            indexes,
            field_id,
            "detail_selectable",
            :field_not_selectable,
            path
          )
      end
    end)
    |> maybe_invalid_list(intent, base_path, [:select, :selected])
  end

  defp validate_filters(intent, indexes) do
    {filters, base_path} = intent_list(intent, [:filters])

    errors =
      Enum.flat_map(filters, fn {filter, path} ->
        field_id = filter_field_id(filter, indexes)
        comparator = comparator_id(filter)

        cond do
          not is_map(filter) ->
            [error(:invalid_filter, path, "filter item must be a map")]

          is_nil(field_id) ->
            [error(:invalid_field_reference, "#{path}.field", "filter must include a field id")]

          true ->
            validate_field_capability(
              indexes,
              field_id,
              "filterable",
              :field_not_filterable,
              "#{path}.field"
            ) ++
              validate_comparator(indexes, field_id, comparator, "#{path}.comparator")
        end
      end)

    maybe_invalid_list(errors, intent, base_path, [:filters])
  end

  defp validate_group_by(intent, indexes) do
    {group_by, base_path} = intent_list(intent, [:group_by])

    Enum.flat_map(group_by, fn {item, path} ->
      case item_field_id(item) do
        nil ->
          [error(:invalid_field_reference, path, "group_by item must include a field id")]

        field_id ->
          validate_field_capability(indexes, field_id, "groupable", :field_not_groupable, path)
      end
    end)
    |> maybe_invalid_list(intent, base_path, [:group_by])
  end

  defp validate_metrics(intent, indexes) do
    {metrics, base_path} = intent_list(intent, [:metrics, :aggregate, :aggregates, :selected])

    errors =
      Enum.flat_map(metrics, fn {metric, path} ->
        field_id = item_field_id(metric)
        aggregate_function = aggregate_function_id(metric)

        cond do
          is_nil(field_id) ->
            [error(:invalid_field_reference, "#{path}.field", "metric must include a field id")]

          true ->
            validate_field_capability(
              indexes,
              field_id,
              "aggregatable",
              :field_not_aggregatable,
              "#{path}.field"
            ) ++
              validate_aggregate_function(
                indexes,
                field_id,
                aggregate_function,
                "#{path}.function"
              )
        end
      end)

    maybe_invalid_list(errors, intent, base_path, [:metrics, :aggregate, :aggregates, :selected])
  end

  defp validate_order_by(intent, indexes) do
    {orders, base_path} = intent_list(intent, [:order_by, :sort])

    errors =
      Enum.flat_map(orders, fn {order, path} ->
        field_id = item_field_id(order)
        direction = sort_direction(order)

        cond do
          is_nil(field_id) ->
            [
              error(
                :invalid_field_reference,
                "#{path}.field",
                "sort item must include a field id"
              )
            ]

          direction not in @sort_directions ->
            [
              error(
                :invalid_sort_direction,
                "#{path}.direction",
                "sort direction must be asc or desc",
                value: direction,
                allowed: @sort_directions
              )
            ] ++
              validate_field_capability(
                indexes,
                field_id,
                "sortable",
                :field_not_sortable,
                "#{path}.field"
              )

          true ->
            validate_field_capability(
              indexes,
              field_id,
              "sortable",
              :field_not_sortable,
              "#{path}.field"
            )
        end
      end)

    maybe_invalid_list(errors, intent, base_path, [:order_by, :sort])
  end

  defp validate_field_capability(indexes, field_id, capability, capability_error, path) do
    case Map.fetch(indexes.fields, string_id(field_id)) do
      {:ok, field} ->
        if map_get(field, capability, false) do
          []
        else
          [
            error(capability_error, path, "field is not allowed for this query use",
              field: string_id(field_id)
            )
          ]
        end

      :error ->
        [
          error(:invalid_field, path, "field is not exposed by this contract",
            field: string_id(field_id)
          )
        ]
    end
  end

  defp validate_comparator(_indexes, _field_id, nil, path) do
    [error(:missing_comparator, path, "filter must include a comparator")]
  end

  defp validate_comparator(indexes, field_id, comparator, path) do
    field = Map.get(indexes.fields, string_id(field_id), %{})

    comparators =
      field
      |> map_get(:comparators, [])
      |> list_or_empty()
      |> Enum.map(&string_id/1)

    comparator = string_id(comparator)

    if comparator in comparators do
      []
    else
      [
        error(:invalid_comparator, path, "comparator is not exposed for this field",
          field: string_id(field_id),
          value: comparator,
          allowed: comparators
        )
      ]
    end
  end

  defp validate_aggregate_function(_indexes, _field_id, nil, path) do
    [error(:missing_aggregate_function, path, "metric must include an aggregate function")]
  end

  defp validate_aggregate_function(indexes, field_id, aggregate_function, path) do
    field = Map.get(indexes.fields, string_id(field_id), %{})

    aggregate_functions =
      field
      |> map_get(:aggregate_functions, [])
      |> list_or_empty()
      |> Enum.map(&string_id/1)

    aggregate_function = string_id(aggregate_function)

    if aggregate_function in aggregate_functions do
      []
    else
      [
        error(
          :invalid_aggregate_function,
          path,
          "aggregate function is not exposed for this field",
          field: string_id(field_id),
          value: aggregate_function,
          allowed: aggregate_functions
        )
      ]
    end
  end

  defp intent_list(intent, keys) do
    key = Enum.find(keys, &map_has_key?(intent, &1))

    case key do
      nil ->
        {[], Atom.to_string(List.first(keys))}

      key ->
        value = map_get(intent, key)
        base_path = Atom.to_string(key)

        {indexed_items(value, base_path), base_path}
    end
  end

  defp maybe_invalid_list(errors, intent, base_path, keys) do
    key = Enum.find(keys, &map_has_key?(intent, &1))

    if key && not list_like?(map_get(intent, key)) do
      [error(:invalid_list, base_path, "intent value must be a list or map") | errors]
    else
      errors
    end
  end

  defp indexed_items(nil, _base_path), do: []

  defp indexed_items(items, base_path) when is_list(items) do
    items
    |> Enum.with_index()
    |> Enum.map(fn {item, index} -> {item, "#{base_path}.#{index}"} end)
  end

  defp indexed_items(items, base_path) when is_map(items) do
    items
    |> Enum.sort_by(fn {key, _value} -> to_string(key) end)
    |> Enum.map(fn {key, item} -> {item, "#{base_path}.#{key}"} end)
  end

  defp indexed_items(_items, _base_path), do: []

  defp list_like?(value), do: is_nil(value) or is_list(value) or is_map(value)

  defp filter_field_id(filter, indexes) when is_map(filter) do
    field_id = item_field_id(filter)

    case Map.fetch(indexes.filters, string_id(field_id)) do
      {:ok, filter_descriptor} ->
        map_get(filter_descriptor, :field) || field_id

      :error ->
        field_id
    end
  end

  defp filter_field_id(_filter, _indexes), do: nil

  defp item_field_id(value) when is_binary(value) or is_atom(value), do: string_id(value)

  defp item_field_id(value) when is_map(value) do
    map_get(value, :field) || map_get(value, :id) || map_get(value, :filter)
  end

  defp item_field_id([field | _rest]), do: field
  defp item_field_id({field, _direction}), do: field
  defp item_field_id(_value), do: nil

  defp comparator_id(filter) when is_map(filter) do
    map_get(filter, :comparator) ||
      map_get(filter, :comp) ||
      map_get(filter, :operator) ||
      map_get(filter, :op)
  end

  defp comparator_id(_filter), do: nil

  defp aggregate_function_id(metric) when is_map(metric) do
    map_get(metric, :function) ||
      map_get(metric, :aggregate_function) ||
      map_get(metric, :aggregate) ||
      map_get(metric, :format)
  end

  defp aggregate_function_id([_field, function | _rest]), do: function
  defp aggregate_function_id({_field, function}), do: function
  defp aggregate_function_id(_metric), do: nil

  defp sort_direction(order) when is_map(order) do
    order
    |> then(fn order ->
      map_get(order, :direction) || map_get(order, :dir) || map_get(order, :sort) || "asc"
    end)
    |> string_id()
    |> String.downcase()
  end

  defp sort_direction([_field, direction | _rest]),
    do: direction |> string_id() |> String.downcase()

  defp sort_direction({_field, direction}), do: direction |> string_id() |> String.downcase()
  defp sort_direction(_order), do: "asc"

  defp error(code, path, message, extra \\ []) do
    extra
    |> Map.new()
    |> Map.merge(%{code: code, path: path, message: message})
  end

  defp map_has_key?(map, key) when is_map(map) and is_atom(key) do
    Map.has_key?(map, key) or Map.has_key?(map, Atom.to_string(key))
  end

  defp map_has_key?(_map, _key), do: false

  defp map_get(map, key, default \\ nil)

  defp map_get(map, key, default) when is_map(map) and is_atom(key) do
    string_key = Atom.to_string(key)

    cond do
      Map.has_key?(map, key) -> Map.get(map, key)
      Map.has_key?(map, string_key) -> Map.get(map, string_key)
      true -> default
    end
  end

  defp map_get(map, key, default) when is_map(map) and is_binary(key) do
    atom_key = existing_atom(key)

    cond do
      Map.has_key?(map, key) -> Map.get(map, key)
      atom_key && Map.has_key?(map, atom_key) -> Map.get(map, atom_key)
      true -> default
    end
  end

  defp map_get(_map, _key, default), do: default

  defp existing_atom(value) do
    String.to_existing_atom(value)
  rescue
    ArgumentError -> nil
  end

  defp list_or_empty(value) when is_list(value), do: value
  defp list_or_empty(_value), do: []

  defp string_id(nil), do: nil
  defp string_id(value), do: to_string(value)
end
