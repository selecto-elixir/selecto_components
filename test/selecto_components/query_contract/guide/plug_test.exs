defmodule SelectoComponents.QueryContract.Guide.PlugTest do
  use ExUnit.Case, async: true

  import Plug.Test

  alias SelectoComponents.QueryContract.Guide.Plug, as: QueryGuidePlug

  describe "init/1" do
    test "requires a domain or resolver" do
      assert_raise ArgumentError, ~r/expected :domain or :resolver/, fn ->
        QueryGuidePlug.init([])
      end
    end
  end

  describe "call/2" do
    test "serves a direct domain as Markdown" do
      conn =
        :get
        |> conn("/query-guide.md")
        |> QueryGuidePlug.call(
          QueryGuidePlug.init(
            domain: domain(),
            generated_at: "2026-04-30T20:10:00Z",
            domain_id: "orders",
            domain_path: "/orders",
            context: %{exports: [:csv], saved_views_enabled: true}
          )
        )

      assert conn.status == 200
      assert conn.halted
      assert ["text/markdown" <> _] = Plug.Conn.get_resp_header(conn, "content-type")
      assert conn.resp_body =~ "# Orders Query Guide"
      assert conn.resp_body =~ "- Domain id: `orders`"
      assert conn.resp_body =~ "## Safety Notes"
    end

    test "uses a two-arity resolver with the path domain id" do
      resolver = fn
        "orders", _conn -> {:ok, domain()}
        _domain_id, _conn -> nil
      end

      conn =
        :get
        |> conn("/selecto/schema/orders/query-guide.md")
        |> with_path_params(%{"domain" => "orders"})
        |> QueryGuidePlug.call(QueryGuidePlug.init(resolver: resolver))

      assert conn.status == 200
      assert conn.resp_body =~ "# Orders Query Guide"
    end

    test "returns 404 when the resolver cannot find a domain" do
      resolver = fn _domain_id, _conn -> nil end

      conn =
        :get
        |> conn("/selecto/schema/missing/query-guide.md")
        |> with_path_params(%{"domain" => "missing"})
        |> QueryGuidePlug.call(QueryGuidePlug.init(resolver: resolver))

      assert conn.status == 404

      body = Jason.decode!(conn.resp_body)

      assert body["error"]["code"] == "not_found"
    end

    test "returns diagnostics JSON when the domain is invalid" do
      conn =
        :get
        |> conn("/query-guide.md")
        |> QueryGuidePlug.call(QueryGuidePlug.init(domain: :not_a_domain))

      assert conn.status == 422

      body = Jason.decode!(conn.resp_body)

      assert body["error"]["code"] == "invalid_query_contract_domain"
      assert [%{"code" => "invalid_domain"}] = body["diagnostics"]["errors"]
    end
  end

  defp with_path_params(conn, path_params), do: %{conn | path_params: path_params}

  defp domain do
    %{
      name: "Orders",
      source: %{
        source_table: "orders",
        primary_key: :id,
        fields: [:id, :status],
        redact_fields: [],
        columns: %{
          id: %{type: :integer, name: "ID"},
          status: %{type: :string, name: "Status"}
        },
        associations: %{}
      },
      schemas: %{},
      joins: %{},
      filters: %{
        status_filter: %{field: :status, type: :string, name: "Status"}
      },
      default_selected: [:id, :status]
    }
  end
end
