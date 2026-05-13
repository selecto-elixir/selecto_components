defmodule SelectoComponents.Execution.CTEsTest do
  use ExUnit.Case, async: true

  alias Selecto.Expr, as: X
  alias SelectoComponents.Execution.CTEs

  test "sync_view_config derives ctes from cte-backed view fields" do
    view_config = %{
      view_mode: "detail",
      filters: [],
      ctes: [],
      views: %{
        detail: %{
          selected: [{"detail-col-1", "active_delivery_projects.priority", %{}}]
        }
      }
    }

    assert CTEs.sync_view_config(view_config, selecto()).ctes == [
             {"auto-cte-active_delivery_projects", "active_delivery_projects", %{}}
           ]
  end

  test "apply_for_params applies derived ctes during execution planning" do
    params = %{
      "view_mode" => "detail",
      "selected" => %{
        "k0" => %{
          "field" => "active_delivery_projects.priority",
          "index" => "0",
          "uuid" => "detail-col-1"
        }
      }
    }

    assert "active_delivery_projects" in applied_cte_names(
             CTEs.apply_for_params(selecto(), params)
           )
  end

  defp applied_cte_names(selecto) do
    selecto.set
    |> Map.get(:ctes, [])
    |> Enum.map(fn spec -> Map.get(spec, :name) || Map.get(spec, "name") end)
  end

  defp selecto do
    domain = %{
      name: "ExecutionCTEsTest",
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
end
