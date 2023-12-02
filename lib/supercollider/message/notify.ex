defmodule SuperCollider.Message.Notify do
    @moduledoc """
    Notify confirmation message.

    This message is the reply when you register to receive notifications from server.

    This is done by using the `:notify` command.
    """

    defstruct [
        :client_id,
        :max_logins
    ]

    @doc """
    Parses OSC arguments in the following order:
    1. `client_id:` the ID of the registered client. If this client has registered for notifications before, this may be the same ID. Otherwise it will be a new one. Clients can use this ID in multi-client situations to avoid conflicts when allocating resources such as node IDs, bus indices, and buffer numbers. 
    2. `max_logins:` the max_logins is only returned when the client ID argument is supplied in this command. max_logins is not supported by supernova.
    """
    def parse(res_data) do
        response_labels = [
            :client_id,
            :max_logins
          ]
        struct(__MODULE__, Enum.zip(response_labels, res_data))
    end

end