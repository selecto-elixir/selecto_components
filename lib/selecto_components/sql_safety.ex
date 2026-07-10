defmodule SelectoComponents.SqlSafety do
  @moduledoc false

  @datetime_grouping_formats ~w(
    YYYY-MM-DD
    YYYY-WW
    YYYY-MM
    YYYY-Q
    YYYY
    MM
    DD
    D
    HH24
  ) ++ ["YYYY-MM-DD HH24"]

  @safe_timezone ~r/\A[A-Za-z0-9_.+\/-]+\z/

  @spec datetime_grouping_format(term(), String.t()) :: String.t()
  def datetime_grouping_format(value, default \\ "YYYY-MM-DD") do
    if value in @datetime_grouping_formats, do: value, else: default
  end

  @spec timezone(term(), String.t() | nil) :: String.t() | nil
  def timezone(value, default \\ "Etc/UTC")

  def timezone(value, default) when is_binary(value) do
    timezone = String.trim(value)

    if timezone != "" and Regex.match?(@safe_timezone, timezone) and
         Timex.Timezone.exists?(timezone) do
      timezone
    else
      default
    end
  rescue
    _ -> default
  end

  def timezone(_value, default), do: default
end
