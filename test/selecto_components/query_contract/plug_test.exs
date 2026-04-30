defmodule SelectoComponents.QueryContract.PlugTest do
  use ExUnit.Case, async: true

  import Plug.Test

  alias SelectoComponents.QueryContract.Plug, as: QueryContractPlug

  describe "init/1" do
    test "requires a domain or resolver" do
      assert_raise ArgumentError, ~r/expected :domain or :resolver/, fn ->
        QueryContractPlug.init([])
      end
    end
  end

  describe "call/2" do
    test "serves a direct domain as query contract JSON" do
      conn =
        :get
        |> conn("/query-contract.json")
        |> QueryContractPlug.call(
          QueryContractPlug.init(
            domain: domain(),
            generated_at: "2026-04-30T19:50:00Z",
            domain_id: "orders",
            domain_path: "/orders",
            context: %{exports: [:csv], saved_views_enabled: true}
          )
        )

      assert conn.status == 200
      assert conn.halted
      assert ["application/json" <> _] = Plug.Conn.get_resp_header(conn, "content-type")

      body = Jason.decode!(conn.resp_body)

      assert body["query_contract_version"] == 1
      assert body["generated_at"] == "2026-04-30T19:50:00Z"
      assert body["projection"] == "query_contract"
      assert body["name"] == "Orders"
      assert body["domain"] == %{"id" => "orders", "name" => "Orders", "path" => "/orders"}
      assert body["context"]["exports"] == ["csv"]
      assert body["context"]["saved_views_enabled"] == true
      assert body["params_schema"]["view_mode"]["default"] == "detail"
      assert body["source"] == %{"source_table" => "orders", "primary_key" => "id"}
    end

    test "uses a two-arity resolver with the path domain id" do
      resolver = fn
        "orders", _conn -> {:ok, domain()}
        _domain_id, _conn -> nil
      end

      conn =
        :get
        |> conn("/selecto/schema/orders/query-contract.json")
        |> with_path_params(%{"domain" => "orders"})
        |> QueryContractPlug.call(QueryContractPlug.init(resolver: resolver))

      assert conn.status == 200

      body = Jason.decode!(conn.resp_body)

      assert body["name"] == "Orders"
      assert body["domain"]["name"] == "Orders"
    end

    test "returns 404 when the resolver cannot find a domain" do
      resolver = fn _domain_id, _conn -> nil end

      conn =
        :get
        |> conn("/selecto/schema/missing/query-contract.json")
        |> with_path_params(%{"domain" => "missing"})
        |> QueryContractPlug.call(QueryContractPlug.init(resolver: resolver))

      assert conn.status == 404

      body = Jason.decode!(conn.resp_body)

      assert body["error"]["code"] == "not_found"
    end

    test "returns diagnostics JSON when the domain is invalid" do
      conn =
        :get
        |> conn("/query-contract.json")
        |> QueryContractPlug.call(QueryContractPlug.init(domain: :not_a_domain))

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
      joins: %{}
    }
  end
end
