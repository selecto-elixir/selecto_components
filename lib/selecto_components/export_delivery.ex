defmodule SelectoComponents.ExportDelivery do
  @moduledoc """
  Behavior for delivering generated export payloads.

  Host applications own the actual delivery integration so they can plug in
  their mailer/provider of choice.
  """

  @typedoc "Normalized export payload ready for delivery"
  @type export_payload :: map()

  @typedoc "Normalized delivery configuration"
  @type delivery_config :: map()

  @callback deliver_email(export_payload(), delivery_config(), keyword()) ::
              {:ok, map()} | {:error, term()}
end
