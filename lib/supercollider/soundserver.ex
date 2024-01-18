defmodule SuperCollider.SoundServer do
  @moduledoc """
  GenServer for communicating with scserver or supernova.

  This module is a:
  - GenServer which is used to communicate with SuperCollider's scserver or supernova
  - Struct which holds the server's basic state and configuration.

  ## Main functions
  The main public functions are:
  - `start_link/1` to start the `SoundServer` GenServer
  - `command/2` or `command/3` for sending asynchronous commands to scsynth or supernova
  - `sync_command/2` or `sync_command/3` for sending commands to scsynth or supernova synchronously, waiting for a result to be returned
  - `state/1` to get the current state of the `SoundServer` GenServer.
  - `clear_responses/2` to clear values in the responses map (`%SoundServer{responses: %{...}}`). By default, clears the `:fail` messages.
  - `add_handler/2` to add one or more callback function(s) which will receive and handle SuperCollider response messages.

  ### Sync vs. async
  The difference between `sync_command/2` and `command/2` functions is that if you need to wait around for a response from a command or not. In most cases you'll probably just use the async `command/2` or `command/3`.

  Async commands can update the state and may add responses under the `:responses` key. These can be fetched via the `state/1` function. See `SuperCollider.SoundServer.Response` for details.

  ## Basic configuration
  By default, it looks for scynth at 127.0.0.1 or localhost on port 57110.

  ## Starting a server
  ```
  alias SuperCollider.SoundServer
  {:ok, pid} = SoundServer.start_link(opts)
  ```
  or
  ```
  alias SuperCollider.SoundServer
  {:ok, pid} = GenServer.start_link(SoundServer, SoundServer.new(opts))
  ```

  When SuperCollider.SoundServer starts, it goes through the following steps:
  1. Check if scsynth or supernova has already been loaded
  2. If not, attempt to boot it at some common file system locations
  3. Populate the `%SuperCollider.SoundServer{}` with:
      - scsynth or supernova's current status under the `:response` key
      - scsynth or supernova version information under the `:response` key
      - the client ID assigned by scsynth or supernova.

  ## Adding SoundServer to your supervision tree
  To add it to you applications supervision tree, see [Adding SoundServer to your application supervision tree](#start_link/1-adding-soundserver-to-your-application-supervision-tree).

  ## Requesting the server's status
  ```
  SoundServer.command(pid, :status)

  # If scynth returned an OSC status response message, you can access it by fetching the SoundServer's state, accessing the responses map and status key:

  iex> SoundServer.state(pid).responses[:status]

  # Returns:
  %SuperCollider.Message.Status{
    unused: 1,
    num_ugens: 4,
    num_synths: 1,
    num_groups: 1,
    num_synthdefs_loaded: 5,
    avg_cpu: 0.02616635337471962,
    peak_cpu: 0.10551269352436066,
    nominal_sample_rate: 44100.0,
    actual_sample_rate: 44100.01409481425
  }
  ```

  ## Play a sine wave UGen
  ### Async example (don't wait for a return message)
  ```
  # Play a sine wave UGen on node 600, with a frequency of 300
  SoundServer.command(pid, :s_new, ["sine", 600, 1, 0, ["freq", 300]])

  # Stop the sine wave by freeing node 600
  SoundServer.command(pid, :n_free, 600)
  ```
  ### Sync example (wait for a return message)
  ```
  # Play a sine wave UGen on node 600, with a frequency of 300
  iex> SoundServer.sync_command(pid, :s_new, ["sine", 600, 1, 0, ["freq", 300]])
  %SuperCollider.Message.Node{
    message: "/n_go",
    id: 600,
    parent_id: 0,
    previous_node_id: -1,
    next_node_id: -1,
    node_type: :synth,
    head_node_id: nil,
    tail_node_id: nil
  }

  # Stop the sine wave by freeing node 600
  iex> SoundServer.sync_command(pid, :n_free, 600)
  %SuperCollider.Message.Node{
    message: "/n_end",
    id: 600,
    parent_id: 0,
    previous_node_id: -1,
    next_node_id: -1,
    node_type: :synth,
    head_node_id: nil,
    tail_node_id: nil
  }
  ```
  """
  use GenServer
  require Logger

  @server_type [
    mac: [
      scsynth: "/Applications/SuperCollider.app/Contents/Resources/scsynth",
      supernova: "/Applications/SuperCollider.app/Contents/Resources/supernova"
    ],
    unix: [
      scsynth: "/usr/local/scsynth",
      supernova: "/usr/local/supernova"
    ],
    windows: [
      scsynth: "\\Program Files\\SuperCollider\\sclang.exe",
      supernova: "\\Program Files\\SuperCollider\\supernova.exe"
    ]
  ]

  alias SuperCollider.SoundServer
  alias SuperCollider.SoundServer.Command, as: Command
  alias SuperCollider.SoundServer.Response, as: Response

  # Struct definitions

  @doc """
  The SoundServer struct holds the servers basic state:
  - `host:` the IP address or hostname of scserver. This defaults to `'127.0.0.1'` but could also be set by name, such as `'localhost'`.
  - `port:` the port used to communicate with scserver. This defaults to 57110.
  - `socket:` the UDP socket used to communicate with scserver, once the connection is open.
  - `type:` which SuperCollider server is being used, accepts :scsynth (default) or :supernova (multicore)
  - `booted?`: this is set to `true` when scynth or supernova has been succesfully connected to when this GenServer started
  - `client_id`: the client id given to this GenServer process by the scynth or supernova.
  - `max_logins`: the maximum number of logins that scynth or supernova reported being able to handle.
  - `from`: holds the 'from' (the PID and reference id) when the `sync_command` function is called.
  - `callback`: holds a list of functions called when a SuperCollider resppnse message is received. The callback must be of single arity and take it's first parameter a message. See `add_handler/2` for an example.
  """
  defstruct host: '127.0.0.1',
            port: 57110,
            socket: nil,
            type: :scsynth,
            booted?: false,
            client_id: 0,
            max_logins: nil,
            responses: %{fail: []},
            from: nil,
            callback: []

  # Genserver callbacks

  @doc section: :impl
  @doc """
  The init callback accepts `%SoundServer{}` struct holding the initial configuration and state. If none is provided, defaults are used.

  Calls the `run/1` function which will check if SuperCollider is loaded and start OSC communication.

  See the `run/1` function for more details
  """
  @impl true
  def init(soundserver \\ %__MODULE__{}) do
    Logger.info("Initialising sound server with #{inspect(soundserver)}")
    case run(soundserver) do
      %{booted?: true}=new_state -> {:ok, new_state, {:continue, :get_client_id}}
      {:error, reason} -> {:error, reason}
    end
    
  end

  @doc section: :impl
  @doc """
  `:get_client_id` is called immediately after the SoundServer is initialised.
  
  After waiting 3 seconds, it sends a `:notify` command to scsynth or supernova which returns the client id of this instance of the GenServer. The version of scsynth or supernova is also requested and populated. 

  Even though scynth or supernova has loaded at this point, the 3 second delay is to ensure that it is ready to recieve the notify command and assign client ids.

  The client id is accessible via the `:client_id` key in this GenServer's state, e.g.:

  ```
  # Start three separate SoundServers
  iex> {:ok, server_one} = SuperCollider.SoundServer.start_link()
  iex> {:ok, server_two} = SuperCollider.SoundServer.start_link()
  iex> {:ok, server_three} = SuperCollider.SoundServer.start_link()

  # Get the client ID:
  iex> SuperCollider.SoundServer.state(server_one).client_id
  0

  iex> SuperCollider.SoundServer.state(server_two).client_id
  1

  iex> SuperCollider.SoundServer.state(server_three).client_id
  3
  ```
  """
  @impl true
  def handle_continue(:get_client_id, soundserver) do
    id = :erlang.unique_integer([:positive])
    Logger.info("Requesting client ID for SoundServer: #{inspect self()} with Sync ID #{id}")
    GenServer.cast(self(), {:command, :sync, [id]})
    :timer.sleep(3000)
    # The notify command returns the client id assigned by scsynth or supernova
    GenServer.cast(self(), {:command, :notify, []})
    # This will populate the state with the version of scsynth or supernova
    GenServer.cast(self(), {:command, :version, []})
    {:noreply, soundserver}
  end

  @doc section: :pub
  @doc """
  Starts the `SuperCollider.SoundServer` GenServer.

  You can override the default configuration by passing a keyword list with the new values. Currently the following can be set:
    - host: the IP address or hostname of scserver. This defaults to `'127.0.0.1'` but it could be set to a hostname such as `'localhost'`.
    - port: the port used to communicate with scserver. This defaults to 57110.
    - socket: the UDP socket used to communicate with scserver, once the connection is open.

  ## Example
  ```
  # Start SoundServer with default configuration
  {:ok, pid} = SuperCollider.SoundServer.start_link()

  # Start SoundServer specifying scynth's port to 57000
  {:ok, pid} = SuperCollider.SoundServer.start_link(port: 57000)
  ```

  ## Adding SoundServer to your application supervision tree
  If you're wanting to include the `SuperCollider.SoundServer` in the application supervision tree of your own project, you can add:

  `{SuperCollider.SoundServer, name: :soundserver}`

  as a child of your supervisor. The `name:` is optional and is the registered name you'd like for the `SuperCollider.SoundServer` process.
  
  For example, if you were writing a Phoenix based web-app musical app, you'd could add it to the `application.ex` file as follows:

  ```
  ...
  def start(_type, _args) do
    children = [
      MyAppWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:my_app, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: MyApp.PubSub},
      {SuperCollider.SoundServer, name: :soundserver},
      MyAppWeb.Endpoint,
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
  ...
  ```

  See the offical Elixir [GenServer: How to supervise](https://hexdocs.pm/elixir/GenServer.html#module-how-to-supervise) documentation for more information.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, nil)
    GenServer.start_link(SoundServer, SoundServer.new(opts), name: name)
  end

  @doc section: :impl
  @impl true
  def handle_call(:state, _from, state) do
    {:reply, state, state}
  end

  @doc section: :impl
  @impl true
  def handle_call({:sync_command, command_name, args}, from, state) do
    state = %{state | from: from}
    new_state = apply(Command, command_name, [state] ++ args)
    {:noreply, new_state}
  end


  @doc section: :pub
  @doc """
  Returns the current state of the server.

  For example, calling `SuperCollider.SoundServer.state(pid)` will return the populated state struct, which includes configuration and any scynth OSC message responses stored in the reponses key:

  ```
  %SuperCollider.SoundServer{
    host: ~c"127.0.0.1",
    port: 57110,
    socket: #Port<0.6>,
    type: :scsynth,
    booted?: true,
    client_id: 0,
    responses: %{
      status: %SuperCollider.Message.Status{
        unused: 1,
        num_ugens: 4,
        num_synths: 1,
        num_groups: 1,
        num_synthdefs_loaded: 5,
        avg_cpu: 0.02616635337471962,
        peak_cpu: 0.10551269352436066,
        nominal_sample_rate: 44100.0,
        actual_sample_rate: 44100.01409481425
      },
      version: %SuperCollider.Message.Version{
        name: "scsynth",
        major_version: 3,
        minor_version: 13,
        patch_name: ".0",
        git_branch: "Version-3.13.0",
        commit_hash_head: "3188503"
      }
    }
  }
  ```
  """
  def state(pid) do
    GenServer.call(pid, :state)
  end

  @doc section: :pub
  @doc """
  Clears values under the response key with an empty value.

  By default, if no key is given, the `:fail` key is cleared.

  Multiple keys can be given as a list.

  ## Example:
  ```
  # Clear the :fail list (will become an empty list)
  SuperCollider.SoundServer.clear_responses(pid, :fail)

  # Clear the :version and :status values (will become nil values)
  SuperCollider.SoundServer.clear_responses(pid, [:version, :status])
  ```
  """
  def clear_responses(pid, :fail) do
    GenServer.cast(pid, {:set_response_value, :fail, []})
  end
  def clear_responses(pid, key) when is_list(key) do
    Enum.each(key, &clear_responses(pid, &1))
  end  
  def clear_responses(pid, key) when is_atom(key) or is_binary(key) do
    GenServer.cast(pid, {:set_response_value, key, nil})
  end


  @doc section: :impl
  @impl true
  def handle_cast({:set_response_value, key, value}, state) do
    new_state = %{state | responses: Map.put(state.responses, key, value)}
    {:noreply, new_state}
  end

  @doc section: :impl
  @impl true
  def handle_cast({:add_handler, handler_fn}, state) do
    handler_fn = if is_list(handler_fn), do: handler_fn, else: [handler_fn]
    new_state = %__MODULE__{state | callback: handler_fn ++ state.callback}
    {:noreply, new_state}
  end

  @doc section: :impl
  @impl true
  def handle_cast({:command, command_name, args}, state) do
    new_state = apply(Command, command_name, [state] ++ args)
    {:noreply, new_state}
  end


  @doc section: :pub
  @doc """
  Add one or more callback function(s) which will receive and handle SuperCollider response messages.

  A single callback function or multiple callback functions can be provided in a list.

  Adding callback functions can be a way to achieve a reactive style of programming, for when your application needs to respond to particular `SuperCollider.Message` types.

  ## Example
  ```
  alias SuperCollider.SoundServer

  # Start your SoundServer process
  {:ok, pid} = SoundServer.start_link()

  # Add a single handler
  SoundServer.add_handler(pid, fn msg -> IO.inspect msg, label: "Inspecting msg" end)

  # Add multiple handlers in a list
  SoundServer.add_handler(
    pid,
    [
      fn msg -> IO.inspect msg, label: "Msg handler 1" end,
      fn msg -> IO.inspect msg, label: "Msg handler 1" end,
    ]
  )

  # If you've defined your hander function in a module function, pass it the usual way:
  SoundServer.add_handler(pid, &MyModule.function_name/1)
  ```
  """
  def add_handler(pid, handler_fn) do
    GenServer.cast(pid, {:add_handler, handler_fn})
  end

  @doc section: :pub
  @doc """
  Sends an OSC command to SuperCollider (scynth or supernova) and returns a result.

  Behaves like a synchonous function.

  Optionally accepts arguments, depending on the command being called.

  Commands must be a valid commmand (function in the SuperCollider.SoundServer.Command module) and match it's arity, otherwise an {:error, reason} tuple ie returned.
  
  Note: If you don't need to return value, use `command/2` or `command/3` instead.
  """
  def sync_command(pid, command_name) do
    if is_valid_command?(command_name) do
      GenServer.call(pid, {:sync_command, command_name, []})
    else
      {:error, "Invalid SuperCollider command or arity."}
    end
  end

  @doc section: :pub
  @doc """
  Sends an OSC command with arguments to SuperCollider (scynth or supernova) and returns a result.

  Behaves like a synchonous function.

  Note: If you don't need to return value, use `command/2` or `command/3` instead.
  """

  def sync_command(pid, command_name, args) when is_list(args) do
    if is_valid_command?(command_name, args) do
      GenServer.call(pid, {:sync_command, command_name, args})
    else
      {:error, "Invalid SuperCollider command or arity."}
    end
  end

  def sync_command(pid, command_name, args) do
    if is_valid_command?(command_name, args)  do
      GenServer.call(pid, {:sync_command, command_name, [args]})
    else
      {:error, "Invalid SuperCollider command or arity."}
    end
  end

  @doc section: :pub
  @doc """
  Sends an OSC command (asynchronous) to SuperCollider (scynth or supernova).

  `SuperCollider.SoundServer.command(pid, :version)` will send the OSC 'version' command.

  Optionally accepts arguments, depending on the command being called.

  Commands must be a valid commmand (function in the SuperCollider.SoundServer.Command module) and match it's arity, otherwise an {:error, reason} tuple ie returned.
  
  Note: If you need a return value, use `sync_command/2` or `sync_command/3` instead.
  """
  def command(pid, command_name) do
     if is_valid_command?(command_name) do
      GenServer.cast(pid, {:command, command_name, []})
    else
      {:error, "Invalid SuperCollider command or arity."}
    end
  end

  @doc section: :pub
  @doc """
  Sends an OSC command (asynchronous) with arguments to SuperCollider (scynth or supernova).
  
  Note: If you need a return value, use `sync_command/2` or `sync_command/3` instead.
  """
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

  @doc section: :impl
  @doc """
  When sending calls to scserver though UDP, a response message may be returned in the following format:

  `{:udp, process_port, ip_addr, port_num, osc_response}`

  The `handle_info/2` callback will forward these messages to `Response.process_osc_message/2` for handling.
  The handler code returns an updated SoundServer struct so that a valid state is maintained.

  To get the messages, use `SuperCollider.SoundServer.state(<pid>).responses` where <pid> is the process id of the SoundServer, or `SuperCollider.response()` if using the top-level API.

  Alternatively, to get messages returned from commands synchronously, use the `sync_command` functions.
  """
  @impl true
  def handle_info({:udp, _process_port, _ip_addr, _port_num, res}, state) do
    {new_state, message} = Response.process_osc_message(state, res)
    
    # Call any registered listeners functions
    # TODO: Consider doing this in a Task
    Enum.each(state.callback, fn callback_fn -> callback_fn.(message) end)

    # Return a value synchronously if required
    if state.from, do: GenServer.reply(state.from, message)

    {:noreply, new_state}
  end

  @doc section: :impl
  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Core
  @doc section: :pub
  @doc """
  A convience function to create a new SoundServer struct.

  The struct holds the basic state and configuration.

  The default values can be overrided by providing a keyword list using the same keys used in the struct. For example:

    ```
    SoundServer.new(host: 'othersoundserver')
    ```

    will override the default host of `'127.0.0.1'`.

  For more information, see the SoundServer struct documentation.
  """
  def new(opts \\ []), do: struct(__MODULE__, opts)

  @doc section: :support
  @doc """
  Open's a UDP connection. Unless a port number is provided, by default it will use port 0.

  Uses :gen_udp.open from Erlang which associates a UDP port number with the calling process (this GenServer).
  """
  def open(port_num \\ 0), do: :gen_udp.open(port_num, [:binary, {:active, true}])

  @doc section: :support
  @doc """
  Runs the server. By default, this function is executed when init is called.

  This function:
  - checks if server is loaded, otherwise attempts to boot it
  - opens a USP socket for Open Sound Communication (OSC) communication with the server.
  """
  def run(soundserver \\ %__MODULE__{}) do
    with {:ok, socket} <- open(),
         {:ok, soundserver} <- maybe_boot_scsynth(%{soundserver | socket: socket}) do
      %__MODULE__{soundserver | socket: socket, booted?: true}
    else
      _any -> {:error, "Could not be initialised. UDP socket could not be opened."}
    end
  end

  @doc section: :support
  @doc """
  Checks if scsynth is loaded by calling `scsynth_booted?/1`. If not it will attempt to boot it asynchronously using `Task.async/1`.

  Currently attempts to start scynth or supernova at the following locations:

  - Mac: /Applications/SuperCollider.app/Contents/Resources/
  - Linux: /usr/local/
  - Windows: \\Program Files\\SuperCollider\\

  Tip: If you want to shutdown the scynth or supernova process after it has booted, you can issue the `:quit` command, e.g. `SuperCollider.SoundServer.command(pid, :quit)`.

  TODO: The location of the scsynth binary is currently set to the fixed locations above, but this will need to be moved out into a config or using different search strategies for different OSes.
  """
  def maybe_boot_scsynth(soundserver) do
    Logger.info("#{soundserver.type} - waiting up to 3 seconds to see if already loaded ⏳")

    cmd = @server_type[os_type()][soundserver.type]

    {booted?, soundserver} = scsynth_booted?(soundserver)
    
    cond do
      !booted? and File.exists?(cmd) ->
        Logger.info("#{soundserver.type} - attempting to start 🏁")
        Task.async(fn -> System.cmd(cmd, ["-u", Integer.to_string(soundserver.port)]) end)
        # TODO: Refactor to return {:error, soundserver} if the System.cmd fails or scynth or supernova errors out.
        {:ok, soundserver}

      !booted? and !File.exists?(cmd) ->
        Logger.error("#{soundserver.type} - unable to find executable at #{cmd}.\nPlease start manually.")
        {:error, soundserver}

      true ->
        # Assume it is already booted
        {:ok, soundserver} 
    end

  end

  @doc section: :support
  @doc """
  Checks if scsynth or supernova is booted.

  It does this by sending the OSC command '/status' through the previously opened UDP port to the address that scsynth is expected.

  It then waits up to 3 seconds to see if a UDP packet is returned.

  This function returns:
  - `{true, soundserver}` if if a '/status.reply' message was recieved via UDP. The soundserver state will be updated.
  - `{false, soundserver}` if either a non-compliant message is recieved or no message is recieved after 5 seconds. In this case the scsynth has been considered not to be loaded.

  Note: an UDP socket must be set on the `%SoundServer{}` state, e.g.:

  ```
  soundserver =
    %SuperCollider.SoundServer{
      socket: #Port<0.8>, # Socket established here, otherwise this would be nil
      host: '127.0.0.1',
      port: 57110,
      type: :scsynth,
      client_id: 0,
      responses: %{}
    }

  SuperCollider.SoundServer.scsynth_booted?(soundserver)
  # Returns {true, soundserver} if booted
  ```

  If you don't have a curently opened socket, you can get one by calling `SoundServer.open/1`, e.g.:
  ```
  {:ok, socket} = SoundServer.open()

  soundserver = SoundServer.new(socket: socket)

  # Returns SoundServer struct with socket populated:
  # %SuperCollider.SoundServer{
  #   socket: #Port<0.9>,
  #   host: '127.0.0.1',
  #   port: 57110,
  #   type: :scsynth,
  #   client_id: 0,
  #   responses: %{}
  # }

  SuperCollider.SoundServer.scsynth_booted?(soundserver)

  # If already booted returns a tuple of {true, soundserver}
  # 11:53:43.734 [info] scsynth - already booted ✅
  # {true,
  #  %SuperCollider.SoundServer{
  #    host: ~c"127.0.0.1",
  #    port: 57110,
  #    socket: #Port<0.13>,
  #    type: :scsynth,
  #    booted?: false,
  #    client_id: 0,
  #    max_logins: nil,
  #    responses: %{
  #      status: %SuperCollider.Message.Status{
  #        unused: 1,
  #        num_ugens: 0,
  #        num_synths: 0,
  #        num_groups: 1,
  #        num_synthdefs_loaded: 5,
  #        avg_cpu: 0.026431389153003693,
  #        peak_cpu: 0.07823443412780762,
  #        nominal_sample_rate: 44100.0,
  #        actual_sample_rate: 44099.966771616244
  #      }
  #    },
  #    from: nil
  #  }}
  ```

  Sockets are automatically created when SoundServer is booted in the typical way through `SuperCollider.SoundServer.start_link` or `SuperCollider.start_link`.
  """
  def scsynth_booted?(soundserver) do
    Command.send_osc(soundserver, "/status")

    receive do
      {:udp, _process_port, _ip_addr, _port_num, data} ->
        message = OSCx.decode(data)

        %{address: "/status.reply", arguments: arguments}  = if is_list(message), do:  List.first(message), else: message

        Logger.info("#{soundserver.type} - already booted ✅")

        # Update SoundServer state with status information
        status_info = SuperCollider.Message.Status.parse(arguments)
        Logger.notice("Status: #{inspect(status_info)}")
        soundserver= %{soundserver | responses: Map.put(soundserver.responses, :status, status_info)}

        {true, soundserver}

      msg ->
        Logger.info("#{soundserver.type} - non-matching UDP message, #{soundserver.type} is probably not booted. \nOSC message recieved: (#{inspect(msg)})")
        {false, soundserver}
    after
      3_000 ->
        Logger.info("#{soundserver.type} - no response, #{soundserver.type} likely not booted.")
        {false, soundserver}
    end
  end

  # Returns of the OS type as :windows, :mac or :unix
  defp os_type do
    case :os.type() do
      {:win32, _} -> :windows
      {:unix, :darwin} -> :mac
      {:unix, _} -> :unix
    end
  end

end
