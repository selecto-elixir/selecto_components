defmodule SelectoComponents.Form.ColumnCatalogTest do
  use ExUnit.Case, async: true

  alias Selecto.Expr, as: X
  alias SelectoComponents.Form.ColumnCatalog

  defp selecto do
    domain = %{
      name: "ColumnCatalogTest",
      source: %{
        source_table: "records",
        primary_key: :id,
        fields: [:id, :status, :priority],
        redact_fields: [],
        columns: %{
          id: %{type: :integer, name: "ID"},
          status: %{type: :string, name: "Status"},
          priority: %{type: :integer, name: "Priority"}
        },
        associations: %{}
      },
      schemas: %{},
      joins: %{},
      query_members: %{
        ctes: %{
          active_delivery_projects: %{
            query: fn selecto ->
              selecto
              |> Selecto.select(["id", X.as("priority", "priority")])
            end,
            columns: ["id", "priority"],
            join: [owner_key: :id, related_key: :id, fields: :infer]
          }
        }
      }
    }

    Selecto.configure(domain, nil)
  end

  test "picker_columns exposes cte-backed fields with a cte icon" do
    {_id, _name, metadata} =
      ColumnCatalog.picker_columns(selecto())
      |> Enum.find(fn {id, _name, _metadata} ->
        to_string(id) == "active_delivery_projects.priority"
      end)

    assert metadata.icon == :cte
    assert metadata.icon_family == :cte
    assert metadata.cte_name == "active_delivery_projects"
  end

  test "required_cte_names_for_fields derives ctes from qualified field ids" do
    assert ColumnCatalog.required_cte_names_for_fields(selecto(), [
             "status",
             "active_delivery_projects.priority",
             "active_delivery_projects.priority"
           ]) == ["active_delivery_projects"]
  end
end
