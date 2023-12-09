defmodule SuperCollider.Message.Done do
    @moduledoc """
    An asynchronous message has completed.

    This message sent in response to all asynchronous commands. 

    Note that the reply to a `:notify` command although is technically a 'Done' reply, is returned via the `SuperCollider.Message.Notify` struct instead.
    """

    defstruct [
        :command,
        :other
    ]

    @doc """
    Parses OSC arguments in the following order:
    1. `command:` the name of the command (string)
    2. `other:` (optional) some commands provide other information, for example a buffer index.
    """
    def parse(res_data) do
        response_labels = [
            :command,
            :other
          ]
        struct(__MODULE__, Enum.zip(response_labels, res_data))
    end

end