defmodule SuperCollider.Message do
  @moduledoc """
  Structs that represent different replies from the SuperCollider server.

  Currently the following message structs have been implemented:
  - `SuperCollider.Message.Error`: A error message from the server.
  - `SuperCollider.Message.Node`: A node message from the server.
  - `SuperCollider.Message.Notify`: A notify confirmation message.
  - `SuperCollider.Message.QueryTree`: A representation of a group's node subtree.
  """
end
