defmodule SelectoComponents.Views.Aggregate do
  @moduledoc """
  Aggregate view for Selecto Components.

  This module provides aggregate/summary visualization capabilities for Selecto data.
  It supports grouping, aggregation functions (count, sum, avg, etc.), and drill-down functionality.
  """

  use SelectoComponents.Views.System,
    process: SelectoComponents.Views.Aggregate.Process,
    form: SelectoComponents.Views.Aggregate.Form,
    component: SelectoComponents.Views.Aggregate.Component
end
