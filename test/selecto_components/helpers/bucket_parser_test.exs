defmodule SelectoComponents.Helpers.BucketParserTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.Helpers.BucketParser

  describe "generate_bucket_case_sql/3" do
    test "supports increment shorthand for numeric bucket ranges" do
      sql = BucketParser.generate_bucket_case_sql("selecto_root.price", "*/10", :integer)

      assert sql =~ "CASE WHEN selecto_root.price IS NULL THEN 'Other'"
      assert sql =~ "FLOOR((selecto_root.price)::numeric / 10)"
      assert sql =~ "|| '-' ||"
      assert sql =~ "+ 9"
    end

    test "does not treat */step as a date bucket format" do
      assert BucketParser.generate_bucket_case_sql("selecto_root.inserted_at", "*/10", :date) ==
               "selecto_root.inserted_at"
    end

    test "rejects invalid increment shorthand values" do
      assert BucketParser.generate_bucket_case_sql("selecto_root.price", "*/0", :integer) ==
               "selecto_root.price"

      assert BucketParser.generate_bucket_case_sql("selecto_root.price", "*/-5", :integer) ==
               "selecto_root.price"
    end
  end

  describe "generate_text_prefix_case_sql/2" do
    test "builds article-aware first-two-letter buckets by default" do
      sql = BucketParser.generate_text_prefix_case_sql("selecto_root.title")

      assert sql =~ "REGEXP_REPLACE"
      assert sql =~ "^(a|an|the)([[:space:]]+|$)"
      assert sql =~ "UPPER(LEFT("
      assert sql =~ ", 2))"
      assert sql =~ "THEN 'Other'"
    end

    test "supports custom prefix length and article handling toggle" do
      sql =
        BucketParser.generate_text_prefix_case_sql("title", %{
          "prefix_length" => "3",
          "exclude_articles" => "false"
        })

      refute sql =~ "REGEXP_REPLACE"
      assert sql =~ "UPPER(LEFT("
      assert sql =~ ", 3))"
    end
  end

  describe "option parsing" do
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
