defmodule SuperCollider.SoundServer do
  use GenServer
  require Logger

  @server_type [
    scsynth: "/Applications/SuperCollider.app/Contents/Resources/scsynth",
    supernova: "/Applications/SuperCollider.app/Contents/Resources/supernova"
  ]

  @moduledoc """
  This module is a:
  - GenServer which is used to communicate with SuperCollider's scserver or supernova
  - Struct which holds the server's basic state and configuration.

  ## Basic configuration
  Buy default, it looks for scynth at 127.0.0.1 or localhost on port 57110.

  ## Starting a server
  ```
  alias SuperCollider.SoundServer
  {:ok, pid} = GenServer.start_link(SoundServer, SoundServer.new(opts))
  ``

  ## Requesting the server's status
  ```
  SoundServer.command(pid, :status)

  # If scynth returned an OSC status response message, you can access it by fetching the SoundServer's state, accessing the responses map and status key:

  SoundServer.state(pid).responses[:status]

  # Returns:
  # [
  #   {"unused", 1},
  #   {"number of unit generators", 0},
  #   {"number of synths", 0},
  #   {"number of groups", 2},
  #   {"number of loaded synth definitions", 109},
  #   {"average percent CPU usage for signal processing", 0.026054037734866142},
  #   {"peak percent CPU usage for signal processing", 0.07464269548654556},
  #   {"nominal sample rate", 44100.0},
  #   {"actual sample rate", 44099.97125381111}
  # ]
  ```

  ## Play a sine wave UGen
  ```
  # Play a sine wave UGen on node 600, with a frequency of 300
  SoundServer.command(pid, :s_new, ["sine", 600, 1, 1, ["freq", 300]])

  # Stop the sine wave by freeing node 600
  SoundServer.command(pid, :n_free, 600)
  ```
  """

  alias SuperCollider.SoundServer
  alias SuperCollider.SoundServer.Command, as: Command
  alias SuperCollider.SoundServer.Response, as: Response

  # Struct definitions

  @doc """
  The SoundServer struct colds the servers basic state:
  - ip: the IP address of scserver. This defaults to '127.0.0.1'
  - hostname: the hostname of the server. This defaults to 'localhost'.
  - port: the port used to communicate with scserver. This defaults to 57110.
  - socket: the UDP socket used to communicate with scserver, once the connection is open.
  - type: which SuperCollider server is being used, accepts :scsynth (default) or :supernova (multicore)
  """
  defstruct ip: '127.0.0.1',
            hostname: 'localhost',
            port: 57110,
            socket: nil,
            type: :scsynth,
            responses: %{}

  # Genserver callbacks

  @doc """
  The init callback accepts `%SoundServer{}` struct holding the initial configuration and state. If none is provided, defaults are used.

  Calls the `run/1` function which will check if SuperCollider is loaded and start OSC communication.

  See the `run/1` function for more details
  """
  @impl true
  def init(soundserver \\ %__MODULE__{}) do
    IO.inspect(soundserver, label: "INIT")
    new_state = run(soundserver)
    {:ok, new_state}
  end

  @doc """
  Starts the `SuperCollider.SoundServer` GenServer.

  You can override the default configuration by passing a keyword list with the new values. Currently the following can be set:
    - ip: the IP address of scserver. This defaults to '127.0.0.1'
    - hostname: the hostname of the server. This defaults to 'localhost'.
    - port: the port used to communicate with scserver. This defaults to 57110.
    - socket: the UDP socket used to communicate with scserver, once the connection is open.

  ## Example
  ```
  # Start SoundServer with default configuration
  {:ok, pid} = SuperCollider.SoundServer.start_link()

  # Start SoundServer specifying scynth's port to 57000
  {:ok, pid} = SuperCollider.SoundServer.start_link(port: 57000)
  ```
  """
  def start_link(opts \\ []) do
    GenServer.start_link(SoundServer, SoundServer.new(opts))
  end

  @impl true
  def handle_call(:state, _from, state) do
    {:reply, state, state}
  end

  @doc """
  Returns the current state of the server.

  For example, calling `SuperCollider.SoundServer.state(pid)` will return the populated state struct, which includes configuration and any scynth OSC message responses stored in the reponses key:

  ```
  %SuperCollider.SoundServer{
    ip: '127.0.0.1',
    hostname: 'localhost',
    port: 57110,
    socket: #Port<0.7>,
    responses: %{
      fail: ["/n_free", "Node 100 not found"],
      status: [
        {"unused", 1},
        {"number of unit generators", 0},
        {"number of synths", 0},
        {"number of groups", 2},
        {"number of loaded synth definitions", 109},
        {"average percent CPU usage for signal processing", 0.026054037734866142},
        {"peak percent CPU usage for signal processing", 0.07464269548654556},
        {"nominal sample rate", 44100.0},
        {"actual sample rate", 44099.97125381111}
      ],
      version: [
        {"Program name. May be \"scsynth\" or \"supernova\".", "scsynth"},
        {"Major version number. Equivalent to sclang's Main.scVersionMajor.", 3},
        {"Minor version number. Equivalent to sclang's Main.scVersionMinor.", 13},
        {"Patch version name. Equivalent to the sclang code \".\" ++ Main.scVersionPatch ++ Main.scVersionTweak.",
        ".0"},
        {"Git branch name.", "Version-3.13.0"},
        {"First seven hex digits of the commit hash.", "3188503"}
      ]
    }
  }
  ```
  """
  def state(pid) do
    GenServer.call(pid, :state)
  end


  @impl true
  def handle_cast({:command, command_name, args}, state) do
    new_state = apply(Command, command_name, [state] ++ args)
    {:noreply, new_state}
  end

  @doc """
  Sends an OSC command to SuperCollider (scynth or supernova).

  `SuperCollider.SoundServer.command(pid, :version)` will sendthe OSC 'version' command.

  Optionally accepts arguments, depending on the command being called.

  Commands must be a valid commmand (function in the SuperCollider.SoundServer.Command module) and match it's arity, otherwise an {:error, reason} tuple ie returned.
  """
  def command(pid, command_name) do
     if is_valid_command?(command_name) do
      GenServer.cast(pid, {:command, command_name, []})
    else
      {:error, "Invalid SuperCollider command or arity."}
    end
  end

  def command(pid, command_name, args) when is_list(args) do
    if is_valid_command?(command_name, args) do
      GenServer.cast(pid, {:command, command_name, args})
    else
      {:error, "Invalid SuperCollider command or arity."}
    end

  end

  def command(pid, command_name, args) do
    if is_valid_command?(command_name, args)  do
      GenServer.cast(pid, {:command, command_name, [args]})
    else
      {:error, "Invalid SuperCollider command or arity."}
    end
  end

  # is_valid_command? checks to see if the command is a function in the SuperCollider.SoundServer.Command module
  # and if it has the appropriate arity when args are provided
  defp is_valid_command?(command_name), do: :erlang.function_exported(SuperCollider.SoundServer.Command, command_name, 1)
  defp is_valid_command?(command_name, args) when is_list(args), do: :erlang.function_exported(SuperCollider.SoundServer.Command, command_name, length(args)+1)
  defp is_valid_command?(command_name, _args), do: :erlang.function_exported(SuperCollider.SoundServer.Command, command_name, 2)


  @doc """
  When sending calls to scserver though UDP, a response message may be returned in the following format:

  `{:udp, process_port, ip_addr, port_num, osc_response}`

  The `handle_info/2` callback will forward these messages to `Response.process_osc_message/2` for handling.
  The handler code must return the updated SoundServer struct for a valid state to be maintained.

  To get the messages, use `SuperCollider.response()`.
  """
  @impl true
  def handle_info(msg, state) do
    new_state =
      case msg do
        {:udp, _process_port, _ip_addr, _port_num, res} ->
          Response.process_osc_message(state, res)

        _ ->
          state
      end

    {:noreply, new_state}
  end

  # Core
  @doc """
  A convience function to create a new SoundServer struct.

  The struct holds the basic state and configuration.

  The default values can be overrided by providing a keyword list using the same keys used in the struct. For example:

    ```
    SoundServer.new(hostname: 'othersoundserver')
    ```

    will override the default hostname of 'localhost'.

  For more information, see the SoundServer struct documentation.
  """
  def new(opts \\ []), do: struct(__MODULE__, opts)

  @doc """
  Open's a UDP connection. Unless a port number is provided, by default it will use port 0.

  Uses :gen_udp.open from Erlang which associates a UDP port number with the calling process (this GenServer).
  """
  def open(port_num \\ 0), do: :gen_udp.open(port_num, [:binary, {:active, true}])

  @doc """
  Runs the server. By default, this function is executed when init is called.

  This function:
  - checks if server is loaded, otherwise attempts to boot it
  - opens a USP socket for Open Sound Communication (OSC) communication with the server.
  """
  def run(soundserver \\ %__MODULE__{}) do
    with {:ok, socket} <- open(),
         :ok <- maybe_boot_scsynth(%{soundserver | socket: socket}) do
      %__MODULE__{soundserver | socket: socket}
    else
      _any -> {:error, "Could not be initialised"}
    end
  end

  @doc """
  Checks if scsynth is loaded by calling `scsynth_booted?/1`. If not it will attempt to boot it asynchronously using `Task.async/1`.

  TODO: The location of the scysnth binary is currently set in the `@scsynth_binary_location` but this will need to be moved out into a config or using different search strategies for different OSes.

  """
  def maybe_boot_scsynth(soundserver) do
    Logger.info("#{soundserver.type} - waiting up to 5 seconds to see if already loaded ⏳")

    cmd = @server_type[soundserver.type]

    if !scsynth_booted?(soundserver) do
      Logger.info("#{soundserver.type} - attempting to start 🏁")

      boot_cmd = fn ->
        System.cmd(cmd, ["-u", Integer.to_string(soundserver.port)])
      end

      Task.async(boot_cmd)

      :ok
    else
      :ok
    end
  end

  @doc """
  Checks if scsynth or supernova is booted.

  It does this by sending the OSC command '/status' through the previously opened UDP port to the address that scsynth is expected.

  It then waits up to 5 seconds to see if a UDP packet is returned.

  This function returns:
  - `true` if if a '/status.reply' message was recieved via UDP.
  - `false` if either a non-compliant message is recieved or no message is recieved after 5 seconds. In this case the scsynth has been considered not to be loaded.

  """
  def scsynth_booted?(soundserver) do
    Command.send_osc(soundserver, "/status")

    receive do
      {:udp, _process_port, _ip_addr, _port_num, data} ->
        packet = data |> OSC.decode!()
        %{address: "/status.reply", arguments: _arguments} = packet.contents |> List.first()
        Logger.info("#{soundserver.type} - already booted ✅")
        true

      msg ->
        Logger.info("#{soundserver.type} - non-matching UDP message, #{soundserver.type} is probably not booted. \nOSC message recieved: (#{inspect(msg)})")
        false
    after
      5_000 ->
        Logger.info("#{soundserver.type} - no response, #{soundserver.type} likely not booted.")
        false
    end
  end
end