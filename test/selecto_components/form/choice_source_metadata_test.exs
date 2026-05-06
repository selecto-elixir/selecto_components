defmodule SelectoComponents.Form.ChoiceSourceMetadataTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.Form.ChoiceSourceMetadata

  describe "fields/2" do
    test "attaches choice-source metadata to bound fields" do
      fields =
        ChoiceSourceMetadata.fields(contract(),
          base_url: "https://example.test",
          headers: [{"authorization", "Bearer token"}]
        )

      assert %{
               "id" => "customer_id",
               "choice_source" => "customer_choices",
               "choice_source_metadata" => metadata
             } = Enum.find(fields, &(&1["id"] == "customer_id"))

      assert metadata["id"] == "customer_choices"
      assert metadata["field"] == "customer_id"
      assert metadata["domain"] == "customers"
      assert metadata["value_field"] == "id"
      assert metadata["label_field"] == "name"
      assert metadata["status"] == "linked"
      assert metadata["transport"] == "http"
      assert metadata["async_options"] == true
      assert metadata["validates_membership"] == true
      assert metadata["presentation"] == %{"control" => "autocomplete", "mode" => "async"}

      assert metadata["options_request"] == %{
               "method" => "get",
               "url" => "https://example.test/api/orders/choice-sources/customer_choices/options",
               "headers" => %{
                 "accept" => "application/json",
                 "authorization" => "Bearer token"
               }
             }

      assert metadata["validate_request_template"] == %{
               "method" => "post",
               "url" =>
                 "https://example.test/api/orders/choice-sources/customer_choices/validate",
               "headers" => %{
                 "accept" => "application/json",
                 "authorization" => "Bearer token",
                 "content-type" => "application/json"
               },
               "body" => %{"field" => "customer_id", "value" => "$value"}
             }

      assert %{"id" => "status"} = status_field = Enum.find(fields, &(&1["id"] == "status"))
      refute Map.has_key?(status_field, "choice_source_metadata")
    end

    test "uses field_choice_bindings when fields do not carry choice_source directly" do
      contract =
        update_in(contract(), ["fields"], fn fields ->
          Enum.map(fields, &Map.delete(&1, "choice_source"))
        end)

      assert [field] = ChoiceSourceMetadata.choice_source_fields(contract)
      assert field["id"] == "customer_id"
      assert field["choice_source_metadata"]["id"] == "customer_choices"
    end

    test "can mark choice sources for LiveView transport" do
      [field] = ChoiceSourceMetadata.choice_source_fields(contract(), transport: :live)

      assert field["choice_source_metadata"]["transport"] == "live"
    end

    test "marks metadata unresolved when a binding points at a missing source" do
      contract = put_in(contract(), ["choice_sources"], [])

      assert [field] = ChoiceSourceMetadata.choice_source_fields(contract)
      metadata = field["choice_source_metadata"]

      assert metadata["status"] == "unresolved"
      assert metadata["async_options"] == false
      assert metadata["validates_membership"] == false
      assert [%{"code" => "choice_source_not_found"}] = metadata["errors"]
    end
  end

  describe "field/3" do
    test "returns a single annotated field or a structured error" do
      assert {:ok, field} = ChoiceSourceMetadata.field(contract(), :customer_id)
      assert field["choice_source_metadata"]["id"] == "customer_choices"

      assert {:error, error} = ChoiceSourceMetadata.field(contract(), :missing)
      assert error["code"] == "field_not_found"
      assert error["path"] == ["fields", "missing"]
    end
  end

  defp contract do
    %{
      "query_contract_version" => 1,
      "projection" => "query_contract",
      "fields" => [
        %{
          "id" => "customer_id",
          "field" => "customer_id",
          "source" => "source",
          "relation" => "source",
          "type" => "integer",
          "label" => "Customer",
          "choice_source" => "customer_choices"
        },
        %{
          "id" => "status",
          "field" => "status",
          "source" => "source",
          "relation" => "source",
          "type" => "string",
          "label" => "Status"
        }
      ],
      "field_choice_bindings" => [
        %{"field" => "customer_id", "choice_source" => "customer_choices"}
      ],
      "choice_sources" => [
        %{
          "id" => "customer_choices",
          "domain" => "customers",
          "source_relationship" => "customer",
          "value_field" => "id",
          "label_field" => "name",
          "presentation" => %{"control" => "autocomplete", "mode" => "async"},
          "links" => %{
            "options" => "/api/orders/choice-sources/customer_choices/options",
            "validate" => "/api/orders/choice-sources/customer_choices/validate"
          }
        }
      ]
    }
  end
end
