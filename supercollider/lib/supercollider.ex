defmodule SuperCollider do
  @moduledoc """
  Documentation for `SuperCollider`.
  """

  alias Supercollider.SoundServer

  def start() do
    {:ok, pid} = GenServer.start_link(SoundServer, SoundServer.new())

    pid
  end

  defdelegate command(pid, command_name), to: SoundServer
  defdelegate command(pid, command_name, args), to: SoundServer
  defdelegate quit, to: SoundServer

end
