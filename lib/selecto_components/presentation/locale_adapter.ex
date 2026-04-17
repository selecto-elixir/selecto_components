defmodule SelectoComponents.Presentation.LocaleAdapter do
  @moduledoc false

  @callback parse_number(String.t(), map()) :: {:ok, float()} | :error
  @callback format_number(term(), map(), keyword()) :: {:ok, String.t()} | :error
end
