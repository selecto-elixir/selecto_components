defmodule SelectoComponents.Helpers do
  def aggregate_datetime_format_options() do
    [
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

  def build_initial_state(list) do
    list
    |> Enum.map(fn
      i when is_bitstring(i) -> {UUID.uuid4(), i, %{}}
      {i, conf} -> {UUID.uuid4(), i, conf}
    end)
  end
end
