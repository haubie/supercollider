defmodule SuperCollider.SoundServer do
  use GenServer

  @scsynth_binary_location "/Applications/SuperCollider.app/Contents/Resources/scsynth"
  @supernova_binary_location "/Applications/SuperCollider.app/Contents/Resources/supernova"

  @moduledoc """
  This module is a:
  - GenServer which is used to communicate with SuperCollider's scserver
  - Struct which holds the server's basic state and configuration.
  """

  alias SuperCollider.SoundServer.Command, as: Command
  alias SuperCollider.SoundServer.Response, as: Response

  # Struct definitions

  @doc """
  The SoundServer struct colds the servers basic state:
  - ip: the IP address of scserver. This defaults to '127.0.0.1'
  - hostname: the hostname of the server. This defaults to 'localhost'.
  - port: the port used to communicate with scserver. This defaults to 57110.
  - socket: the UDP socket used to communicate with scserver, once the connection is open.
  """
  defstruct ip: '127.0.0.1',
            hostname: 'localhost',
            port: 57110,
            socket: nil

  # Genserver callbacks

  @impl true
  def init(soundserver \\ %__MODULE__{}) do
    IO.inspect(soundserver, label: "INIT")
    new_state = run(soundserver)
    {:ok, new_state}
  end

  # Genserver handlers

  # @impl true
  # def handle_call(:pop, _from, [head | tail]) do
  #   {:reply, head, tail}
  # end

  @impl true
  def handle_cast({:command, command_name, args}, state) do
    new_state = apply(Command, command_name, [state] ++ args)
    {:noreply, new_state}
  end

  # def command(pid, command_name, args) when not is_list(args) do
  #   GenServer.cast(pid, {:command, command_name, [args]})
  # end

  def command(pid, command_name) do
    GenServer.cast(pid, {:command, command_name, []})
  end

  def command(pid, command_name, args) when is_list(args) do
    GenServer.cast(pid, {:command, command_name, args})
  end

  def command(pid, command_name, args) do
    GenServer.cast(pid, {:command, command_name, [args]})
  end

  @impl true
  def handle_cast(:run, state) do
    new_state = run(state)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:quit, state) do
    new_state = Command.quit(state)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:tone, state) do
    new_state = Command.tone(state)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:synth, attr}, state) do
    new_state = Command.synth(state, attr)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:free_node, state) do
    new_state = Command.free_node(state, 100)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:status, state) do
    new_state = Command.status(state)
    {:noreply, new_state}
  end

  @doc """
  When sending calls to scserver though UDP, a response message may be returned in the following format:

  `{:udp, process_port, ip_addr, port_num, osc_response}`

  The `handle_info/2` callback will forward these messages to `Response.process_osc_message/2` for handling.
  The handler code must return the updated SoundServer struct for a valid state to be maintained.
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
  def run(sserver \\ %__MODULE__{}) do
    with {:ok, socket} <- open(),
         :ok <- maybe_boot_scsynth(%{sserver | socket: socket}) do
      %__MODULE__{sserver | socket: socket}
    else
      _any -> {:error, "Could not be initialised"}
    end
  end

  @doc """
  Checks if scsynth is loaded by calling `scsynth_booted?/1`. If not it will attempt to boot it asynchronously using `Task.async/1`.

  TODO: The location of the scysnth binary is currently set in the `@scsynth_binary_location` but this will need to be moved out into a config or using different search strategies for different OSes.

  """
  def maybe_boot_scsynth(soundserver) do
    IO.puts("scsynth - maybe boot, waiting up to 5 seconds to see if loaded")

    if !scsynth_booted?(soundserver) do
      IO.inspect("scynth - attempting boot up")

      boot_cmd = fn ->
        System.cmd(@scsynth_binary_location, ["-u", Integer.to_string(soundserver.port)])
      end

      Task.async(boot_cmd)

      :ok
    else
      :ok
    end
  end

  @doc """
  Checks if scsynth is booted.

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
        IO.puts("scsynth - already booted")
        true

      msg ->
        IO.inspect(msg, label: "scsynth - Non matching UDP message - probably not booted?")
        false
    after
      5_000 ->
        IO.puts("scsynth - nothing booted after 5 seconds. Try booting scsynth manually.")
        false
    end
  end
end
