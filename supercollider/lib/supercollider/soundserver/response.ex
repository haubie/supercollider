defmodule SuperCollider.SoundServer.Response do
  def process_osc_message(soundserver, res) do
    packet = res |> OSC.decode!()

    case packet.contents |> List.first() do
      %{address: "/version.reply", arguments: arguments} ->
        IO.inspect(arguments, label: "Version information request")

      %{address: "/status.reply", arguments: arguments} ->
        IO.inspect(arguments, label: "Status information request")

      %{address: "/fail", arguments: arguments} ->
        IO.inspect(arguments, label: "Failure message from server")

      %{address: "/done", arguments: arguments} ->
        IO.inspect(arguments, label: "Sound server (scsynth or supernova) has shutdown")

      %{address: "/synced", arguments: arguments} ->
        IO.inspect(arguments,
          label:
            "All asynchronous commands received before this one (see command code) have completed"
        )

      msg ->
        IO.inspect(msg, label: "Some other osc message")
    end

    soundserver
  end
end
