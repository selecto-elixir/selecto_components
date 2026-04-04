defmodule SelectoComponents.QueryResultsTest do
  use ExUnit.Case, async: true

  alias Decimal, as: D
  alias SelectoComponents.QueryResults

  test "normalizes raw uuid and bytea values for liveview-safe rendering" do
    uuid = "7ebf047b-f57f-4171-9858-05b68a324629"
    {:ok, uuid_binary} = Ecto.UUID.dump(uuid)

    query_results =
      {[
         [1, uuid_binary, <<"alpha", 0, 1, 2>>],
         %{"public_id" => uuid_binary, "payload_blob" => <<1, 2, 3>>}
       ], ["id", "public_id", "payload_blob"], ["id", "public_id", "payload_blob"]}

    assert {rows, ["id", "public_id", "payload_blob"], ["id", "public_id", "payload_blob"]} =
             QueryResults.normalize_query_results(query_results)

    assert Enum.at(rows, 0) == [1, uuid, "\\x616c706861000102"]
    assert Enum.at(rows, 1) == %{"payload_blob" => "\\x010203", "public_id" => uuid}
  end

  test "preserves decimal structs while normalizing unsafe binaries" do
    uuid = "7ebf047b-f57f-4171-9858-05b68a324629"
    {:ok, uuid_binary} = Ecto.UUID.dump(uuid)
    decimal = D.new("145.50")

    assert {[["Alpha Launch", ^decimal, ^uuid]], _, _} =
             QueryResults.normalize_query_results(
               {[["Alpha Launch", decimal, uuid_binary]], ["name", "cost", "public_id"],
                ["name", "cost", "public_id"]}
             )
  end

  test "does not reinterpret already-normalized hex strings as uuids" do
    assert {[["\\x62657461030405"]], ["payload_blob"], ["payload_blob"]} =
             QueryResults.normalize_query_results(
               {[["\\x62657461030405"]], ["payload_blob"], ["payload_blob"]}
             )
  end
end
