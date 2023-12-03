defmodule SuperCollider.Message.Node do
    @moduledoc """
    A node message from the server.

    This is usually only returned from the server if you've registered to receive notifications from server via the `:notify` command.
    """

    defstruct [
        :message,
        :id,
        :parent_id,
        :previous_node_id,
        :next_node_id,
        :node_type,
        :head_node_id,
        :tail_node_id,
    ]

    @doc """
    Parses OSC arguments in the following order:
    1. id: the ID of the node
    2. parent_id: the node's parent group ID
    3. previous_node_id: previous node ID, -1 if no previous node.
    4. next_node_id: next node ID, -1 if no next node.
    5. node_type: which will be represented as `:synth` or `:group` in the struct, or `:unknown` the type value is unrecognised

    Additionally, if the node type is a `:group`, the following two additional arguments will be parsed:
    6. head_node_id: the ID of the head node, -1 if there is no head node.
    7. tail_node_id: the ID of the tail node, -1 if there is no tail node.

    The message is added to the `:message` struct, which will be one of:
    - `"/n_go"`: A node was started. This command is sent to all registered clients when a node is created.
    - `"/n_end"`: A node ended. This command is sent to all registered clients when a node ends and is deallocated.
    - `"/n_off"`: A node was turned off. This command is sent to all registered clients when a node is turned off.
    - `"/n_on"`: A node was turned on. This command is sent to all registered clients when a node is turned on.
    - `"/n_move"`: A node was moved. This command is sent to all registered clients when a node is moved.
    - `"/n_info"`: Reply to /n_query. This command is sent to all registered clients in response to an /n_query command.

    ## Example messages
    ```
    %SuperCollider.Message.Node{message: "/n_on", id: 0, parent_id: -1, previous_node_id: -1, next_node_id: -1, node_type: :group, head_node_id: 440, tail_node_id: 440}
    
    %SuperCollider.Message.Node{message: "/n_off", id: 0, parent_id: -1, previous_node_id: -1, next_node_id: -1, node_type: :group, head_node_id: 440, tail_node_id: 440}
    ```
    """
    def parse(address, res_data) do
        response_labels = [
            :id,
            :parent_id,
            :previous_node_id,
            :next_node_id,
            :node_type,
            :head_node_id,
            :tail_node_id,
        ]

        struct(__MODULE__, Enum.zip(response_labels, res_data))
        |> set_node_type()
        |> set_message(address)
    end

    defp set_node_type(populated_struct) when populated_struct.node_type ==0, do: %{populated_struct | node_type: :synth}
    defp set_node_type(populated_struct) when populated_struct.node_type ==1, do: %{populated_struct | node_type: :group}
    defp set_node_type(populated_struct), do: %{populated_struct | node_type: :unknown}

    defp set_message(populated_struct, address), do: %{populated_struct | message: address}
end