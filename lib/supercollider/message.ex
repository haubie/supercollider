defmodule SuperCollider.Message do
  @moduledoc """
  Structs that represent different replies from the SuperCollider server.

  The following message structs have been implemented:
  - `SuperCollider.Message.Error`: A error message from the server.
  - `SuperCollider.Message.Node`: A node message from the server.
  - `SuperCollider.Message.Notify`: A notify confirmation message.
  - `SuperCollider.Message.Done`: An asynchronous message has completed.
  - `SuperCollider.Message.QueryTree`: A representation of a group's node subtree.
  - `SuperCollider.Message.Sync`:  A sync message from the server.
  - `SuperCollider.Message.Late`:  A command was received too late.
  - `SuperCollider.Message.Trigger`: A trigger message.
  - `SuperCollider.Message.Version`: A version message.
  - `SuperCollider.Message.Status`: A status message.
  """
end