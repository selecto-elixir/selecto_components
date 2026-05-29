defmodule SelectoComponents.SchemaUtils do
  @moduledoc false

  def with_resolved_type(nil, column), do: column

  def with_resolved_type(selecto, %{} = column) do
    Map.put(column, :type, resolved_type(selecto, column))
  end

  def with_resolved_type(_selecto, column), do: column

  def resolved_type(nil, %{} = column), do: Map.get(column, :type, :string)
  def resolved_type(nil, _column), do: :string

  def resolved_type(selecto, %{} = column) do
    merged_column =
      case Map.get(column, :colid) do
        colid
        when (is_binary(colid) and colid != "") or (is_atom(colid) and not is_nil(colid)) ->
          case Selecto.field(selecto, colid) do
            nil -> column
            field_info -> Map.merge(field_info, column)
          end

        _ ->
          column
      end

    case schema_field_type(selecto, merged_column) do
      nil -> Map.get(merged_column, :type, :string)
      type -> type
    end
  end

  def resolved_type(selecto, field)
      when (is_binary(field) and field != "") or (is_atom(field) and not is_nil(field)) do
    case Selecto.field(selecto, field) do
      nil ->
        resolved_type(selecto, field_fallback_metadata(field))

      column ->
        resolved_type(selecto, column)
    end
  end

  def resolved_type(_selecto, _field), do: :string

  def uuid_type?(type), do: normalize_type(type) == :uuid

  @doc false
  def lookup_domain_column_metadata(selecto, schema_ref, field_name)
      when is_binary(schema_ref) and is_binary(field_name) do
    schemas = get_in(Selecto.domain(selecto), [:schemas]) || %{}

    case find_schema_config(schemas, schema_ref) do
      %{columns: columns} when is_map(columns) ->
        lookup_column_in_schema(columns, field_name)

      _ ->
        nil
    end
  end

  def lookup_domain_column_metadata(_selecto, _schema_ref, _field_name), do: nil

  defp find_schema_config(schemas, schema_ref) when is_map(schemas) do
    cond do
      Map.has_key?(schemas, schema_ref) ->
        Map.get(schemas, schema_ref)

      true ->
        Enum.find_value(schemas, fn {key, config} ->
          if schema_ref_matches?(key, config, schema_ref), do: config
        end) ||
          case safe_existing_atom(schema_ref) do
            {:ok, atom} -> Map.get(schemas, atom)
            :error -> nil
          end
    end
  end

  defp schema_ref_matches?(key, config, schema_ref) do
    key_str = to_string(key)
    source_table = config |> Map.get(:source_table) |> to_string()

    schema_ref == key_str or schema_ref == source_table or
      String.ends_with?(key_str, "." <> schema_ref)
  end

  defp lookup_column_in_schema(columns, field_name) do
    Map.get(columns, field_name) ||
      case safe_existing_atom(field_name) do
        {:ok, atom} -> Map.get(columns, atom)
        :error -> nil
      end
  end

  defp schema_field_type(selecto, column) do
    with {:ok, field_atom} <- field_atom(column),
         {:ok, schema_module} <- schema_module(column, selecto),
         true <- function_exported?(schema_module, :__schema__, 2),
         type when not is_nil(type) <- schema_module.__schema__(:type, field_atom) do
      normalize_type(type)
    else
      _ -> nil
    end
  end

  defp schema_module(column, selecto) do
    join_ref =
      Map.get(column, :requires_join) ||
        Map.get(column, :source_join) ||
        inferred_join_ref(column)

    case join_ref do
      :selecto_root ->
        module = get_in(Selecto.domain(selecto), [:source, :schema_module])
        if is_atom(module), do: {:ok, module}, else: :error

      join when is_atom(join) ->
        module = get_in(Selecto.domain(selecto), [:schemas, join, :schema_module])
        if is_atom(module), do: {:ok, module}, else: :error

      join when is_binary(join) ->
        case safe_existing_atom(join) do
          {:ok, join_atom} -> schema_module(Map.put(column, :requires_join, join_atom), selecto)
          :error -> :error
        end

      _ ->
        :error
    end
  end

  defp field_atom(column) do
    column
    |> field_name()
    |> safe_existing_atom()
  end

  defp field_name(column) do
    Map.get(column, :field) || inferred_field_name(column)
  end

  defp inferred_field_name(column) do
    column
    |> Map.get(:colid)
    |> case do
      nil -> nil
      colid -> colid |> to_string() |> String.split(".") |> List.last()
    end
  end

  defp inferred_join_ref(column) do
    column
    |> Map.get(:colid)
    |> case do
      nil ->
        nil

      colid ->
        case String.split(to_string(colid), ".", parts: 2) do
          [_field_only] -> :selecto_root
          [join, _field] -> join
        end
    end
  end

  defp field_fallback_metadata(field) do
    %{field: inferred_field_name(%{colid: field}), colid: field, type: :string}
  end

  defp safe_existing_atom(value) when is_atom(value), do: {:ok, value}

  defp safe_existing_atom(value) when is_binary(value) do
    try do
      {:ok, String.to_existing_atom(value)}
    rescue
      ArgumentError -> :error
    end
  end

  defp safe_existing_atom(_value), do: :error

  defp normalize_type(type) do
    type =
      if function_exported?(Selecto.TypeSystem, :normalize_type, 1) do
        Selecto.TypeSystem.normalize_type(type)
      else
        type
      end

    case type do
      :binary_id -> :uuid
      Ecto.UUID -> :uuid
      other -> other
    end
  end
end
