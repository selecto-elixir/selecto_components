defmodule SelectoComponents.Views.Detail.ProcessTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.Views.Detail.Process

  defp selecto do
    domain = %{
      name: "DetailProcessTest",
      source: %{
        source_table: "workspaces",
        primary_key: :id,
        fields: [:id, :name, :purpose],
        redact_fields: [],
        columns: %{
          id: %{type: :integer},
          name: %{type: :string},
          purpose: %{type: :string}
        },
        associations: %{}
      },
      schemas: %{},
      joins: %{},
      detail_actions: %{
        workspace_snapshot: %{
          name: "Workspace Snapshot",
          type: :modal,
          required_fields: [:id, :name, :purpose],
          payload: %{}
        }
      }
    }

    Selecto.configure(domain, nil)
  end

  test "appends hidden required row action fields to the query selection" do
    params = %{
      "view_mode" => "detail",
      "row_click_action" => "workspace_snapshot",
      "selected" => %{
        "k0" => %{"field" => "id", "index" => "0", "uuid" => "id-col", "alias" => ""},
        "k1" => %{"field" => "name", "index" => "1", "uuid" => "name-col", "alias" => ""}
      }
    }

    columns = Selecto.columns(selecto())

    {view_set, view_meta} = Process.view(%{}, params, columns, [], selecto())

    assert Enum.map(view_set.columns, & &1["field"]) == ["id", "name"]
    assert Enum.map(view_set.row_action_query_columns, & &1["field"]) == ["id", "name", "purpose"]

    hidden_column = Enum.find(view_set.row_action_query_columns, &(&1["field"] == "purpose"))

    assert hidden_column["hidden"] == true
    assert hidden_column["row_action_required"] == true
    assert length(view_set.selected) == 3
    assert view_meta.row_click_action == "workspace_snapshot"
  end
end
