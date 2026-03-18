defmodule SelectoComponents.ExportedViews.IPAllowlist do
  @moduledoc false

  alias SelectoComponents.ExportedViews

  @spec allowed?(map(), tuple() | nil) :: boolean()
  def allowed?(view, request_ip) do
    allowlist_text = ExportedViews.field(view, :ip_allowlist_text)

    case parse_entries(allowlist_text) do
      [] -> true
      _entries when is_nil(request_ip) -> false
      entries -> Enum.any?(entries, &matches?(&1, request_ip))
    end
  end

  @spec parse_entries(String.t() | nil) :: [tuple()]
  def parse_entries(nil), do: []

  def parse_entries(text) when is_binary(text) do
    text
    |> String.split(["\n", ","], trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.flat_map(&parse_entry/1)
  end

  def parse_entries(_), do: []

  defp parse_entry(entry) do
    case String.split(entry, "/", parts: 2) do
      [ip_text, prefix_text] ->
        with {:ok, ip} <- parse_ip(ip_text),
             {prefix, ""} <- Integer.parse(String.trim(prefix_text)),
             true <- valid_prefix?(ip, prefix) do
          [{:cidr, ip, prefix}]
        else
          _ -> []
        end

      [ip_text] ->
        case parse_ip(ip_text) do
          {:ok, ip} -> [{:ip, ip}]
          _ -> []
        end
    end
  end

  defp parse_ip(text) when is_binary(text) do
    text
    |> String.trim()
    |> String.to_charlist()
    |> :inet.parse_address()
  end

  defp matches?({:ip, allowed_ip}, request_ip), do: allowed_ip == request_ip

  defp matches?({:cidr, network_ip, prefix}, request_ip) do
    same_family?(network_ip, request_ip) and
      masked(network_ip, prefix) == masked(request_ip, prefix)
  end

  defp same_family?(ip1, ip2), do: tuple_size(ip1) == tuple_size(ip2)

  defp valid_prefix?(ip, prefix) when tuple_size(ip) == 4, do: prefix >= 0 and prefix <= 32
  defp valid_prefix?(ip, prefix) when tuple_size(ip) == 8, do: prefix >= 0 and prefix <= 128
  defp valid_prefix?(_ip, _prefix), do: false

  defp masked(ip, prefix) do
    bits = tuple_to_bits(ip)
    size = bit_size(bits)
    host_bits = max(size - prefix, 0)

    if host_bits == 0 do
      bits
    else
      <<network::bitstring-size(prefix), _host::bitstring-size(host_bits)>> = bits
      <<network::bitstring, 0::size(host_bits)>>
    end
  end

  defp tuple_to_bits(ip) when tuple_size(ip) == 4 do
    {a, b, c, d} = ip
    <<a, b, c, d>>
  end

  defp tuple_to_bits(ip) when tuple_size(ip) == 8 do
    {a, b, c, d, e, f, g, h} = ip
    <<a::16, b::16, c::16, d::16, e::16, f::16, g::16, h::16>>
  end
end
