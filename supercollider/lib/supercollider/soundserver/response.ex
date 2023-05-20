defmodule SuperCollider.SoundServer.Response do
  def process_osc_message(soundserver, res) do
    packet = res |> OSC.decode!()

    IO.inspect packet, label: "OSC packet recieved"

    case packet.contents |> List.first() do
      %{address: "/version.reply", arguments: arguments} ->
        version_info = format_version(arguments)
        IO.inspect(version_info, label: "Version information request")
        # %{soundserver | responses: Map.put(soundserver.responses, :version, version_info)}
        put_response(soundserver, :version, version_info)

      %{address: "/status.reply", arguments: arguments} ->
        status_info = format_status(arguments)
        IO.inspect status_info, label: "Status information request"
        # %{soundserver | responses: Map.put(soundserver.responses, :status, status_info)}
        put_response(soundserver, :status, status_info)

      %{address: "/fail", arguments: arguments} ->
        IO.inspect(arguments, label: "Failure message from server")
        # %{soundserver | responses: Map.put(soundserver.responses, :fail, arguments)}
        put_response(soundserver, :fail, arguments)

      %{address: "/done", arguments: arguments} ->
        IO.inspect(arguments, label: "Command complete")
        soundserver

      %{address: "/synced", arguments: arguments} ->
        IO.inspect(arguments,
          label:
            "All asynchronous commands received before this one (see command code) have completed"
        )
        soundserver

      msg ->
        IO.inspect(msg, label: "Some other osc message")
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
