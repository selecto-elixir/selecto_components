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

  defp datetime_selecto do
    domain = %{
      name: "FiltersDateTimeTest",
      source: %{
        source_table: "records",
        primary_key: :id,
        fields: [:id, :created_at],
        redact_fields: [],
        columns: %{
          id: %{type: :integer},
          created_at: %{type: :utc_datetime}
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

    test "keeps STARTS with article stripping case-sensitive unless ignore_case is set" do
      filters = %{
        "filters" => [
          %{
            "uuid" => "f1",
            "section" => "filters",
            "filter" => "title",
            "comp" => "STARTS",
            "value" => "Of",
            "exclude_articles" => "true",
            "ignore_case" => "false"
          }
        ]
      }

      [filter] = Filters.filter_recurse(selecto(), filters, "filters")

      assert {{:raw_sql, sql_expr}, {:like, "Of%"}} = filter
      refute sql_expr =~ "LOWER("
    end

    test "supports equals with article stripping and case-insensitive mode" do
      filters = %{
        "filters" => [
          %{
            "uuid" => "f1",
            "section" => "filters",
            "filter" => "title",
            "comp" => "=",
            "value" => "Office",
            "exclude_articles" => "true",
            "ignore_case" => "true"
          }
        ]
      }

      [filter] = Filters.filter_recurse(selecto(), filters, "filters")

      assert {{:raw_sql, sql_expr}, "office"} = filter
      assert sql_expr =~ "LOWER("
      assert sql_expr =~ "REGEXP_REPLACE"
    end

    test "supports case-insensitive contains filters" do
      filters = %{
        "filters" => [
          %{
            "uuid" => "f1",
            "section" => "filters",
            "filter" => "title",
            "comp" => "LIKE",
            "value" => "office",
            "ignore_case" => "true"
          }
        ]
      }

      [filter] = Filters.filter_recurse(selecto(), filters, "filters")

      assert {{:upper, "title"}, {:like, "%OFFICE%"}} = filter
    end

    test "supports case-insensitive starts-with filters" do
      filters = %{
        "filters" => [
          %{
            "uuid" => "f1",
            "section" => "filters",
            "filter" => "title",
            "comp" => "STARTS",
            "value" => "the",
            "ignore_case" => "true"
          }
        ]
      }

      [filter] = Filters.filter_recurse(selecto(), filters, "filters")

      assert {{:upper, "title"}, {:like, "THE%"}} = filter
    end
  end

  describe "filter_recurse/3 datetime coercion" do
    test "converts DATE_BETWEEN bounds to DateTime for utc_datetime fields" do
      filters = %{
        "filters" => [
          %{
            "uuid" => "f1",
            "section" => "filters",
            "filter" => "created_at",
            "comp" => "DATE_BETWEEN",
            "value" => "2017-01-01",
            "value2" => "2018-01-01"
          }
        ]
      }

      [{"created_at", {:between, start_dt, end_dt}}] =
        Filters.filter_recurse(datetime_selecto(), filters, "filters")

      assert %DateTime{} = start_dt
      assert %DateTime{} = end_dt
    end

    test "supports weekday extraction filter for datetime fields" do
      filters = %{
        "filters" => [
          %{
            "uuid" => "f1",
            "section" => "filters",
            "filter" => "created_at",
            "comp" => "WEEKDAY",
            "value" => "1"
          }
        ]
      }

      [filter] = Filters.filter_recurse(datetime_selecto(), filters, "filters")

      assert {:raw_sql_filter, iodata} = filter
      sql = IO.iodata_to_binary(iodata)
      assert sql =~ "EXTRACT(ISODOW FROM selecto_root.created_at)"
      assert sql =~ "= 1"
    end

    test "supports sunday-based weekday filter for grouped D format" do
      filters = %{
        "filters" => [
          %{
            "uuid" => "f1",
            "section" => "filters",
            "filter" => "created_at",
            "comp" => "WEEKDAY_SUN1",
            "value" => "1"
          }
        ]
      }

      [filter] = Filters.filter_recurse(datetime_selecto(), filters, "filters")

      assert {:raw_sql_filter, iodata} = filter
      sql = IO.iodata_to_binary(iodata)
      assert sql =~ "to_char(selecto_root.created_at, 'D')::int = 1"
    end

    test "supports week-of-year grouped filter" do
      filters = %{
        "filters" => [
          %{
            "uuid" => "f1",
            "section" => "filters",
            "filter" => "created_at",
            "comp" => "WEEK_OF_YEAR",
            "value" => "2017-02"
          }
        ]
      }

      [filter] = Filters.filter_recurse(datetime_selecto(), filters, "filters")

      assert {:raw_sql_filter, iodata} = filter
      sql = IO.iodata_to_binary(iodata)
      assert sql =~ "to_char(selecto_root.created_at, 'YYYY-WW') = '2017-02'"
    end

    test "supports weekday shortcut filters" do
      filters = %{
        "filters" => [
          %{
            "uuid" => "f1",
            "section" => "filters",
            "filter" => "created_at",
            "comp" => "SHORTCUT",
            "value" => "weekdays"
          }
        ]
      }

      [filter] = Filters.filter_recurse(datetime_selecto(), filters, "filters")

      assert {:raw_sql_filter, iodata} = filter
      sql = IO.iodata_to_binary(iodata)
      assert sql =~ "EXTRACT(ISODOW FROM selecto_root.created_at)"
      assert sql =~ "IN (1,2,3,4,5)"
    end

    test "supports standard date shortcut filters" do
      filters = %{
        "filters" => [
          %{
            "uuid" => "f1",
            "section" => "filters",
            "filter" => "created_at",
            "comp" => "SHORTCUT",
            "value" => "last_week"
          }
        ]
      }

      [{"created_at", {:between, start_dt, end_dt}}] =
        Filters.filter_recurse(datetime_selecto(), filters, "filters")

      assert %DateTime{} = start_dt
      assert %DateTime{} = end_dt
    end

    test "supports specific weekday shortcut filters" do
      filters = %{
        "filters" => [
          %{
            "uuid" => "f1",
            "section" => "filters",
            "filter" => "created_at",
            "comp" => "SHORTCUT",
            "value" => "monday"
          }
        ]
      }

      [filter] = Filters.filter_recurse(datetime_selecto(), filters, "filters")

      assert {:raw_sql_filter, iodata} = filter
      sql = IO.iodata_to_binary(iodata)
      assert sql =~ "IN (1)"
    end
  end
end
