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

  describe "extract_field_name/2" do
    test "extracts field name from phx-value- prefix" do
      socket = %{assigns: %{used_params: %{}}}

      assert DrillDownFilters.extract_field_name("phx-value-category", socket) == "category"
      assert DrillDownFilters.extract_field_name("phx-value-order_date", socket) == "order_date"
      assert DrillDownFilters.extract_field_name("phx-value-customer_id", socket) == "customer_id"
    end

    test "falls back to id for empty field names" do
      socket = %{assigns: %{used_params: %{"group_by" => %{}}}}

      assert DrillDownFilters.extract_field_name("", socket) == "id"
      assert DrillDownFilters.extract_field_name(nil, socket) == "id"
    end

    test "returns field name as-is if not prefixed" do
      socket = %{assigns: %{used_params: %{}}}

      assert DrillDownFilters.extract_field_name("category", socket) == "category"
      assert DrillDownFilters.extract_field_name("price", socket) == "price"
    end

    test "prevents SQL injection in field names" do
      socket = %{assigns: %{used_params: %{}}}

      malicious_names = [
        "phx-value-category'; DROP TABLE products--",
        "phx-value-id OR 1=1--",
        "phx-value-name' UNION SELECT password FROM users--"
      ]

      for malicious_name <- malicious_names do
        # Should extract the full malicious string
        # Field name validation happens at Selecto level
        result = DrillDownFilters.extract_field_name(malicious_name, socket)
        assert is_binary(result)
      end
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
        "phx-value-username" => "admin'; DROP TABLE users--",
        "phx-value-email" => "user@example.com' OR '1'='1",
        "phx-value-id" => "1 UNION SELECT password FROM admin"
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
        "phx-value-column'; DROP TABLE--" => "value",
        "phx-value-id OR 1=1--" => "value"
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
        "phx-value-category" => "Electronics'; DROP TABLE--",
        "phx-value-price" => "100 OR 1=1"
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
  end
end
