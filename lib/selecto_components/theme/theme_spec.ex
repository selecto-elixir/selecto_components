defmodule SelectoComponents.Theme.ThemeSpec do
  @moduledoc false

  @type t :: %__MODULE__{
          id: String.t(),
          mode: atom(),
          tokens: map(),
          slots: map(),
          assets: map(),
          options: map()
        }

  defstruct id: "light",
            mode: :light,
            tokens: %{},
            slots: %{},
            assets: %{},
            options: %{}
end
