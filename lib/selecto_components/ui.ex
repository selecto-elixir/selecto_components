defmodule SelectoComponents.UI do
  @moduledoc """
  Pure UI rendering functions for SelectoComponents.
  
  Contains functions for building UI data structures and rendering helpers
  without state management or business logic concerns.
  
  Updated to support parameterized joins with dot notation while maintaining
  backward compatibility with existing bracket notation.
  """

  alias SelectoComponents.ParameterizedFieldBuilder

  @doc """
  Builds the column list for UI display from a selecto structure.
  
  Enhanced to support parameterized joins with suggestions and backward compatibility.
  """
  def build_column_list(selecto) do
    try do
      # Try enhanced builder first (supports parameterized joins)
      ParameterizedFieldBuilder.build_enhanced_column_list(selecto)
    rescue
      _ ->
        # Fall back to legacy builder for compatibility
        build_legacy_column_list(selecto)
    end
  end

  @doc """
  Builds the filter list for UI display from a selecto structure.
  
  Enhanced to support parameterized joins with suggestions and backward compatibility.
  """
  def build_filter_list(selecto) do
    try do
      # Try enhanced builder first (supports parameterized joins)
      ParameterizedFieldBuilder.build_enhanced_filter_list(selecto)
    rescue
      _ ->
        # Fall back to legacy builder for compatibility
        build_legacy_filter_list(selecto)
    end
  end

  @doc """
  Legacy column list builder for backward compatibility.
  """
  def build_legacy_column_list(selecto) do
    Map.values(Selecto.columns(selecto))
    |> Enum.sort(fn a, b -> Map.get(a, :name, "") <= Map.get(b, :name, "") end)
    |> Enum.map(fn c -> {Map.get(c, :colid), Map.get(c, :name), Map.get(c, :format)} end)
  end

  @doc """
  Legacy filter list builder for backward compatibility.
  """
  def build_legacy_filter_list(selecto) do
    # Include explicit filters and only columns that are marked as filterable
    filterable_columns = Map.values(Selecto.columns(selecto))
    |> Enum.filter(fn column ->
      # Only include columns that are explicitly marked as filterable
      # or don't have component formatting (which indicates they're display-only)
      Map.get(column, :make_filter, false) or 
      (not Map.has_key?(column, :format) and not Map.has_key?(column, :component))
    end)
    
    (Map.values(Selecto.filters(selecto)) ++ filterable_columns)
    |> List.flatten()
    |> Enum.sort(fn a, b -> Map.get(a, :name, "") <= Map.get(b, :name, "") end)
    |> Enum.map(fn
      %{colid: id} = c -> {id, Map.get(c, :name)}
      %{id: id} = c -> {id, Map.get(c, :name)}
    end)
  end

  @doc """
  Prepares assigns for the main form template rendering.
  """
  def prepare_form_assigns(state, additional_assigns \\ %{}) do
    base_assigns = %{
      columns: build_column_list(state.selecto),
      field_filters: build_filter_list(state.selecto),
      active_tab: state.active_tab,
      view_config: state.view_config,
      selecto: state.selecto,
      execution_error: state.execution_error,
      query_results: state.query_results
    }
    
    Map.merge(base_assigns, additional_assigns)
  end

  @doc """
  Determines CSS classes for tab visibility.
  """
  def tab_class(active_tab, tab_name) do
    if active_tab == tab_name or (active_tab == nil and tab_name == "view") do
      "border-solid border rounded-md border-gray-300 min-h-96 max-h-screen overflow-auto p-1 bg-base-100 text-base-content"
    else
      "hidden"
    end
  end

  @doc """
  Formats error messages for display.
  """
  def format_error_message(error) when is_nil(error), do: nil
  def format_error_message(error) do
    case error do
      %{message: message} -> message
      %{reason: reason} -> to_string(reason)
      error when is_binary(error) -> error
      error -> inspect(error)
    end
  end

  @doc """
  Builds form configuration for Phoenix forms.
  """
  def build_form_config(view_config) do
    Ecto.Changeset.cast({%{}, %{}}, view_config, []) |> Phoenix.HTML.Form.to_form(as: "view_config")
  end

  @doc """
  Determines if saved views should be shown.
  """
  def show_saved_views?(assigns) do
    Map.get(assigns, :saved_view_module, false)
  end

  @doc """
  Extracts view mode from view configuration.
  """
  def extract_view_mode(view_config) do
    Map.get(view_config, :view_mode, "aggregate")
  end

  @doc """
  Validates if a tab name is valid.
  """
  def valid_tab?(tab) when tab in ["view", "filter", "save", "export"], do: true
  def valid_tab?(_), do: false

  @doc """
  Gets the default view if none is specified.
  """
  def default_view(views) do
    case List.first(views) do
      {id, _, _, _} -> Atom.to_string(id)
      _ -> "aggregate"
    end
  end

  @doc """
  Migrates field references in view configuration from bracket to dot notation.
  
  This function helps maintain backward compatibility while transitioning
  to the new dot notation syntax.
  """
  def migrate_view_config_fields(view_config) when is_map(view_config) do
    view_config
    |> migrate_selected_fields()
    |> migrate_group_by_fields()  
    |> migrate_filter_fields()
    |> migrate_order_by_fields()
  end

  def migrate_view_config_fields(view_config), do: view_config

  @doc """
  Validates field references in a view configuration against selecto instance.
  """
  def validate_view_config_fields(selecto, view_config) do
    errors = []
    
    # Validate selected fields
    errors = validate_field_list(selecto, Map.get(view_config, :selected, []), "selected") ++ errors
    
    # Validate group by fields
    errors = validate_field_list(selecto, Map.get(view_config, :group_by, []), "group_by") ++ errors
    
    # Validate filter fields
    filter_errors = validate_filter_fields(selecto, Map.get(view_config, :filters, []))
    errors = filter_errors ++ errors
    
    case errors do
      [] -> {:ok, view_config}
      errors -> {:error, errors}
    end
  end

  @doc """
  Suggests field completions for autocomplete functionality.
  """
  def suggest_field_completions(selecto, partial_field) do
    ParameterizedFieldBuilder.suggest_field_completions(selecto, partial_field)
  end

  # Private implementation for field migration

  defp migrate_selected_fields(view_config) do
    case Map.get(view_config, :selected) do
      nil -> view_config
      selected_fields when is_list(selected_fields) ->
        migrated_fields = Enum.map(selected_fields, &ParameterizedFieldBuilder.migrate_field_reference/1)
        Map.put(view_config, :selected, migrated_fields)
      _ -> view_config
    end
  end

  defp migrate_group_by_fields(view_config) do
    case Map.get(view_config, :group_by) do
      nil -> view_config
      group_by_fields when is_list(group_by_fields) ->
        migrated_fields = Enum.map(group_by_fields, &ParameterizedFieldBuilder.migrate_field_reference/1)
        Map.put(view_config, :group_by, migrated_fields)
      _ -> view_config
    end
  end

  defp migrate_filter_fields(view_config) do
    case Map.get(view_config, :filters) do
      nil -> view_config
      filters when is_list(filters) ->
        migrated_filters = Enum.map(filters, &migrate_single_filter/1)
        Map.put(view_config, :filters, migrated_filters)
      _ -> view_config
    end
  end

  defp migrate_order_by_fields(view_config) do
    case Map.get(view_config, :order_by) do
      nil -> view_config
      order_by_fields when is_list(order_by_fields) ->
        migrated_fields = Enum.map(order_by_fields, fn
          {field, direction} -> 
            {ParameterizedFieldBuilder.migrate_field_reference(field), direction}
          field -> 
            ParameterizedFieldBuilder.migrate_field_reference(field)
        end)
        Map.put(view_config, :order_by, migrated_fields)
      _ -> view_config
    end
  end

  defp migrate_single_filter(filter) when is_map(filter) do
    case Map.get(filter, :field) do
      nil -> filter
      field_ref -> Map.put(filter, :field, ParameterizedFieldBuilder.migrate_field_reference(field_ref))
    end
  end

  defp migrate_single_filter(filter), do: filter

  defp validate_field_list(_selecto, [], _context), do: []
  defp validate_field_list(selecto, fields, context) when is_list(fields) do
    fields
    |> Enum.with_index()
    |> Enum.flat_map(fn {field, index} ->
      case ParameterizedFieldBuilder.validate_field_reference(selecto, field) do
        {:ok, _field_info} -> []
        {:error, reason} -> 
          [%{
            context: context,
            field: field,
            index: index,
            error: reason,
            message: "Invalid field '#{field}' in #{context}: #{inspect(reason)}"
          }]
      end
    end)
  end

  defp validate_field_list(_selecto, _fields, _context), do: []

  defp validate_filter_fields(_selecto, []), do: []
  defp validate_filter_fields(selecto, filters) when is_list(filters) do
    filters
    |> Enum.with_index()
    |> Enum.flat_map(fn {filter, index} ->
      case Map.get(filter, :field) do
        nil -> []
        field_ref ->
          case ParameterizedFieldBuilder.validate_field_reference(selecto, field_ref) do
            {:ok, _field_info} -> []
            {:error, reason} -> 
              [%{
                context: "filters",
                field: field_ref,
                index: index,
                error: reason,
                message: "Invalid filter field '#{field_ref}': #{inspect(reason)}"
              }]
          end
      end
    end)
  end

  defp validate_filter_fields(_selecto, _filters), do: []
end