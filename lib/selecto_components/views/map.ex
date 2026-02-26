defmodule SelectoComponents.Views.Map do
  @moduledoc """
  Map view for spatial data visualization.
  """

  use SelectoComponents.Views.System,
    process: SelectoComponents.Views.Map.Process,
    form: SelectoComponents.Views.Map.Form,
    component: SelectoComponents.Views.Map.Component
end
