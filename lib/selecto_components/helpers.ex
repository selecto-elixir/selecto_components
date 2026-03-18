defmodule SelectoComponents.Helpers do
  def aggregate_datetime_format_options() do
    [
      {"count", "Count"},
      {"count_distinct", "Count Distinct"},
      {"sum", "Sum"},
      {"avg", "Average"},
      {"min", "Min"},
      {"max", "Max"},
      {"buckets", "Buckets"},
      {"true_count", "True Count"},
      {"false_count", "False Count"},
      {"YYYY-MM-DD", "Day"},
      {"YYYY-WW", "Week"},
      {"YYYY-MM", "Month"},
      {"YYYY-Q", "Quarter"},
      {"YYYY", "Year"},
      {"MM", "Month of Year"},
      {"DD", "Day of Month"},
      {"D", "Day of Week"},
      {"HH24", "Hour of Day"},
      {"age_buckets", "Age Buckets"},
      {"custom_buckets", "Custom Date Buckets"}
    ]
  end

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

  def aggregate_datetime_format_label(format) when is_atom(format) do
    format
    |> Atom.to_string()
    |> aggregate_datetime_format_label()
  end

  def aggregate_datetime_format_label(format) when is_binary(format) do
    Enum.find_value(aggregate_datetime_format_options(), format, fn
      {^format, label} -> label
      _ -> nil
    end)
  end

  def aggregate_datetime_format_label(format), do: to_string(format)

  def build_initial_state(list) do
    list
    |> Enum.map(fn
      i when is_bitstring(i) -> {UUID.uuid4(), i, %{}}
      {i, conf} -> {UUID.uuid4(), i, conf}
    end)
  end
end
