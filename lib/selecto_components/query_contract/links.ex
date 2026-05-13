defmodule SelectoComponents.QueryContract.Links do
  @moduledoc false

  @json_type "application/json"
  @markdown_type "text/markdown"

  @spec document(keyword() | map()) :: map()
  def document(opts) do
    defaults = %{
      query_contract:
        option(opts, :query_contract_url) ||
          option(opts, :contract_url) ||
          option(opts, :self_url),
      query_guide:
        option(opts, :query_guide_url) ||
          option(opts, :guide_url)
    }

    opts
    |> option(:links, %{})
    |> link_option_map()
    |> then(&Map.merge(defaults, &1))
    |> Enum.reject(fn {_key, value} -> is_nil(value) or value == "" end)
    |> Map.new()
  end

  @spec with_request_defaults(Plug.Conn.t(), keyword(), :query_contract | :query_guide) ::
          keyword()
  def with_request_defaults(conn, opts, artifact) do
    defaults = request_defaults(conn.request_path, artifact)

    opts
    |> Keyword.put_new(:query_contract_url, Map.get(defaults, :query_contract))
    |> Keyword.put_new(:query_guide_url, Map.get(defaults, :query_guide))
  end

  @spec header(keyword() | map(), :query_contract | :query_guide) :: String.t() | nil
  def header(opts, artifact) do
    opts
    |> document()
    |> header_entries(artifact)
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> nil
      entries -> Enum.join(entries, ", ")
    end
  end

  defp request_defaults(path, :query_contract) do
    %{
      query_contract: path,
      query_guide: sibling_path(path, "/query-contract.json", "/query-guide.md")
    }
  end

  defp request_defaults(path, :query_guide) do
    %{
      query_contract: sibling_path(path, "/query-guide.md", "/query-contract.json"),
      query_guide: path
    }
  end

  defp sibling_path(path, suffix, replacement) when is_binary(path) do
    if String.ends_with?(path, suffix) do
      String.replace_suffix(path, suffix, replacement)
    end
  end

  defp sibling_path(_path, _suffix, _replacement), do: nil

  defp header_entries(links, :query_contract) do
    [
      link_entry(Map.get(links, :query_contract), "self", @json_type),
      link_entry(Map.get(links, :query_guide), "alternate", @markdown_type)
    ]
  end

  defp header_entries(links, :query_guide) do
    [
      link_entry(Map.get(links, :query_guide), "self", @markdown_type),
      link_entry(Map.get(links, :query_contract), "describedby", @json_type)
    ]
  end

  defp link_entry(nil, _rel, _type), do: nil
  defp link_entry("", _rel, _type), do: nil

  defp link_entry(url, rel, type) do
    url =
      url
      |> to_string()
      |> String.replace(">", "%3E")

    ~s(<#{url}>; rel="#{rel}"; type="#{type}")
  end

  defp link_option_map(value) do
    value
    |> option_map()
    |> Map.new(fn {key, value} -> {link_key(key), value} end)
  end

  defp link_key(key) do
    case to_string(key) do
      "contract" -> :query_contract
      "self" -> :query_contract
      "guide" -> :query_guide
      "query_contract" -> :query_contract
      "query_guide" -> :query_guide
      other -> other
    end
  end

  defp option(opts, key, default \\ nil)

  defp option(opts, key, default) when is_list(opts) do
    Keyword.get(opts, key, default)
  end

  defp option(opts, key, default) when is_map(opts) do
    Map.get(opts, key) || Map.get(opts, to_string(key)) || default
  end

  defp option(_opts, _key, default), do: default

  defp option_map(value) when is_map(value), do: value
  defp option_map(value) when is_list(value), do: Map.new(value)
  defp option_map(_value), do: %{}
end
