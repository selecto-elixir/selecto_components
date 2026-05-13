defmodule SelectoComponents.QueryContract.IntentValidator.PlugTest do
  use ExUnit.Case, async: true

  import Plug.Test

  alias SelectoComponents.QueryContract.IntentValidator.Plug, as: IntentValidatorPlug

  describe "init/1" do
    test "requires a domain or resolver" do
      assert_raise ArgumentError, ~r/expected :domain or :resolver/, fn ->
        IntentValidatorPlug.init([])
      end
    end
  end

  describe "call/2" do
    test "validates a direct domain and valid intent" do
      conn =
        :post
        |> conn("/query-intent/validate")
        |> with_body_params(%{
          "intent" => %{
            "view_mode" => "detail",
            "select" => ["id", "status"],
            "filters" => [
              %{"field" => "status", "comparator" => "contains", "value" => "open"}
            ],
            "order_by" => [
              %{"field" => "id", "direction" => "desc"}
            ]
          }
        })
        |> IntentValidatorPlug.call(IntentValidatorPlug.init(domain: domain()))

      assert conn.status == 200
      assert conn.halted
      assert ["application/json" <> _] = Plug.Conn.get_resp_header(conn, "content-type")

      body = Jason.decode!(conn.resp_body)

      assert body["valid"] == true
      assert body["errors"] == []
      assert body["warnings"] == []
    end

    test "returns diagnostics for invalid generated intent without failing the request" do
      conn =
        :post
        |> conn("/query-intent/validate")
        |> with_body_params(%{
          "view_mode" => "detail",
          "select" => ["missing"],
          "filters" => [
            %{"field" => "status", "comparator" => "regex", "value" => "open"}
          ]
        })
        |> IntentValidatorPlug.call(IntentValidatorPlug.init(domain: domain()))

      assert conn.status == 200

      body = Jason.decode!(conn.resp_body)

      assert body["valid"] == false
      assert Enum.find(body["errors"], &match?(%{"code" => "invalid_field"}, &1))
      assert Enum.find(body["errors"], &match?(%{"code" => "invalid_comparator"}, &1))
    end

    test "uses a two-arity resolver with the path domain id" do
      resolver = fn
        "orders", _conn -> {:ok, domain()}
        _domain_id, _conn -> nil
      end

      conn =
        :post
        |> conn("/selecto/schema/orders/query-intent/validate")
        |> with_path_params(%{"domain" => "orders"})
        |> with_body_params(%{"intent" => %{"view_mode" => "detail", "select" => ["id"]}})
        |> IntentValidatorPlug.call(IntentValidatorPlug.init(resolver: resolver))

      assert conn.status == 200

      body = Jason.decode!(conn.resp_body)

      assert body["valid"] == true
    end

    test "returns 400 when the body has no intent object" do
      conn =
        :post
        |> conn("/query-intent/validate")
        |> with_body_params(%{"intent" => "not a map"})
        |> IntentValidatorPlug.call(IntentValidatorPlug.init(domain: domain()))

      assert conn.status == 400

      body = Jason.decode!(conn.resp_body)

      assert body["error"]["code"] == "invalid_intent"
    end

    test "returns 404 when the resolver cannot find a domain" do
      resolver = fn _domain_id, _conn -> nil end

      conn =
        :post
        |> conn("/selecto/schema/missing/query-intent/validate")
        |> with_path_params(%{"domain" => "missing"})
        |> with_body_params(%{"intent" => %{"view_mode" => "detail"}})
        |> IntentValidatorPlug.call(IntentValidatorPlug.init(resolver: resolver))

      assert conn.status == 404

      body = Jason.decode!(conn.resp_body)

      assert body["error"]["code"] == "not_found"
    end

    test "rejects non-POST requests" do
      conn =
        :get
        |> conn("/query-intent/validate")
        |> IntentValidatorPlug.call(IntentValidatorPlug.init(domain: domain()))

      assert conn.status == 405
      assert ["POST"] = Plug.Conn.get_resp_header(conn, "allow")

      body = Jason.decode!(conn.resp_body)

      assert body["error"]["code"] == "method_not_allowed"
    end
  end

  defp with_body_params(conn, body_params),
    do: %{conn | body_params: body_params, params: body_params}

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
