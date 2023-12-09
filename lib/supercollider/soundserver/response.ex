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
  * `/done /notify` a notify confirmation message
  * `/synced`

  Server responses are logged using Elixir's logger.

  The OSC messages returned are converted to `SuperCollider.Message` structs:
  - `SuperCollider.Message.Error`: A error message from the server.
  - `SuperCollider.Message.Node`: A node message from the server.
  - `SuperCollider.Message.Notify`: A notify confirmation message.
  - `SuperCollider.Message.Done`: An asynchronous message has completed.
  - `SuperCollider.Message.QueryTree`: A representation of a group's node subtree.
  - `SuperCollider.Message.Sync`:  A sync message from the server.
  - `SuperCollider.Message.Late`:  A command was received too late.
  - `SuperCollider.Message.Trigger`: A trigger message.
  - `SuperCollider.Message.Version`: A version message.
  - `SuperCollider.Message.Status`: A status message.

  Version, status and fail messages are added to the SoundServer's state under the `responses:` key, e.g.:
  ```
  %SuperCollider.SoundServer{
    ip: ~c"127.0.0.1",
    hostname: ~c"localhost",
    port: 57110,
    socket: #Port<0.6>,
    type: :scsynth,
    booted?: true,
    client_id: 0,
    max_logins: 64,
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
  For convenience, you can quickly access these reponse messages by calling `SuperCollider.response()` or `SuperCollider.response(key)` where key is `:version`, `:status` or `:fail`.
  """

  alias SuperCollider.{SoundServer, Message}
  require Logger

  @doc """
  Handles SuperColliders OSC response message types.

  This is called from the `SoundServer` handle_info function, when it recieves OSC messages.

  Accepts a %SoundServer{} as the first parameter and the OSC response message as the second.

  The OSC messages received from scynth or supernova are converted into one of the `SuperCollider.Message` structs. See the `SuperCollider.Message` documentation for the complete list.
  """
  def process_osc_message(soundserver, res) do
    message = OSCx.decode(res)

    # This may no longer be needed with using OSCx
    message = if is_list(message), do: List.first(message), else: message

    case message do
      %{address: "/version.reply", arguments: arguments} ->
        version_info = Message.Version.parse(arguments)
        Logger.notice("Version: #{inspect(version_info)}")
        put_response(soundserver, :version, version_info)

      %{address: "/status.reply", arguments: arguments} ->
        status_info = Message.Status.parse(arguments)
        Logger.notice("Status: #{inspect(status_info)}")
        put_response(soundserver, :status, status_info)
    
      %{address: "/g_queryTree.reply", arguments: arguments} ->
        tree = Message.QueryTree.parse(arguments)
        Logger.info("Group tree: #{inspect(tree)}")
        soundserver  

      ## In case the client was already registered and tries to register again (after a reboot or network problem),
      ## scsynth sends back a failed message AND the client this client had earlier, and the client will use that client id.
      ## Error is shown as a warning in this case and the client id reassigned to the soundserver state.
      %{address: "/fail", arguments: ["/notify", message, client_id]=arguments} ->
        error = Message.Error.parse(arguments)
        Logger.warning("Previously registered at client id: #{client_id}. Message: #{inspect error}")
        %SoundServer{soundserver | client_id: client_id}
        |> put_response(:fail, error)

      %{address: "/fail", arguments: arguments} ->
        IO.inspect arguments, label: "fail args"
        error = Message.Error.parse(arguments)
        Logger.error(inspect(error))
        put_response(soundserver, :fail, error)

      %{address: "/late", arguments: arguments} ->
        notification = Message.Late.parse(arguments)
        Logger.warning("Late: #{inspect(notification)}")
        soundserver

      %{address: "/done", arguments: ["/notify" | rest_args]=_arguments} ->
        notification = Message.Notify.parse(rest_args)
        Logger.info("Notify: #{inspect(notification)}")
        %SoundServer{soundserver | client_id: notification.client_id, max_logins: notification.max_logins}

      %{address: "/done", arguments: arguments} ->
        notification = Message.Done.parse(arguments)
        Logger.info("Done: #{inspect(notification)}")
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
        trigger = Message.Trigger.parse(arguments)
        Logger.info("Trigger: #{inspect(trigger)}")
        soundserver    

      msg ->
        # Ignore message
        Logger.info("Non matched message: #{inspect(msg)}")
        soundserver
    end

  end

  # Helper functions for formatting responses and adding response data to the state (if applicable)
  defp put_response(soundserver, key, value) do
    %{soundserver | responses: Map.put(soundserver.responses, key, value)}
  end

end
