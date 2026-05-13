defmodule SelectoComponents.QueryContract.HttpCache do
  @moduledoc false

  import Plug.Conn

  @spec etag(iodata()) :: String.t()
  def etag(body) do
    hash =
      body
      |> IO.iodata_to_binary()
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

    ~s("#{hash}")
  end

  @spec not_modified?(Plug.Conn.t(), String.t()) :: boolean()
  def not_modified?(%Plug.Conn{method: method} = conn, etag) when method in ["GET", "HEAD"] do
    conn
    |> get_req_header("if-none-match")
    |> Enum.flat_map(&parse_if_none_match/1)
    |> Enum.any?(&etag_match?(&1, etag))
  end

  def not_modified?(_conn, _etag), do: false

  @spec put_etag(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  def put_etag(conn, etag), do: put_resp_header(conn, "etag", etag)

  defp parse_if_none_match(header) do
    header
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp etag_match?("*", _etag), do: true
  defp etag_match?(candidate, etag), do: normalize_etag(candidate) == normalize_etag(etag)

  defp normalize_etag("W/" <> etag), do: etag
  defp normalize_etag(etag), do: etag
end
