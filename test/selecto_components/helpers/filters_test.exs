defmodule SelectoComponents.Helpers.FiltersTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.Helpers.Filters

  defp selecto do
    domain = %{
      name: "FiltersTest",
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

  describe "filter_recurse/3 text prefix buckets" do
    test "builds a normalized raw-sql prefix filter" do
      filters = %{
        "filters" => [
          %{
            "uuid" => "f1",
            "section" => "filters",
            "filter" => "title",
            "comp" => "TEXT_PREFIX",
            "value" => "OF",
            "prefix_length" => "2",
            "exclude_articles" => "true"
          }
        ]
      }

      [filter] = Filters.filter_recurse(selecto(), filters, "filters")

      assert {{:raw_sql, sql_expr}, {:like, "of%"}} = filter
      assert sql_expr =~ "REGEXP_REPLACE"
      assert sql_expr =~ "selecto_root.title"
    end

    test "builds an Other-bucket raw sql filter" do
      filters = %{
        "filters" => [
          %{
            "uuid" => "f1",
            "section" => "filters",
            "filter" => "title",
            "comp" => "TEXT_PREFIX_OTHER",
            "value" => "",
            "prefix_length" => "2",
            "exclude_articles" => "true"
          }
        ]
      }

      [filter] = Filters.filter_recurse(selecto(), filters, "filters")

      assert {:raw_sql_filter, sql_filter} = filter
      assert IO.iodata_to_binary(sql_filter) =~ " = ''"
    end

    test "supports STARTS with article stripping" do
      filters = %{
        "filters" => [
          %{
            "uuid" => "f1",
            "section" => "filters",
            "filter" => "title",
            "comp" => "STARTS",
            "value" => "of",
            "exclude_articles" => "true"
          }
        ]
      }

      [filter] = Filters.filter_recurse(selecto(), filters, "filters")

      assert {{:raw_sql, sql_expr}, {:like, "of%"}} = filter
      assert sql_expr =~ "REGEXP_REPLACE"
      assert sql_expr =~ "selecto_root.title"
    end
  end
end
