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
end
