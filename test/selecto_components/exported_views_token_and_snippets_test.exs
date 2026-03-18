defmodule SelectoComponents.ExportedViewsTokenAndSnippetsTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.ExportedViews.Snippets
  alias SelectoComponents.ExportedViews.Token

  defmodule TestEndpoint do
    def config(:secret_key_base), do: String.duplicate("a", 64)
    def url, do: "https://example.test"
  end

  test "signed tokens verify against the expected export version" do
    view = %{public_id: "pub_123", signature_version: 2}
    token = Token.sign(view, endpoint: TestEndpoint)

    assert :ok = Token.verify(view, token, endpoint: TestEndpoint)

    assert {:error, :invalid} =
             Token.verify(%{view | signature_version: 3}, token, endpoint: TestEndpoint)
  end

  test "snippet builder emits iframe-friendly snippets" do
    view = %{public_id: "pub_123", signature_version: 1}
    snippets = Snippets.build(view, endpoint: TestEndpoint, base_url: "/exports")

    assert snippets.embed_url =~ "/exports/pub_123?sig="
    assert snippets.html =~ "<iframe"
    assert snippets.javascript =~ "createElement(\"iframe\")"
    assert snippets.vue =~ "<template>"
    assert snippets.react =~ "export function SelectoExportedView"
  end
end
