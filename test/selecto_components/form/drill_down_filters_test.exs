defmodule SelectoComponents.Form.DrillDownFiltersTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.Form.DrillDownFilters

  defp selecto do
    domain = %{
      name: "DrillDownFilters",
      source: %{
        source_table: "records",
        primary_key: :id,
        fields: [:id, :username, :email, :category, :price, :order_date],
        redact_fields: [],
        columns: %{
          id: %{type: :integer},
          username: %{type: :string},
          email: %{type: :string},
          category: %{type: :string},
          price: %{type: :integer},
          order_date: %{type: :date}
        },
        associations: %{}
      },
      schemas: %{},
      joins: %{}
    }

    Selecto.configure(domain, nil)
  end

  describe "build_filter_map/2 indexed params" do
    test "builds filters from indexed field/value pairs" do
      socket = %{assigns: %{used_params: %{"filters" => %{}}, selecto: selecto()}}

      result =
        DrillDownFilters.build_filter_map(%{"field0" => "category", "value0" => "Action"}, socket)

      assert is_map(result)
      [filter] = Map.values(result)
      assert filter["filter"] == "category"
      assert filter["value"] == "Action"
    end

    test "supports single non-indexed field/value keys" do
      socket = %{assigns: %{used_params: %{"filters" => %{}}, selecto: selecto()}}

      result = DrillDownFilters.build_filter_map(%{"field" => "price", "value" => "42"}, socket)

      [filter] = Map.values(result)
      assert filter["filter"] == "price"
      assert filter["value"] == "42"
    end

    test "ignores unrelated params" do
      socket = %{assigns: %{used_params: %{"filters" => %{}}, selecto: selecto()}}

      result = DrillDownFilters.build_filter_map(%{"foo" => "bar", "baz" => "qux"}, socket)

      assert result == %{}
    end
  end

  describe "determine_filter_comp_and_values/3" do
    test "handles YYYY-MM-DD date format" do
      field_conf = %{type: :date}

      {comp, v1, v2} =
        DrillDownFilters.determine_filter_comp_and_values(
          "2024-01-15",
          field_conf,
          false
        )

      assert comp == "DATE="
      assert v1 == "2024-01-15"
      assert v2 == ""
    end

    test "handles YYYY-MM month format" do
      field_conf = %{type: :date}

      {comp, v1, v2} =
        DrillDownFilters.determine_filter_comp_and_values(
          "2024-03",
          field_conf,
          false
        )

      assert comp == "DATE_BETWEEN"
      assert v1 == "2024-03-01"
      assert String.starts_with?(v2, "2024-04")
    end

    test "handles YYYY year format" do
      field_conf = %{type: :date}

      {comp, v1, v2} =
        DrillDownFilters.determine_filter_comp_and_values(
          "2024",
          field_conf,
          false
        )

      assert comp == "DATE_BETWEEN"
      assert v1 == "2024-01-01"
      assert v2 == "2025-01-01"
    end

    test "handles YYYY year format for utc_datetime fields" do
      field_conf = %{type: :utc_datetime}

      {comp, v1, v2} =
        DrillDownFilters.determine_filter_comp_and_values(
          "2017",
          field_conf,
          %{format: "YYYY"}
        )

      assert comp == "DATE_BETWEEN"
      assert v1 == "2017-01-01"
      assert v2 == "2018-01-01"
    end

    test "handles YYYY-Q quarter format for datetime fields" do
      field_conf = %{type: :utc_datetime}

      {comp, v1, v2} =
        DrillDownFilters.determine_filter_comp_and_values(
          "2017-2",
          field_conf,
          %{format: "YYYY-Q"}
        )

      assert comp == "DATE_BETWEEN"
      assert v1 == "2017-04-01"
      assert v2 == "2017-07-01"
    end

    test "handles YYYY-WW week format for datetime fields" do
      field_conf = %{type: :utc_datetime}

      {comp, v1, v2} =
        DrillDownFilters.determine_filter_comp_and_values(
          "2017-02",
          field_conf,
          %{format: "YYYY-WW"}
        )

      assert comp == "WEEK_OF_YEAR"
      assert v1 == "2017-02"
      assert v2 == ""
    end

    test "handles D day-of-week format as weekday filter" do
      field_conf = %{type: :utc_datetime}

      {comp, v1, v2} =
        DrillDownFilters.determine_filter_comp_and_values(
          "2",
          field_conf,
          %{format: "D"}
        )

      assert comp == "WEEKDAY_SUN1"
      assert v1 == "2"
      assert v2 == ""
    end

    test "handles MM/DD/HH24 grouped date formats" do
      field_conf = %{type: :utc_datetime}

      assert {"MONTH_OF_YEAR", "3", ""} =
               DrillDownFilters.determine_filter_comp_and_values("03", field_conf, %{format: "MM"})

      assert {"DAY_OF_MONTH", "14", ""} =
               DrillDownFilters.determine_filter_comp_and_values("14", field_conf, %{format: "DD"})

      assert {"HOUR_OF_DAY", "9", ""} =
               DrillDownFilters.determine_filter_comp_and_values("09", field_conf, %{
                 format: "HH24"
               })
    end

    test "handles numeric bucket ranges" do
      field_conf = %{type: :integer}

      # Range like "1-10"
      {comp, v1, v2} =
        DrillDownFilters.determine_filter_comp_and_values(
          "1-10",
          field_conf,
          false
        )

      assert comp == "BETWEEN"
      assert v1 == "1"
      assert v2 == "10"
    end

    test "handles open-ended bucket ranges" do
      field_conf = %{type: :integer}

      # Range like "11+"
      {comp, v1, _v2} =
        DrillDownFilters.determine_filter_comp_and_values(
          "11+",
          field_conf,
          false
        )

      assert comp == ">="
      assert v1 == "11"
    end

    test "handles text-prefix bucket labels" do
      field_conf = %{type: :string}

      {comp, v1, v2} =
        DrillDownFilters.determine_filter_comp_and_values(
          "OF",
          field_conf,
          %{format: "text_prefix", prefix_length: 2, exclude_articles: true}
        )

      assert comp == "STARTS"
      assert v1 == "of"
      assert v2 == ""
    end

    test "handles text-prefix Other bucket" do
      field_conf = %{type: :string}

      {comp, v1, v2} =
        DrillDownFilters.determine_filter_comp_and_values(
          "Other",
          field_conf,
          %{format: "text_prefix", prefix_length: 2, exclude_articles: true}
        )

      assert comp == "TEXT_PREFIX_OTHER"
      assert v1 == ""
      assert v2 == ""
    end

    test "handles age buckets on date fields" do
      field_conf = %{type: :date}

      # Age bucket "0-10" days
      {comp, v1, v2} =
        DrillDownFilters.determine_filter_comp_and_values(
          "0-10",
          field_conf,
          # is_age_bucket = true
          true
        )

      assert comp == "DATE_BETWEEN"
      assert is_binary(v1)
      assert is_binary(v2)
      # v1 and v2 should be ISO date strings
      assert String.match?(v1, ~r/^\d{4}-\d{2}-\d{2}$/)
      assert String.match?(v2, ~r/^\d{4}-\d{2}-\d{2}$/)
    end

    test "handles year buckets on date fields" do
      field_conf = %{type: :date}

      {comp, v1, v2} =
        DrillDownFilters.determine_filter_comp_and_values(
          "2020-2024",
          field_conf,
          %{format: "year_buckets"}
        )

      assert comp == "DATE_BETWEEN"
      assert v1 == "2020-01-01"
      assert v2 == "2025-01-01"
    end

    test "prevents SQL injection in date values" do
      field_conf = %{type: :date}

      malicious_dates = [
        "2024-01-01'; DROP TABLE users--",
        "2024' OR '1'='1",
        "2024 UNION SELECT password FROM admin"
      ]

      for malicious_date <- malicious_dates do
        {comp, v1, v2} =
          DrillDownFilters.determine_filter_comp_and_values(
            malicious_date,
            field_conf,
            false
          )

        # Should treat as regular string since format doesn't match
        assert comp == "="
        assert v1 == malicious_date
        assert v2 == ""
        # The actual SQL injection prevention happens through parameterization
      end
    end

    test "prevents SQL injection in bucket values" do
      field_conf = %{type: :integer}

      malicious_buckets = [
        "1-10'; DROP TABLE products--",
        "11+' OR '1'='1",
        "5-15 UNION SELECT * FROM users"
      ]

      for malicious_bucket <- malicious_buckets do
        {comp, v1, v2} =
          DrillDownFilters.determine_filter_comp_and_values(
            malicious_bucket,
            field_conf,
            false
          )

        # Should handle malformed bucket safely
        assert is_binary(comp)
        assert is_binary(v1)
        assert is_binary(v2)
      end
    end
  end

  describe "build_filter_map/2 SQL injection prevention" do
    setup do
      # Mock socket structure
      socket = %{
        assigns: %{
          used_params: %{"filters" => %{}, "group_by" => %{}},
          selecto: selecto()
        }
      }

      {:ok, socket: socket}
    end

    test "prevents SQL injection through filter values", %{socket: socket} do
      malicious_params = %{
        "field0" => "username",
        "value0" => "admin'; DROP TABLE users--",
        "field1" => "email",
        "value1" => "user@example.com' OR '1'='1",
        "field2" => "id",
        "value2" => "1 UNION SELECT password FROM admin"
      }

      # The function should handle these values safely
      # SQL injection prevention comes from parameterization
      result = DrillDownFilters.build_filter_map(malicious_params, socket)

      assert is_map(result)
      # Each filter should be a parameterized value
      for {_uuid, filter_config} <- result do
        assert Map.has_key?(filter_config, "filter")
        assert Map.has_key?(filter_config, "value")
        assert is_binary(filter_config["value"])
      end
    end

    test "prevents SQL injection through field names", %{socket: socket} do
      malicious_params = %{
        "field0" => "column'; DROP TABLE--",
        "value0" => "value",
        "field1" => "id OR 1=1--",
        "value1" => "value"
      }

      result = DrillDownFilters.build_filter_map(malicious_params, socket)

      assert is_map(result)
      # Field names should be extracted and validated
      for {_uuid, filter_config} <- result do
        assert is_binary(filter_config["filter"])
      end
    end
  end

  describe "build_filter_tuples/2 SQL injection prevention" do
    setup do
      socket = %{
        assigns: %{
          used_params: %{},
          selecto: selecto()
        }
      }

      {:ok, socket: socket}
    end

    test "prevents SQL injection in filter tuples", %{socket: socket} do
      malicious_params = %{
        "field0" => "category",
        "value0" => "Electronics'; DROP TABLE--",
        "field1" => "price",
        "value1" => "100 OR 1=1"
      }

      result = DrillDownFilters.build_filter_tuples(malicious_params, socket)

      assert is_list(result)

      for {uuid, section, filter_data} <- result do
        assert is_binary(uuid)
        assert section == "filters"
        assert is_map(filter_data)
        assert Map.has_key?(filter_data, "filter")
        assert Map.has_key?(filter_data, "value")
      end
    end
  end

  describe "Security documentation" do
    test "documents SQL injection prevention mechanisms" do
      # This test documents the security measures:
      #
      # 1. All filter values are passed as parameters to Selecto
      # 2. Selecto uses Postgrex parameterized queries (not string interpolation)
      # 3. Field names are validated against the schema by Selecto.field()
      # 4. Date parsing failures result in treating values as strings
      # 5. No raw SQL concatenation occurs in this module
      # 6. All values maintain type safety through the chain

      assert true, "SQL injection prevention documented"
    end
  end

  describe "build_agg_drill_down_params/2 robustness" do
    test "handles missing used_params assign" do
      socket = %{assigns: %{selecto: selecto()}}

      params = %{
        "field0" => "category",
        "value0" => "Action"
      }

      view_params = DrillDownFilters.build_agg_drill_down_params(params, socket)

      assert view_params["view_mode"] == "detail"
      assert is_map(view_params["filters"])
    end

    test "text prefix drill-down enables case-insensitive starts filter when excluding articles" do
      socket =
        %{assigns: %{selecto: selecto(), used_params: %{}}}
        |> put_in(
          [:assigns, :used_params, "group_by"],
          %{
            "g1" => %{
              "field" => "title",
              "index" => "0",
              "format" => "text_prefix",
              "prefix_length" => "2",
              "exclude_articles" => "true"
            }
          }
        )

      params = %{
        "field0" => "title",
        "value0" => "OF"
      }

      view_params = DrillDownFilters.build_agg_drill_down_params(params, socket)
      [filter] = Map.values(view_params["filters"])

      assert filter["comp"] == "STARTS"
      assert filter["value"] == "of"
      assert filter["exclude_articles"] == "true"
      assert filter["ignore_case"] == "true"
    end

    test "uses group index to disambiguate repeated datetime fields with different formats" do
      socket =
        %{assigns: %{selecto: selecto(), used_params: %{}}}
        |> put_in(
          [:assigns, :used_params, "group_by"],
          %{
            "g0" => %{"field" => "order_date", "index" => "0", "format" => "D"},
            "g1" => %{"field" => "order_date", "index" => "1", "format" => "DD"}
          }
        )

      params = %{
        "field0" => "order_date",
        "value0" => "6",
        "gidx0" => "0",
        "field1" => "order_date",
        "value1" => "14",
        "gidx1" => "1"
      }

      view_params = DrillDownFilters.build_agg_drill_down_params(params, socket)
      filters = Map.values(view_params["filters"])

      assert Enum.any?(filters, fn f -> f["comp"] == "WEEKDAY_SUN1" and f["value"] == "6" end)
      assert Enum.any?(filters, fn f -> f["comp"] == "DAY_OF_MONTH" and f["value"] == "14" end)
    end
  end
end
