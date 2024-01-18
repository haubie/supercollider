defmodule SuperCollider.SoundServer.Command do
  @moduledoc """
  This module is used to send [Open Sound Control (OSC)](https://en.wikipedia.org/wiki/Open_Sound_Control) commands to SuperCollider's server (scsynth or supernova) via UDP.

  These commands make use of the server configuration and state details in %SoundServer{}, and is most cases, a %SoundServer{} struct is passed as the first parameter in these funtions.

  For an official list of these commands, see: https://doc.sccode.org/Reference/Server-Command-Reference.html

  ## Structure of this module
  The functions of this module are grouped into the following categories:
  - scserver communication helper functions, such as to encode OSC messages and to send them to a scserver insrtance
  - scserver commands, following the SuperCollider Server Synth Engine Command Reference:
    - General Commands - such as for getting *status* or *version* information or *quitting* scynth/supernova.
    - Node Commands - for manipulating nodes including *freeing* them
    - Synth Commands - such as for *sending* or *loading* synth defs, and *creating* a new synth
    - Group Commands
    - Unit Generator Commands
    - Buffer Commands
    - Control Bus Commands
    - Non Real Time Mode Commands
    - Replies to Commands
    - Node Notifications from Server
    - Trigger Notification
    - Buffer Fill Commands.

  Note that this library uses the OSC style string format to send commands, rather than command numbers.
  """

  alias SuperCollider.SoundServer, as: SoundServer

  ## ##################################
  ## SCSYNTH COMMUNICATION
  ## ##################################

  ## Helpers

  @doc section: :osc
  @doc """
  Sends an encoded OSC message to the specified `%SoundServer{}` via UDP.
  Mainly used by `send_osc/3` as a helper function.
  """

  def send_to_sc(soundserver, osc_message) do
    :gen_udp.send(soundserver.socket, soundserver.host, soundserver.port, osc_message)
  end

  @doc section: :osc
  @doc """
  Takes an address and a list of optional arguments and encodes them as an OSC message.

  Mainly used by `send_osc/3` as a helper function.
  """
  def encode_osc(address, arguments \\ []) do
    %OSCx.Message{address: address, arguments: arguments}
    |> OSCx.encode()
  end

  @doc section: :osc
  @doc """
  The primary way to send commands to a scynth sound server.

  For a given `%SoundServer{}`, takes an adress an optional arguments, encodes them as OSC and sends them to the sound server via UDP.

  This function makes use of the `encode_osc/3` and `send_to_sc/2` helper functions.
  """
  def send_osc(soundserver, address, arguments \\ []) do
    osc_data = encode_osc(address, arguments)
    send_to_sc(soundserver, osc_data)
    soundserver
  end

  ## SC Server API
  @doc section: :top_level_commands
  @doc """
  Instructs scsynth to quit.
  Before exiting, scserver will reply to the sender with '/done'.
  """
  def quit(soundserver) do
    soundserver
    |> send_osc("/quit")

    # Close socket
    # TODO: the responsibility for this should probably be in SoundServer?
    :gen_udp.close(soundserver.socket)

    # Return soundserver state with empty socket
    %SoundServer{soundserver | socket: nil}
  end

  @doc section: :top_level_commands
  @doc """
  Register to receive notifications from scserver.

  Takes two optional parameters:
  - flag: this is an integer with either:
    - 1 to receive notifications (default): the server will remember your return address and send you notifications
    - 0 to stop receiving them: scserver will stop sending notifications.
  - client_id: an integer representing the client. This is optional.

  From SuperCollider documentation:

    Replies to sender with /done /notify clientID [maxLogins] when complete.

    If this client has registered for notifications before, this may be the same ID. Otherwise it will be a new one.

    Clients can use this ID in multi-client situations to avoid conflicts when allocating resources such as node IDs, bus indices, and buffer numbers.

    maxLogins is only returned when the client ID argument is supplied in this command. maxLogins is not supported by supernova.

  """
  def notify(soundserver, flag \\ 1, client_id \\ nil) do
    soundserver
    |> send_osc("/notify", [flag, client_id])
  end

  ## ##################################
  ## TOP LEVEL COMMANDS
  ## ##################################

  @doc section: :top_level_commands
  @doc """
    Query the servers status.

    Replies to sender with an '/status.reply' message with a list containing the following:

    - `int` 1. unused.
    - `int` number of unit generators.
    - `int` number of synths.
    - `int` number of groups.
    - `int` number of loaded synth definitions.
    - `float` average percent CPU usage for signal processing
    - `float` peak percent CPU usage for signal processing
    - `double` nominal sample rate
    - `double` actual sample rate
  """
  def status(soundserver) do
    soundserver
    |> send_osc("/status")
  end

  @doc section: :top_level_commands
  @doc """
  Send a plug-in defined command. Commands are defined by plug-ins.

  This function takes:
  - command name (String)
  - any arguments (As a list []).
  """
  def cmd(soundserver, command_name, arguments \\ []) do
    soundserver
    |> send_osc("/cmd", [command_name] ++ arguments)
  end

  @doc section: :osc
  @doc """
  Displays incoming OSC messages.

  Turns on and off printing of the contents of incoming Open Sound Control messages. This is useful when debugging your command stream.

  Accepts one of the following integers as the second parameter:

  - 0	turn dumping OFF.
  - 1	print the parsed contents of the message.
  - 2	print the contents in hexadecimal.
  - 3	print both the parsed and hexadecimal representations of the contents.

  """
  def dump_osc(soundserver, code) do
    soundserver
    |> send_osc("/dumpOSC", [code])
  end

  def dump_OSC(soundserver, code), do: dump_osc(soundserver, code)

  @doc section: :top_level_commands
  @doc """
  Notify when async commands have completed.

  Takes an unique integer identifying this command as the second parameter.

  Replies with a /synced message when all asynchronous commands received before this one have completed. The reply will contain the sent unique ID.
  """
  def sync(soundserver, command_code) do
    soundserver
    |> send_osc("/sync", [command_code])
  end

  @doc section: :top_level_commands
  @doc """
  Clear all scheduled bundles. Removes all bundles from the scheduling queue.
  """
  def clear_sched(soundserver) do
    soundserver
    |> send_osc("/clearSched", [])
  end

  @doc section: :top_level_commands
  @doc """
  Enable/disable error message posting.

  Turn on or off error messages sent to the SuperCollider post window. Useful when sending a message, such as /n_free, whose failure does not necessarily indicate anything wrong.

  Takes an integer as the second parameter:
  - 0	turn off error posting until the next ['/error', 1] message.
  - 1	turn on error posting.

  For convenience of client-side methods, you can also suppress errors temporarily, for the scope of a single bundle. To do that use the following codes:
  - \-1	turn off locally in the bundle -- error posting reverts to the "permanent" setting for the next message or bundle.
  - \-2	turn on locally in the bundle.

  These "temporary" states accumulate within a single bundle -- so if you have nested calls to methods that use bundle-local error suppression, error posting remains off until all the layers have been unwrapped. If you use ['/error', -1] within a self-bundling method, you should always close it with ['/error', -2] so that subsequent bundled messages will take the correct error posting status. However, even if this is not done, the next bundle or message received will begin with the standard error posting status, as set by modes 0 or 1.

  Temporary error suppression may not affect asynchronous commands in every case.
  """
  def error(soundserver, mode) do
    soundserver
    |> send_osc("/clearSched", [mode])
  end

  @doc section: :top_level_commands
  @doc """
  Query the SuperCollider version. Replies to sender with the following message:
  - `string`	Program name. May be "scsynth" or "supernova".
  - `int`	Major version number. Equivalent to sclang's Main.scVersionMajor.
  - `int`	Minor version number. Equivalent to sclang's Main.scVersionMinor.
  - `string`	Patch version name. Equivalent to the sclang code "." ++ Main.scVersionPatch ++ Main.scVersionTweak.
  - `string`	Git branch name.
  - `string`	First seven hex digits of the commit hash.
  """
  def version(soundserver) do
    soundserver
    |> send_osc("/version", [])
  end

  ## ##################################
  ## SYNTH DEFINITION COMMANDS
  ## ##################################

  @doc section: :synth_commands
  @doc """
  Instructs the sound server (scsynth or supernova) to receive a synth definition file.

  This function takes as it's second and third parameter:
  - bytes	of data which contain the file of synth definition(s)
  - OSC message to execute upon completion (optional).

  Replies to sender with /done when complete.
  """
  def d_recv(soundserver, data, completion_message \\ nil) do
    soundserver
    |> send_osc("/d_recv", [data, completion_message])
  end

  @doc section: :synth_commands
  @doc """
  Loads a file of synth definitions.

  The second and third parameter are:
  - pathname of the file (string). Can be a pattern like "synthdefs/perc-*"
  - OSC message to execute upon completion. (optional)

  Replies to sender with /done when complete.
  """
  def d_load(soundserver, path, completion_message \\ nil) do
    soundserver
    |> send_osc("/d_load", [path, completion_message])
  end

  @doc section: :synth_commands
  @doc """
  Loads a directory of synth definitions files.

  The second and third parameter are:
  - pathname of the directory (string)
  - OSC message to execute upon completion. (optional)

  Replies to sender with /done when complete.
  """
  def d_load_dir(soundserver, path, completion_message \\ nil) do
    soundserver
    |> send_osc("/d_loadDir", [path, completion_message])
  end

  @doc section: :synth_commands
  @doc """
  Deleted (removes) a synth definition.

  The second parameter is a string representing the name of the synth.

  The definition is removed immediately, and does not wait for synth nodes based on that definition to end.
  """
  def d_free(soundserver, synth_def_name) do
    soundserver
    |> send_osc("/d_free", [synth_def_name])
  end

  ## ##################################
  ## NODE COMMANDS
  ## ##################################

  @doc section: :node_commands
  @doc """
  Deletes a node. There is is also an alias to this function called free_node/2.

  From the SuperCollider docs:

    Stops a node abruptly, removes it from its group, and frees its memory.
    A list of node IDs may be specified.
    Using this method can cause a click if the node is not silent at the time it is freed.

  Takes the node id (integer) to delete as the second parameter.
  """
  def n_free(soundserver, node_id) do
    soundserver
    |> send_osc("/n_free", [node_id])
  end

  def free_node(soundserver, node_id), do: n_free(soundserver, node_id)

  @doc section: :node_commands
  @doc """
  Turns a node on or off.

  Takes a node id (integer) as the second parameter and a run flag (integer) as the third.

  If the run flag set:
  - to zero then the node will not be executed.
  - back to one, then it will be executed.

  Note that using this method to start and stop nodes can cause a click if the node is not silent at the time run flag is toggled.
  """
  def n_run(soundserver, node_id, run_flag) do
    soundserver
    |> send_osc("/n_run", [node_id, run_flag])
  end

  ## TODO - the args bit, takes a list of pairs - need to massage it into the OSC format
  @doc section: :node_commands
  @doc """
  Set a node's control value(s).

  If the node is a group, then it sets the controls of every node in the group.

  The second parameter is the node id (integer).

  The third parameter takes a list of pairs of control indices and values and sets the controls to those values.

  This message supports array type tags ($[ and $]) in the control/value component of the OSC message.
  Arrayed control values are applied in the manner of n_setn (i.e., sequentially starting at the indexed or named control).

  """
  def n_set(soundserver, node_id, args \\ []) do
    soundserver
    |> send_osc("/n_free", [node_id] ++ args)
  end

  ## TODO - the args bit
  @doc section: :node_commands
  @doc """
  Set ranges of a node's control value(s).

  From the SuperCollider documentation:
    Set contiguous ranges of control indices to sets of values.
    For each range, the starting control index is given followed by the number of controls to change, followed by the values.
    If the node is a group, then it sets the controls of every node in the group.

  Takes a node id (integer) as it's second parameter.
  """
  def n_setn(soundserver, node_id, args \\ []) do
    soundserver
    |> send_osc("/n_setn", [node_id] ++ args)
  end

  @doc section: :node_commands
  @doc """
  Fill ranges of a node's control value(s).

  Set contiguous ranges of control indices to single values. For each range, the starting control index is given followed by the number of controls to change, followed by the value to fill.

  If the node is a group, then it sets the controls of every node in the group.
  """
  def n_fill(soundserver, node_id, args \\ []) do
    soundserver
    |> send_osc("/n_fill", [node_id] ++ args)
  end

  @doc section: :node_commands
  @doc """
  Map a node's controls to read from a bus.

  Takes a list of pairs of control names or indices and bus indices and causes those controls to be read continuously from a global control bus. If the node is a group, then it maps the controls of every node in the group. If the control bus index is -1 then any current mapping is undone.

  Any n_set, n_setn and n_fill command will also unmap the control.
  """
  def n_map(soundserver, node_id, args \\ []) do
    soundserver
    |> send_osc("/n_map", [node_id] ++ args)
  end

  @doc section: :node_commands
  @doc """
  Map a node's controls to read from buses.

  Takes a list of triplets of control names or indices, bus indices, and number of controls to map and causes those controls to be mapped sequentially to buses. If the node is a group, then it maps the controls of every node in the group. If the control bus index is -1 then any current mapping is undone. Any n_set, n_setn and n_fill command will also unmap the control.
  """
  def n_mapn(soundserver, node_id, args \\ []) do
    soundserver
    |> send_osc("/n_mapn", [node_id] ++ args)
  end

  @doc section: :node_commands
  @doc """
  Map a node's controls to read from an audio bus.

  Takes a list of pairs of control names or indices and audio bus indices and causes those controls to be read continuously from a global audio bus. If the node is a group, then it maps the controls of every node in the group. If the audio bus index is -1 then any current mapping is undone. Any n_set, n_setn and n_fill command will also unmap the control. For the full audio rate signal, the argument must have its rate set to \\ar.
  """
  def n_mapa(soundserver, node_id, args \\ []) do
    soundserver
    |> send_osc("/n_mapa", [node_id] ++ args)
  end

  @doc section: :node_commands
  @doc """
  Map a node's controls to read from audio buses.

  Takes a list of triplets of control names or indices, audio bus indices, and number of controls to map and causes those controls to be mapped sequentially to buses. If the node is a group, then it maps the controls of every node in the group. If the audio bus index is -1 then any current mapping is undone. Any n_set, n_setn and n_fill command will also unmap the control. For the full audio rate signal, the argument must have its rate set to \\ar.
  """
  def n_mapan(soundserver, node_id, args \\ []) do
    soundserver
    |> send_osc("/n_mapan", [node_id] ++ args)
  end

  @doc section: :node_commands
  @doc """
  Place a node before another.

  Places node A in the same group as node B, to execute immediately before node B.
  """
  def n_before(soundserver, node_a_id, node_b_id) do
    soundserver
    |> send_osc("/n_before", [node_a_id, node_b_id])
  end

  @doc section: :node_commands
  @doc """
  Place a node after another.

  Places node A in the same group as node B, to execute immediately after node B.
  """
  def n_after(soundserver, node_a_id, node_b_id) do
    soundserver
    |> send_osc("/n_after", [node_a_id, node_b_id])
  end

  @doc section: :node_commands
  @doc """
  Get info about a node.

  The server sends an /n_info message for each node to registered clients. See Node Notifications below for the format of the /n_info message.
  """
  def n_query(soundserver, node_id) do
    soundserver
    |> send_osc("/n_query", [node_id])
  end

  @doc section: :node_commands
  @doc """
  Trace a node.

  Causes a synth to print out the values of the inputs and outputs of its unit generators for one control period. Causes a group to print the node IDs and names of each node in the group for one control period.
  """
  def n_trace(soundserver, node_id) do
    soundserver
    |> send_osc("/n_trace", [node_id])
  end

  @doc section: :node_commands
  @doc """
  Move and order a list of nodes. Moves the listed nodes to the location specified by the target and add action, and place them in the order specified. Nodes which have already been freed will be ignored.

  The second, third and fourth parameters are:

  - `int`	add action (0,1,2 or 3 see below)
  - `int`	add target ID
  - `N * int`	node IDs

  add actions are as follows:
  - 0	construct the node order at the head of the group specified by the add target ID.
  - 1	construct the node order at the tail of the group specified by the add target ID.
  - 2	construct the node order just before the node specified by the add target ID.
  - 3	construct the node order just after the node specified by the add target ID.
  """
  def n_order(soundserver, add_action_code, add_target_id, node_ids \\ []) do
    soundserver
    |> send_osc("/n_order", [add_action_code, add_target_id] ++ node_ids)
  end

  ## ##################################
  ## SYNTH COMMANDS
  ## ##################################

  @doc section: :synth_commands
  @doc """
  Create a new synth.

  Create a new synth from a synth definition, give it an ID, and add it to the tree of nodes. There are four ways to add the node to the tree as determined by the add action argument which is defined as follows:

  Parameters:

  - string	synth definition name
  - int	synth ID
  - int	add action (0,1,2, 3 or 4 see below)
  - int	add target ID
  - N *
    - int or string	a control index or name
    - float or int or string	floating point and integer arguments are interpreted as control value. a symbol argument consisting of the letter 'c' or 'a' (for control or audio) followed by the bus's index.

  add actions:
  - 0	add the new node to the head of the group specified by the add target ID.
  - 1	add the new node to the tail of the group specified by the add target ID.
  - 2	add the new node just before the node specified by the add target ID.
  - 3	add the new node just after the node specified by the add target ID.
  - 4	the new node replaces the node specified by the add target ID. The target node is freed.

  Controls may be set when creating the synth. The control arguments are the same as for the n_set command.

  If you send /s_new with a synth ID of -1, then the server will generate an ID for you. The server reserves all negative IDs. Since you don't know what the ID is, you cannot talk to this node directly later. So this is useful for nodes that are of finite duration and that get the control information they need from arguments and buses or messages directed to their group. In addition no notifications are sent when there are changes of state for this node, such as /go, /end, /on, /off.

  If you use a node ID of -1 for any other command, such as /n_map, then it refers to the most recently created node by /s_new (auto generated ID or not). This is how you can map the controls of a node with an auto generated ID. In a multi-client situation, the only way you can be sure what node -1 refers to is to put the messages in a bundle.

  This message now supports array type tags ($[ and $]) in the control/value component of the OSC message. Arrayed control values are applied in the manner of n_setn (i.e., sequentially starting at the indexed or named control). See the Node Messaging helpfile: https://doc.sccode.org/Guides/NodeMessaging.html
  """
  def s_new(
        soundserver,
        synth_def_name,
        synth_id,
        add_action_code,
        add_target_id,
        control_args \\ []
      ) do
    soundserver
    |> send_osc(
      "/s_new",
      [synth_def_name, synth_id, add_action_code, add_target_id] ++ control_args
    )
  end

  def tone(soundserver) do
    # Send a message to play the default sound with a new synth
    synth_definition_name = "default"
    # or could used nextNodeID
    node_id = 100
    add_action = 1
    add_target_id = 0

    soundserver
    |> send_osc("/s_new", [synth_definition_name, node_id, add_action, add_target_id])
  end

  # Special high level
  def synth(soundserver, attr \\ []) do
    synth_definition_name = "default"
    # or could used nextNodeID
    node_id = 100
    add_action = 1
    add_target_id = 0

    soundserver
    |> send_osc("/s_new", [synth_definition_name, node_id, add_action, add_target_id] ++ attr)

    :timer.sleep(200)

    soundserver |> send_osc("/n_free", [node_id])
  end

  @doc section: :synth_commands
  @doc """
  Get control value(s).

  Second parameter is the synth id (integer). The third parameter is the control identifier, which can either be an integer id or a string name.

  Replies to sender with the corresponding /n_set command.

  """
  def s_get(soundserver, synth_id, control_name) do
    soundserver
    |> send_osc("/s_get", [synth_id, control_name])
  end

  @doc section: :synth_commands
  @doc """
  Get ranges of control value(s).
  Get contiguous ranges of controls. Replies to sender with the corresponding /n_setn command.
  """
  def s_getn(soundserver, synth_id, control_name) do
    soundserver
    |> send_osc("/s_getn", [synth_id, control_name])
  end

  @doc section: :synth_commands
  @doc """
  Auto-reassign synth's ID to a reserved value.

  This command is used when the client no longer needs to communicate with the synth and wants to have the freedom to reuse the ID. The server will reassign this synth to a reserved negative number. This command is purely for bookkeeping convenience of the client. No notification is sent when this occurs.
  """
  def s_noid(soundserver, synth_ids) when is_list(synth_ids) do
    soundserver
    |> send_osc("/s_noid", synth_ids)
  end

  def s_noid(soundserver, synth_id) when is_integer(synth_id) do
    soundserver
    |> send_osc("/s_noid", [synth_id])
  end

  ## ##################################
  ## GROUP COMMANDS
  ## ##################################

  @doc section: :group_commands
  @doc """
  Create a new group.
  """
  def g_new(soundserver, node_id, add_action_id, target_node_id) do
    soundserver
    |> send_osc("/s_noid", [node_id, add_action_id, target_node_id])
  end

  @doc section: :group_commands
  @doc """
  Create a new parallel group.
  """
  def p_new(soundserver, node_id, add_action_id, target_node_id) do
    soundserver
    |> send_osc("/p_new", [node_id, add_action_id, target_node_id])
  end

  @doc section: :group_commands
  @doc """
  Adds the node to the head (first to be executed) of the group.
  """
  def g_head(soundserver, node_id, group_id, node_id) do
    soundserver
    |> send_osc("/g_head", [group_id, node_id])
  end

  @doc section: :group_commands
  @doc """
  Adds the node to the tail (last to be executed) of the group.
  """
  def g_tail(soundserver, node_id, group_id, node_id) do
    soundserver
    |> send_osc("/g_tail", [group_id, node_id])
  end

  @doc section: :group_commands
  @doc """
  Frees all nodes in the group. A list of groups may be specified.
  """
  def g_free_all(soundserver, group_id) when is_integer(group_id) do
    soundserver
    |> send_osc("/g_freeAll", [group_id])
  end

  def g_free_all(soundserver, group_ids) when is_list(group_ids) do
    soundserver
    |> send_osc("/g_freeAll", group_ids)
  end

  @doc section: :group_commands
  @doc """
  Free all synths in this group and all its sub-groups.

  Traverses all groups below this group and frees all the synths. Sub-groups are not freed.

  A list of groups may be specified.
  """
  def g_deep_free(soundserver, group_id) when is_integer(group_id) do
    soundserver
    |> send_osc("/g_deepFree", [group_id])
  end

  def g_deep_free(soundserver, group_ids) when is_list(group_ids) do
    soundserver
    |> send_osc("/g_deepFree", group_ids)
  end

  @doc section: :group_commands
  @doc """
  Post a representation of this group's node subtree.

  Posts a representation of this group's node subtree, i.e. all the groups and synths contained within it, optionally including the current control values for synths.

  For the flag code: if not 0 the current control (arg) values for synths will be posted.
  """
  def g_dump_tree(soundserver, group_id, flag_code \\ 1) do
    soundserver
    |> send_osc("/g_dumpTree", [group_id, flag_code])
  end

  @doc section: :group_commands
  @doc """
  Get a representation of this group's node subtree.

  Request a representation of this group's node subtree, i.e. all the groups and synths contained within it. Replies to the sender with a /g_queryTree.reply message listing all of the nodes contained within the group in the following format: https://doc.sccode.org/Reference/Server-Command-Reference.html#/g_queryTree
  """
  def g_query_tree(soundserver, group_id, flag_code \\ 1) do
    soundserver
    |> send_osc("/g_queryTree", [group_id, flag_code])
  end

  ## ##################################
  ## UNIT GENERATOR COMMANDS
  ## ##################################

  @doc section: :ug_commands
  @doc """
  Send a command to a unit generator.

  Sends all arguments following the command name to the unit generator to be performed. Commands are defined by unit generator plug ins.
  """
  def u_cmd(soundserver, node_id, ug_index, command_name, args \\ []) do
    soundserver
    |> send_osc("/u_cmd", [node_id, ug_index, command_name] ++ args)
  end
end
