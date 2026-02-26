defmodule SelectoComponents.Helpers.BucketParser do
  @moduledoc """
  Parser for bucket range specifications like "1, 2-5, 6-14, 15+"
  and numeric increment shorthand like "*/10"
  """

  @numeric_bucket_types [:int, :integer, :id, :decimal, :float]
  @default_prefix_length 2
  @max_prefix_length 10
  @common_articles ~w(a an the)

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

  @doc """
  Generate SQL CASE expression for text prefix buckets.

  Example buckets with default options:

  - "The Office" -> "OF"
  - "A Team" -> "TE"
  - nil/blank/article-only -> "Other"
  """
  def generate_text_prefix_case_sql(field_name, opts \\ %{}) do
    prefix_length =
      parse_prefix_length(
        Map.get(opts, :prefix_length) || Map.get(opts, "prefix_length"),
        @default_prefix_length
      )

    normalized_expr = normalized_text_sql(field_name, opts)

    "CASE WHEN #{normalized_expr} = '' THEN 'Other' ELSE UPPER(LEFT(#{normalized_expr}, #{prefix_length})) END"
  end

  @doc """
  Build normalized SQL text expression for prefix bucketing/filtering.
  """
  def normalized_text_sql(field_name, opts \\ %{}) do
    qualified_field = qualify_field_name(field_name)
    trimmed_expr = "LOWER(BTRIM(COALESCE(#{qualified_field}::text, '')))"

    if exclude_articles?(
         Map.get(opts, :exclude_articles) || Map.get(opts, "exclude_articles"),
         true
       ) do
      articles_pattern = Enum.join(@common_articles, "|")
      "REGEXP_REPLACE(#{trimmed_expr}, '^(#{articles_pattern})([[:space:]]+|$)', '', 'i')"
    else
      trimmed_expr
    end
  end

  def qualify_field_name(field_name) when is_binary(field_name) do
    if String.contains?(field_name, ".") do
      field_name
    else
      "selecto_root.#{field_name}"
    end
  end

  def qualify_field_name(field_name) when is_atom(field_name), do: "selecto_root.#{field_name}"
  def qualify_field_name(field_name), do: to_string(field_name)

  def parse_prefix_length(value, default \\ @default_prefix_length)

  def parse_prefix_length(value, _default) when is_integer(value) and value > 0 do
    min(value, @max_prefix_length)
  end

  def parse_prefix_length(value, default) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {parsed, ""} when parsed > 0 -> min(parsed, @max_prefix_length)
      _ -> default
    end
  end

  def parse_prefix_length(_value, default), do: default

  def exclude_articles?(value, default \\ true)

  def exclude_articles?(nil, default), do: default

  def exclude_articles?(value, _default) when value in [true, "true", "TRUE", "on", "1", 1],
    do: true

  def exclude_articles?(value, _default) when value in [false, "false", "FALSE", "off", "0", 0],
    do: false

  def exclude_articles?(_value, default), do: default

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
