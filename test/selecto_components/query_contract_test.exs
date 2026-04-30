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
end
