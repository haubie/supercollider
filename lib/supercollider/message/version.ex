defmodule SuperCollider.Message.Version do
    @moduledoc """
    A version message.

    This message sent in response to the `:version` command.
    """
    defstruct [
        :name,
        :major_version,
        :minor_version,
        :patch_name,
        :git_branch,
        :commit_hash_head
    ]

    @doc """
    Parses OSC arguments in the following order:
    1. name: The program name (string). May be "scsynth" or "supernova".
    2. major_version: Major version number. Equivalent to sclang's Main.scVersionMajor.
    3. minor_version: Minor version number. Equivalent to sclang's Main.scVersionMinor.
    4. patch_name: Patch version name (string). Equivalent to the sclang code "." ++ Main.scVersionPatch ++ Main.scVersionTweak.
    5. git_branch: Git branch name (string)
    6. commit_hash_head: First seven hex digits of the commit hash (string).
    """
    def parse(res_data) do
        response_labels = [
            :name,
            :major_version,
            :minor_version,
            :patch_name,
            :git_branch,
            :commit_hash_head
          ]
        struct(__MODULE__, Enum.zip(response_labels, res_data))
    end

end