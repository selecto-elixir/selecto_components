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

  defp text_search_selecto do
    domain = %{
      name: "FiltersTextSearchTest",
      source: %{
        source_table: "records",
        primary_key: :id,
        fields: [:id, :search_document],
        redact_fields: [],
        columns: %{
          id: %{type: :integer, colid: "id", name: "ID"},
          search_document: %{type: :tsvector, colid: "search_document", name: "Search Document"}
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

  defp epoch_datetime_selecto do
    domain = %{
      name: "FiltersEpochDateTimeTest",
      source: %{
        source_table: "records",
        primary_key: :id,
        fields: [:id, :occurred_at_epoch],
        redact_fields: [],
        columns: %{
          id: %{type: :integer},
          occurred_at_epoch: %{
            type: :integer,
            presentation_type: :utc_datetime,
            datetime_storage: :unix_ms
          }
        },
        associations: %{}
      },
      schemas: %{},
      joins: %{}
    }

    Selecto.configure(domain, nil)
  end

  describe "filter_recurse/3 text prefix buckets" do
    test "preserves explicit text search mode config" do
      filters = %{
        "filters" => [
          %{
            "uuid" => "f1",
            "section" => "filters",
            "filter" => "search_document",
            "comp" => "TEXT_SEARCH",
            "value" => "wireless charger",
            "mode" => "boolean"
          }
        ]
      }

      [filter] = Filters.filter_recurse(text_search_selecto(), filters, "filters")

      assert {"search_document", {:text_search, "wireless charger", [mode: :boolean]}} = filter
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

    test "coerces epoch-backed datetime shortcuts to epoch integers" do
      filters = %{
        "filters" => [
          %{
            "uuid" => "f1",
            "section" => "filters",
            "filter" => "occurred_at_epoch",
            "comp" => "SHORTCUT",
            "value" => "today"
          }
        ]
      }

      [{"occurred_at_epoch", {:between, start_epoch, end_epoch}}] =
        Filters.filter_recurse(epoch_datetime_selecto(), filters, "filters")

      assert is_integer(start_epoch)
      assert is_integer(end_epoch)
      assert end_epoch > start_epoch
    end

    test "uses epoch-aware SQL extraction for weekday filters" do
      filters = %{
        "filters" => [
          %{
            "uuid" => "f1",
            "section" => "filters",
            "filter" => "occurred_at_epoch",
            "comp" => "SHORTCUT",
            "value" => "monday"
          }
        ]
      }

      [filter] = Filters.filter_recurse(epoch_datetime_selecto(), filters, "filters")

      assert {:raw_sql_filter, iodata} = filter
      sql = IO.iodata_to_binary(iodata)
      assert sql =~ "TO_TIMESTAMP((selecto_root.occurred_at_epoch) / 1000.0)"
      assert sql =~ "EXTRACT(ISODOW FROM"
    end
  end
end
