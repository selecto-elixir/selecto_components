defmodule SelectoComponents.Views.Graph do
  @moduledoc """
  Graph view for Selecto Components.

  This module provides graph/chart visualization capabilities for Selecto data.
  It supports various chart types including bar, line, pie, scatter, and area charts.
  """

  use SelectoComponents.Views.System,
    process: SelectoComponents.Views.Graph.Process,
    form: SelectoComponents.Views.Graph.Form,
    component: SelectoComponents.Views.Graph.Component
end
