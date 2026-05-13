defmodule SelectoComponents.QueryContract.ChoiceSource.ClientTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.QueryContract.ChoiceSource.Client
  alias SelectoComponents.QueryContract.ChoiceSource.Request

  describe "choice source discovery" do
    test "finds advertised choice source links" do
      assert [%{"id" => "customer_choices"}] = Client.choice_sources(contract())

      assert {:ok, links} = Client.links(contract(), :customer_choices)

      assert links["options"] == "/api/orders/choice-sources/customer_choices/options"
      assert links["validate"] == "/api/orders/choice-sources/customer_choices/validate"
    end

    test "returns structured errors for missing choice sources and links" do
      assert {:error, error} = Client.links(contract(), :missing)
      assert error["code"] == "choice_source_not_found"
      assert error["path"] == ["choice_sources", "missing"]

      contract = put_in(contract(), ["choice_sources", Access.at(0), "links"], %{})

      assert {:error, error} = Client.options_request(contract, :customer_choices)
      assert error["code"] == "choice_source_link_not_found"
      assert error["path"] == ["choice_sources", "customer_choices", "links", "options"]
    end
  end

  describe "request builders" do
    test "builds option lookup requests with query params and headers" do
      assert {:ok, %Request{} = request} =
               Client.options_request(contract(), :customer_choices,
                 base_url: "https://example.test",
                 search: "acme",
                 limit: 10,
                 offset: 20,
                 params: %{tenant: "north"},
                 headers: [{"authorization", "Bearer token"}]
               )

      assert request.method == :get
      assert request.operation == :options
      assert request.choice_source == "customer_choices"

      assert request.url ==
               "https://example.test/api/orders/choice-sources/customer_choices/options?limit=10&offset=20&search=acme&tenant=north"

      assert {"authorization", "Bearer token"} in request.headers
      assert {"accept", "application/json"} in request.headers
      assert request.body == nil
      assert request.metadata == %{"field" => "customer_id"}
    end

    test "builds membership requests and infers the bound field" do
      assert Client.inferred_field(contract(), "customer_choices") == "customer_id"

      assert {:ok, %Request{} = request} =
               Client.validate_request(contract(), "customer_choices", 42,
                 headers: %{"x-csrf-token" => "abc"}
               )

      assert request.method == :post
      assert request.url == "/api/orders/choice-sources/customer_choices/validate"

      assert request.headers == [
               {"x-csrf-token", "abc"},
               {"accept", "application/json"},
               {"content-type", "application/json"}
             ]

      assert request.body == %{"field" => "customer_id", "value" => 42}
      assert request.metadata == %{"field" => "customer_id"}
    end

    test "respects an explicit validation field when the contract has multiple bindings" do
      contract =
        put_in(contract(), ["field_choice_bindings"], [
          %{"field" => "customer_id", "choice_source" => "customer_choices"},
          %{"field" => "billing_customer_id", "choice_source" => "customer_choices"}
        ])

      assert Client.inferred_field(contract, :customer_choices) == nil

      assert {:ok, request} =
               Client.validate_request(contract, :customer_choices, 42,
                 field: "billing_customer_id"
               )

      assert request.body == %{"field" => "billing_customer_id", "value" => 42}
    end
  end

  describe "transport execution" do
    test "fetch_options executes a caller transport and decodes JSON responses" do
      transport = fn %Request{} = request ->
        assert request.method == :get
        assert request.url =~ "search=acme"

        {:ok,
         %{
           status: 200,
           body: Jason.encode!(%{status: :resolved, options: [%{value: 42, label: "Acme"}]})
         }}
      end

      assert {:ok, response} =
               Client.fetch_options(contract(), :customer_choices,
                 search: "acme",
                 transport: transport
               )

      assert response["status"] == "resolved"
      assert response["options"] == [%{"value" => 42, "label" => "Acme"}]
    end

    test "validate_choice executes a caller transport and returns decoded bodies" do
      transport = fn %Request{} = request ->
        assert request.method == :post
        assert request.body == %{"field" => "customer_id", "value" => 42}

        {:ok, %{status: 200, body: %{"status" => "valid", "valid" => true}}}
      end

      assert {:ok, %{"valid" => true, "status" => "valid"}} =
               Client.validate_choice(contract(), :customer_choices, 42, transport: transport)
    end

    test "returns structured errors for missing transport and HTTP errors" do
      assert {:error, error} = Client.fetch_options(contract(), :customer_choices)
      assert error["code"] == "transport_required"

      transport = fn _request ->
        {:ok, %{status: 422, body: %{"error" => %{"code" => "invalid_choice_value"}}}}
      end

      assert {:error, error} =
               Client.validate_choice(contract(), :customer_choices, "bad", transport: transport)

      assert error["code"] == "choice_source_http_error"
      assert error["status"] == 422
      assert error["body"]["error"]["code"] == "invalid_choice_value"
    end
  end

  defp contract do
    %{
      "query_contract_version" => 1,
      "projection" => "query_contract",
      "choice_sources" => [
        %{
          "id" => "customer_choices",
          "domain" => "customers",
          "value_field" => "id",
          "label_field" => "name",
          "links" => %{
            "options" => "/api/orders/choice-sources/customer_choices/options",
            "validate" => "/api/orders/choice-sources/customer_choices/validate"
          }
        }
      ],
      "field_choice_bindings" => [
        %{"field" => "customer_id", "choice_source" => "customer_choices"}
      ]
    }
  end
end
