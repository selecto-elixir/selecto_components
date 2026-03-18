defmodule SelectoComponents.ExportedViews.Snippets do
  @moduledoc false

  alias SelectoComponents.ExportedViews
  alias SelectoComponents.ExportedViews.Token

  @default_height 520

  @spec build(map(), keyword()) :: map()
  def build(view, opts) do
    embed_url = embed_url(view, opts)
    height = Keyword.get(opts, :height, @default_height)

    %{
      html: html_snippet(embed_url, height),
      javascript: javascript_snippet(embed_url, height),
      vue: vue_snippet(embed_url, height),
      react: react_snippet(embed_url, height),
      embed_url: embed_url
    }
  end

  @spec embed_url(map(), keyword()) :: String.t()
  def embed_url(view, opts) do
    endpoint = Keyword.fetch!(opts, :endpoint)
    base_url = Keyword.get(opts, :base_url, ExportedViews.default_embed_path())
    token = Token.sign(view, endpoint: endpoint)

    base_path =
      case base_url do
        url when is_binary(url) ->
          if String.starts_with?(url, "http"),
            do: url,
            else: Phoenix.VerifiedRoutes.unverified_url(endpoint, url)

        path ->
          Phoenix.VerifiedRoutes.unverified_url(endpoint, path)
      end

    public_id = ExportedViews.field(view, :public_id)
    separator = if String.ends_with?(base_path, "/"), do: "", else: "/"

    "#{base_path}#{separator}#{public_id}?sig=#{URI.encode_www_form(token)}"
  end

  defp html_snippet(embed_url, height) do
    """
    <iframe
      src=\"#{embed_url}\"
      title=\"Selecto exported view\"
      loading=\"lazy\"
      style=\"width:100%;min-height:#{height}px;border:0;border-radius:16px;background:#ffffff;\"
      referrerpolicy=\"strict-origin-when-cross-origin\"
    ></iframe>
    """
    |> String.trim()
  end

  defp javascript_snippet(embed_url, height) do
    """
    <div id=\"selecto-exported-view\"></div>
    <script>
      const iframe = document.createElement("iframe");
      iframe.src = #{inspect(embed_url)};
      iframe.title = "Selecto exported view";
      iframe.loading = "lazy";
      iframe.style.width = "100%";
      iframe.style.minHeight = "#{height}px";
      iframe.style.border = "0";
      iframe.style.borderRadius = "16px";
      iframe.referrerPolicy = "strict-origin-when-cross-origin";
      document.getElementById("selecto-exported-view").appendChild(iframe);
    </script>
    """
    |> String.trim()
  end

  defp vue_snippet(embed_url, height) do
    """
    <template>
      <iframe
        :src=\"src\"
        title=\"Selecto exported view\"
        loading=\"lazy\"
        referrerpolicy=\"strict-origin-when-cross-origin\"
        style=\"width:100%;border:0;border-radius:16px;background:#ffffff;\"
        :style="{ minHeight: `${height}px` }"
      />
    </template>

    <script setup>
    const src = #{inspect(embed_url)}
    const height = #{height}
    </script>
    """
    |> String.trim()
  end

  defp react_snippet(embed_url, height) do
    """
    export function SelectoExportedView() {
      return (
        <iframe
          src={#{inspect(embed_url)}}
          title=\"Selecto exported view\"
          loading=\"lazy\"
          referrerPolicy=\"strict-origin-when-cross-origin\"
          style={{ width: "100%", minHeight: #{height}, border: 0, borderRadius: 16, background: "#ffffff" }}
        />
      );
    }
    """
    |> String.trim()
  end
end
