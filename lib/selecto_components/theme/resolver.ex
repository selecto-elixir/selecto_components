defmodule SelectoComponents.Theme.Resolver do
  @moduledoc false

  alias SelectoComponents.Theme.ThemeSpec

  @callback resolve_theme(map()) :: ThemeSpec.t()
end
