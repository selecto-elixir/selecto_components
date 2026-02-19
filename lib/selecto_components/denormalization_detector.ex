defmodule SelectoComponents.DenormalizationDetector do
  @moduledoc """
  Detects columns that would cause denormalization (row multiplication) in query results.
  Groups columns by their relationship path to enable subselect generation.
  """

  @doc """
  Detects columns that would cause denormalization and groups them by relationship.

  Returns a tuple of {normal_columns, denormalizing_groups}
  where denormalizing_groups is a map of relationship_path => columns
  """
  def detect_and_group_columns(selecto, selected_columns) do
    columns_with_info = Enum.map(selected_columns, fn col_name ->
      field = Selecto.field(selecto, col_name)
      {col_name, field, analyze_column(selecto, field, col_name)}
    end)

    # Separate normal columns from denormalizing ones
    {normal, denormalizing} = Enum.split_with(columns_with_info, fn {_, _, info} ->
      !info.causes_denormalization
    end)

    normal_columns = Enum.map(normal, fn {name, _, _} -> name end)

    # Group denormalizing columns by their relationship path
    denormalizing_groups =
      denormalizing
      |> Enum.group_by(fn {_, _, info} -> info.relationship_path end)
      |> Enum.map(fn {path, columns} ->
        col_names = Enum.map(columns, fn {name, _, _} -> name end)
        {path, col_names}
      end)
      |> Map.new()

    {normal_columns, denormalizing_groups}
  end

  @doc """
  Checks if a specific column would cause denormalization
  """
  def is_denormalizing_column?(selecto, field) do
    info = analyze_column(selecto, field)
    info.causes_denormalization
  end

  @doc """
  Groups columns by their relationship path for subselect generation
  """
  def group_columns_by_relationship(selecto, columns) do
    columns
    |> Enum.map(fn col_name ->
      field = Selecto.field(selecto, col_name)
      info = analyze_column(selecto, field, col_name)
      {col_name, info.relationship_path}
    end)
    |> Enum.group_by(fn {_, path} -> path end, fn {name, _} -> name end)
  end

  # Private functions

  defp analyze_column(selecto, field, fallback_field_name \\ nil) do
    # Get the join path for this field
    join_path = get_join_path(field, fallback_field_name)

    # Check if this involves a one-to-many or many-to-many relationship
    causes_denormalization = is_denormalizing_join?(selecto, join_path)

    %{
      field: field,
      join_path: join_path,
      relationship_path: build_relationship_path(join_path),
      causes_denormalization: causes_denormalization,
      relationship_type: get_relationship_type(selecto, join_path)
    }
  end

  defp get_join_path(field, fallback_field_name) do
    # Extract join path from field definition
    # Check various field formats for join indicators
    normalized_field = field || %{}

    # Try richer identifiers first (colid/qualified_name) before bare field names
    field_name =
      Map.get(normalized_field, :colid) ||
        Map.get(normalized_field, :qualified_name) ||
        Map.get(normalized_field, :field) ||
        fallback_field_name ||
        ""
      |> to_string()

    cond do
      # Check for bracket notation: "table[column]"
      String.contains?(field_name, "[") ->
        [table, _] = String.split(field_name, ["[", "]"], trim: true)
        [table]

      # Check for dot notation: "table.column"
      String.contains?(field_name, ".") ->
        parts = String.split(field_name, ".")
        # All but the last part are the join path
        Enum.take(parts, length(parts) - 1)

      # Check requires_join field
      Map.get(normalized_field, :requires_join) not in [nil, :selecto_root] ->
        # If it requires a join, use that as the path
        [to_string(Map.get(normalized_field, :requires_join))]

      true ->
        # No join required
        []
    end
  end

  defp build_relationship_path(join_path) do
    # Convert join path to a standardized relationship identifier
    Enum.join(join_path, ".")
  end

  defp is_denormalizing_join?(_selecto, []) do
    # No join means no denormalization
    false
  end

  defp is_denormalizing_join?(selecto, join_path) do
    get_relationship_type(selecto, join_path) in [:one_to_many, :many_to_many]
  end

  defp get_relationship_type(_selecto, []) do
    :none
  end

  defp get_relationship_type(selecto, join_path) do
    # Determine the type of relationship
    last_segment = List.last(join_path) |> to_string()

    relationship_type_from_config(selecto, last_segment) ||
      relationship_type_from_name(last_segment)
  end

  defp relationship_type_from_config(selecto, join_segment) do
    join_config = find_join_config(selecto, join_segment)

    if is_map(join_config) do
      cond do
        many_to_many_join?(join_segment, join_config) ->
          :many_to_many

        one_to_many_join?(selecto, join_segment, join_config) ->
          :one_to_many

        true ->
          :one_to_one
      end
    end
  end

  defp relationship_type_from_name(join_segment) do
    downcased = join_segment |> to_string() |> String.downcase()

    cond do
      Enum.any?(["mapping", "junction", "link", "_join", "_map"], &String.contains?(downcased, &1)) ->
        :many_to_many

      String.ends_with?(downcased, "s") ->
        :one_to_many

      true -> :one_to_one
    end
  end

  defp find_join_config(selecto, join_segment) do
    joins =
      selecto
      |> Map.get(:config, %{})
      |> Map.get(:joins, %{})

    Enum.find_value(joins, fn {join_id, join_config} ->
      if to_string(join_id) == join_segment, do: join_config
    end)
  end

  defp many_to_many_join?(join_segment, join_config) do
    join_type = Map.get(join_config, :join_type)

    descriptor =
      [join_segment, Map.get(join_config, :source, "")]
      |> Enum.join(" ")
      |> String.downcase()

    join_type in [:tagging, :many_to_many] ||
      Enum.any?(["mapping", "junction", "link", "_join", "_map", "tags"], &String.contains?(descriptor, &1))
  end

  defp one_to_many_join?(selecto, join_segment, join_config) do
    target_primary_key = find_target_primary_key(selecto, join_segment, join_config)
    join_target_key = Map.get(join_config, :my_key)

    cond do
      not is_nil(target_primary_key) and not is_nil(join_target_key) ->
        to_string(join_target_key) != to_string(target_primary_key)

      true ->
        relationship_type_from_name(join_segment) == :one_to_many
    end
  end

  defp find_target_primary_key(selecto, join_segment, join_config) do
    schemas =
      selecto
      |> Map.get(:domain, %{})
      |> Map.get(:schemas, %{})
    target_source_table = to_string(Map.get(join_config, :source, ""))

    Enum.find_value(schemas, fn {schema_name, schema_config} ->
      cond do
        to_string(schema_name) == join_segment ->
          Map.get(schema_config, :primary_key)

        to_string(Map.get(schema_config, :source_table)) == target_source_table ->
          Map.get(schema_config, :primary_key)

        true ->
          nil
      end
    end)
  end

  @doc """
  Analyzes a Selecto query to detect potential denormalization based on joins
  """
  def analyze_query(selecto) do
    # Get all joins from the Selecto structure
    joins = Map.get(selecto, :joins, [])

    # Analyze each join for denormalization potential
    join_analysis = Enum.map(joins, fn join ->
      %{
        table: join.table,
        type: join.type,
        causes_denormalization: join_causes_denormalization?(join),
        cardinality: estimate_join_cardinality(join)
      }
    end)

    %{
      has_denormalizing_joins: Enum.any?(join_analysis, & &1.causes_denormalization),
      joins: join_analysis
    }
  end

  defp join_causes_denormalization?(join) do
    # Check if this specific join would cause row multiplication
    join.type in [:left, :right, :full] &&
      is_one_to_many_relationship?(join)
  end

  defp is_one_to_many_relationship?(join) do
    # This would ideally check actual schema relationships.
    # For now, use common naming patterns for fan-out tables.
    table = join.table |> to_string() |> String.downcase()

    Enum.any?(~w(items details events logs payments rentals orders line_items), &String.contains?(table, &1))
  end

  defp estimate_join_cardinality(join) do
    table = join.table |> to_string() |> String.downcase()

    # Estimate whether this join produces 1:1, 1:N, or M:N results
    cond do
      Enum.any?(["mapping", "junction", "link", "_join", "_map"], &String.contains?(table, &1)) ->
        :many_to_many

      is_one_to_many_relationship?(join) -> :one_to_many
      true -> :one_to_one
    end
  end
end
