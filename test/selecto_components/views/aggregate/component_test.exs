defmodule SelectoComponents.Views.Aggregate.ComponentTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias SelectoComponents.Views.Aggregate.Component

  defp aggregate_assigns(overrides \\ %{}) do
    rows =
      1..250
      |> Enum.map(fn i -> ["group_#{i}", i] end)

    base = %{
      id: "aggregate-component-pagination-test",
      executed: true,
      execution_error: nil,
      view_config: %{
        view_mode: "aggregate",
        filters: [],
        group_by: %{
          "g0" => %{
            "field" => "release_year",
            "index" => "0"
          }
        }
      },
      selecto: %{
        selecto()
        | set: %{
            selected: [
              {:field, :release_year, "release_year"},
              {:field, {:count, :film_id}, "film_count"}
            ],
            group_by: [{:rollup, [{:literal_position, 1}]}],
            aggregates: [{:field, {:count, :film_id}, "film_count"}]
          }
      },
      query_results: {rows, [], ["release_year", "film_count"]},
      view_meta: %{exe_id: "aggregate-test-run-1"}
    }

    Map.merge(base, overrides)
  end

  defp selecto do
    domain = %{
      name: "AggregateComponentTest",
      source: %{
        source_table: "film",
        primary_key: :film_id,
        fields: [:film_id, :title, :release_year],
        redact_fields: [],
        columns: %{
          film_id: %{type: :integer},
          title: %{type: :string},
          release_year: %{type: :integer}
        },
        associations: %{}
      },
      schemas: %{},
      joins: %{}
    }

    Selecto.configure(domain, nil)
  end

  test "bucketed group-by drill-down uses the configured group field" do
    bucket_expr =
      "CASE WHEN selecto_root.release_year >= 2000 AND selecto_root.release_year <= 2004 THEN '2000-2004' ELSE 'Other' END"

    assigns = %{
      id: "aggregate-component-test",
      executed: true,
      execution_error: nil,
      view_config: %{
        view_mode: "aggregate",
        filters: [],
        group_by: %{
          "g0" => %{
            "field" => "release_year",
            "index" => "0",
            "format" => "buckets",
            "bucket_ranges" => "2000-2004"
          }
        }
      },
      selecto: %{
        selecto()
        | set: %{
            selected: [
              {:field, {:coalesce, [{:raw_sql, bucket_expr}, {:literal, "[NULL]"}]},
               "release_year"},
              {:field, {:count, :film_id}, "film_id"}
            ],
            group_by: [{:rollup, [{:literal_position, 1}]}],
            aggregates: [{:field, {:count, :film_id}, "film_id"}]
          }
      },
      query_results: {[[nil, 1003], ["2000-2004", 267]], [], ["release_year", "film_id"]}
    }

    html = render_component(Component, assigns)

    assert html =~ ~s(phx-value-field0="release_year")
    assert html =~ ~s(phx-value-value0="2000-2004")
    refute html =~ ~s(phx-value-field0="id")
  end

  test "aggregate results are paginated with a default page size of 100" do
    html = render_component(Component, aggregate_assigns())

    assert html =~ "1-100"
    assert html =~ "of"
    assert html =~ "250"
    assert html =~ "rows"

    assert html =~
             ~r/id="aggregate-table-wrapper-[^"]+" class="[^"]*sc-panel[^"]*responsive-table-wrapper[^"]*"/
  end

  test "renders friendly headers from selected field aliases instead of query aliases" do
    html =
      render_component(
        Component,
        aggregate_assigns(%{
          selecto: %{
            selecto()
            | set: %{
                selected: [
                  {:field, "category.category_name", "Category Name"},
                  {:field, {:count_distinct, "order_details.order_id"}, "Order ID Distinct Count"}
                ],
                group_by: [{:rollup, [{:literal_position, 1}]}],
                aggregates: [
                  {:field, {:count_distinct, "order_details.order_id"}, "Order ID Distinct Count"}
                ]
              }
          },
          query_results: {[["Books", 3]], [], ["category_name", "count_distinct_order_id"]}
        })
      )

    assert html =~ "Category Name"
    assert html =~ "Order ID Distinct Count"
    refute html =~ ">category_name<"
  end

  test "aggregate page navigation clamps to first and last pages" do
    socket =
      %Phoenix.LiveView.Socket{
        assigns: %{__changed__: %{}, aggregate_max_page: 2, aggregate_page: 0}
      }

    {:noreply, updated_socket} =
      Component.handle_event("set_aggregate_page", %{"page" => "-5"}, socket)

    assert updated_socket.assigns.aggregate_page == 0

    {:noreply, updated_socket} =
      Component.handle_event("set_aggregate_page", %{"page" => "999"}, updated_socket)

    assert updated_socket.assigns.aggregate_page == 2
  end

  test "aggregate per-page uses view config and supports 'all'" do
    html =
      render_component(
        Component,
        aggregate_assigns(%{view_meta: %{exe_id: "aggregate-test-run-2", per_page: "all"}})
      )

    assert html =~ "1-250"
    assert html =~ "of"
    assert html =~ "250"
    assert html =~ "rows"
  end

  test "null group-by value renders as [NULL] and is drill-down clickable" do
    assigns =
      aggregate_assigns(%{
        query_results: {[[nil, 3], [2001, 7], [nil, 10]], [], ["release_year", "film_count"]}
      })

    html = render_component(Component, assigns)

    assert html =~ "[NULL]"
    assert html =~ ~s(phx-click="agg_add_filters")
    assert html =~ ~s(phx-value-value0="__NULL__")
    assert html =~ "Total"
  end

  test "linked group-by blocks collapse into one header and preserve multi-filter drill-down" do
    domain = %{
      name: "AggregateLinkedGroupComponentTest",
      source: %{
        source_table: "work_items",
        primary_key: :id,
        fields: [:id, :state, :title, :rank, :inserted_at],
        redact_fields: [],
        columns: %{
          id: %{type: :integer},
          state: %{type: :string},
          title: %{type: :string},
          rank: %{type: :integer},
          inserted_at: %{type: :date}
        },
        associations: %{}
      },
      schemas: %{},
      joins: %{}
    }

    linked_selecto = Selecto.configure(domain, nil)

    assigns = %{
      id: "aggregate-linked-group-render-test",
      executed: true,
      execution_error: nil,
      view_config: %{
        view_mode: "aggregate",
        filters: [],
        group_by: %{
          "g0" => %{"field" => "state", "index" => "0", "linked_to_next" => true},
          "g1" => %{"field" => "title", "index" => "1", "linked_to_next" => true},
          "g2" => %{
            "field" => "rank",
            "index" => "2",
            "format" => "buckets",
            "bucket_ranges" => "0-4",
            "linked_to_next" => false
          },
          "g3" => %{"field" => "inserted_at", "index" => "3"}
        }
      },
      selecto: %{
        linked_selecto
        | set: %{
            selected: [
              {:field, "state", "State"},
              {:field, "title", "Title"},
              {:field, "rank", "Rank"},
              {:field, "inserted_at", "Inserted At"},
              {:field, {:count, :id}, "ID Count"}
            ],
            groups: [
              {:field, "state", "State"},
              {:field, "title", "Title"},
              {:field, "rank", "Rank"},
              {:field, "inserted_at", "Inserted At"}
            ],
            group_by: [
              {:rollup,
               [
                 {:grouping_set,
                  [
                    {:literal_position, 1},
                    {:literal_position, 2},
                    {:literal_position, 3}
                  ]},
                 {:literal_position, 4}
               ]}
            ],
            aggregates: [{:field, {:count, :id}, "ID Count"}]
          }
      },
      query_results:
        {[
           ["done", "ES", "0-4", nil, 32],
           [nil, nil, nil, nil, 32]
         ], [], ["state", "title", "rank", "inserted_at", "id_count"]},
      view_meta: %{exe_id: "aggregate-linked-group-render-test-run"}
    }

    html = render_component(Component, assigns)

    assert html =~ "State / Title / Rank"
    assert html =~ "Inserted At"
    assert html =~ "done / ES / 0-4"
    assert html =~ ~s(phx-value-field0="state")
    assert html =~ ~s(phx-value-value0="done")
    assert html =~ ~s(phx-value-field1="title")
    assert html =~ ~s(phx-value-value1="ES")
    assert html =~ ~s(phx-value-field2="rank")
    assert html =~ ~s(phx-value-value2="0-4")
    refute html =~ ~s(phx-value-field3="inserted_at")
  end

  test "renders aggregate grid when enabled with 2 group-by and 1 aggregate" do
    assigns = %{
      id: "aggregate-grid-test",
      executed: true,
      execution_error: nil,
      view_config: %{
        view_mode: "aggregate",
        filters: [],
        group_by: %{
          "g0" => %{"field" => "release_year", "index" => "0"},
          "g1" => %{"field" => "title", "index" => "1"}
        }
      },
      selecto: %{
        selecto()
        | set: %{
            selected: [
              {:field, :release_year, "release_year"},
              {:field, :title, "title"},
              {:field, {:count, :film_id}, "film_count"}
            ],
            group_by: [{:rollup, [{:literal_position, 1}, {:literal_position, 2}]}],
            aggregates: [{:field, {:count, :film_id}, "film_count"}]
          }
      },
      query_results:
        {[[2001, "A", 3], [2001, "B", 5], [2002, "A", 2]], [],
         ["release_year", "title", "film_count"]},
      view_meta: %{exe_id: "aggregate-grid-test-run", grid_enabled: true}
    }

    html = render_component(Component, assigns)

    assert html =~ "Aggregate Grid"
    assert html =~ "release_year"
    assert html =~ "2001"
    assert html =~ "2002"
    assert html =~ "3"
    assert html =~ "5"
    assert html =~ "2"
    assert html =~ "overflow-x-auto"

    assert html =~
             ~r/id="aggregate-grid-wrapper-[^"]+" class="[^"]*sc-panel[^"]*overflow-x-auto[^"]*overflow-y-auto[^"]*"/

    assert html =~ "sticky left-0 top-0"
    refute html =~ ~s(phx-click="set_aggregate_page")
  end

  test "aggregate grid renders null buckets with subdued text" do
    assigns = %{
      id: "aggregate-grid-null-style-test",
      executed: true,
      execution_error: nil,
      view_config: %{
        view_mode: "aggregate",
        filters: [],
        group_by: %{
          "g0" => %{"field" => "release_year", "index" => "0"},
          "g1" => %{"field" => "title", "index" => "1"}
        }
      },
      selecto: %{
        selecto()
        | set: %{
            selected: [
              {:field, :release_year, "release_year"},
              {:field, :title, "title"},
              {:field, {:count, :film_id}, "film_count"}
            ],
            group_by: [{:rollup, [{:literal_position, 1}, {:literal_position, 2}]}],
            aggregates: [{:field, {:count, :film_id}, "film_count"}]
          }
      },
      query_results:
        {[["[NULL]", "A", 3], [2002, "A", 5]], [], ["release_year", "title", "film_count"]},
      view_meta: %{exe_id: "aggregate-grid-null-style-run", grid_enabled: true}
    }

    html = render_component(Component, assigns)

    assert html =~ ~r/<span[^>]*>\s*\[NULL\]\s*<\/span>/
  end

  test "grid view renders all rows instead of paginating" do
    query_rows =
      1..150
      |> Enum.map(fn i -> ["region", "bucket_#{i}", i] end)

    assigns = %{
      id: "aggregate-grid-unpaged-test",
      executed: true,
      execution_error: nil,
      view_config: %{
        view_mode: "aggregate",
        filters: [],
        group_by: %{
          "g0" => %{"field" => "release_year", "index" => "0"},
          "g1" => %{"field" => "title", "index" => "1"}
        }
      },
      selecto: %{
        selecto()
        | set: %{
            selected: [
              {:field, :release_year, "release_year"},
              {:field, :title, "title"},
              {:field, {:count, :film_id}, "film_count"}
            ],
            group_by: [{:rollup, [{:literal_position, 1}, {:literal_position, 2}]}],
            aggregates: [{:field, {:count, :film_id}, "film_count"}]
          }
      },
      query_results: {query_rows, [], ["release_year", "title", "film_count"]},
      view_meta: %{exe_id: "aggregate-grid-unpaged-run", grid_enabled: true, per_page: "100"}
    }

    html = render_component(Component, assigns)

    assert html =~ "bucket_150"
    assert html =~ ~r/>\s*150\s*</
    refute html =~ ~s(phx-click="set_aggregate_page")
  end

  test "shows grid requirements message when configuration does not match" do
    html =
      render_component(
        Component,
        aggregate_assigns(%{view_meta: %{exe_id: "aggregate-grid-message", grid_enabled: true}})
      )

    assert html =~ "Grid view requires exactly 2 Group By axes and 1 Aggregate"
  end

  test "grid can use a linked group-by block as one axis" do
    domain = %{
      name: "AggregateLinkedGridComponentTest",
      source: %{
        source_table: "work_items",
        primary_key: :id,
        fields: [:id, :state, :title, :rank],
        redact_fields: [],
        columns: %{
          id: %{type: :integer},
          state: %{type: :string},
          title: %{type: :string},
          rank: %{type: :integer}
        },
        associations: %{}
      },
      schemas: %{},
      joins: %{}
    }

    linked_selecto = Selecto.configure(domain, nil)

    assigns = %{
      id: "aggregate-grid-linked-axis-test",
      executed: true,
      execution_error: nil,
      view_config: %{
        view_mode: "aggregate",
        filters: [],
        group_by: %{
          "g0" => %{"field" => "state", "index" => "0", "linked_to_next" => true},
          "g1" => %{
            "field" => "title",
            "index" => "1",
            "format" => "text_prefix",
            "prefix_length" => "2"
          },
          "g2" => %{
            "field" => "rank",
            "index" => "2",
            "format" => "buckets",
            "bucket_ranges" => "0-4"
          }
        }
      },
      selecto: %{
        linked_selecto
        | set: %{
            selected: [
              {:field, "state", "State"},
              {:field, "title", "Title"},
              {:field, "rank", "Rank"},
              {:field, {:count, :id}, "ID Count"}
            ],
            groups: [
              {:field, "state", "State"},
              {:field, "title", "Title"},
              {:field, "rank", "Rank"}
            ],
            group_by: [
              {:rollup,
               [
                 {:grouping_set, [{:literal_position, 1}, {:literal_position, 2}]},
                 {:literal_position, 3}
               ]}
            ],
            aggregates: [{:field, {:count, :id}, "ID Count"}],
            gb_params: %{
              "g0" => %{"field" => "state", "index" => "0", "linked_to_next" => true},
              "g1" => %{
                "field" => "title",
                "index" => "1",
                "format" => "text_prefix",
                "prefix_length" => "2"
              },
              "g2" => %{
                "field" => "rank",
                "index" => "2",
                "format" => "buckets",
                "bucket_ranges" => "0-4"
              }
            }
          }
      },
      query_results:
        {[
           ["done", "ES", "0-4", 32],
           ["planned", "BU", "0-4", 8]
         ], [], ["state", "title", "rank", "id_count"]},
      view_meta: %{exe_id: "aggregate-grid-linked-axis-run", grid_enabled: true}
    }

    html = render_component(Component, assigns)

    assert html =~ "Aggregate Grid"
    assert html =~ "State / Title"
    assert html =~ "done / ES"
    assert html =~ "planned / BU"
    assert html =~ ~s(phx-value-field0="state")
    assert html =~ ~s(phx-value-value0="done")
    assert html =~ ~s(phx-value-field1="title")
    assert html =~ ~s(phx-value-value1="ES")
    assert html =~ ~s(phx-value-field2="rank")
    assert html =~ ~s(phx-value-value2="0-4")
  end

  test "grid view sorts hour-of-day columns numerically" do
    assigns = %{
      id: "aggregate-grid-hour-sort-test",
      executed: true,
      execution_error: nil,
      view_config: %{
        view_mode: "aggregate",
        filters: [],
        group_by: %{
          "g0" => %{"field" => "release_year", "index" => "0", "format" => "D"},
          "g1" => %{"field" => "title", "index" => "1", "format" => "HH24"}
        }
      },
      selecto: %{
        selecto()
        | set: %{
            selected: [
              {:field, :release_year, "release_year"},
              {:field, :title, "title"},
              {:field, {:count, :film_id}, "film_count"}
            ],
            group_by: [{:rollup, [{:literal_position, 1}, {:literal_position, 2}]}],
            aggregates: [{:field, {:count, :film_id}, "film_count"}],
            gb_params: %{
              "g0" => %{"field" => "release_year", "index" => "0", "format" => "D"},
              "g1" => %{"field" => "title", "index" => "1", "format" => "HH24"}
            }
          }
      },
      # First seen hour is 10, then 02; grid should still render 02 before 10
      query_results: {[[1, 10, 3], [1, 2, 5]], [], ["release_year", "title", "film_count"]},
      view_meta: %{exe_id: "aggregate-grid-hour-sort", grid_enabled: true}
    }

    html = render_component(Component, assigns)

    normalized = String.replace(html, ~r/\s+/, " ")

    {idx_2, _} = :binary.match(normalized, "> 2 <")
    {idx_10, _} = :binary.match(normalized, "> 10 <")

    assert idx_2 < idx_10
  end

  test "grid cells are clickable and pass both group filters" do
    assigns = %{
      id: "aggregate-grid-cell-click-test",
      executed: true,
      execution_error: nil,
      view_config: %{
        view_mode: "aggregate",
        filters: [],
        group_by: %{
          "g0" => %{"field" => "release_year", "index" => "0", "format" => "D"},
          "g1" => %{"field" => "title", "index" => "1", "format" => "HH24"}
        }
      },
      selecto: %{
        selecto()
        | set: %{
            selected: [
              {:field, :release_year, "release_year"},
              {:field, :title, "title"},
              {:field, {:count, :film_id}, "film_count"}
            ],
            group_by: [{:rollup, [{:literal_position, 1}, {:literal_position, 2}]}],
            aggregates: [{:field, {:count, :film_id}, "film_count"}],
            gb_params: %{
              "g0" => %{"field" => "release_year", "index" => "0", "format" => "D"},
              "g1" => %{"field" => "title", "index" => "1", "format" => "HH24"}
            }
          }
      },
      query_results: {[[6, 10, 3]], [], ["release_year", "title", "film_count"]},
      view_meta: %{exe_id: "aggregate-grid-cell-click", grid_enabled: true}
    }

    html = render_component(Component, assigns)

    assert html =~ ~s(phx-click="agg_add_filters")
    assert html =~ ~s(phx-value-field0="release_year")
    assert html =~ ~s(phx-value-value0="6")
    assert html =~ ~s(phx-value-field1="title")
    assert html =~ ~s(phx-value-value1="10")
  end

  test "grid can colorize cells with a linear scale" do
    assigns = %{
      id: "aggregate-grid-colorize-linear-test",
      executed: true,
      execution_error: nil,
      view_config: %{
        view_mode: "aggregate",
        filters: [],
        group_by: %{
          "g0" => %{"field" => "release_year", "index" => "0"},
          "g1" => %{"field" => "title", "index" => "1"}
        }
      },
      selecto: %{
        selecto()
        | set: %{
            selected: [
              {:field, :release_year, "release_year"},
              {:field, :title, "title"},
              {:field, {:count, :film_id}, "film_count"}
            ],
            group_by: [{:rollup, [{:literal_position, 1}, {:literal_position, 2}]}],
            aggregates: [{:field, {:count, :film_id}, "film_count"}]
          }
      },
      query_results:
        {[[2001, "A", 0], [2001, "B", 3], [2002, "A", 9]], [],
         ["release_year", "title", "film_count"]},
      view_meta: %{
        exe_id: "aggregate-grid-colorize-linear",
        grid_enabled: true,
        grid_colorize: true,
        grid_color_scale: "linear"
      }
    }

    html = render_component(Component, assigns)

    assert html =~ "Linear color scale"
    assert html =~ "Color legend"
    assert html =~ "Low"
    assert html =~ "High"
    assert html =~ ~s|style="background: var(--sc-surface-bg); color: var(--sc-text-primary);"|

    assert html =~
             ~s|style="background-color: color-mix(in srgb, var(--sc-accent) 28%, var(--sc-surface-bg)); color: var(--sc-text-primary);"|

    assert html =~
             ~s|style="background-color: color-mix(in srgb, var(--sc-accent) 64%, var(--sc-surface-bg)); color: var(--sc-text-primary);"|
  end

  test "grid can colorize cells with a log scale" do
    assigns = %{
      id: "aggregate-grid-colorize-log-test",
      executed: true,
      execution_error: nil,
      view_config: %{
        view_mode: "aggregate",
        filters: [],
        group_by: %{
          "g0" => %{"field" => "release_year", "index" => "0"},
          "g1" => %{"field" => "title", "index" => "1"}
        }
      },
      selecto: %{
        selecto()
        | set: %{
            selected: [
              {:field, :release_year, "release_year"},
              {:field, :title, "title"},
              {:field, {:count, :film_id}, "film_count"}
            ],
            group_by: [{:rollup, [{:literal_position, 1}, {:literal_position, 2}]}],
            aggregates: [{:field, {:count, :film_id}, "film_count"}]
          }
      },
      query_results:
        {[[2001, "A", 1], [2001, "B", 10], [2002, "A", 1000]], [],
         ["release_year", "title", "film_count"]},
      view_meta: %{
        exe_id: "aggregate-grid-colorize-log",
        grid_enabled: true,
        grid_colorize: true,
        grid_color_scale: "log"
      }
    }

    html = render_component(Component, assigns)

    assert html =~ "Log color scale"

    assert html =~
             ~s|style="background-color: color-mix(in srgb, var(--sc-accent) 16%, var(--sc-surface-bg)); color: var(--sc-text-primary);"|

    assert html =~
             ~s|style="background-color: color-mix(in srgb, var(--sc-accent) 28%, var(--sc-surface-bg)); color: var(--sc-text-primary);"|

    assert html =~
             ~s|style="background-color: color-mix(in srgb, var(--sc-accent) 64%, var(--sc-surface-bg)); color: var(--sc-text-primary);"|
  end

  test "day-of-week group-by displays weekday names" do
    assigns =
      aggregate_assigns(%{
        view_config: %{
          view_mode: "aggregate",
          filters: [],
          group_by: %{
            "g0" => %{"field" => "release_year", "index" => "0", "format" => "D"}
          }
        },
        selecto: %{
          selecto()
          | set: %{
              selected: [
                {:field, :release_year, "release_year"},
                {:field, {:count, :film_id}, "film_count"}
              ],
              group_by: [{:rollup, [{:literal_position, 1}]}],
              aggregates: [{:field, {:count, :film_id}, "film_count"}]
            }
        },
        query_results: {[[6, 10]], [], ["release_year", "film_count"]}
      })

    html = render_component(Component, assigns)

    assert html =~ "Friday"
    refute html =~ ">6<"
  end

  test "renders presentation-formatted aggregate values and group labels" do
    selecto =
      Selecto.configure(
        %{
          name: "AggregatePresentationTest",
          source: %{
            source_table: "records",
            primary_key: :id,
            fields: [:id, :temperature_c, :recorded_at],
            redact_fields: [],
            columns: %{
              id: %{type: :integer},
              temperature_c: %{
                type: :decimal,
                presentation: %{
                  semantic_type: :measurement,
                  quantity: :temperature,
                  canonical_unit: :celsius,
                  default_unit: :celsius,
                  format: %{maximum_fraction_digits: 1}
                }
              },
              recorded_at: %{
                type: :integer,
                presentation_type: :utc_datetime,
                datetime_storage: :unix_seconds,
                presentation: %{
                  semantic_type: :temporal,
                  temporal_kind: :instant,
                  display_timezone: :viewer
                }
              }
            },
            associations: %{}
          },
          schemas: %{},
          joins: %{}
        },
        nil
      )

    assigns = %{
      id: "aggregate-presentation-test",
      executed: true,
      execution_error: nil,
      view_config: %{
        view_mode: "aggregate",
        filters: [],
        group_by: %{
          "g0" => %{"field" => "recorded_at", "index" => "0"}
        }
      },
      selecto: %{
        selecto
        | set: %{
            selected: [
              {:field, :recorded_at, "recorded_at"},
              {:field, {:avg, :temperature_c}, "avg_temperature_c"}
            ],
            group_by: [{:rollup, [{:literal_position, 1}]}],
            aggregates: [{:field, {:avg, :temperature_c}, "avg_temperature_c"}]
          }
      },
      query_results: {[[1_704_067_200, 0]], [], ["recorded_at", "avg_temperature_c"]},
      view_meta: %{exe_id: "aggregate-presentation-run"},
      presentation_context: %{unit_system: :us_customary, timezone: "America/New_York"}
    }

    html = render_component(Component, assigns)

    assert html =~ "2023-12-31 19:00"
    assert html =~ "32.0 F"
  end
end
