defmodule SelectoComponents.SafeAtom do
  @moduledoc """
  Safe atom conversion functions to prevent atom table exhaustion attacks.

  ## Security

  Elixir atoms are never garbage collected. If user input is directly converted
  to atoms via `String.to_atom/1`, an attacker can exhaust the atom table
  (default limit ~1 million atoms) causing a Denial of Service.

  This module provides safe alternatives that:
  - Validate input against whitelists before conversion
  - Use `String.to_existing_atom/1` for schema-derived values
  - Return safe defaults for invalid input

  ## Usage

      # Instead of:
      view = String.to_atom(params["view_mode"])

      # Use:
      view = SafeAtom.to_view_mode(params["view_mode"])

  ## Functions

  Each function validates against a specific whitelist:
  - `to_view_mode/2` - :detail, :aggregate, :graph, :chart, :table
  - `to_theme/2` - :light, :dark, :high_contrast, :system, :auto
  - `to_sort_direction/2` - :asc, :desc
  - `to_form_mode/2` - :collapsed, :inline, :modal, :expanded
  - `to_widget_type/2` - :chart, :table, :metric, :filter, :summary, :kpi, :gauge
  - `to_aggregate_function/2` - :count, :sum, :avg, :min, :max, etc.
  - `to_list_name/2` - :group_by, :aggregate, :selected, :order_by, etc.

  For schema-derived values (field names, table names), use `to_existing/1`
  which wraps `String.to_existing_atom/1` with proper error handling.
  """

  # Whitelists for known valid values
  @valid_view_modes ~w(detail aggregate graph chart table)a
  @valid_themes ~w(light dark high_contrast system auto)a
  @valid_sort_directions ~w(asc desc)a
  @valid_form_modes ~w(collapsed inline modal expanded)a
  @valid_widget_types ~w(chart table metric filter summary kpi gauge list text html iframe)a
  @valid_aggregate_functions ~w(count sum avg min max array_agg string_agg median mode stddev variance first last)a
  @valid_list_names ~w(group_by aggregate selected order_by columns fields filters joins having)a

  # Theme property keys for atomize_keys
  @valid_theme_properties ~w(
    primary_50 primary_100 primary_200 primary_300 primary_400 primary_500
    primary_600 primary_700 primary_800 primary_900 primary_950
    secondary_50 secondary_100 secondary_200 secondary_300 secondary_400 secondary_500
    secondary_600 secondary_700 secondary_800 secondary_900 secondary_950
    success warning error info neutral
    background surface text border
    font_family font_size border_radius spacing
  )a

  @doc """
  Safely convert a string to a view mode atom.

  Returns the atom if valid, otherwise returns the default.

  ## Examples

      iex> SafeAtom.to_view_mode("detail")
      :detail

      iex> SafeAtom.to_view_mode("malicious_input")
      :detail

      iex> SafeAtom.to_view_mode("aggregate", :graph)
      :aggregate

      iex> SafeAtom.to_view_mode(nil)
      :detail
  """
  @spec to_view_mode(String.t() | atom() | nil, atom()) :: atom()
  def to_view_mode(value, default \\ :detail)
  def to_view_mode(nil, default), do: default
  def to_view_mode(value, _default) when is_atom(value) and value in @valid_view_modes, do: value
  def to_view_mode(value, default) when is_atom(value), do: default

  def to_view_mode(value, default) when is_binary(value) do
    to_atom_if_allowed(value, @valid_view_modes, default)
  end

  @doc """
  Safely convert a string to a theme atom.

  ## Examples

      iex> SafeAtom.to_theme("dark")
      :dark

      iex> SafeAtom.to_theme("hacker_theme")
      :light
  """
  @spec to_theme(String.t() | atom() | nil, atom()) :: atom()
  def to_theme(value, default \\ :light)
  def to_theme(nil, default), do: default
  def to_theme(value, _default) when is_atom(value) and value in @valid_themes, do: value
  def to_theme(value, default) when is_atom(value), do: default

  def to_theme(value, default) when is_binary(value) do
    to_atom_if_allowed(value, @valid_themes, default)
  end

  @doc """
  Safely convert a string to a sort direction atom.

  ## Examples

      iex> SafeAtom.to_sort_direction("asc")
      :asc

      iex> SafeAtom.to_sort_direction("DROP TABLE")
      :asc
  """
  @spec to_sort_direction(String.t() | atom() | nil, atom()) :: atom()
  def to_sort_direction(value, default \\ :asc)
  def to_sort_direction(nil, default), do: default
  def to_sort_direction(value, _default) when is_atom(value) and value in @valid_sort_directions, do: value
  def to_sort_direction(value, default) when is_atom(value), do: default

  def to_sort_direction(value, default) when is_binary(value) do
    to_atom_if_allowed(value, @valid_sort_directions, default)
  end

  @doc """
  Safely convert a string to a form mode atom.

  ## Examples

      iex> SafeAtom.to_form_mode("modal")
      :modal

      iex> SafeAtom.to_form_mode("evil")
      :collapsed
  """
  @spec to_form_mode(String.t() | atom() | nil, atom()) :: atom()
  def to_form_mode(value, default \\ :collapsed)
  def to_form_mode(nil, default), do: default
  def to_form_mode(value, _default) when is_atom(value) and value in @valid_form_modes, do: value
  def to_form_mode(value, default) when is_atom(value), do: default

  def to_form_mode(value, default) when is_binary(value) do
    to_atom_if_allowed(value, @valid_form_modes, default)
  end

  @doc """
  Safely convert a string to a widget type atom.

  ## Examples

      iex> SafeAtom.to_widget_type("chart")
      :chart

      iex> SafeAtom.to_widget_type("malware")
      :table
  """
  @spec to_widget_type(String.t() | atom() | nil, atom()) :: atom()
  def to_widget_type(value, default \\ :table)
  def to_widget_type(nil, default), do: default
  def to_widget_type(value, _default) when is_atom(value) and value in @valid_widget_types, do: value
  def to_widget_type(value, default) when is_atom(value), do: default

  def to_widget_type(value, default) when is_binary(value) do
    to_atom_if_allowed(value, @valid_widget_types, default)
  end

  @doc """
  Safely convert a string to an aggregate function atom.

  ## Examples

      iex> SafeAtom.to_aggregate_function("sum")
      :sum

      iex> SafeAtom.to_aggregate_function("DROP")
      :count
  """
  @spec to_aggregate_function(String.t() | atom() | nil, atom()) :: atom()
  def to_aggregate_function(value, default \\ :count)
  def to_aggregate_function(nil, default), do: default
  def to_aggregate_function("", default), do: default
  def to_aggregate_function(value, _default) when is_atom(value) and value in @valid_aggregate_functions, do: value
  def to_aggregate_function(value, default) when is_atom(value), do: default

  def to_aggregate_function(value, default) when is_binary(value) do
    to_atom_if_allowed(value, @valid_aggregate_functions, default)
  end

  @doc """
  Safely convert a string to a list name atom.

  ## Examples

      iex> SafeAtom.to_list_name("group_by")
      :group_by

      iex> SafeAtom.to_list_name("hacked")
      :selected
  """
  @spec to_list_name(String.t() | atom() | nil, atom()) :: atom()
  def to_list_name(value, default \\ :selected)
  def to_list_name(nil, default), do: default
  def to_list_name(value, _default) when is_atom(value) and value in @valid_list_names, do: value
  def to_list_name(value, default) when is_atom(value), do: default

  def to_list_name(value, default) when is_binary(value) do
    to_atom_if_allowed(value, @valid_list_names, default)
  end

  @doc """
  Safely convert a string to a theme property atom.

  Used when atomizing keys from imported theme JSON.

  ## Examples

      iex> SafeAtom.to_theme_property("primary_500")
      :primary_500

      iex> SafeAtom.to_theme_property("malicious_key")
      nil
  """
  @spec to_theme_property(String.t() | nil) :: atom() | nil
  def to_theme_property(nil), do: nil

  def to_theme_property(value) when is_binary(value) do
    to_atom_if_allowed(value, @valid_theme_properties, nil)
  end

  @doc """
  Convert a string to an existing atom, or return nil if it doesn't exist.

  This is safe because it only converts to atoms that already exist in the
  atom table (e.g., from compiled schema definitions).

  ## Examples

      iex> SafeAtom.to_existing("id")  # Assuming :id exists
      :id

      iex> SafeAtom.to_existing("nonexistent_atom_xyz123")
      nil
  """
  @spec to_existing(String.t() | atom() | nil) :: atom() | nil
  def to_existing(nil), do: nil
  def to_existing(value) when is_atom(value), do: value

  def to_existing(value) when is_binary(value) do
    String.to_existing_atom(value)
  rescue
    ArgumentError -> nil
  end

  @doc """
  Convert a string to an existing atom, raising if it doesn't exist.

  Use this when you expect the atom to exist (e.g., schema field names)
  and want to fail fast if it doesn't.

  ## Examples

      iex> SafeAtom.to_existing!("id")  # Assuming :id exists
      :id

      iex> SafeAtom.to_existing!("nonexistent")
      ** (ArgumentError) not an existing atom: "nonexistent"
  """
  @spec to_existing!(String.t() | atom()) :: atom()
  def to_existing!(value) when is_atom(value), do: value

  def to_existing!(value) when is_binary(value) do
    String.to_existing_atom(value)
  end

  @doc """
  Generic function to convert a string to an atom if it's in the allowed list.

  Returns the default if the string is not in the allowed list.

  ## Examples

      iex> SafeAtom.to_atom_if_allowed("foo", [:foo, :bar], :default)
      :foo

      iex> SafeAtom.to_atom_if_allowed("baz", [:foo, :bar], :default)
      :default
  """
  @spec to_atom_if_allowed(String.t() | nil, [atom()], atom() | nil) :: atom() | nil
  def to_atom_if_allowed(nil, _allowed, default), do: default
  def to_atom_if_allowed("", _allowed, default), do: default

  def to_atom_if_allowed(value, allowed, default) when is_binary(value) do
    # Convert allowed atoms to strings for comparison
    allowed_strings = Enum.map(allowed, &Atom.to_string/1)

    if value in allowed_strings do
      # Safe to convert because we verified it's in the whitelist
      String.to_atom(value)
    else
      default
    end
  end

  @doc """
  Safely atomize map keys, only keeping keys that are in the allowed list.

  Keys not in the allowed list are dropped from the result.

  ## Examples

      iex> SafeAtom.atomize_keys(%{"primary_500" => "#fff", "evil" => "bad"}, @valid_theme_properties)
      %{primary_500: "#fff"}
  """
  @spec atomize_keys(map(), [atom()]) :: map()
  def atomize_keys(map, allowed_keys) when is_map(map) do
    allowed_strings = Enum.map(allowed_keys, &Atom.to_string/1)

    map
    |> Enum.filter(fn {k, _v} -> is_binary(k) and k in allowed_strings end)
    |> Enum.map(fn {k, v} -> {String.to_atom(k), v} end)
    |> Map.new()
  end

  @doc """
  Returns the list of valid theme property atoms.

  Useful for validating theme imports.
  """
  @spec valid_theme_properties() :: [atom()]
  def valid_theme_properties, do: @valid_theme_properties

  @doc """
  Returns the list of valid view mode atoms.
  """
  @spec valid_view_modes() :: [atom()]
  def valid_view_modes, do: @valid_view_modes

  @doc """
  Returns the list of valid widget type atoms.
  """
  @spec valid_widget_types() :: [atom()]
  def valid_widget_types, do: @valid_widget_types
end
