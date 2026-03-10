defmodule SelectoComponents.Views.Detail.ComponentTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias SelectoComponents.Views.Detail.Component

  defp selecto do
    domain = %{
      name: "DetailComponentTest",
      source: %{
        source_table: "records",
        primary_key: :id,
        fields: [:id],
        redact_fields: [],
        columns: %{id: %{type: :integer}},
        associations: %{}
      },
      schemas: %{},
      joins: %{}
    }

    Selecto.configure(domain, nil)
  end

  defp base_assigns(overrides \\ %{}) do
    base = %{
      id: "detail-component-test",
      executed: true,
      execution_error: nil,
      selecto: %{
        selecto()
        | set: %{
            columns: [
              %{"field" => "id", "alias" => "id", "uuid" => "id-col"}
            ]
          }
      },
      query_results: {[[100], [101]], [:id], ["ID"]},
      view_meta: %{page: 2, per_page: 2, total_rows: 10, subselect_configs: []}
    }

    Map.merge(base, overrides)
  end

  test "renders current detail page rows and global row numbers" do
    html = render_component(Component, base_assigns())

    assert html =~ "5-6"
    assert html =~ "rows"

    assert html =~
             ~r/Page\s*<span class="font-semibold">3<\/span>\s*of\s*<span class="font-semibold">5<\/span>/

    assert html =~ ~r/>\s*5\s*</
    assert html =~ ~r/>\s*6\s*</
    assert html =~ "100"
    assert html =~ "101"
    assert html =~ "aria-label=\"First page\""
    assert html =~ "aria-label=\"Previous page\""
    assert html =~ "aria-label=\"Next page\""
    assert html =~ "aria-label=\"Last page\""
  end

  test "disables forward pagination buttons on the last page" do
    assigns =
      base_assigns(%{
        view_meta: %{page: 4, per_page: 2, total_rows: 10, subselect_configs: []}
      })

    html = render_component(Component, assigns)

    assert html =~ ~r/aria-label="Next page"[^>]*disabled/
    assert html =~ ~r/aria-label="Last page"[^>]*disabled/
    refute html =~ ~r/aria-label="First page"[^>]*disabled/
    refute html =~ ~r/aria-label="Previous page"[^>]*disabled/
  end

  test "disables backward pagination buttons on the first page" do
    assigns =
      base_assigns(%{
        view_meta: %{page: 0, per_page: 2, total_rows: 10, subselect_configs: []}
      })

    html = render_component(Component, assigns)

    assert html =~ ~r/aria-label="First page"[^>]*disabled/
    assert html =~ ~r/aria-label="Previous page"[^>]*disabled/
    refute html =~ ~r/aria-label="Next page"[^>]*disabled/
    refute html =~ ~r/aria-label="Last page"[^>]*disabled/
  end

  test "renders mapped row values when query columns are string keys" do
    assigns =
      base_assigns(%{
        query_results: {[%{id: 100}, %{id: 101}], ["id"], ["ID"]}
      })

    html = render_component(Component, assigns)

    assert html =~ "100"
    assert html =~ "101"
  end

  test "renders row values when column uuid does not match row-data uuid mapping" do
    assigns =
      base_assigns(%{
        selecto: %{
          selecto()
          | set: %{
              columns: [
                %{"field" => "id", "alias" => "id", "uuid" => "unknown-uuid"}
              ]
            }
        },
        query_results: {[%{"id" => 100}, %{"id" => 101}], ["id"], ["ID"]}
      })

    html = render_component(Component, assigns)

    assert html =~ "100"
    assert html =~ "101"
  end

  test "maps row values by alias when DB columns collide" do
    domain = %{
      name: "DetailAliasCollisionTest",
      source: %{
        source_table: "orders",
        primary_key: :id,
        fields: [:id],
        redact_fields: [],
        columns: %{id: %{type: :integer}},
        associations: %{}
      },
      schemas: %{},
      joins: %{}
    }

    collision_selecto =
      Selecto.configure(domain, nil)
      |> Map.put(:set, %{
        columns: [
          %{"field" => "supplier.co_name", "alias" => "supplier_name", "uuid" => "c1"},
          %{"field" => "customer.co_name", "alias" => "customer_name", "uuid" => "c2"}
        ]
      })

    assigns = %{
      id: "detail-component-alias-collision",
      executed: true,
      execution_error: nil,
      selecto: collision_selecto,
      query_results:
        {[["Supplier A", "Customer B"]], ["co_name", "co_name"],
         ["supplier_name", "customer_name"]},
      view_meta: %{page: 0, per_page: 10, total_rows: 1, subselect_configs: []}
    }

    html = render_component(Component, assigns)

    assert html =~ "Supplier A"
    assert html =~ "Customer B"
  end
end
