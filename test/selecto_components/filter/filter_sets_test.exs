defmodule SelectoComponents.Filter.FilterSetsTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.Filter.FilterSets

  test "decode_shared_filters/1 decodes valid payload" do
    filters = %{
      "f1" => %{"filter" => "id", "comp" => "=", "value" => "1"},
      "f2" => %{"filter" => "status", "comp" => "IN", "value" => "active"}
    }

    encoded = encode_shared_filters(filters)

    assert {:ok, ^filters} = FilterSets.decode_shared_filters(encoded)
  end

  test "decode_shared_filters/1 rejects oversized encoded payload" do
    encoded = String.duplicate("a", 40_000)

    assert {:error, {:decode_failed, :shared_filters_param_too_large}} =
             FilterSets.decode_shared_filters(encoded)
  end

  test "decode_shared_filters/1 rejects invalid decoded shape" do
    encoded =
      "not-a-filter-map"
      |> Jason.encode!()
      |> :zlib.compress()
      |> Base.url_encode64(padding: false)

    assert {:error, {:decode_failed, :invalid_filters_shape}} =
             FilterSets.decode_shared_filters(encoded)
  end

  defp encode_shared_filters(filters) do
    filters
    |> Jason.encode!()
    |> :zlib.compress()
    |> Base.url_encode64(padding: false)
  end
end
