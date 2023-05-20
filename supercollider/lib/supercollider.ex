defmodule SuperCollider do
  @moduledoc """
  Documentation for `SuperCollider`.
  """

  alias SuperCollider.SoundServer


  @doc """
  Starts the `SuperCollider.SoundServer` GenServer and returns it's pid.

  The pid for the `SuperCollider.SoundServer` is also stored as a persisitient term under `:supercollider_soundserver`. This is used by the `SuperCollider.state/0`, `SuperCollider.response/0`, `SuperCollider.response/1`, `SuperCollider.command/1` and `SuperCollider.command/2` functions so that they're passed the global SoundServer pid without having to specify it.

  If you want to directly interact with a SoundServer through it's pid, see the equivalent functions under `SuperCollider.SoundServer`.
  """
  def start(opts \\ []) do
    {:ok, pid} = GenServer.start_link(SoundServer, SoundServer.new(opts))
    :persistent_term.put(:supercollider_soundserver, pid)
    pid
  end


  @doc """
  Get's the state of the global SoundServer. It also accepts as it's first parameter, an optional pid for any active SoundServer processed.
  """
  def state(pid \\ nil) do
    case get_pid(pid) do
      {:ok, pid} -> SoundServer.state(pid)
      {:error, msg} -> {:error, msg}
    end
  end

  @doc """
  Get's any OSC responses stored in the state of the `SoundServer`.

  Responses are stored in a Map. If there are no responses stored, an empty map is returned, e.g. `%{}`.
  """
  def response() do
    case :persistent_term.get(:supercollider_soundserver, nil) do
      nil -> {:error, "Global SuperCollider.SoundServer pid not stored as a persistient term under :supercollider_soundserver"}
      pid ->
        SoundServer.state(pid)
        |> Map.get(:responses)
    end
  end

  @doc """
  Get's a specific OSC response stored in the state of the server, by it's key. If no response is available for the specific key, `nil` is returned.

  The following are currently stored responses:
  * :version - the version information from a `SuperCollider.command(:version)` call
  * :status - the last status message stored from a `SuperCollider.command(:status)` call
  * :fail - the last fail message from a `SuperCollider.command(...)` call

  ## Example
  For example, if a version request was made:

  ```
  SuperCollider.command :version
  ```

  To get the response held by the `SuperCollider.SoundServer` you'd call:

  ```
  SuperCollider.response(:version)
  ```

  This would return the version response in the following format:

  ```
  [
    {"Program name. May be \"scsynth\" or \"supernova\".", "scsynth"},
    {"Major version number. Equivalent to sclang's Main.scVersionMajor.", 3},
    {"Minor version number. Equivalent to sclang's Main.scVersionMinor.", 13},
    {"Patch version name. Equivalent to the sclang code \".\" ++ Main.scVersionPatch ++ Main.scVersionTweak.",
     ".0"},
    {"Git branch name.", "Version-3.13.0"},
    {"First seven hex digits of the commit hash.", "3188503"}
  ]
  ```
  """
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

  @doc """
  Send a command to the default SoundServer.

  This function accepts the following parameters:
  * command, in a form of an atom representing SuperCollider commands (See: `SuperCollider.SoundServer.Command` for details)
  * args, which is optional and needed only for commands which take them. Multiple options can be provided as a list.

  ## Examples
  ```
  # Get the server's status
  SuperCollider.command(:status) # Make the call
  SuperCollider.response(:status) # Get the status response data
  ```
  """
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
