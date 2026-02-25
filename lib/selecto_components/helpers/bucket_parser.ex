defmodule SelectoComponents.Helpers.BucketParser do
  @moduledoc """
  Parser for bucket range specifications like "1, 2-5, 6-14, 15+"
  and numeric increment shorthand like "*/10"
  """

  @numeric_bucket_types [:int, :integer, :id, :decimal, :float]

  def parse_bucket_ranges(ranges_string) when is_binary(ranges_string) do
    ranges_string
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&parse_single_range/1)
    |> Enum.reject(&is_nil/1)
  end

  def parse_bucket_ranges(_), do: []

  defp parse_single_range(range) do
    cond do
      # Single value like "1"
      String.match?(range, ~r/^\d+$/) ->
        val = String.to_integer(range)
        {val, val, "#{val}"}

      # Range like "2-5"
      String.match?(range, ~r/^\d+-\d+$/) ->
        [min_str, max_str] = String.split(range, "-")
        min = String.to_integer(min_str)
        max = String.to_integer(max_str)
        {min, max, "#{min}-#{max}"}

      # Open-ended range like "15+"
      String.match?(range, ~r/^\d+\+$/) ->
        min = range |> String.replace("+", "") |> String.to_integer()
        {min, :infinity, "#{min}+"}

      # Open-ended range like "-5" (up to 5)
      String.match?(range, ~r/^-\d+$/) ->
        max = range |> String.replace("-", "") |> String.to_integer()
        {:negative_infinity, max, "≤#{max}"}

      # Special keywords for date buckets
      range in ["today", "yesterday", "tomorrow"] ->
        {range, range, range}

      true ->
        nil
    end
  end

  @doc """
  Generate SQL CASE expression for bucketing values
  """
  def generate_bucket_case_sql(field_name, bucket_ranges, field_type \\ :integer) do
    increment = parse_increment_shorthand(bucket_ranges)

    if field_type in @numeric_bucket_types and is_integer(increment) do
      generate_increment_case_sql(field_name, increment)
    else
      ranges = parse_bucket_ranges(bucket_ranges)

      if Enum.empty?(ranges) do
        field_name
      else
        case_clauses =
          Enum.map(ranges, fn
            {min, max, label} when is_integer(min) and is_integer(max) ->
              if min == max do
                "WHEN #{field_name} = #{min} THEN '#{label}'"
              else
                "WHEN #{field_name} >= #{min} AND #{field_name} <= #{max} THEN '#{label}'"
              end

            {min, :infinity, label} ->
              # For "11+" we want >= 11, not > 11
              # The min value in "11+" means "11 and above"
              "WHEN #{field_name} >= #{min} THEN '#{label}'"

            {:negative_infinity, max, label} ->
              "WHEN #{field_name} <= #{max} THEN '#{label}'"

            {"today", "today", _label} when field_type in [:date, :datetime] ->
              "WHEN DATE(#{field_name}) = CURRENT_DATE THEN 'Today'"

            {"yesterday", "yesterday", _label} when field_type in [:date, :datetime] ->
              "WHEN DATE(#{field_name}) = CURRENT_DATE - INTERVAL '1 day' THEN 'Yesterday'"

            {"tomorrow", "tomorrow", _label} when field_type in [:date, :datetime] ->
              "WHEN DATE(#{field_name}) = CURRENT_DATE + INTERVAL '1 day' THEN 'Tomorrow'"

            _ ->
              nil
          end)
          |> Enum.reject(&is_nil/1)

        if Enum.empty?(case_clauses) do
          field_name
        else
          "CASE #{Enum.join(case_clauses, " ")} ELSE 'Other' END"
        end
      end
    end
  end

  defp parse_increment_shorthand(ranges_string) when is_binary(ranges_string) do
    trimmed = String.trim(ranges_string)

    case Regex.run(~r{^\*/(\d+)$}, trimmed, capture: :all_but_first) do
      [step_str] ->
        case Integer.parse(step_str) do
          {step, ""} when step > 0 -> step
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp parse_increment_shorthand(_), do: nil

  defp generate_increment_case_sql(field_name, increment) do
    bucket_start = "(FLOOR((#{field_name})::numeric / #{increment})::bigint * #{increment})"

    "CASE WHEN #{field_name} IS NULL THEN 'Other' ELSE " <>
      "(#{bucket_start})::text || '-' || ((#{bucket_start}) + #{increment - 1})::text END"
  end

  @doc """
  Get bucket labels in order for column headers
  """
  def get_bucket_labels(bucket_ranges) do
    ranges = parse_bucket_ranges(bucket_ranges)
    Enum.map(ranges, fn {_, _, label} -> label end) ++ ["Other"]
  end

  @doc """
  Generate filter for a specific bucket
  """
  def generate_bucket_filter(_field_name, bucket_label, bucket_ranges) do
    ranges = parse_bucket_ranges(bucket_ranges)

    case Enum.find(ranges, fn {_, _, label} -> label == bucket_label end) do
      {min, max, _} when is_integer(min) and is_integer(max) ->
        if min == max do
          %{"comp" => "=", "value" => min}
        else
          %{"comp" => "BETWEEN", "value" => "#{min},#{max}"}
        end

      {min, :infinity, _} ->
        %{"comp" => ">=", "value" => min}

      {:negative_infinity, max, _} ->
        %{"comp" => "<=", "value" => max}

      {"today", "today", _} ->
        %{"comp" => "SHORTCUT", "value" => "today"}

      {"yesterday", "yesterday", _} ->
        %{"comp" => "SHORTCUT", "value" => "yesterday"}

      {"tomorrow", "tomorrow", _} ->
        %{"comp" => "SHORTCUT", "value" => "tomorrow"}

      _ ->
        nil
    end
  end
end
