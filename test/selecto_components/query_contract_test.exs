defmodule SelectoComponents.QueryContractTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.QueryContract

  describe "build/1" do
    test "builds a query contract from an authored domain" do
      assert {:ok, contract, diagnostics} = QueryContract.build(domain())

      assert diagnostics.errors == []
      assert contract.projection == :query_contract
      assert contract.name == "Orders"
      assert contract.source == %{source_table: "orders", primary_key: :id}

      assert %{id: "id", source: :source, relation: :source, type: :integer} =
               Enum.find(contract.fields, &(&1.id == "id"))

      assert %{id: "customers.name", source: :schema, relation: :customers, type: :string} =
               Enum.find(contract.fields, &(&1.id == "customers.name"))

      assert [
               %{
                 id: "customer",
                 path: ["customer"],
                 parent: :source,
                 target_schema: :customers,
                 type: :left
               }
             ] = contract.joins

      assert [%{id: :status_filter, field: "status", type: :string}] = contract.filters
      assert [%{id: :status_label, kind: :scalar}] = contract.functions
      assert [%{id: :open_orders, columns: [:id, :status]}] = contract.query_members.ctes
      assert [%{id: :order_summary, kind: :view}] = contract.published_views

      assert [%{id: :customer_choices, domain: :customers, value_field: "id"}] =
               contract.choice_sources

      assert [%{field: "customer_id", choice_source: :customer_choices}] =
               contract.field_choice_bindings

      assert contract.capability_ids == [
               "customer.choose",
               "order.filter",
               "order.member",
               "order.rank",
               "order.view"
             ]

      refute Map.has_key?(contract, :writes)
      refute Map.has_key?(contract, :actions)
      refute Map.has_key?(contract, :detail_actions)
    end

    test "builds a query contract from a configured Selecto struct" do
      selecto = Selecto.configure(domain(), nil, validate: false)

      assert {:ok, contract, diagnostics} = QueryContract.build(selecto)

      assert diagnostics.errors == []
      assert contract.projection == :query_contract
      assert contract.name == "Orders"
    end

    test "builds a query contract from a selecto-like map" do
      assert {:ok, contract, diagnostics} = QueryContract.build(%{domain: domain()})

      assert diagnostics.errors == []
      assert contract.projection == :query_contract
      assert contract.name == "Orders"
    end

    test "passes normalized domains through without unwrapping them" do
      assert {:ok, normalized, _diagnostics} = Selecto.Domain.normalize(domain())

      assert {:ok, contract, diagnostics} = QueryContract.build(normalized)

      assert diagnostics.errors == []
      assert contract.projection == :query_contract
      assert contract.name == "Orders"
    end

    test "returns core diagnostics for invalid input" do
      assert {:error, diagnostics} = QueryContract.build(:not_a_domain)

      assert [%{code: :invalid_domain}] = diagnostics.errors
    end
  end

  describe "json_document/1" do
    test "returns a JSON-ready query contract document" do
      assert {:ok, document, diagnostics} =
               QueryContract.json_document(domain(),
                 generated_at: "2026-04-30T19:50:00Z",
                 domain_id: "orders",
                 domain_path: "/orders",
                 query_contract_url: "/selecto/orders/query-contract.json",
                 query_guide_url: "/selecto/orders/query-guide.md",
                 context: %{
                   exports: [:csv, :json],
                   saved_views_enabled: true,
                   exported_views_enabled: true
                 }
               )

      assert diagnostics.errors == []
      assert document["query_contract_version"] == 1
      assert document["generated_at"] == "2026-04-30T19:50:00Z"
      assert document["schema_version"] == 1
      assert document["projection"] == "query_contract"
      assert document["domain"] == %{"id" => "orders", "name" => "Orders", "path" => "/orders"}

      assert document["links"] == %{
               "query_contract" => "/selecto/orders/query-contract.json",
               "query_guide" => "/selecto/orders/query-guide.md"
             }

      assert document["context"]["view_modes"] == ["detail", "aggregate", "graph"]
      assert document["context"]["default_view_mode"] == "detail"
      assert document["context"]["exports"] == ["csv", "json"]
      assert document["context"]["saved_views_enabled"] == true
      assert document["context"]["exported_views_enabled"] == true
      assert document["params_schema"]["view_mode"]["type"] == "enum"
      assert document["params_schema"]["view_mode"]["values"] == ["detail", "aggregate", "graph"]
      assert document["examples"] == []
      assert %{"codes" => error_codes} = document["errors"]
      assert Enum.any?(error_codes, &(&1["code"] == "invalid_field"))
      assert document["source"] == %{"source_table" => "orders", "primary_key" => "id"}

      assert %{"id" => "status_filter", "field" => "status", "type" => "string"} =
               Enum.find(document["filters"], &(&1["id"] == "status_filter"))

      assert %{
               "id" => "customer_id",
               "filterable" => true,
               "sortable" => true,
               "groupable" => true,
               "aggregatable" => true,
               "aggregate_functions" => ["count", "count_distinct", "sum", "avg", "min", "max"]
             } = customer_id_field = Enum.find(document["fields"], &(&1["id"] == "customer_id"))

      assert "between" in customer_id_field["comparators"]

      assert %{"id" => "customer", "target_schema" => "customers"} =
               Enum.find(document["joins"], &(&1["id"] == "customer"))

      assert %{"field" => "customer_id", "choice_source" => "customer_choices"} =
               Enum.find(
                 document["field_choice_bindings"],
                 &(&1["field"] == "customer_id")
               )

      assert_json_safe(document)
      refute_nil_map_values(document)
    end

    test "encodes a query contract JSON document" do
      assert {:ok, json, diagnostics} =
               QueryContract.encode_json(domain(),
                 pretty: true,
                 generated_at: "2026-04-30T19:50:00Z",
                 domain_id: "orders"
               )

      assert diagnostics.errors == []

      decoded = Jason.decode!(json)

      assert decoded["query_contract_version"] == 1
      assert decoded["generated_at"] == "2026-04-30T19:50:00Z"
      assert decoded["domain"]["id"] == "orders"
      assert decoded["projection"] == "query_contract"

      assert decoded["capability_ids"] == [
               "customer.choose",
               "order.filter",
               "order.member",
               "order.rank",
               "order.view"
             ]
    end

    test "returns core diagnostics for invalid JSON document input" do
      assert {:error, diagnostics} = QueryContract.json_document(:not_a_domain)

      assert [%{code: :invalid_domain}] = diagnostics.errors
    end
  end

  describe "validate_intent/2" do
    test "accepts a valid detail query intent" do
      document = query_contract_document()

      validation =
        QueryContract.validate_intent(document, %{
          "view_mode" => "detail",
          "select" => ["id", "status", "customers.name"],
          "filters" => [
            %{"field" => "status", "comparator" => "contains", "value" => "open"}
          ],
          "order_by" => [
            %{"field" => "customer_id", "direction" => "desc"}
          ]
        })

      assert validation[:valid?]
      assert validation.errors == []
      assert validation.warnings == []
    end

    test "reports stable diagnostics for invalid fields, comparators, and sort direction" do
      validation =
        QueryContract.validate_intent(query_contract_document(), %{
          "view_mode" => "detail",
          "select" => ["missing_field"],
          "filters" => [
            %{"field" => "status", "comparator" => "regex", "value" => "open"}
          ],
          "order_by" => [
            %{"field" => "customer_id", "direction" => "sideways"}
          ]
        })

      refute validation[:valid?]

      assert Enum.find(validation.errors, &match?(%{code: :invalid_field, path: "select.0"}, &1))

      assert Enum.find(
               validation.errors,
               &match?(%{code: :invalid_comparator, path: "filters.0.comparator"}, &1)
             )

      assert Enum.find(
               validation.errors,
               &match?(%{code: :invalid_sort_direction, path: "order_by.0.direction"}, &1)
             )
    end

    test "rejects fields that are not exposed for the requested query use" do
      document =
        query_contract_document()
        |> put_field_capability("status", "filterable", false)
        |> put_field_capability("customer_id", "sortable", false)

      validation =
        QueryContract.validate_intent(document, %{
          "view_mode" => "detail",
          "filters" => [
            %{"field" => "status", "comparator" => "contains", "value" => "open"}
          ],
          "order_by" => [
            %{"field" => "customer_id", "direction" => "asc"}
          ]
        })

      refute validation[:valid?]

      assert Enum.find(
               validation.errors,
               &match?(%{code: :field_not_filterable, path: "filters.0.field"}, &1)
             )

      assert Enum.find(
               validation.errors,
               &match?(%{code: :field_not_sortable, path: "order_by.0.field"}, &1)
             )
    end

    test "accepts a valid aggregate query intent" do
      validation =
        QueryContract.validate_intent(query_contract_document(), %{
          "view_mode" => "aggregate",
          "group_by" => ["status"],
          "metrics" => [
            %{"field" => "customer_id", "function" => "sum"}
          ],
          "filters" => [
            %{"field" => "status", "comparator" => "contains", "value" => "open"}
          ],
          "order_by" => [
            %{"field" => "customer_id", "direction" => "desc"}
          ]
        })

      assert validation[:valid?]
      assert validation.errors == []
      assert validation.warnings == []
    end

    test "reports aggregate diagnostics for group fields, metric fields, and functions" do
      validation =
        QueryContract.validate_intent(query_contract_document(), %{
          "view_mode" => "aggregate",
          "group_by" => ["missing_group"],
          "metrics" => [
            %{"field" => "status", "function" => "sum"},
            %{"field" => "customer_id", "function" => "median"}
          ]
        })

      refute validation[:valid?]

      assert Enum.find(
               validation.errors,
               &match?(%{code: :invalid_field, path: "group_by.0"}, &1)
             )

      assert Enum.find(
               validation.errors,
               &match?(%{code: :field_not_aggregatable, path: "metrics.0.field"}, &1)
             )

      assert Enum.find(
               validation.errors,
               &match?(%{code: :invalid_aggregate_function, path: "metrics.1.function"}, &1)
             )
    end

    test "accepts a valid graph query intent" do
      validation =
        QueryContract.validate_intent(query_contract_document(), %{
          "view_mode" => "graph",
          "x_axis" => ["status"],
          "y_axis" => [
            %{"field" => "customer_id", "function" => "sum"}
          ],
          "series" => ["customers.name"],
          "filters" => [
            %{"field" => "status", "comparator" => "contains", "value" => "open"}
          ]
        })

      assert validation[:valid?]
      assert validation.errors == []
      assert validation.warnings == []
    end

    test "reports graph diagnostics for axes, series, metric fields, and functions" do
      validation =
        QueryContract.validate_intent(query_contract_document(), %{
          "view_mode" => "graph",
          "x_axis" => ["missing_axis"],
          "y_axis" => [
            %{"field" => "status", "function" => "sum"},
            %{"field" => "customer_id", "function" => "median"}
          ],
          "series" => ["missing_series"]
        })

      refute validation[:valid?]

      assert Enum.find(validation.errors, &match?(%{code: :invalid_field, path: "x_axis.0"}, &1))

      assert Enum.find(validation.errors, &match?(%{code: :invalid_field, path: "series.0"}, &1))

      assert Enum.find(
               validation.errors,
               &match?(%{code: :field_not_aggregatable, path: "y_axis.0.field"}, &1)
             )

      assert Enum.find(
               validation.errors,
               &match?(%{code: :invalid_aggregate_function, path: "y_axis.1.function"}, &1)
             )
    end

    test "rejects invalid view modes" do
      document = query_contract_document()

      invalid = QueryContract.validate_intent(document, %{"view_mode" => "timeline"})

      assert [%{code: :invalid_view_mode, path: "view_mode"}] = invalid.errors
    end
  end

  defp domain do
    %{
      name: "Orders",
      source: %{
        source_table: "orders",
        primary_key: :id,
        fields: [:id, :status, :customer_id],
        redact_fields: [],
        columns: %{
          id: %{type: :integer, name: "ID"},
          status: %{type: :string, name: "Status"},
          customer_id: %{
            type: :integer,
            name: "Customer",
            choice_source: :customer_choices
          }
        },
        associations: %{
          customer: %{
            queryable: :customers,
            field: :customer,
            owner_key: :customer_id,
            related_key: :id
          }
        }
      },
      schemas: %{
        customers: %{
          source_table: "customers",
          primary_key: :id,
          fields: [:id, :name],
          redact_fields: [],
          columns: %{
            id: %{type: :integer, name: "ID"},
            name: %{type: :string, name: "Name"}
          },
          associations: %{}
        }
      },
      joins: %{customer: %{type: :left}},
      default_selected: [:id, "customers.name"],
      filters: %{
        status_filter: %{
          field: :status,
          type: :string,
          name: "Status",
          capability: "order.filter"
        }
      },
      functions: %{
        status_label: %{
          kind: :scalar,
          sql_name: "public.status_label",
          allowed_in: [:select],
          returns: :string,
          capability: "order.rank"
        }
      },
      query_members: %{
        ctes: %{
          open_orders: %{
            query: fn selecto -> selecto end,
            columns: [:id, :status],
            join: [owner_key: :id, related_key: :id],
            capability: "order.member"
          }
        }
      },
      published_views: %{
        order_summary: %{
          database_name: "reporting.order_summary",
          kind: :view,
          query: fn selecto -> selecto end,
          columns: %{order_id: %{type: :integer}},
          capability: "order.view"
        }
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
      },
      capabilities: %{
        "customer.choose" => %{operations: [:choice_source]},
        "order.filter" => %{operations: [:filter]},
        "order.member" => %{operations: [:query_member]},
        "order.rank" => %{operations: [:select]},
        "order.view" => %{operations: [:select]}
      }
    }
  end

  defp assert_json_safe(value) when is_map(value) do
    Enum.each(value, fn {key, value} ->
      assert is_binary(key)
      assert_json_safe(value)
    end)
  end

  defp assert_json_safe(value) when is_list(value), do: Enum.each(value, &assert_json_safe/1)

  defp assert_json_safe(value) when is_atom(value), do: assert(value in [nil, true, false])

  defp assert_json_safe(value) do
    assert is_binary(value) or is_number(value)
  end

  defp refute_nil_map_values(value) when is_map(value) do
    Enum.each(value, fn {key, value} ->
      refute is_nil(value), "expected #{inspect(key)} to be omitted instead of nil"
      refute_nil_map_values(value)
    end)
  end

  defp refute_nil_map_values(value) when is_list(value),
    do: Enum.each(value, &refute_nil_map_values/1)

  defp refute_nil_map_values(_value), do: :ok

  defp query_contract_document do
    assert {:ok, document, diagnostics} =
             QueryContract.json_document(domain(),
               generated_at: "2026-04-30T19:50:00Z",
               domain_id: "orders",
               domain_path: "/orders"
             )

    assert diagnostics.errors == []

    document
  end

  defp put_field_capability(document, field_id, capability, value) do
    update_in(document["fields"], fn fields ->
      Enum.map(fields, fn
        %{"id" => ^field_id} = field -> Map.put(field, capability, value)
        field -> field
      end)
    end)
  end
end
