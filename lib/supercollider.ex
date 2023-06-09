defmodule SuperCollider do
  @moduledoc """
  This is the main `SuperCollider` module.

  With this module, you can:
  * start a `SuperCollider.SoundServer`, which is a GenServer used to communicate with scynth and recieve messages from it.
  * issue commands
  * access SuperColliders state.

  This module aims to minimise the need to pass a pid around representing the active `SoundServer` by storing it's PID as a persisitient term under `:supercollider_soundserver`. Calling `SuperCollider.start()` will automatically store the pid of the SoundServer as a persistient term.

  ## Example
  ```
  alias SuperCollider, as :SC

  # Start the `SuperCollider.SoundServer` GenServer
  SC.start() # this will return the PID of the SoundServer, however, you don't have to assign this to a variable as its stored as a persistient term used by the other functions in this module.

  # Issue the verion command and get the response from SoundServer's state
  SC.command(:version) # send the version commant to SuperCollider
  SC.response(:version) # retrieves the version response from the SoundServer's state

  # Play a sine wave UGen on node 600, with a frequency of 300
  SC.command(:s_new, ["sine", 600, 1, 1, ["freq", 300]])

  # Stop the sine wave by freeing node 600
  SC.command(:n_free, 600)
  ```

  ## LiveBook tour
  You can explore this library further in the [LiveBook demo](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2Fhaubie%2Fsupercollider%2Fblob%2Fmain%2Flivebook%2Fsupercollider_tour.livemd).
  [![Run in Livebook](https://livebook.dev/badge/v1/blue.svg)](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2Fhaubie%2Fsupercollider%2Fblob%2Fmain%2Flivebook%2Fsupercollider_tour.livemd)
  """

  alias SuperCollider.SoundServer

  @doc """
  Starts the `SuperCollider.SoundServer` GenServer and returns it's pid.

  The pid for the `SuperCollider.SoundServer` is also stored as a persisitient term under `:supercollider_soundserver`. This is used by the `SuperCollider.state/0`, `SuperCollider.response/0`, `SuperCollider.response/1`, `SuperCollider.command/1` and `SuperCollider.command/2` functions so that they're passed the global SoundServer pid without having to specify it.

  If you want to directly interact with a SoundServer through it's pid, see the equivalent functions under `SuperCollider.SoundServer`, such as `{:ok, pid} = SuperCollider.SoundServer.start_link()` or through `{:ok, pid} = GenServer.start_link(SoundServer, SoundServer.new())`.

  ## Options
  Additionally, this function can take options:
  - ip: the IP address of scserver. This defaults to '127.0.0.1'
  - hostname: the hostname of the server. This defaults to 'localhost'.
  - port: the port used to communicate with scserver. This defaults to 57110.
  - socket: the UDP socket used to communicate with scserver, once the connection is open.
  - type: the server type being used, accepts :scsynth (default) or :supernova (multicore)

  Note if the hostname is set to `nil` it will try the IP address at `ip`.

  ## Examples
  Start SuperCollider with defaults
  ```
  SuperCollider.start()
  ```

  Start SuperCollider with a supernova server
  ```
  SuperCollider.start(type: :supernova)
  ```

  This function starts the `SuperCollider.SoundServer` GenServer which will check if SuperCollider has booted on your system. If not, it will currently attempt to start scynth or supernova at the following locations:

  - Mac: /Applications/SuperCollider.app/Contents/Resources/
  - Linux: /usr/local/
  - Windows: \\Program Files\\SuperCollider\\
  """
  def start(opts \\ []) do
    {:ok, pid} = GenServer.start_link(SoundServer, SoundServer.new(opts))
    :persistent_term.put(:supercollider_soundserver, pid)
    pid
  end

  @doc """
  Get's the state of the global SoundServer (whos PID is stored as a persisitient term under `:supercollider_soundserver`).

  ## Example
  ```
  SuperCollider.state()

  ## Returns the populated SoundServer struct
  # %SuperCollider.SoundServer{
  #   ip: '127.0.0.1',
  #   hostname: 'localhost',
  #   port: 57110,
  #   socket: #Port<0.12>,
  #   type: :supernova,
  #   responses: %{}
  # }
  ```
  """
  def state() do
    case :persistent_term.get(:supercollider_soundserver, nil) do
      nil -> {:error, "Global SuperCollider.SoundServer pid not stored as a persistient term under :supercollider_soundserver"}
      pid ->
        SoundServer.state(pid)
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
  SuperCollider.command(:version)
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


  @doc """
  Returns the PID of the SoundServer stored as a persistent_term as :supercollider_soundserver.
  """
  def pid, do: :persistent_term.get(:supercollider_soundserver, nil)

  @doc """
  Send a command to the default SoundServer.

  This function accepts the following parameters:
  * command, in a form of an atom representing SuperCollider commands (See: `SuperCollider.SoundServer.Command` for details)

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

  @doc """
  Send a command to the default SoundServer with arguments.

  This function accepts the following parameters:
  * command, in a form of an atom representing SuperCollider commands (See: `SuperCollider.SoundServer.Command` for details)
  * args, commands which take them. Multiple options can be provided as a list.

  ## Examples
  ```
  # Send a command to play a basic 300Hz sinusoidal sound on node 100
  SuperCollider.command(:s_new, ["sine", 100, 1, 1, ["freq", 300]])

  # Stop the sound by freeing node 100
  SuperCollider.command(:n_free, 100)
  ```
  """
  def command(command_name, args) do
    case :persistent_term.get(:supercollider_soundserver, nil) do
      nil -> {:error, "Global SuperCollider.SoundServer pid not stored as a persistient term under :supercollider_soundserver"}
      pid -> SoundServer.command(pid, command_name, args)
    end
  end

end
