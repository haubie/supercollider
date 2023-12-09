defmodule SuperCollider.Message.Trigger do
    @moduledoc """
    A trigger message.

    This command is the mechanism that synths can use to trigger events in clients.

    The server sends the trigger notification to all clients who have registered via the `:notify` command.
    """
 
    defstruct [
        :node_id,
        :trigger_id,
        :value
    ]

    @doc """
    Parses OSC arguments in the following order:
    1. `node_id:` (Integer) The node ID is the node that is sending the trigger.
    2. `trigger_id:` (Integer) The trigger ID is determined by inputs to the SendTrig unit generator which is the originator of this message.
    3. `value:` (Float) The trigger value is determined by inputs to the SendTrig unit generator which is the originator of this message.
    """
    def parse(res_data) do
        response_labels = [
            :node_id,
            :trigger_id,
            :value
          ]
        struct(__MODULE__, Enum.zip(response_labels, res_data))
    end

end