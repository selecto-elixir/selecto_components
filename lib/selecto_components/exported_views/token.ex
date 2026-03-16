defmodule SelectoComponents.ExportedViews.Token do
  @moduledoc false

  alias SelectoComponents.ExportedViews

  @salt "selecto_components_exported_view"
  @max_age 315_360_000

  @spec sign(map(), keyword()) :: String.t()
  def sign(view, opts) do
    endpoint = Keyword.fetch!(opts, :endpoint)

    Phoenix.Token.sign(endpoint, @salt, %{
      "public_id" => ExportedViews.field(view, :public_id),
      "version" => ExportedViews.field(view, :signature_version, 1)
    })
  end

  @spec verify(map(), String.t(), keyword()) :: :ok | {:error, :invalid}
  def verify(view, token, opts) when is_binary(token) do
    endpoint = Keyword.fetch!(opts, :endpoint)

    with {:ok, payload} <- Phoenix.Token.verify(endpoint, @salt, token, max_age: @max_age),
         true <- payload_matches_view?(payload, view) do
      :ok
    else
      _ -> {:error, :invalid}
    end
  end

  def verify(_view, _token, _opts), do: {:error, :invalid}

  defp payload_matches_view?(%{"public_id" => public_id, "version" => version}, view) do
    public_id == ExportedViews.field(view, :public_id) and
      version == ExportedViews.field(view, :signature_version, 1)
  end

  defp payload_matches_view?(_, _view), do: false
end
