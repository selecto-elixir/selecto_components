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
      {col_name, field, analyze_column(selecto, field)}
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
      info = analyze_column(selecto, field)
      {col_name, info.relationship_path}
    end)
    |> Enum.group_by(fn {_, path} -> path end, fn {name, _} -> name end)
  end

  # Private functions

  defp analyze_column(selecto, field) do
    # Get the join path for this field
    join_path = get_join_path(field)

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

  defp get_join_path(field) do
    # Extract join path from field definition
    # Check various field formats for join indicators

    # Try field name first (e.g., "entity[name]" or "orders.total")
    field_name = Map.get(field, :field) || Map.get(field, :qualified_name) || ""

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
      Map.get(field, :requires_join) not in [nil, :selecto_root] ->
        # If it requires a join, use that as the path
        [to_string(Map.get(field, :requires_join))]

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

  defp is_denormalizing_join?(_selecto, join_path) do
    # Check if this join represents a one-to-many or many-to-many relationship
    # This is determined by checking if multiple rows could be returned

    # For now, we'll use a heuristic based on common patterns
    # In a real implementation, this would check the actual schema relationships

    last_segment = List.last(join_path)

    denormalizing_patterns = [
      # Common one-to-many and many-to-many indicators
      "items",
      "details",
      "events",
      "logs",
      "payments",
      "rentals",
      "orders",
      "line_items",
      "mapping",
      "junction",
      "link"
    ]

    result = Enum.any?(denormalizing_patterns, fn pattern ->
      String.contains?(String.downcase(last_segment), pattern)
    end)

    result
  end

  defp get_relationship_type(_selecto, []) do
    :none
  end

  defp get_relationship_type(_selecto, join_path) do
    # Determine the type of relationship
    last_segment = List.last(join_path) |> to_string() |> String.downcase()

    cond do
      Enum.any?(["mapping", "junction", "link", "_join", "_map"], &String.contains?(last_segment, &1)) ->
        :many_to_many

      String.ends_with?(last_segment, "s") ->
        :one_to_many

      true -> :one_to_one
    end
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
