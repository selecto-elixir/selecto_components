defmodule SelectoComponents.ParameterizedFieldBuilder do
  @moduledoc """
  Enhanced field building functionality for SelectoComponents with parameterized join support.

  This module provides functions to build field lists that are compatible with the new
  parameterized join syntax while maintaining backward compatibility with existing
  bracket notation.
  """

  alias Selecto.FieldResolver

  @doc """
  Builds enhanced column list supporting both legacy bracket notation and new dot notation.

  Returns columns in the format expected by SelectoComponents UI with additional
  metadata for parameterized joins.
  """
  def build_enhanced_column_list(selecto) do
    # Get base columns from existing column resolver
    base_columns = Map.values(Selecto.columns(selecto))

    # Add parameterized join fields that are available
    parameterized_fields = build_parameterized_field_suggestions(selecto)

    # Combine and format for UI
    (base_columns ++ parameterized_fields)
    |> Enum.sort(fn a, b -> Map.get(a, :name, "") <= Map.get(b, :name, "") end)
    |> Enum.map(fn field ->
      {
        Map.get(field, :colid, Map.get(field, :id, Map.get(field, :name))),
        format_field_display_name(field),
        Map.get(field, :format),
        build_field_metadata(field)
      }
    end)
    |> Enum.uniq_by(fn {id, _name, _format, _metadata} -> id end)
  end

  @doc """
  Builds enhanced filter list supporting parameterized joins and dot notation.
  """
  def build_enhanced_filter_list(selecto) do
    # Get filterable columns
    filterable_columns = Map.values(Selecto.columns(selecto))
    |> Enum.filter(fn column ->
      Map.get(column, :make_filter, false) or
      (not Map.has_key?(column, :format) and not Map.has_key?(column, :component))
    end)

    # Add explicit filters
    explicit_filters = Map.values(Selecto.filters(selecto))

    # Add parameterized join suggestions for filters
    parameterized_filters = build_parameterized_filter_suggestions(selecto)

    (explicit_filters ++ filterable_columns ++ parameterized_filters)
    |> List.flatten()
    |> Enum.sort(fn a, b -> Map.get(a, :name, "") <= Map.get(b, :name, "") end)
    |> Enum.map(fn field ->
      {
        Map.get(field, :colid, Map.get(field, :id, Map.get(field, :name))),
        format_field_display_name(field),
        build_field_metadata(field)
      }
    end)
    |> Enum.uniq_by(fn {id, _name, _metadata} -> id end)
  end

  @doc """
  Builds suggestions for parameterized join fields based on join configurations.

  These are example fields that users can use as templates for creating
  parameterized joins with specific parameter values.
  """
  def build_parameterized_field_suggestions(selecto) do
    selecto
    |> join_configs()
    |> Enum.filter(fn {_join_name, join_config} ->
      # Only include joins that have parameters defined
      Map.has_key?(join_config, :parameters) and
      is_list(Map.get(join_config, :parameters)) and
      length(Map.get(join_config, :parameters, [])) > 0
    end)
    |> Enum.flat_map(fn {join_name, join_config} ->
      # Generate example parameterized fields for each join
      example_params = generate_example_parameters(Map.get(join_config, :parameters, []))
      join_fields = Map.get(join_config, :fields, %{})

      Enum.flat_map(join_fields, fn {field_key, field_config} ->
        field_name = extract_field_name(field_key, field_config)

        Enum.map(example_params, fn {param_signature, param_display} ->
          dot_notation = "#{join_name}:#{param_signature}.#{field_name}"

          %{
            id: dot_notation,
            colid: dot_notation,
            name: field_name,
            qualified_name: dot_notation,
            display_name: "#{Map.get(join_config, :name, join_name)} (#{param_display}).#{field_name}",
            join: join_name,
            parameters: param_signature,
            parameter_display: param_display,
            type: Map.get(field_config, :type, :string),
            is_parameterized: true,
            is_suggestion: true,
            make_filter: Map.get(field_config, :make_filter, false)
          }
        end)
      end)
    end)
  end

  @doc """
  Builds suggestions for parameterized filter fields.
  """
  def build_parameterized_filter_suggestions(selecto) do
    build_parameterized_field_suggestions(selecto)
    |> Enum.filter(fn field ->
      Map.get(field, :make_filter, false) or
      Map.get(field, :type) in [:string, :integer, :float, :boolean, :date, :datetime]
    end)
  end

  @doc """
  Migrates a field reference from bracket notation to dot notation.

  This function helps components transition existing field references
  to the new dot notation syntax.
  """
  def migrate_field_reference(field_ref) when is_binary(field_ref) do
    cond do
      # Already dot notation or parameterized
      String.contains?(field_ref, ".") -> field_ref

      # Bracket notation to migrate
      String.contains?(field_ref, "[") && String.contains?(field_ref, "]") ->
        case Regex.run(~r/^(.+?)\[([^\]]+)\]$/, field_ref) do
          [_, join, field] -> "#{join}.#{field}"
          _ -> field_ref
        end

      # Simple field name, no change needed
      true -> field_ref
    end
  end

  def migrate_field_reference(field_ref), do: field_ref

  @doc """
  Validates a field reference against the current selecto configuration.

  Returns {:ok, field_info} or {:error, reason} for validation feedback.
  """
  def validate_field_reference(selecto, field_ref) do
    FieldResolver.resolve_field(selecto, field_ref)
  end

  @doc """
  Provides suggestions for completing partial field references.

  Useful for autocomplete functionality in field selection UI.
  """
  def suggest_field_completions(selecto, partial_field) do
    available_fields = FieldResolver.get_available_fields(selecto)
    parameterized_suggestions = build_parameterized_field_suggestions(selecto)

    all_suggestions =
      (Map.keys(available_fields) ++ Enum.map(parameterized_suggestions, & &1.qualified_name))

    all_suggestions
    |> Enum.filter(fn field ->
      String.contains?(String.downcase(field), String.downcase(partial_field))
    end)
    |> Enum.sort_by(&String.jaro_distance(&1, partial_field), :desc)
    |> Enum.take(10)
  end

  defp join_configs(selecto) do
    selecto
    |> Map.get(:config, %{})
    |> Map.get(:joins, %{})
    |> case do
      joins when is_map(joins) -> joins
      _ -> %{}
    end
  end

  # Private implementation

  defp generate_example_parameters(param_definitions) do
    # Generate a few example parameter combinations
    required_params = Enum.filter(param_definitions, &Map.get(&1, :required, false))
    optional_params = Enum.reject(param_definitions, &Map.get(&1, :required, false))

    examples = []

    # Example 1: Just required parameters
    if length(required_params) > 0 do
      {signature, display} = build_example_from_params(required_params)
      examples = [{signature, display} | examples]
    end

    # Example 2: Required + first optional
    if length(required_params) > 0 and length(optional_params) > 0 do
      first_optional = List.first(optional_params)
      {signature, display} = build_example_from_params(required_params ++ [first_optional])
      examples = [{signature, display} | examples]
    end

    # Example 3: All parameters
    if length(required_params) + length(optional_params) > 2 do
      {signature, display} = build_example_from_params(param_definitions)
      examples = [{signature, display} | examples]
    end

    # Ensure we have at least one example
    case examples do
      [] -> [{"example", "example"}]
      _ -> examples
    end
  end

  defp build_example_from_params(param_definitions) do
    param_values = Enum.map(param_definitions, &generate_example_value/1)

    signature = param_values |> Enum.map(&elem(&1, 0)) |> Enum.join(":")
    display = param_values |> Enum.map(&elem(&1, 1)) |> Enum.join(", ")

    {signature, display}
  end

  defp generate_example_value(param_def) do
    case param_def.type do
      :string ->
        example_val = Map.get(param_def, :example, param_def.name)
        {to_string(example_val), "#{param_def.name}=#{example_val}"}
      :integer ->
        example_val = Map.get(param_def, :example, 1)
        {to_string(example_val), "#{param_def.name}=#{example_val}"}
      :float ->
        example_val = Map.get(param_def, :example, 1.0)
        {to_string(example_val), "#{param_def.name}=#{example_val}"}
      :boolean ->
        example_val = Map.get(param_def, :example, true)
        {to_string(example_val), "#{param_def.name}=#{example_val}"}
      :atom ->
        example_val = Map.get(param_def, :example, param_def.name)
        {to_string(example_val), "#{param_def.name}=#{example_val}"}
      _ ->
        example_val = Map.get(param_def, :example, "value")
        {to_string(example_val), "#{param_def.name}=#{example_val}"}
    end
  end

  defp extract_field_name(field_key, field_config) do
    cond do
      is_binary(field_key) -> field_key
      is_atom(field_key) -> Atom.to_string(field_key)
      Map.has_key?(field_config, :field) -> to_string(field_config.field)
      Map.has_key?(field_config, :name) -> to_string(field_config.name)
      true -> "field"
    end
  end

  defp format_field_display_name(field) do
    cond do
      Map.has_key?(field, :display_name) -> field.display_name
      Map.has_key?(field, :is_parameterized) && field.is_parameterized ->
        "#{field.name} (#{field.parameter_display})"
      Map.has_key?(field, :qualified_name) -> field.qualified_name
      Map.has_key?(field, :name) -> field.name
      true -> "Unknown Field"
    end
  end

  defp build_field_metadata(field) do
    %{
      is_parameterized: Map.get(field, :is_parameterized, false),
      is_suggestion: Map.get(field, :is_suggestion, false),
      parameters: Map.get(field, :parameters),
      parameter_display: Map.get(field, :parameter_display),
      join: Map.get(field, :join),
      type: Map.get(field, :type, :string),
      qualified_name: Map.get(field, :qualified_name)
    }
  end
end
