defmodule SelectoComponents.Views.Aggregate.ComponentTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias SelectoComponents.Views.Aggregate.Component

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
end
