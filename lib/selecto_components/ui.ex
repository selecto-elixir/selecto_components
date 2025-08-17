defmodule SelectoComponents.UI do
  @moduledoc """
  Pure UI rendering functions for SelectoComponents.
  
  Contains functions for building UI data structures and rendering helpers
  without state management or business logic concerns.
  """

  @doc """
  Builds the column list for UI display from a selecto structure.
  """
  def build_column_list(selecto) do
    Map.values(Selecto.columns(selecto))
    |> Enum.sort(fn a, b -> a.name <= b.name end)
    |> Enum.map(fn c -> {c.colid, c.name, Map.get(c, :format)} end)
  end

  @doc """
  Builds the filter list for UI display from a selecto structure.
  """
  def build_filter_list(selecto) do
    (Map.values(Selecto.filters(selecto)) ++ Map.values(Selecto.columns(selecto)))
    |> List.flatten()
    |> Enum.sort(fn a, b -> a.name <= b.name end)
    |> Enum.map(fn
      %{colid: id} = c -> {id, c.name}
      %{id: id} = c -> {id, c.name}
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
      "border-solid border rounded-md border-grey dark:border-black h-90 p-1"
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
end