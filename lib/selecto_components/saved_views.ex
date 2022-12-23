defmodule SelectoComponents.SavedViews do

  @doc """
  Implement this behavior as basis for your saved views
  """

  @doc """

  """
  @callback get_names( context :: any ) :: list
  @callback get_view( name :: String, context :: any ) :: map
  @callback save_view( name :: String, context :: any, params :: map ) :: map
  @callback update_view( name :: String, context :: any, params :: map ) :: map

end
