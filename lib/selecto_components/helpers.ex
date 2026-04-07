defmodule SelectoComponents.Helpers do
  def text_search_mode_options(adapter) do
    case Selecto.AdapterSupport.adapter_name(adapter) do
      :mysql ->
        [
          {"natural", "Natural Language"},
          {"websearch", "Web Style"},
          {"plain", "Plain Tokens"},
          {"boolean", "Boolean"},
          {"query_expansion", "Query Expansion"}
        ]

      :sqlite ->
        [
          {"websearch", "Default MATCH"},
          {"boolean", "Boolean"},
          {"phrase", "Phrase"}
        ]

      _ ->
        [
          {"websearch", "Web Style"},
          {"plain", "Plain Tokens"},
          {"phrase", "Phrase"},
          {"boolean", "Boolean"},
          {"natural", "Natural Language"}
        ]
    end
  end

  def default_text_search_mode(adapter) do
    case Selecto.AdapterSupport.adapter_name(adapter) do
      :mysql -> "natural"
      :sqlite -> "websearch"
      _ -> "websearch"
    end
  end

  def text_search_help_text(adapter) do
    case Selecto.AdapterSupport.adapter_name(adapter) do
      :mysql ->
        "Native text search with natural-language, boolean, or query-expansion modes."

      :sqlite ->
        "FTS-backed text search with MATCH syntax, including phrase and boolean-style queries when supported."

      :postgresql ->
        "Full-text search with web-style, plain, phrase, or boolean query modes."

      _ ->
        "Text search behavior is adapter-specific. Supported modes depend on the active database adapter."
    end
  end

  def datetime_grouping_format_options() do
    [
      {"YYYY-MM-DD", "Day"},
      {"YYYY-WW", "Week"},
      {"YYYY-MM", "Month"},
      {"YYYY-Q", "Quarter"},
      {"YYYY", "Year"},
      {"year_buckets", "Year Buckets"},
      {"MM", "Month of Year"},
      {"DD", "Day of Month"},
      {"D", "Day of Week"},
      {"HH24", "Hour of Day"},
      {"age_buckets", "Age Buckets"},
      {"custom_buckets", "Custom Date Buckets"}
    ]
  end

  def aggregate_datetime_format_options, do: datetime_grouping_format_options()

  def date_formats() do
    %{
      "YYYY-MM-DD" => "YYYY-MM-DD",
      "YYYY-WW" => "YYYY-WW",
      "YYYY-MM" => "YYYY-MM",
      "YYYY-Q" => "YYYY-Q",
      "YYYY" => "YYYY",
      "MM" => "MM",
      "DD" => "DD",
      "D" => "D",
      "HH24" => "HH24",
      "MM-DD-YYYY HH:MM" => "MM-DD-YYYY HH:MM",
      "YYYY-MM-DD HH:MM" => "YYYY-MM-DD HH:MM"
    }
  end

  def datetime_grouping_format_label(format) when is_atom(format) do
    format
    |> Atom.to_string()
    |> datetime_grouping_format_label()
  end

  def datetime_grouping_format_label(format) when is_binary(format) do
    Enum.find_value(datetime_grouping_format_options(), format, fn
      {^format, label} -> label
      _ -> nil
    end)
  end

  def aggregate_datetime_format_label(format) do
    datetime_grouping_format_label(format) || to_string(format)
  end

  def datetime_bucket_placeholder("age_buckets"), do: "e.g., 0, 1-7, 8-30, 31-90, 91+"
  def datetime_bucket_placeholder("year_buckets"), do: "e.g., */5 or 2020-2024, 2025-2029"
  def datetime_bucket_placeholder(_), do: "e.g., today, yesterday, 2-7, 8+"

  def build_initial_state(list) do
    list
    |> Enum.map(fn
      i when is_bitstring(i) -> {UUID.uuid4(), i, %{}}
      {i, conf} -> {UUID.uuid4(), i, conf}
    end)
  end
end
