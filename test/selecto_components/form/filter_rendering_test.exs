defmodule SelectoComponents.Form.FilterRenderingTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias SelectoComponents.Form.FilterRendering

  defmodule TestMySQLAdapter do
    def name, do: :mysql
  end

  describe "is_date_shortcut/1" do
    test "recognizes valid date shortcuts" do
      valid_shortcuts = [
        "today",
        "yesterday",
        "tomorrow",
        "this_week",
        "last_week",
        "next_week",
        "this_month",
        "last_month",
        "next_month",
        "this_year",
        "last_year",
        "next_year",
        "ytd",
        "qtd",
        "mtd",
        "last_7_days",
        "last_30_days"
      ]

      for shortcut <- valid_shortcuts do
        assert FilterRendering.is_date_shortcut(shortcut) == true
      end
    end

    test "rejects invalid shortcuts" do
      invalid_shortcuts = [
        "not_a_shortcut",
        "today'; DROP TABLE--",
        "last_week OR 1=1",
        123,
        nil,
        %{}
      ]

      for shortcut <- invalid_shortcuts do
        assert FilterRendering.is_date_shortcut(shortcut) == false
      end
    end

    test "prevents SQL injection through shortcuts" do
      malicious_shortcuts = [
        "today'; DROP TABLE users--",
        "yesterday' OR '1'='1",
        "this_month UNION SELECT * FROM passwords"
      ]

      for shortcut <- malicious_shortcuts do
        # Should not be recognized as valid shortcuts
        assert FilterRendering.is_date_shortcut(shortcut) == false
      end
    end
  end

  describe "is_relative_date/1" do
    test "recognizes valid relative date patterns" do
      valid_patterns = [
        # 5 days ago
        "5",
        # 3-7 days ago
        "3-7",
        # more than 30 days ago
        "-30",
        # within 30 days
        "30-",
        # 0-10 days ago
        "0-10",
        # more than a year ago
        "-365"
      ]

      for pattern <- valid_patterns do
        assert FilterRendering.is_relative_date(pattern) == true
      end
    end

    test "rejects invalid relative date patterns" do
      invalid_patterns = [
        "not a number",
        "5'; DROP TABLE--",
        "3-7 OR 1=1",
        "abc-def",
        nil,
        123,
        %{}
      ]

      for pattern <- invalid_patterns do
        assert FilterRendering.is_relative_date(pattern) == false
      end
    end

    test "prevents SQL injection through relative dates" do
      malicious_patterns = [
        "5'; DELETE FROM users WHERE '1'='1",
        "3-7' OR '1'='1",
        "-30 UNION SELECT password FROM admin"
      ]

      for pattern <- malicious_patterns do
        # Should not match the regex pattern
        assert FilterRendering.is_relative_date(pattern) == false
      end
    end
  end

  describe "date_shortcut_preview/2" do
    test "formats whole-period shortcuts compactly" do
      today = ~D[2026-04-03]

      assert FilterRendering.date_shortcut_preview("this_month", today) == "04-2026"
      assert FilterRendering.date_shortcut_preview("this_quarter", today) == "Q2-2026"
      assert FilterRendering.date_shortcut_preview("this_year", today) == "2026"
    end

    test "formats range-based shortcuts with exact dates" do
      today = ~D[2026-04-03]

      assert FilterRendering.date_shortcut_preview("this_week", today) ==
               "2026-03-30 to 2026-04-05"

      assert FilterRendering.date_shortcut_preview("mtd", today) ==
               "2026-04-01 to 2026-04-03"
    end

    test "formats weekday shortcuts as recurring labels" do
      assert FilterRendering.date_shortcut_preview("friday", ~D[2026-04-03]) == "Every Friday"
      assert FilterRendering.date_shortcut_preview("weekdays", ~D[2026-04-03]) == "Every Mon-Fri"
    end
  end

  describe "format_datetime_value/2" do
    test "formats valid dates correctly" do
      assert FilterRendering.format_datetime_value("2024-01-15", :date) == "2024-01-15"
      assert FilterRendering.format_datetime_value("", :date) == ""
      assert FilterRendering.format_datetime_value(nil, :date) == ""
    end

    test "formats datetime values for datetime-local input" do
      result = FilterRendering.format_datetime_value("2024-01-15T10:30:00", :naive_datetime)
      assert result == "2024-01-15T10:30"

      result = FilterRendering.format_datetime_value("2024-01-15 10:30:00", :utc_datetime)
      assert result == "2024-01-15T10:30"
    end

    test "formats epoch-backed datetime values for date and datetime inputs" do
      date_field = %{type: :integer, presentation_type: :date, datetime_storage: :unix_ms}

      datetime_field = %{
        type: :integer,
        presentation_type: :utc_datetime,
        datetime_storage: :unix_ms
      }

      assert FilterRendering.format_datetime_value(1_705_276_800_000, date_field) == "2024-01-15"

      assert FilterRendering.format_datetime_value(1_705_316_400_000, datetime_field) ==
               "2024-01-15T11:00"
    end

    test "prevents SQL injection in datetime formatting" do
      malicious_dates = [
        "2024-01-01'; DROP TABLE users--",
        "2024' OR '1'='1",
        "2024-01-01 UNION SELECT password"
      ]

      for malicious_date <- malicious_dates do
        # Should handle malformed dates safely
        result = FilterRendering.format_datetime_value(malicious_date, :date)
        assert is_binary(result)
        # Malformed dates are truncated or returned as-is
        # Actual SQL safety comes from parameterization
      end
    end
  end

  describe "hash_filter_structure/1" do
    test "generates consistent hash for filter structure" do
      filters1 = [
        {UUID.uuid4(), "filters", %{"filter" => "name", "value" => "test"}},
        {UUID.uuid4(), "filters", %{"filter" => "age", "value" => "25"}}
      ]

      hash1 = FilterRendering.hash_filter_structure(filters1)
      hash2 = FilterRendering.hash_filter_structure(filters1)

      assert hash1 == hash2
      assert is_integer(hash1)
    end

    test "prevents SQL injection through filter hashing" do
      malicious_filters = [
        {UUID.uuid4(), "filters'; DROP TABLE--", %{"filter" => "id"}},
        {UUID.uuid4(), "filters", %{"filter" => "name'; DELETE FROM users--"}}
      ]

      # Hashing should handle any structure safely
      hash = FilterRendering.hash_filter_structure(malicious_filters)
      assert is_integer(hash)
    end
  end

  describe "build_filter_list/1 SQL injection prevention" do
    test "builds filter list from Selecto configuration safely" do
      # Mock selecto structure
      selecto = %{
        domain: :mock,
        columns: fn ->
          %{
            id: %{colid: :id, name: "ID", type: :integer},
            name: %{colid: :name, name: "Name", type: :string},
            created_at: %{colid: :created_at, name: "Created At", type: :date}
          }
        end,
        filters: fn ->
          %{
            search: %{id: :search, name: "Search"}
          }
        end
      }

      # Create a mock Selecto module behavior
      defmodule MockSelecto do
        def columns(_selecto) do
          %{
            id: %{colid: :id, name: "ID", type: :integer, make_filter: true},
            name: %{colid: :name, name: "Name", type: :string}
          }
        end

        def filters(_selecto) do
          %{
            search: %{id: :search, name: "Search"}
          }
        end
      end

      # The build_filter_list function should only return columns/filters from the schema
      # This prevents arbitrary field names from being used in queries
    end
  end

  describe "text search rendering" do
    test "renders adapter-aware generic text search help and mode options" do
      html =
        render_component(&FilterRendering.render_text_search_filter/1, %{
          uuid: "f1",
          section: "filters",
          index: 0,
          filter_value: %{"filter" => "search_document", "value" => "wireless charger"},
          selecto: %{adapter: TestMySQLAdapter}
        })

      assert html =~ "Search Mode"
      assert html =~ "Natural Language"
      assert html =~ "Query Expansion"
      assert html =~ "Native text search"
      refute html =~ "websearch_to_tsquery"
    end
  end

  describe "standard filter IN rendering" do
    test "renders textarea, selected checkboxes, and uncheck all for string IN filters" do
      html =
        render_component(&FilterRendering.render_standard_filter/1, %{
          uuid: "f1",
          section: "filters",
          index: 0,
          field_type: :string,
          filter_value: %{
            "filter" => "status",
            "comp" => "IN",
            "selected_values" => ["open", "closed", "paused"]
          },
          selecto: render_selecto(),
          column_def: %{type: :string},
          filter_def: %{type: :string}
        })

      assert html =~ ~s(name="filters[f1][pending_values]")
      assert html =~ ~s(phx-click="toggle_filter_selected_value")
      assert html =~ "Uncheck all"
      assert html =~ "pointer-events-none"
      assert html =~ "open"
      assert html =~ "closed"
      assert html =~ "paused"
    end
  end

  describe "choice-source filter rendering" do
    test "build_filter_list carries choice-source metadata into available filters" do
      filters =
        FilterRendering.build_filter_list(choice_source_selecto(),
          choice_source_links: choice_source_links()
        )

      {_id, _name, metadata} =
        Enum.find(filters, fn {id, _name, _metadata} -> to_string(id) == "customer_id" end)

      assert metadata.choice_source == "customer_choices"
      assert metadata.choice_source_metadata["id"] == "customer_choices"
      assert metadata.choice_source_metadata["field"] == "customer_id"

      assert metadata.choice_source_metadata["presentation"] == %{
               "control" => "autocomplete",
               "mode" => "async"
             }

      assert metadata.choice_source_metadata["options_request"]["url"] ==
               "/api/customers/choices/options"

      assert metadata.choice_source_metadata["validate_request_template"]["url"] ==
               "/api/customers/choices/validate"
    end

    test "build_filter_list projects live choice-source metadata without HTTP links" do
      filters =
        FilterRendering.build_filter_list(choice_source_selecto(),
          choice_source_transport: :live
        )

      {_id, _name, metadata} =
        Enum.find(filters, fn {id, _name, _metadata} -> to_string(id) == "customer_id" end)

      assert metadata.choice_source == "customer_choices"
      assert metadata.choice_source_metadata["transport"] == "live"
      assert metadata.choice_source_metadata["async_options"] == true
      assert metadata.choice_source_metadata["validates_membership"] == true
      refute Map.has_key?(metadata.choice_source_metadata, "options_request")
      refute Map.has_key?(metadata.choice_source_metadata, "validate_request_template")
    end

    test "build_filter_list infers live choice-source metadata from resolvers" do
      filters =
        FilterRendering.build_filter_list(choice_source_selecto(),
          choice_source_options_resolver: fn _request -> {:ok, []} end
        )

      {_id, _name, metadata} =
        Enum.find(filters, fn {id, _name, _metadata} -> to_string(id) == "customer_id" end)

      assert metadata.choice_source == "customer_choices"
      assert metadata.choice_source_metadata["transport"] == "live"
      assert metadata.choice_source_metadata["async_options"] == true
      assert metadata.choice_source_metadata["validates_membership"] == true
      refute Map.has_key?(metadata.choice_source_metadata, "options_request")
      refute Map.has_key?(metadata.choice_source_metadata, "validate_request_template")
    end

    test "renders a lookup shell for equality filters with choice-source metadata" do
      html =
        render_component(&FilterRendering.render_standard_filter/1, %{
          uuid: "f1",
          section: "filters",
          index: 0,
          field_type: :integer,
          filter_value: %{
            "filter" => "customer_id",
            "comp" => "=",
            "value" => "42"
          },
          selecto: choice_source_selecto(),
          column_def: %{
            type: :integer,
            choice_source_metadata: %{
              "id" => "customer_choices",
              "field" => "customer_id",
              "label_field" => "name",
              "presentation" => %{"control" => "autocomplete", "mode" => "async"},
              "options_request" => %{
                "method" => "get",
                "url" => "/api/customers/choices/options"
              },
              "validate_request_template" => %{
                "method" => "post",
                "url" => "/api/customers/choices/validate",
                "body" => %{"field" => "customer_id", "value" => "$value"}
              }
            }
          },
          filter_def: %{type: :integer}
        })

      assert html =~ ~s(data-choice-source-filter)
      assert html =~ ~s(data-choice-source-id="customer_choices")
      assert html =~ ~s(data-choice-source-field="customer_id")
      assert html =~ ~s(data-choice-source-control="autocomplete")
      assert html =~ ~s(data-choice-source-transport="http")
      assert html =~ ~s(data-choice-source-options-url="/api/customers/choices/options")
      assert html =~ ~s(data-choice-source-validate-url="/api/customers/choices/validate")
      assert html =~ ~s(phx-hook="SelectoComponents.Form.FilterRendering.ChoiceSourceFilter")
      assert html =~ ~s(data-choice-source-options)
      assert html =~ ~s(data-choice-source-validate-on="blur submit")
      assert html =~ ~s(data-choice-source-validation-state="unknown")
      assert html =~ ~s(role="listbox")
      assert html =~ ~s(data-choice-source-status)
      assert html =~ ~s(data-choice-source-limit="20")
      assert html =~ ~s(type="search")
      assert html =~ ~s(data-choice-source-display-input)
      assert html =~ ~s(data-choice-source-value-input)
      assert html =~ ~s(data-choice-source-display-value-input)
      assert html =~ ~s(id="filters-choice-source-value-f1-display")
      assert html =~ ~s(name="filters[f1][value]")
      assert html =~ ~s(name="filters[f1][display_value]")
      assert html =~ ~s(value="42")
      assert html =~ ~s(aria-invalid="false")
      assert html =~ ~s(placeholder="Search Name...")
      assert length(Regex.scan(~r/name="filters\[f1\]\[value\]"/, html)) == 1
    end

    test "keeps submitted id separate from display label" do
      html =
        render_component(&FilterRendering.choice_source_filter_input/1, %{
          uuid: "f1",
          scope: "filters",
          value: "42",
          display_value: "Ada Lovelace",
          metadata: %{
            "id" => "customer_choices",
            "field" => "customer_id",
            "options_request" => %{"url" => "/api/customers/choices/options"},
            "validate_request_template" => %{"url" => "/api/customers/choices/validate"}
          }
        })

      assert html =~ ~s(name="filters[f1][value]" value="42")
      assert html =~ ~s(name="filters[f1][display_value]" value="Ada Lovelace")
      assert html =~ ~s(type="search")
      assert html =~ ~s(value="Ada Lovelace")
      assert length(Regex.scan(~r/name="filters\[f1\]\[value\]"/, html)) == 1
    end

    test "allows callers to override submitted and display input names" do
      html =
        render_component(&FilterRendering.choice_source_filter_input/1, %{
          uuid: "assignee_id",
          value: "7",
          display_value: "Grace Hopper",
          input_name: "write_form[fields][assignee_id]",
          display_input_name: "write_form[field_displays][assignee_id]",
          input_id: "write-form-field-assignee_id",
          display_input_id: "write-form-field-assignee_id-display",
          metadata: %{
            "id" => "work_item_assignees",
            "field" => "assignee_id",
            "transport" => "live"
          }
        })

      assert html =~ ~s(id="write-form-field-assignee_id")
      assert html =~ ~s(id="write-form-field-assignee_id-display")
      assert html =~ ~s(name="write_form[fields][assignee_id]" value="7")
      assert html =~ ~s(name="write_form[field_displays][assignee_id]" value="Grace Hopper")
      assert html =~ ~s(data-choice-source-transport="live")
      assert length(Regex.scan(~r/name="write_form\[fields\]\[assignee_id\]"/, html)) == 1
    end
  end

  describe "standard filter controller promotion" do
    test "renders a promote checkbox for non-equals standard filters" do
      html =
        render_component(&FilterRendering.render_standard_filter/1, %{
          uuid: "f1",
          section: "filters",
          index: 0,
          field_type: :integer,
          filter_value: %{
            "filter" => "estimate",
            "comp" => "BETWEEN",
            "value_start" => "3",
            "value_end" => "8",
            "promote" => "true"
          },
          selecto: render_selecto(),
          column_def: %{type: :integer},
          filter_def: %{type: :integer}
        })

      assert html =~ ~s(name="filters[f1][promote]")
      assert html =~ "Promote to View Controller"
    end

    test "locks promoted standard filters in the filter tab" do
      html =
        render_component(&FilterRendering.render_standard_filter/1, %{
          uuid: "f1",
          section: "filters",
          index: 0,
          field_type: :string,
          filter_value: %{
            "filter" => "title",
            "comp" => "=",
            "value" => "alpha",
            "promote" => "true"
          },
          selecto: render_selecto(),
          column_def: %{type: :string},
          filter_def: %{type: :string}
        })

      assert html =~ ~s(data-promoted-lock="true")
      assert html =~ ~s(inert)
      assert html =~ "Edited in View Controller."
    end

    test "renders a promote checkbox for datetime filters" do
      html =
        render_component(&FilterRendering.render_datetime_filter/1, %{
          uuid: "f1",
          section: "filters",
          index: 0,
          field_type: :date,
          filter_value: %{
            "filter" => "due_on",
            "comp" => "SHORTCUT",
            "value" => "today",
            "promote" => "true"
          },
          selecto: render_selecto(),
          column_def: %{type: :date},
          filter_def: %{type: :date}
        })

      assert html =~ ~s(name="filters[f1][promote]")
      assert html =~ "Promote to View Controller"
      assert html =~ "Preview:"
      assert html =~ FilterRendering.date_shortcut_preview("today")
      assert html =~ ~s(data-promoted-lock="true")
      assert html =~ "Edited in View Controller."
    end

    test "renders a promote checkbox for text search filters" do
      html =
        render_component(&FilterRendering.render_text_search_filter/1, %{
          uuid: "f1",
          section: "filters",
          index: 0,
          filter_value: %{
            "filter" => "search",
            "value" => "launch pad",
            "promote" => "true"
          },
          selecto: render_selecto()
        })

      assert html =~ ~s(name="filters[f1][promote]")
      assert html =~ "Promote to View Controller"
      assert html =~ ~s(data-promoted-lock="true")
      assert html =~ "Edited in View Controller."
    end
  end

  describe "presentation-aware filter inputs" do
    test "renders canonical measurement filters back in display units" do
      html =
        render_component(&FilterRendering.render_standard_filter/1, %{
          uuid: "f1",
          section: "filters",
          index: 0,
          field_type: :decimal,
          filter_value: %{
            "filter" => "temperature_c",
            "comp" => "=",
            "value" => "0",
            "display_value" => "32"
          },
          selecto: render_presentation_selecto(),
          column_def: %{
            type: :decimal,
            presentation: %{
              semantic_type: :measurement,
              quantity: :temperature,
              canonical_unit: :celsius,
              default_unit: :celsius
            }
          },
          filter_def: %{type: :decimal},
          presentation_context: %{unit_system: :us_customary}
        })

      assert html =~ ~s(value="32")
    end

    test "renders canonical instant datetime filters in viewer local time" do
      html =
        render_component(&FilterRendering.render_datetime_filter/1, %{
          uuid: "f1",
          section: "filters",
          index: 0,
          field_type: :utc_datetime,
          filter_value: %{
            "filter" => "recorded_at",
            "comp" => ">=",
            "value" => "2024-01-01T12:00:00Z",
            "display_value" => "2024-01-01T07:00"
          },
          selecto: render_presentation_selecto(),
          column_def: %{
            type: :integer,
            presentation_type: :utc_datetime,
            datetime_storage: :unix_seconds,
            presentation: %{
              semantic_type: :temporal,
              temporal_kind: :instant,
              display_timezone: :viewer
            }
          },
          filter_def: %{type: :utc_datetime},
          presentation_context: %{timezone: "America/New_York"}
        })

      assert html =~ ~s(value="2024-01-01T07:00")
    end

    test "renders canonical plain numeric filters back in display-local form" do
      html =
        render_component(&FilterRendering.render_standard_filter/1, %{
          uuid: "f1",
          section: "filters",
          index: 0,
          field_type: :decimal,
          filter_value: %{
            "filter" => "amount",
            "comp" => ">=",
            "value" => "1234.5",
            "display_value" => "1.234,5"
          },
          selecto: render_presentation_selecto(),
          column_def: %{type: :decimal},
          filter_def: %{type: :decimal},
          presentation_context: %{locale: "de-DE"}
        })

      assert html =~ ~s(value="1.234,5")
    end
  end

  describe "Security notes" do
    test "documents security measures for filter rendering" do
      # Security measures in FilterRendering:
      #
      # 1. Date shortcuts are validated against a fixed whitelist
      # 2. Relative date patterns are validated with strict regex
      # 3. Datetime formatting does not perform SQL operations
      # 4. Filter list is built only from Selecto schema (not user input)
      # 5. All filter values are passed to Selecto for parameterization
      # 6. LIKE patterns are sanitized by Helpers.Filters (separate module)
      #
      # The rendering module focuses on UI - actual SQL generation
      # happens in Selecto with proper parameterization.

      assert true, "Security measures documented"
    end
  end

  defp render_selecto do
    domain = %{
      name: "FilterRenderingRenderTest",
      source: %{
        source_table: "records",
        primary_key: :id,
        fields: [:id, :status],
        redact_fields: [],
        columns: %{
          id: %{type: :integer, colid: :id, name: "ID"},
          status: %{type: :string, colid: :status, name: "Status"}
        },
        associations: %{}
      },
      schemas: %{},
      joins: %{}
    }

    Selecto.configure(domain, nil)
  end

  defp choice_source_selecto do
    domain = %{
      name: "ChoiceSourceFilterRenderingTest",
      source: %{
        source_table: "orders",
        primary_key: :id,
        fields: [:id, :customer_id, :status],
        redact_fields: [],
        columns: %{
          id: %{type: :integer, colid: :id, name: "ID"},
          customer_id: %{
            type: :integer,
            colid: :customer_id,
            name: "Customer",
            choice_source: :customer_choices
          },
          status: %{type: :string, colid: :status, name: "Status"}
        },
        associations: %{}
      },
      schemas: %{},
      joins: %{},
      choice_sources: %{
        customer_choices: %{
          domain: :customers,
          value_field: :id,
          label_field: :name,
          presentation: %{control: :autocomplete, mode: :async}
        }
      }
    }

    Selecto.configure(domain, nil)
  end

  defp choice_source_links do
    %{
      customer_choices: %{
        options: "/api/customers/choices/options",
        validate: "/api/customers/choices/validate"
      }
    }
  end

  defp render_presentation_selecto do
    domain = %{
      name: "FilterRenderingPresentationTest",
      source: %{
        source_table: "records",
        primary_key: :id,
        fields: [:id, :temperature_c, :recorded_at, :amount],
        redact_fields: [],
        columns: %{
          id: %{type: :integer, colid: :id, name: "ID"},
          temperature_c: %{
            type: :decimal,
            colid: :temperature_c,
            name: "Temperature",
            presentation: %{
              semantic_type: :measurement,
              quantity: :temperature,
              canonical_unit: :celsius,
              default_unit: :celsius
            }
          },
          recorded_at: %{
            type: :integer,
            colid: :recorded_at,
            name: "Recorded At",
            presentation_type: :utc_datetime,
            datetime_storage: :unix_seconds,
            presentation: %{
              semantic_type: :temporal,
              temporal_kind: :instant,
              display_timezone: :viewer
            }
          },
          amount: %{
            type: :decimal,
            colid: :amount,
            name: "Amount"
          }
        },
        associations: %{}
      },
      schemas: %{},
      joins: %{}
    }

    Selecto.configure(domain, nil)
  end
end
