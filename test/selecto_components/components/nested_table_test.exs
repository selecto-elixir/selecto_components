defmodule SelectoComponents.Components.NestedTableTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias SelectoComponents.Components.NestedTable

  test "get_data_keys uses config column order when provided" do
    parsed_data = [
      %{"co_name" => "Acme", "id" => 10, "status" => "active"}
    ]

    config = %{
      columns: [
        {"u1", "supplier.co_name", %{}},
        {"u2", "supplier.status", %{}},
        {"u3", "supplier.id", %{}}
      ]
    }

    assert NestedTable.get_data_keys(parsed_data, config) == ["co_name", "status", "id"]
  end

  test "inline nested table renders list and JSON descendants recursively" do
    data = [
      %{
        "name" => "Parent",
        "children" => [
          %{
            "name" => "Child",
            "grandchildren" => Jason.encode!([%{"name" => "Grandchild"}])
          }
        ]
      }
    ]

    html =
      render_component(&NestedTable.inline_nested_table/1, %{
        data: data,
        config: %{key: "parents", title: "Parents", max_depth: 6},
        row_id: "parents"
      })

    assert html =~ "Parent"
    assert html =~ "Children"
    assert html =~ "Child"
    assert html =~ "Grandchildren"
    assert html =~ "Grandchild"
    refute html =~ ~s(&quot;Grandchild&quot;)
  end
end
