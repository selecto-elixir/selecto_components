defmodule SelectoComponents.Explorer.Config do
  @moduledoc """
  Host-facing configuration for the Explorer surface.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          selecto: term(),
          views: list(),
          features: map(),
          theme: map(),
          presentation: map(),
          title: String.t() | nil
        }

  defstruct id: nil,
            selecto: nil,
            views: [],
            features: %{},
            theme: %{},
            presentation: %{},
            title: nil

  @spec new(map()) :: t()
  def new(attrs \\ %{}) when is_map(attrs) do
    struct(__MODULE__, attrs)
  end
end
