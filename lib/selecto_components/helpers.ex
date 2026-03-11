defmodule SelectoComponents.Helpers do
  def aggregate_datetime_format_options() do
    [
      {"Day", "YYYY-MM-DD"},
      {"Week", "YYYY-WW"},
      {"Month", "YYYY-MM"},
      {"Quarter", "YYYY-Q"},
      {"Year", "YYYY"},
      {"Month of Year", "MM"},
      {"Day of Month", "DD"},
      {"Day of Week", "D"},
      {"Hour of Day", "HH24"},
      {"Age Buckets", "age_buckets"},
      {"Custom Date Buckets", "custom_buckets"}
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
