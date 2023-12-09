defmodule SuperCollider.Message.Sync do
    @moduledoc """
    A sync message from the server.

    Replies when all asynchronous commands received before this one have completed.
    
    The reply will contain the sent unique ID.

    The timestamp of when this message was received is added to the `:timestamp` field.
    """

    defstruct [
        :id,
        :timestamp
    ]

    @doc """
    Parses OSC arguments in the following order:
    1. `id:` the ID argument provided when calling the `:sync` command.

    To the `:timestamp` key, the `DateTime.utc_now/0` the message was received is added.
    """
    def parse([id | _rest]=_res_data) do
       %__MODULE__{id: id, timestamp: DateTime.utc_now()}
    end

end