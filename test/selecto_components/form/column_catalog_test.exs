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
        fields: [:id, :status, :priority, :customer_id],
        redact_fields: [],
        columns: %{
          id: %{type: :integer, name: "ID"},
          status: %{type: :string, name: "Status"},
          priority: %{type: :integer, name: "Priority"},
          customer_id: %{
            type: :integer,
            name: "Customer",
            choice_source: :customer_choices
          }
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
      },
      choice_sources: %{
        customer_choices: %{
          domain: :customers,
          value_field: :id,
          label_field: :name,
          presentation: %{control: :autocomplete}
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

  test "picker_columns exposes choice-source metadata for choice-backed fields" do
    {_id, _name, metadata} =
      ColumnCatalog.picker_columns(selecto())
      |> Enum.find(fn {id, _name, _metadata} ->
        to_string(id) == "customer_id"
      end)

    assert metadata.choice_source == "customer_choices"
    assert metadata.choice_source_metadata["id"] == "customer_choices"
    assert metadata.choice_source_metadata["field"] == "customer_id"
    assert metadata.choice_source_metadata["domain"] == "customers"
    assert metadata.choice_source_metadata["presentation"] == %{"control" => "autocomplete"}
  end

  test "choice_source_metadata_by_field returns a field-indexed metadata map" do
    assert %{
             "customer_id" => %{
               "choice_source_metadata" => %{"id" => "customer_choices"}
             }
           } = ColumnCatalog.choice_source_metadata_by_field(selecto())
  end

  test "required_cte_names_for_fields derives ctes from qualified field ids" do
    assert ColumnCatalog.required_cte_names_for_fields(selecto(), [
             "status",
             "active_delivery_projects.priority",
             "active_delivery_projects.priority"
           ]) == ["active_delivery_projects"]
  end
end
