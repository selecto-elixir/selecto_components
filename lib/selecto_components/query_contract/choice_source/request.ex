defmodule SelectoComponents.QueryContract.ChoiceSource.Request do
  @moduledoc """
  Transport-neutral HTTP request for query-contract choice-source links.

  `SelectoComponents` does not prescribe an HTTP client. Host applications can
  turn this struct into a `Req`, `Finch`, browser hook, or test transport call.
  """

  @enforce_keys [:method, :url, :operation, :choice_source]
  defstruct method: :get,
            url: nil,
            operation: nil,
            choice_source: nil,
            headers: [],
            body: nil,
            metadata: %{}

  @type method :: :get | :post
  @type operation :: :options | :validate

  @type t :: %__MODULE__{
          method: method(),
          url: String.t(),
          operation: operation(),
          choice_source: String.t(),
          headers: [{String.t(), String.t()}],
          body: map() | nil,
          metadata: map()
        }
end
