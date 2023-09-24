defmodule SuperCollider.SoundServer.Response do
  @moduledoc """
  This module is used to process OSC response messages sent from the SuperCollider.

  Currently, the following message types are supported:
  * /version.reply (the server will send this OSC response after the `SuperCollider.command(:version)` command is issued)
  * /status.reply (the server will send this OSC response after the `SuperCollider.command(:status)` command is issued)
  * /fail (the server will send this OSC response when a command fails, such as freeing a node that doesn't exist `SuperCollider.command(:n_free, 800)`)
  * /done
  * /synced

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
        {"unused", 1},
        {"number of unit generators", 0},
        {"number of synths", 0},
        {"number of groups", 2},
        {"number of loaded synth definitions", 109},
        {"average percent CPU usage for signal processing", 0.022701745852828026},
        {"peak percent CPU usage for signal processing", 0.08792437613010406},
        {"nominal sample rate", 44100.0},
        {"actual sample rate", 44100.008983920634}
      ],
      version: [
        {"Program name. May be \"scsynth\" or \"supernova\".", "scsynth"},
        {"Major version number. Equivalent to sclang's Main.scVersionMajor.", 3},
        {"Minor version number. Equivalent to sclang's Main.scVersionMinor.", 13},
        {"Patch version name. Equivalent to the sclang code \".\" ++ Main.scVersionPatch ++ Main.scVersionTweak.", ".0"},
        {"Git branch name.", "Version-3.13.0"},
        {"First seven hex digits of the commit hash.", "3188503"}
      ]
    }
  }
  ```
  For convenience, you can quickly access these reponse messages by calling `SuperCollider.response()` or `SuperCollider.response(key)` where key is `:version`, `:status` or `:fail`.
  """

  require Logger

  @doc """
  Handles SuperColliders OSC response message types.

  This is called from the `SoundServer` handle_info function, when it recieves OSC messages.

  Accepts a %SoundServer{} as the first parameter and the OSC response message as the second.

  For Version and Status response messages, additional text labels are added to the values returned in the form of a tuple: `{"label", value}`. For example, an exert of the enrished version response is below:
  ```
  [
      {"Program name. May be \"scsynth\" or \"supernova\".", "scsynth"},
      {"Major version number. Equivalent to sclang's Main.scVersionMajor.", 3},
      {"Minor version number. Equivalent to sclang's Main.scVersionMinor.", 13},
      {"Patch version name. Equivalent to the sclang code \".\" ++ Main.scVersionPatch ++ Main.scVersionTweak.", ".0"},
      {"Git branch name.", "Version-3.13.0"},
      {"First seven hex digits of the commit hash.", "3188503"}
  ]
  ```
  """
  def process_osc_message(soundserver, res) do
    packet = res |> OSC.decode!()

    # IO.inspect packet, label: "OSC packet recieved"

    message = if is_list(packet.contents), do: List.first(packet.contents), else: packet.contents

    case message do
      %{address: "/version.reply", arguments: arguments} ->
        version_info = format_version(arguments)
        Logger.notice("Version: #{inspect(version_info)}")
        put_response(soundserver, :version, version_info)

      %{address: "/status.reply", arguments: arguments} ->
        status_info = format_status(arguments)
        Logger.notice("Status: #{inspect(status_info)}")
        put_response(soundserver, :status, status_info)

      %{address: "/fail", arguments: arguments} ->
        Logger.error(arguments)
        put_response(soundserver, :fail, arguments)

      %{address: "/done", arguments: arguments} ->
        Logger.info(arguments)
        soundserver

      %{address: "/synced", arguments: arguments} ->
        Logger.info("Synced #{inspect(arguments)}")
        soundserver

      msg ->
        IO.inspect(msg, label: "OSC server message")
        soundserver
    end

  end

  # Helper functions for formatting responses and adding response data to the state (if applicable)
  defp put_response(soundserver, key, value) do
    %{soundserver | responses: Map.put(soundserver.responses, key, value)}
  end

  defp format_status(res_data) do
    response_labels = [
      "unused",
      "number of unit generators",
      "number of synths",
      "number of groups",
      "number of loaded synth definitions",
      "average percent CPU usage for signal processing",
      "peak percent CPU usage for signal processing",
      "nominal sample rate",
      "actual sample rate"
    ]

    Enum.zip(response_labels, res_data)
  end

  defp format_version(res_data) do
    response_labels = [
      "Program name. May be \"scsynth\" or \"supernova\".",
      "Major version number. Equivalent to sclang's Main.scVersionMajor.",
      "Minor version number. Equivalent to sclang's Main.scVersionMinor.",
      "Patch version name. Equivalent to the sclang code \".\" ++ Main.scVersionPatch ++ Main.scVersionTweak.",
      "Git branch name.",
      "First seven hex digits of the commit hash."
    ]

    Enum.zip(response_labels, res_data)
  end

end
