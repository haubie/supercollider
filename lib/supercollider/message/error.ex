defmodule SuperCollider.Message.Error do
    @moduledoc """
    A error message from the server.

    """

    defstruct [
        :command,
        :message,
        :other
    ]

    @doc """
    Parses OSC arguments in the following order:
    1. `command:` the name of the command,
    2. `message:` the error message (string),
    3. `other:` (optional) some commands provide other information, for example a buffer index.
    """
    def parse(res_data) do
        response_labels = [
            :command,
            :message,
            :other
          ]
        struct(__MODULE__, Enum.zip(response_labels, res_data))
    end

end