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
end
