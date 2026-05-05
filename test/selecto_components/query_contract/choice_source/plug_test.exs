defmodule SelectoComponents.QueryContract.ChoiceSource.PlugTest do
  use ExUnit.Case, async: true

  import Plug.Test

  alias Selecto.Domain.Choices
  alias Selecto.Domain.Choices.{OptionsRequest, Request}
  alias SelectoComponents.QueryContract.ChoiceSource.Plug, as: ChoiceSourcePlug

  describe "init/1" do
    test "requires a domain or resolver" do
      assert_raise ArgumentError, ~r/expected :domain or :resolver/, fn ->
        ChoiceSourcePlug.init([])
      end
    end
  end

  describe "call/2" do
    test "serves option lists for a declared choice source" do
      options_resolver = fn %OptionsRequest{} = request ->
        assert request.choice_source == "customer_choices"
        assert request.search == "acme"
        assert request.limit == 1
        assert request.offset == 2
        assert request.context == %{surface: :test}

        Choices.options_resolved(
          [
            %{value: 42, label: "Acme Camps", metadata: %{tier: :gold}}
          ],
          total_count: 1,
          metadata: %{source: :fixture}
        )
      end

      conn =
        :get
        |> conn("/choice-sources/customer_choices/options?search=acme&limit=1&offset=2")
        |> ChoiceSourcePlug.call(
          ChoiceSourcePlug.init(
            domain: domain(),
            options_resolver: options_resolver,
            context: %{surface: :test},
            collection_url: "/selecto/orders/artifacts"
          )
        )

      assert conn.status == 200
      assert conn.halted
      assert ["application/json" <> _] = Plug.Conn.get_resp_header(conn, "content-type")

      assert [link_header] = Plug.Conn.get_resp_header(conn, "link")
      assert link_header == ~s(</selecto/orders/artifacts>; rel="collection"; type="text/html")

      body = Jason.decode!(conn.resp_body)

      assert body["status"] == "resolved"
      assert body["reason_code"] == "options_resolved"
      assert body["choice_source"] == "customer_choices"
      assert body["domain"] == "orders"
      assert body["search"] == "acme"
      assert body["limit"] == 1
      assert body["offset"] == 2
      assert body["total_count"] == 1
      assert body["metadata"] == %{"source" => "fixture"}
      assert [%{"label" => "Acme Camps", "metadata" => %{"tier" => "gold"}}] = body["options"]
      refute Map.has_key?(body, "field")
    end

    test "validates choice membership for a submitted field value" do
      membership_resolver = fn %Request{} = request ->
        assert request.choice_source == :customer_choices
        assert request.field == "customer_id"
        assert request.value == 42
        assert request.context == %{surface: :test, endpoint: :validate}

        Choices.valid(:fixture_member, metadata: %{source: :fixture, label: "Acme Camps"})
      end

      conn =
        :post
        |> conn("/choice-sources/customer_choices/validate")
        |> with_body_params(%{"field" => "customer_id", "value" => 42})
        |> ChoiceSourcePlug.call(
          ChoiceSourcePlug.init(
            domain: domain(),
            membership_resolver: membership_resolver,
            context: %{surface: :test},
            membership_context: %{endpoint: :validate}
          )
        )

      assert conn.status == 200

      body = Jason.decode!(conn.resp_body)

      assert body["status"] == "valid"
      assert body["valid"] == true
      assert body["reason_code"] == "fixture_member"
      assert body["choice_source"] == "customer_choices"
      assert body["field"] == "customer_id"
      assert body["value"] == 42
      assert body["label"] == "Acme Camps"
      assert body["metadata"] == %{"source" => "fixture", "label" => "Acme Camps"}
    end

    test "supports configured default fields for membership validation" do
      membership_resolver = fn %Request{field: "customer_id"} ->
        Choices.invalid(:fixture_missing)
      end

      conn =
        :post
        |> conn("/choice-sources/customer_choices/validate")
        |> with_body_params(%{"value" => 404})
        |> ChoiceSourcePlug.call(
          ChoiceSourcePlug.init(
            domain: domain(),
            membership_resolver: membership_resolver,
            field_by_choice_source: %{customer_choices: "customer_id"}
          )
        )

      assert conn.status == 200

      body = Jason.decode!(conn.resp_body)

      assert body["status"] == "invalid"
      assert body["valid"] == false
      assert body["reason_code"] == "fixture_missing"
      assert body["field"] == "customer_id"
    end

    test "returns not found for undeclared choice sources" do
      conn =
        :get
        |> conn("/choice-sources/missing/options")
        |> ChoiceSourcePlug.call(ChoiceSourcePlug.init(domain: domain()))

      assert conn.status == 404

      body = Jason.decode!(conn.resp_body)

      assert body["error"]["code"] == "choice_source_not_found"
    end

    test "returns validation errors from a value parser" do
      value_parser = fn value, _context ->
        {:error,
         %{
           code: :invalid_choice_value,
           message: "expected integer id, got #{inspect(value)}",
           path: [:value]
         }}
      end

      conn =
        :post
        |> conn("/choice-sources/customer_choices/validate")
        |> with_body_params(%{"field" => "customer_id", "value" => "nope"})
        |> ChoiceSourcePlug.call(
          ChoiceSourcePlug.init(
            domain: domain(),
            value_parser: value_parser,
            membership_resolver: fn _request -> Choices.valid(:fixture_member) end
          )
        )

      assert conn.status == 422

      body = Jason.decode!(conn.resp_body)

      assert body["error"]["code"] == "invalid_choice_value"
      assert body["error"]["path"] == ["value"]
    end

    test "rejects unsupported methods" do
      conn =
        :get
        |> conn("/choice-sources/customer_choices/validate")
        |> ChoiceSourcePlug.call(ChoiceSourcePlug.init(domain: domain()))

      assert conn.status == 405
      assert ["POST"] = Plug.Conn.get_resp_header(conn, "allow")

      body = Jason.decode!(conn.resp_body)

      assert body["error"]["code"] == "method_not_allowed"
    end
  end

  defp with_body_params(conn, body_params),
    do: %{conn | body_params: body_params, params: body_params}

  defp domain do
    %{
      schema_version: 1,
      name: :orders,
      source: valid_source(),
      schemas: %{
        customers: %{
          source_table: "customers",
          primary_key: :id,
          fields: [:id, :name],
          columns: %{
            id: %{type: :integer},
            name: %{type: :string}
          },
          associations: %{}
        }
      },
      joins: %{
        customer: %{type: :left}
      },
      capabilities: %{
        "customer.choose" => %{operations: [:choice_source]}
      },
      source_relationships: %{
        customer: %{
          target_domain: :customers,
          source_field: :customer_id,
          target_field: :id
        }
      },
      choice_sources: %{
        customer_choices: %{
          domain: :customers,
          value_field: :id,
          label_field: :name,
          source_relationship: :customer,
          capability: "customer.choose"
        }
      }
    }
  end

  defp valid_source do
    %{
      source_table: "orders",
      primary_key: :id,
      fields: [:id, :status, :customer_id, :customer_name],
      columns: %{
        id: %{type: :integer},
        status: %{type: :string},
        customer_id: %{
          type: :integer,
          reference: %{
            choice_source: :customer_choices,
            value_source: "customers.id",
            caption_source: "customers.name",
            caption_field: :customer_name
          }
        },
        customer_name: %{type: :string}
      },
      associations: %{
        customer: %{
          queryable: :customers,
          field: :customer,
          owner_key: :customer_id,
          related_key: :id
        }
      }
    }
  end
end
