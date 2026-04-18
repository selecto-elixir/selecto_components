defmodule SelectoComponents.Views.Aggregate.ProcessTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.Views.Aggregate.Process

  defmodule Registration do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: false}

    schema "registrations" do
      field(:date_tier_id, Ecto.UUID)
    end
  end

  defmodule DateTier do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: false}

    schema "date_tiers" do
      field(:name, :string)
    end
  end

  defp uuid_join_selecto do
    domain = %{
      name: "AggregateUuidTest",
      source: %{
        source_table: "registrations",
        primary_key: :id,
        fields: [:id, :date_tier_id],
        redact_fields: [],
        columns: %{
          id: %{type: :string},
          date_tier_id: %{type: :string}
        },
        associations: %{}
      },
      schemas: %{
        date_tier: %{
          source_table: "date_tiers",
          primary_key: :id,
          fields: [:id, :name],
          columns: %{
            id: %{
              name: "Date Tier",
              type: :string,
              join_mode: :lookup,
              filter_type: :multi_select_id,
              display_field: :name,
              group_by_filter: "date_tier_id"
            },
            name: %{
              name: "Date Tier Name",
              type: :string
            }
          }
        }
      },
      joins: %{}
    }

    Selecto.configure(domain, nil)
  end

  test "param_to_state reads aggregate grid toggle" do
    state = Process.param_to_state(%{"aggregate_grid" => "true"}, %{})
    assert state.grid == true

    state = Process.param_to_state(%{"aggregate_grid" => "false"}, %{})
    assert state.grid == false
  end

  test "param_to_state reads aggregate grid color settings" do
    state =
      Process.param_to_state(
        %{
          "aggregate_grid_colorize" => "true",
          "aggregate_grid_color_scale" => "log"
        },
        %{}
      )

    assert state.grid_colorize == true
    assert state.grid_color_scale == "log"
  end

  test "aggregates honors count distinct from format" do
    columns = %{"id" => %{name: "Category ID", type: :id, colid: "id"}}

    assert Process.aggregates(
             %{"a1" => %{"field" => "id", "format" => "count_distinct"}},
             columns
           ) ==
             [{:field, {:count_distinct, "id"}, "Category ID Distinct Count"}]
  end

  test "aggregates build filtered boolean counts" do
    columns = %{"active" => %{name: "Active", type: :boolean, colid: "active"}}

    assert Process.aggregates(
             %{
               "a1" => %{"field" => "active", "format" => "true_count"},
               "a2" => %{"field" => "active", "format" => "false_count", "index" => "1"}
             },
             columns
           ) == [
             {:field, {:count, "active", {"active", true}}, "Active True Count"},
             {:field, {:count, "active", {"active", false}}, "Active False Count"}
           ]
  end

  test "aggregates can treat null as zero for sum" do
    columns = %{"total" => %{name: "Total", type: :decimal, colid: "total"}}

    assert Process.aggregates(
             %{
               "a1" => %{
                 "field" => "total",
                 "format" => "sum",
                 "ignore_nulls_in_sum" => "true"
               }
             },
             columns
           ) == [
             {:field, {:sum, {:coalesce, ["total", 0]}}, "Total Sum"}
           ]
  end

  test "group by uses column display names by default" do
    columns = %{
      "category.category_name" => %{
        name: "Category: Category name",
        type: :string,
        colid: "category.category_name"
      }
    }

    [{coldef, selector}] =
      Process.group_by(
        %{"g1" => %{"field" => "category.category_name", "format" => "default"}},
        columns,
        nil
      )

    assert selector == {:field, "category.category_name", "Category Name"}

    assert Map.take(coldef, [:name, :type, :colid, :group_format, :linked_to_next]) == %{
             name: "Category: Category name",
             type: :string,
             colid: "category.category_name",
             group_format: "default",
             linked_to_next: false
           }

    assert coldef["group_format"] == "default"
    assert coldef["linked_to_next"] == false
  end

  test "aggregates use friendly default labels" do
    columns = %{
      "order_details.order_id" => %{
        name: "Order Details: Order id",
        type: :id,
        colid: "order_details.order_id"
      }
    }

    assert Process.aggregates(
             %{"a1" => %{"field" => "order_details.order_id", "format" => "count_distinct"}},
             columns
           ) ==
             [{:field, {:count_distinct, "order_details.order_id"}, "Order ID Distinct Count"}]
  end

  test "group by supports datetime year buckets" do
    columns = %{
      "created_at" => %{name: "Created At", type: :utc_datetime, colid: :created_at}
    }

    [{_col, selector}] =
      Process.group_by(
        %{
          "g1" => %{"field" => "created_at", "format" => "year_buckets", "bucket_ranges" => "*/5"}
        },
        columns,
        nil
      )

    assert {:field, {:raw_sql, sql}, "Created At"} = selector
    assert sql =~ "EXTRACT(YEAR FROM selecto_root.created_at)"
    assert sql =~ "CASE WHEN"
  end

  test "group by uses viewer timezone for instant datetime formatting" do
    columns = %{
      "created_at" => %{
        name: "Created At",
        type: :utc_datetime,
        colid: :created_at,
        presentation: %{
          semantic_type: :temporal,
          temporal_kind: :instant,
          display_timezone: :viewer
        }
      }
    }

    [{_col, selector}] =
      Process.group_by(
        %{"g1" => %{"field" => "created_at", "format" => "YYYY-MM", "index" => "0"}},
        columns,
        nil,
        %{timezone: "America/New_York"}
      )

    assert {:field, {:raw_sql, sql}, "Created At"} = selector
    assert sql == "to_char(selecto_root.created_at AT TIME ZONE 'America/New_York', 'YYYY-MM')"
  end

  test "group by uses viewer timezone for epoch-backed instant year buckets" do
    columns = %{
      "occurred_at_epoch" => %{
        name: "Occurred At",
        type: :integer,
        colid: :occurred_at_epoch,
        presentation_type: :utc_datetime,
        datetime_storage: :unix_seconds,
        presentation: %{
          semantic_type: :temporal,
          temporal_kind: :instant,
          display_timezone: :viewer
        }
      }
    }

    [{_col, selector}] =
      Process.group_by(
        %{
          "g1" => %{
            "field" => "occurred_at_epoch",
            "format" => "year_buckets",
            "bucket_ranges" => "*/5",
            "index" => "0"
          }
        },
        columns,
        nil,
        %{timezone: "America/New_York"}
      )

    assert {:field, {:raw_sql, sql}, "Occurred At"} = selector

    assert sql =~
             "EXTRACT(YEAR FROM to_timestamp(selecto_root.occurred_at_epoch) AT TIME ZONE 'America/New_York')"
  end

  test "group by leaves naive datetime formatting unchanged" do
    columns = %{
      "created_at" => %{
        name: "Created At",
        type: :naive_datetime,
        colid: :created_at,
        presentation: %{
          semantic_type: :temporal,
          temporal_kind: :naive_datetime
        }
      }
    }

    [{_col, selector}] =
      Process.group_by(
        %{"g1" => %{"field" => "created_at", "format" => "YYYY-MM", "index" => "0"}},
        columns,
        nil,
        %{timezone: "America/New_York"}
      )

    assert {:field, {:to_char, {:created_at, "YYYY-MM"}}, "Created At"} = selector
  end

  test "group by preserves joined field references for datetime year buckets" do
    columns = %{
      "delivery_team.inserted_at" => %{
        name: "Delivery Team Inserted At",
        type: :utc_datetime,
        colid: "delivery_team.inserted_at"
      }
    }

    [{_col, selector}] =
      Process.group_by(
        %{
          "g1" => %{
            "field" => "delivery_team.inserted_at",
            "format" => "year_buckets",
            "bucket_ranges" => "*/5"
          }
        },
        columns,
        nil
      )

    assert {:field, {:raw_sql, sql}, "Delivery Team Inserted At"} = selector
    assert sql =~ "EXTRACT(YEAR FROM delivery_team.inserted_at)"
    refute sql =~ "EXTRACT(YEAR FROM t.inserted_at)"
  end

  test "view does not wrap UUID group-bys in text coalesce" do
    selecto = uuid_join_selecto()

    columns = %{
      "date_tier.id" => %{name: "Date Tier", type: :string, colid: "date_tier.id"}
    }

    {view_set, _meta} =
      Process.view(
        nil,
        %{"group_by" => %{"g1" => %{"field" => "date_tier.id", "index" => "0"}}},
        columns,
        [],
        selecto
      )

    assert {:field, "date_tier.id", "Date Tier"} = hd(view_set.selected)
  end

  test "view collapses linked group by items into rollup grouping sets" do
    columns = %{
      "city" => %{name: "City", type: :string, colid: "city"},
      "state" => %{name: "State", type: :string, colid: "state"},
      "country" => %{name: "Country", type: :string, colid: "country"}
    }

    {view_set, _meta} =
      Process.view(
        nil,
        %{
          "group_by" => %{
            "g0" => %{"field" => "city", "index" => "0", "linked_to_next" => "true"},
            "g1" => %{"field" => "state", "index" => "1"},
            "g2" => %{"field" => "country", "index" => "2"}
          }
        },
        columns,
        [],
        nil
      )

    assert view_set.group_by == [
             {:rollup,
              [
                {:grouping_set,
                 [
                   {:field, {:coalesce, ["city", {:literal, "[NULL]"}]}, "City"},
                   {:field, {:coalesce, ["state", {:literal, "[NULL]"}]}, "State"}
                 ]},
                {:field, {:coalesce, ["country", {:literal, "[NULL]"}]}, "Country"}
              ]}
           ]

    assert length(view_set.groups) == 3
  end
end
