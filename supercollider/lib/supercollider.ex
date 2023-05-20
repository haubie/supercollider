defmodule SuperCollider do
  @moduledoc """
  Documentation for `SuperCollider`.
  """

  alias SuperCollider.SoundServer

  def start(opts \\ []) do
    {:ok, pid} = GenServer.start_link(SoundServer, SoundServer.new(opts))
    :persistent_term.put(:supercollider_soundserver, pid)
    pid
  end

  def state(pid \\ nil) do
    case get_pid(pid) do
      {:ok, pid} -> SoundServer.state(pid)
      {:error, msg} -> {:error, msg}
    end
  end

  def response() do
    case :persistent_term.get(:supercollider_soundserver, nil) do
      nil -> {:error, "Global SuperCollider.SoundServer pid not stored as a persistient term under :supercollider_soundserver"}
      pid ->
        SoundServer.state(pid)
        |> Map.get(:responses)
    end
  end
  def response(key) do
    case :persistent_term.get(:supercollider_soundserver, nil) do
      nil -> {:error, "Global SuperCollider.SoundServer pid not stored as a persistient term under :supercollider_soundserver"}
      pid ->
        SoundServer.state(pid)
        |> Map.get(:responses)
        |> Map.get(key, nil)
    end
  end

  defp get_pid(pid) do
    global_sound_server = :persistent_term.get(:supercollider_soundserver, nil)
    cond do
      pid != nil -> {:ok, pid}
      global_sound_server != nil -> {:ok, global_sound_server}
      true -> {:error, "SuperCollider.SoundServer pid not given or a global pid not stored as a persistient term under :supercollider_soundserver"}
    end
  end

  def command(command_name) do
    case :persistent_term.get(:supercollider_soundserver, nil) do
      nil -> {:error, "Global SuperCollider.SoundServer pid not stored as a persistient term under :supercollider_soundserver"}
      pid -> SoundServer.command(pid, command_name)
    end
  end

  def command(command_name, args) do
    case :persistent_term.get(:supercollider_soundserver, nil) do
      nil -> {:error, "Global SuperCollider.SoundServer pid not stored as a persistient term under :supercollider_soundserver"}
      pid -> SoundServer.command(pid, args, command_name)
    end
  end



end
