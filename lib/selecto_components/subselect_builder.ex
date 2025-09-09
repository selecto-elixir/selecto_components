defmodule SelectoComponents.SubselectBuilder do
  @moduledoc """
  Builds subselect queries for denormalizing columns to prevent row multiplication.
  Converts one-to-many and many-to-many relationships into JSON aggregations.
  """

  @doc """
  Builds a Selecto query with subselects for denormalizing columns.
  
  Takes a base selecto, normal columns, and denormalizing groups,
  returns an enhanced selecto with subselects.
  """
  def build_with_subselects(selecto, normal_columns, denormalizing_groups) do
    # Start with the base query and normal columns
    query = apply_normal_columns(selecto, normal_columns)
    
    # Add subselects for each denormalizing group
    Enum.reduce(denormalizing_groups, query, fn {relationship_path, columns}, acc ->
      add_subselect_for_group(acc, relationship_path, columns)
    end)
  end

  @doc """
  Separates columns into main query columns and subselect groups
  """
  def separate_columns(selecto, all_columns, prevent_denormalization \\ true) do
    if prevent_denormalization do
      SelectoComponents.DenormalizationDetector.detect_and_group_columns(selecto, all_columns)
    else
      # If prevention is disabled, all columns go to main query
      {all_columns, %{}}
    end
  end

  @doc """
  Formats subselect results for proper JSON aggregation
  """
  def format_subselect_results(results, subselect_config) do
    # Process the raw subselect results into a structured format
    case subselect_config.format do
      :json_agg ->
        format_as_json_array(results)
      :array_agg ->
        format_as_array(results)
      _ ->
        results
    end
  end

  # Private functions

  defp apply_normal_columns(selecto, columns) do
    # Apply select for normal columns that don't cause denormalization
    case columns do
      [] -> selecto
      cols -> Selecto.select(selecto, cols)
    end
  end

  def add_subselect_for_group(selecto, relationship_path, columns) do
    # Generate a subselect for a group of related columns
    # All columns for a relationship should be in ONE subselect that returns JSON objects
    
    # Extract just the field names without the table prefix
    field_names = Enum.map(columns, fn col ->
      # Remove table prefix if present (e.g., "film.description" -> "description")
      case String.split(col, ".", parts: 2) do
        [_table, field] -> field
        [field] -> field
      end
    end)
    
    IO.puts("[SUBSELECT BUILD] Creating subselect for #{relationship_path} with fields: #{inspect(field_names)}")
    
    # Create a single config for all fields of this relationship
    config = %{
      fields: field_names,
      target_schema: String.to_atom(relationship_path),
      format: :json_agg,
      alias: relationship_path  # Use the relationship path as the alias
    }
    
    # Apply a single subselect for all fields of this relationship
    Selecto.subselect(selecto, [config])
  end

  defp build_subselect_alias(relationship_path) do
    # Convert relationship path to a valid SQL alias
    # e.g., "actor" -> "actors_data"
    base = relationship_path
    |> String.split(".")
    |> List.last()
    |> pluralize()
    
    "#{base}_data"
  end

  defp pluralize(word) do
    # Simple pluralization for common patterns
    cond do
      String.ends_with?(word, "y") ->
        String.slice(word, 0..-2//1) <> "ies"
      String.ends_with?(word, "s") ->
        word
      true ->
        word <> "s"
    end
  end

  defp format_as_json_array(results) do
    # Format results as JSON array for nested display
    case results do
      nil -> []
      data when is_list(data) -> data
      data -> [data]
    end
  end

  defp format_as_array(results) do
    # Format results as simple array
    List.wrap(results)
  end

  @doc """
  Builds SQL for subselects with proper correlation
  """
  def build_subselect_sql(base_table, relationship, columns, correlation_key) do
    # This would generate the actual SQL for a correlated subquery
    # Example output:
    # (SELECT JSON_AGG(row_to_json(t)) FROM (
    #   SELECT actor.name, actor.age 
    #   FROM actor 
    #   JOIN film_actor ON actor.id = film_actor.actor_id
    #   WHERE film_actor.film_id = film.id
    # ) t) AS actors_data
    
    # For now, return a placeholder structure
    %{
      type: :subselect,
      base_table: base_table,
      relationship: relationship,
      columns: columns,
      correlation_key: correlation_key,
      format: :json_agg
    }
  end

  @doc """
  Optimizes subselects for performance
  """
  def optimize_subselects(selecto, subselect_configs) do
    # Apply optimizations like:
    # - Combining multiple subselects on same table
    # - Using lateral joins where appropriate
    # - Adding proper indexes hints
    
    selecto
  end

  @doc """
  Validates that subselects are properly configured
  """
  def validate_subselects(selecto) do
    subselects = Map.get(selecto, :subselects, [])
    
    errors = Enum.flat_map(subselects, fn subselect ->
      validate_single_subselect(subselect)
    end)
    
    case errors do
      [] -> :ok
      errors -> {:error, errors}
    end
  end

  defp validate_single_subselect(subselect) do
    errors = []
    
    # Check for required fields
    errors = if Map.has_key?(subselect, :columns) do
      errors
    else
      ["Subselect missing required 'columns' field" | errors]
    end
    
    # Check for valid alias
    errors = if Map.has_key?(subselect, :as) && is_binary(subselect.as) do
      errors
    else
      ["Subselect missing or invalid 'as' alias" | errors]
    end
    
    errors
  end

  @doc """
  Merges subselect results with main query results
  """
  def merge_results(main_results, subselect_results) do
    # Combine the main query results with subselect data
    Enum.map(main_results, fn row ->
      # Add subselect data to each row
      Enum.reduce(subselect_results, row, fn {subselect_key, subselect_data}, acc ->
        Map.put(acc, subselect_key, subselect_data)
      end)
    end)
  end

  @doc """
  Generates configuration for nested table display
  """
  def generate_nested_config(relationship_path, columns) do
    %{
      key: relationship_path,
      title: humanize_relationship(relationship_path),
      columns: prepare_nested_columns(columns),
      expandable: true,
      initial_state: :collapsed,
      max_rows: 10,
      show_more: true
    }
  end

  defp humanize_relationship(path) do
    path
    |> String.split(".")
    |> List.last()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp prepare_nested_columns(columns) do
    Enum.map(columns, fn col ->
      # Extract the actual column name from formats like "actor[name]"
      display_name = case String.split(col, ["[", "]"], trim: true) do
        [_table, field] -> field
        [field] -> field
      end
      
      %{
        field: col,
        header: String.capitalize(display_name),
        sortable: false
      }
    end)
  end
end