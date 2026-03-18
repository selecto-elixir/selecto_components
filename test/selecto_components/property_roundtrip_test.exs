defmodule SelectoComponents.PropertyRoundtripTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias SelectoComponents.Filter.FilterSets
  alias SelectoComponents.Form.ParamsState

  property "decode_shared_filters round-trips encoded filter maps" do
    check all(filters <- shared_filters_generator()) do
      encoded = encode_shared_filters(filters)
      assert {:ok, decoded} = FilterSets.decode_shared_filters(encoded)
      assert decoded == filters
    end
  end

  property "decode_shared_filters rejects non-binary input" do
    check all(input <- non_binary_generator()) do
      assert {:error, :invalid_input} = FilterSets.decode_shared_filters(input)
    end
  end

  property "filters_to_params and view_filter_process preserve filter tuples" do
    check all(filters <- filter_tuples_generator()) do
      params = ParamsState.filters_to_params(filters)
      processed = ParamsState.view_filter_process(%{"filters" => params}, "filters")

      assert length(processed) == length(filters)

      Enum.zip(filters, processed)
      |> Enum.each(fn {{orig_uuid, orig_section, orig_map}, {uuid, section, processed_map}} ->
        assert uuid =~ ~r/^k[0-9a-z]+$/
        assert section == orig_section
        assert processed_map["uuid"] == orig_uuid
        assert processed_map["filter"] == orig_map["filter"]
        assert processed_map["comp"] == orig_map["comp"]
        assert processed_map["value"] == orig_map["value"]
      end)
    end
  end

  property "view_filter_process converts selected_ids arrays into CSV values" do
    check all(
            ids <- list_of(integer(1..200), min_length: 1, max_length: 8),
            comp <- member_of(["IN", "NOT IN"])
          ) do
      selected_ids = Enum.map(ids, &Integer.to_string/1)

      params = %{
        "filters" => %{
          "f1" => %{
            "filter" => "id",
            "comp" => comp,
            "selected_ids" => selected_ids,
            "section" => "where",
            "index" => "0"
          }
        }
      }

      [{_uuid, _section, filter_map}] = ParamsState.view_filter_process(params, "filters")

      assert filter_map["value"] == Enum.join(selected_ids, ",")
      refute Map.has_key?(filter_map, "selected_ids")
    end
  end

  defp encode_shared_filters(filters) do
    filters
    |> Jason.encode!()
    |> :zlib.compress()
    |> Base.url_encode64(padding: false)
  end

  defp shared_filters_generator do
    map_of(
      string(:alphanumeric, min_length: 1, max_length: 12),
      fixed_map(%{
        "filter" => member_of(["id", "status", "name", "category"]),
        "comp" => member_of(["=", "!=", "IN", "NOT IN", "LIKE"]),
        "value" => string(:alphanumeric, min_length: 1, max_length: 16)
      }),
      max_length: 30
    )
  end

  defp filter_tuples_generator do
    list_of(
      fixed_map(%{
        uuid: string(:alphanumeric, min_length: 1, max_length: 12),
        section: member_of(["where", "having", "detail"]),
        filter: member_of(["id", "status", "name", "priority"]),
        comp: member_of(["=", "!=", "LIKE", "IN"]),
        value: string(:alphanumeric, min_length: 1, max_length: 14)
      }),
      min_length: 1,
      max_length: 10
    )
    |> map(&Enum.uniq_by(&1, fn entry -> entry.uuid end))
    |> filter(&(length(&1) > 0))
    |> map(fn entries ->
      Enum.map(entries, fn entry ->
        {entry.uuid, entry.section,
         %{"filter" => entry.filter, "comp" => entry.comp, "value" => entry.value}}
      end)
    end)
  end

  defp non_binary_generator do
    one_of([
      integer(),
      boolean(),
      atom(:alphanumeric),
      list_of(integer(0..9), max_length: 6),
      map_of(string(:alphanumeric, min_length: 1, max_length: 6), integer(0..50), max_length: 3)
    ])
  end
end
