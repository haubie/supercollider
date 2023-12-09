defmodule SuperCollider.SoundServer.Allocator do
    @moduledoc """
    An agent used for allocating and maintaining valid IDs for nodes on the server.

    # Named IDs
    Additionally, this library supports 'named' IDs, that is, using Elixir strings or atoms to represent a node id.
    This module translates the names (string or atom) to a node number on the SuperCollider server, and vice-versa.

    # Node ID allocation

    NodeIDAllocator uses a fixed binary prefix of (2 ** 26) * clientID:

    # References
    The following served as references for the design of this module: 
    - [Multi client setups](https://doc.sccode.org/Guides/MultiClient_Setups.html)
    - [ReadableNodeIDAllocator](https://doc.sccode.org/Classes/ReadableNodeIDAllocator.html)
    - [NodeIDAllocator in Engine.sc](https://github.com/supercollider/supercollider/blob/2db872ad2a42ff85726566149855ecdb60d65b77/SCClassLibrary/Common/Control/Engine.sc#L4)
    - [Supriya (Python-based) allocators](https://github.com/josiah-wolf-oberholtzer/supriya/blob/abafd35490565327e2cd6afff81e6a2cd9dc59d6/supriya/contexts/allocators.py#L264)
    """

    use Agent

    @num_ids 0x04000000 

    defstruct [
        initial_node_id: 1000,
        client_id: 0,
        next_permanent_id: 1,
        freed_permanent_ids: MapSet.new()
    ]

    @doc """
    Creates a new Allocator struct and assigns any values passed to it as options.
    """
    def new(opts \\ []) do
        struct(__MODULE__, opts)
    end

    @doc """
    Starts a new Allocator.

    Optionally takes a keyword list of values to populate the initial state.
    """
    def start_link(opts \\ []) do
        Agent.start_link(fn -> new(opts) end)
    end


    @doc """
    
    """
    def next_node_id() do
    end


    # @doc """
    # Gets a value from the `bucket` by `key`.
    # """
    # def get(bucket, key) do
    #     Agent.get(bucket, &Map.get(&1, key))
    # end

    # @doc """
    # Puts the `value` for the given `key` in the `bucket`.
    # """
    # def put(bucket, key, value) do
    #     Agent.update(bucket, &Map.put(&1, key, value))
    # end





    # def allocate_permanent_node_id(allocator) do
    #     if MapSet.size(allocator.freed_permanent_ids) == 0 do
    #         x = Enum.min(allocator.freed_permanent_ids)
    #         MapSet.delete(allocator.freed_permanent_ids, x)
    #     else

    #     end

    # end

    # def allocate_permanent_node_id(self) -> int:
    #     with self._lock:
    #         if self._freed_permanent_ids:
    #             x = min(self._freed_permanent_ids)
    #             self._freed_permanent_ids.remove(x)
    #         else:
    #             x = self._next_permanent_id
    #             self._next_permanent_id = min(x + 1, self._initial_node_id - 1)
    #         x = x | self._mask
    #         return x







    # def allocate_node_id(self, count: int = 1) -> int:
    #     with self._lock:
    #         x = self._temp
    #         temp = x + count
    #         if 0x03FFFFFF < temp:
    #             temp = (temp % 0x03FFFFFF) + self._initial_node_id
    #         self._temp = temp
    #         x = x | self._mask
    #         return x

    # def allocate_permanent_node_id(self) -> int:
    #     with self._lock:
    #         if self._freed_permanent_ids:
    #             x = min(self._freed_permanent_ids)
    #             self._freed_permanent_ids.remove(x)
    #         else:
    #             x = self._next_permanent_id
    #             self._next_permanent_id = min(x + 1, self._initial_node_id - 1)
    #         x = x | self._mask
    #         return x

    # def free(self, node_id: int) -> None:
    #     if node_id < self._initial_node_id:
    #         self.free_permanent_node_id(node_id)

    # def free_permanent_node_id(self, node_id: int) -> None:
    #     with self._lock:
    #         node_id = node_id & 0x03FFFFFF
    #         if node_id < self._initial_node_id:
    #             self._freed_permanent_ids.add(node_id)





end