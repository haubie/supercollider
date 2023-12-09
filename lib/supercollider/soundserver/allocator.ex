defmodule SuperCollider.SoundServer.Allocator do
    @moduledoc """
    An agent used for allocating and maintaining valid IDs for nodes on the server.

    # Named IDs
    Additionally, this library supports 'named' IDs, that is, using Elixir strings or atoms to represent a node id.
    This module translates the names (string or atom) to a node number on the SuperCollider server, and vice-versa.

    # Node ID allocation method
    This module is largely a port of NodeIDAllocator from SuperCollider. The Python [Supriya library](https://github.com/josiah-wolf-oberholtzer/supriya/) was also used as a reference.

    # More information
    The following served as references for the design of this module: 
    - [Multi client setups](https://doc.sccode.org/Guides/MultiClient_Setups.html)
    - [ReadableNodeIDAllocator](https://doc.sccode.org/Classes/ReadableNodeIDAllocator.html)
    - [NodeIDAllocator in Engine.sc](https://github.com/supercollider/supercollider/blob/2db872ad2a42ff85726566149855ecdb60d65b77/SCClassLibrary/Common/Control/Engine.sc#L4)
    - [Supriya (Python-based) allocators](https://github.com/josiah-wolf-oberholtzer/supriya/blob/abafd35490565327e2cd6afff81e6a2cd9dc59d6/supriya/contexts/allocators.py#L264)
    """

    use Agent
    alias SuperCollider.SoundServer.Allocator

    @id_offset (2 ** 26) 

    defstruct [
        initial_node_id: 1000,
        client_id: 0,
        mask: Bitwise.bsl(0, 26),
        temp: 1000,
        next_permanent_id: 1,
        freed_permanent_ids: MapSet.new()
    ]

    @doc """
    Resets the allocator to the defaults.

    Values that were initially provided to `start_link/1` or `new/1` will also need to provided as options.
    """
    def reset(allocator, opts \\ []) do
        Agent.update(allocator, fn _ -> new(opts) end)
    end

    @doc """
    Creates a new Allocator struct and assigns any values passed to it as options.
    """
    def new(opts \\ []) do
        client_id = Keyword.get(opts, :client_id, 0)
        initial_node_id = Keyword.get(opts, :initial_node_id, 1000)

        if (client_id > 31), do: raise "Node ID allocator error: client_id cannot be > 31. Given a client_id of #{inspect(client_id)}."

        %__MODULE__{
            initial_node_id: initial_node_id,
            client_id: client_id,
            mask: mask(client_id),
            temp: initial_node_id,
            next_permanent_id: 1,
            freed_permanent_ids: MapSet.new()
        }
    end

    @doc """
    Starts a new Allocator.

    Optionally takes a keyword list of values to populate the initial state.
    """
    def start_link(opts \\ []) do
        Agent.start_link(fn -> new(opts) end)
    end

    @doc """
    Returns the state of the allocator agent.
    """
    def state(allocator), do: Agent.get(allocator, & &1)

    @doc """
    Returns the next node
    """
    def next_node_id(allocator) do
        allocator
    end

    @doc """
    Allocates a temporary node id.
    """
    def allocate_node(allocator, count \\ 1) do
        state = Allocator.state(allocator)

        x = state.temp 
        temp = x + count

        temp = if (@id_offset-1 < temp),
            do: wrap(temp, state.initial_node_id),
            else: temp 
        
        Agent.update(allocator, &Map.put(&1, :temp, temp))

        Bitwise.bor(x, state.mask)
    end

    @doc """
    Allocates a permanent node id.
    """
    def allocate_permanent_node(allocator) do
        state = Allocator.state(allocator)
        x =
            if MapSet.size(state.freed_permanent_ids) != 0 do
                # Get the lowest number from the freed_permanent_ids and remove it from the state
                x = Enum.min(state.freed_permanent_ids)
                Agent.update(allocator, &Map.put(&1, :freed_permanent_ids, MapSet.delete(state.freed_permanent_ids, x)))
                x
            else
                x = state.next_permanent_id
                Agent.update(allocator, &Map.put(&1, :next_permanent_id, min(x+1, state.initial_node_id-1)))
                x
            end

        Bitwise.bor(x, state.mask)
    end

    @doc """
    Frees a permanent node id.

    The freed ids are reallocated when the allocate_permanent_node/1 is called.
    """
    def free_permanent_node(allocator, node_id) do
        state = Allocator.state(allocator)
        node_id = Bitwise.band(node_id, @id_offset-1)

        if (node_id < state.initial_node_id),
            do: Agent.update(allocator, &Map.put(&1, :freed_permanent_ids, MapSet.put(state.freed_permanent_ids, node_id)))
    end

    ## Helper functions

    defp id_offset(client_id), do: @id_offset * client_id
    defp default_group(client_id), do: id_offset(client_id) + 1
    defp mask(client_id), do: Bitwise.bsl(client_id, 26)
    defp wrap(value_1, value_2), do: Integer.mod(value_1, @id_offset-1) + value_2

end