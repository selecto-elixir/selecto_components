defmodule SelectoComponents.Helpers.BucketParserTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.Helpers.BucketParser

  describe "generate_bucket_case_sql/3" do
    test "does not treat */step as a date bucket format" do
      assert BucketParser.generate_bucket_case_sql("selecto_root.inserted_at", "*/10", :date) ==
               "selecto_root.inserted_at"
    end

    test "maps custom date buckets to current-date-relative date comparisons" do
      sql =
        BucketParser.generate_bucket_case_sql(
          "selecto_root.inserted_at",
          "today, yesterday, 2-7, 8+",
          :date
        )

      assert sql =~ "DATE(selecto_root.inserted_at) = CURRENT_DATE"
      assert sql =~ "DATE(selecto_root.inserted_at) = CURRENT_DATE - INTERVAL '1 day'"

      assert sql =~
               "DATE(selecto_root.inserted_at) BETWEEN CURRENT_DATE - INTERVAL '7 day' AND CURRENT_DATE - INTERVAL '2 day'"

      assert sql =~ "DATE(selecto_root.inserted_at) <= CURRENT_DATE - INTERVAL '8 day'"
    end

    test "rejects invalid increment shorthand values" do
      assert BucketParser.generate_bucket_case_sql("selecto_root.price", "*/0", :integer) ==
               "selecto_root.price"

      assert BucketParser.generate_bucket_case_sql("selecto_root.price", "*/-5", :integer) ==
               "selecto_root.price"
    end
  end

  describe "option parsing" do
    test "exposes year bucket datetime option label" do
      assert {"year_buckets", "Year Buckets"} in SelectoComponents.Helpers.datetime_grouping_format_options()
      assert SelectoComponents.Helpers.datetime_bucket_placeholder("year_buckets") =~ "*/5"
    end

    test "parses and clamps prefix length" do
      assert BucketParser.parse_prefix_length("2") == 2
      assert BucketParser.parse_prefix_length(4) == 4
      assert BucketParser.parse_prefix_length("99") == 10
      assert BucketParser.parse_prefix_length("0", 2) == 2
      assert BucketParser.parse_prefix_length("bad", 2) == 2
    end

    test "parses exclude_articles option" do
      assert BucketParser.exclude_articles?("true")
      assert BucketParser.exclude_articles?("on")
      refute BucketParser.exclude_articles?("false")
      refute BucketParser.exclude_articles?("0")
      assert BucketParser.exclude_articles?(nil, true)
      refute BucketParser.exclude_articles?(nil, false)
    end
  end
end
