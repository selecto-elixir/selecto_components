defmodule SelectoComponents.Views.Aggregate.ProcessTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.Views.Aggregate.Process

  defp selecto do
    domain = %{
      name: "AggregateProcessTest",
      source: %{
        source_table: "records",
        primary_key: :id,
        fields: [:id, :title],
        redact_fields: [],
        columns: %{
          id: %{type: :integer},
          title: %{type: :string}
        },
        associations: %{}
      },
      schemas: %{},
      joins: %{}
    }

    Selecto.configure(domain, nil)
  end

  test "group_by/3 builds text prefix bucket selector for string fields" do
    columns = %{
      "title" => %{colid: :title, type: :string, name: "Title"}
    }

    params = %{
      "g1" => %{
        "field" => "title",
        "index" => "0",
        "format" => "text_prefix",
        "prefix_length" => "2",
        "exclude_articles" => "true"
      }
    }

    [{_col, {:field, {:raw_sql, sql}, "title"}}] = Process.group_by(params, columns, selecto())

    assert sql =~ "REGEXP_REPLACE"
    assert sql =~ "UPPER(LEFT("
    assert sql =~ ", 2))"
  end
end
