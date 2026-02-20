defmodule SelectoComponents.Views.Detail do
  @moduledoc """
  Detail view for Selecto Components.

  This module provides detailed record-level visualization capabilities for Selecto data.
  It supports column selection, sorting, pagination, and individual record display.
  """

  use SelectoComponents.Views.System,
    process: SelectoComponents.Views.Detail.Process,
    form: SelectoComponents.Views.Detail.Form,
    component: SelectoComponents.Views.Detail.Component
end
