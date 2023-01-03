defmodule SelectoComponents.SavedViews do

  @doc """
  Implement this behavior as basis for your saved views
  """

  @doc """

  """
  @callback get_view_names( context :: any ) :: list
  @callback get_view( name :: String, context :: any ) :: map
  @callback save_view( name :: String, context :: any, params :: map ) :: map
  @callback decode_view( view :: map ) :: map

end
