defmodule SelectoComponents.QueryContract.GuideTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.QueryContract.Guide

  describe "markdown/2" do
    test "renders a readable Markdown query guide" do
      assert {:ok, markdown, diagnostics} =
               Guide.markdown(domain(),
                 generated_at: "2026-04-30T20:10:00Z",
                 domain_id: "orders",
                 domain_path: "/orders",
                 choice_source_links: %{
                   customer_choices: %{
                     options: "/selecto/orders/choice-sources/customer_choices/options",
                     validate: "/selecto/orders/choice-sources/customer_choices/validate"
                   }
                 },
                 context: %{exports: [:csv], saved_views_enabled: true}
               )

      assert diagnostics.errors == []
      assert markdown =~ "# Orders Query Guide"
      assert markdown =~ "- Domain id: `orders`"
      assert markdown =~ "- Path: `/orders`"
      assert markdown =~ "## Context"
      assert markdown =~ "- Exports: `csv`"
      assert markdown =~ "## Fields"
      assert markdown =~ "| `status` | Status | string | select, filter, sort, group |"
      assert markdown =~ "## Filters"
      assert markdown =~ "| `status_filter` | `status` | string |"
      assert markdown =~ "## Choice Sources"

      assert markdown =~
               "| `customer_choices` | `customers` | `id` | `name` | domain_of_interest=fail_closed | /selecto/orders/choice-sources/customer_choices/options | /selecto/orders/choice-sources/customer_choices/validate |"

      assert markdown =~ "## Choice-Backed Fields"

      assert markdown =~
               "| `customer_id` | `customer_choices` | autocomplete | /selecto/orders/choice-sources/customer_choices/options | /selecto/orders/choice-sources/customer_choices/validate |"

      assert markdown =~ "## Intent Vocabulary"
      assert markdown =~ "`contains`"
      assert markdown =~ "## Example Intent"
      assert markdown =~ "## Safety Notes"
    end

    test "returns core diagnostics for invalid input" do
      assert {:error, diagnostics} = Guide.markdown(:not_a_domain)

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
          customer_id: %{type: :integer, choice_source: :customer_choices}
        },
        associations: %{}
      },
      schemas: %{
        customers: %{
          source_table: "customers",
          primary_key: :id,
          fields: [:id, :name],
          redact_fields: [],
          columns: %{
            id: %{type: :integer},
            name: %{type: :string}
          },
          associations: %{}
        }
      },
      joins: %{},
      filters: %{
        status_filter: %{field: :status, type: :string, name: "Status"}
      },
      choice_sources: %{
        customer_choices: %{
          domain: :customers,
          value_field: :id,
          label_field: :name,
          constraint_policy: %{domain_of_interest: :fail_closed},
          presentation: %{control: :autocomplete}
        }
      },
      default_selected: [:id, :status]
    }
  end
end
