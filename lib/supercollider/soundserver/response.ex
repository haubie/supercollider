defmodule SuperCollider.SoundServer.Response do
  @moduledoc """
  This module is used to process OSC response messages sent from the SuperCollider.

  Currently, the following message types are supported:
  * `/version.reply` the server will send this OSC response after the `SuperCollider.command(:version)` command is issued
  * `/status.reply` the server will send this OSC response after the `SuperCollider.command(:status)` command is issued
  * `/g_queryTree.reply` a groups subtree, from the `:g_queryTree` command
  * `/n_* `node notification messages, such as /n_go, /n_end, /n_on, /n_off, /n_move, /n_info (interest in these are registered via the `:notify` command)
  * `/tr` a trigger message (interest in this is registered via the `:notify` command)
  * `/fail` the server will send this OSC response when a command fails, such as freeing a node that doesn't exist `SuperCollider.command(:n_free, 800)`
  * `/late` a command was received too late
  * `/done` an asynchronous message has completed
  * `/synced`

  Server responses are logged using Elixir's logger.

  Version, status and fail messages are added to the SoundServer's state under the `response` key, e.g.:
  ```
  %SuperCollider.SoundServer{
    ip: '127.0.0.1',
    hostname: 'localhost',
    port: 57110,
    socket: #Port<0.5>,
    responses: %{
      fail: ["/n_free", "Node 100 not found"],
      status: [
        {"Unused", 1},
        {"Number of unit generators", 0},
        {"Number of synths", 0},
        {"Number of groups", 2},
        {"Number of loaded synth definitions", 109},
        {"Average percent CPU usage for signal processing", 0.022701745852828026},
        {"Peak percent CPU usage for signal processing", 0.08792437613010406},
        {"Nominal sample rate", 44100.0},
        {"Actual sample rate", 44100.008983920634}
      ],
      version: [
        {"Program name", "scsynth"},
        {"Major version number", 3},
        {"Minor version number", 13},
        {"Patch version name", ".0"},
        {"Git branch name", "Version-3.13.0"},
        {"First seven hex digits of the commit hash", "3188503"}
      ]
    }
  }
  ```
  For convenience, you can quickly access these reponse messages by calling `SuperCollider.response()` or `SuperCollider.response(key)` where key is `:version`, `:status` or `:fail`.
  """

  alias SuperCollider.Message
  require Logger

  @doc """
  Handles SuperColliders OSC response message types.

  This is called from the `SoundServer` handle_info function, when it recieves OSC messages.

  Accepts a %SoundServer{} as the first parameter and the OSC response message as the second.

  For Version and Status response messages, additional text labels are added to the values returned in the form of a tuple: `{"label", value}`. For example, an exert of the enrished version response is below:
  ```
  [
      {"Program name", "scsynth"},
      {"Major version number", 3},
      {"Minor version number", 13},
      {"Patch version name", ".0"},
      {"Git branch name", "Version-3.13.0"},
      {"First seven hex digits of the commit hash", "3188503"}
  ]
  ```
  """
  def process_osc_message(soundserver, res) do
    message = OSCx.decode(res)

    # This may no longer be needed with using OSCx
    message = if is_list(message), do: List.first(message), else: message

    case message do
      %{address: "/version.reply", arguments: arguments} ->
        version_info = format_version(arguments)
        Logger.notice("Version: #{inspect(version_info)}")
        put_response(soundserver, :version, version_info)

      %{address: "/status.reply", arguments: arguments} ->
        status_info = format_status(arguments)
        Logger.notice("Status: #{inspect(status_info)}")
        put_response(soundserver, :status, status_info)
    
      %{address: "/g_queryTree.reply", arguments: arguments} ->
        tree = Message.QueryTree.parse(arguments)
        Logger.info("Group tree: #{inspect(tree)}")
        soundserver  

      %{address: "/fail", arguments: arguments} ->
        error = Message.Error.parse(arguments)
        Logger.error(inspect(error))
        put_response(soundserver, :fail, error)

      %{address: "/late", arguments: arguments} ->
        Logger.warning("Late: #{inspect(arguments)}")
        soundserver

      %{address: "/done", arguments: ["/notify" | rest_args]=_arguments} ->
        notification = Message.Notify.parse(rest_args)
        Logger.info("Notify: #{inspect(notification)}")
        soundserver

      %{address: "/done", arguments: arguments} ->
        Logger.info("Done: #{inspect(arguments)}")
        soundserver

      %{address: "/synced", arguments: arguments} ->
        notification = Message.Sync.parse(arguments)
        Logger.info("Synced: #{inspect(notification)}")
        soundserver
   
      %{address: <<"/n_", _rest::binary>>=address, arguments: arguments} ->
        notification = Message.Node.parse(address, arguments)
        Logger.info("Node #{address}: #{inspect(notification)}")
        soundserver

      %{address: "/tr", arguments: arguments} ->
        Logger.info("Trigger: #{inspect(arguments)}")
        soundserver    

      _msg ->
        # Ignore message
        soundserver
    end

  end

  # Helper functions for formatting responses and adding response data to the state (if applicable)
  defp put_response(soundserver, key, value) do
    %{soundserver | responses: Map.put(soundserver.responses, key, value)}
  end

  defp format_status(res_data) do
    response_labels = [
      "Unused",
      "Number of unit generators",
      "Number of synths",
      "Number of groups",
      "Number of loaded synth definitions",
      "Average percent CPU usage for signal processing",
      "Peak percent CPU usage for signal processing",
      "Nominal sample rate",
      "Actual sample rate"
    ]

    Enum.zip(response_labels, res_data)
  end

  defp format_version(res_data) do
    response_labels = [
      "Program name",
      "Major version number",
      "Minor version number",
      "Patch version name",
      "Git branch name",
      "First seven hex digits of the commit hash"
    ]

    Enum.zip(response_labels, res_data)
  end

end
