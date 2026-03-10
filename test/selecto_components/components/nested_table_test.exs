defmodule SelectoComponents.Components.NestedTableTest do
  use ExUnit.Case, async: true

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
end
