defmodule SuperCollider.SynthDef.ScFile do

  alias SuperCollider.SynthDef.ScFile

  @type_id "SCgf"
  @file_version 2

  defstruct type_id: @type_id, file_version: @file_version, synth_defs_count: nil, synth_defs: nil


  def open(file \\ "/Users/haubie/Development/supercollider/ambient.scsyndef") do
    File.read!(file)
  end

  @doc """
  The header consists of:
  * int32 - four byte file type id containing the ASCII characters: "SCgf"
  * int32 - file version, currently 2.
  * int16 - number of synth definitions in this file (D).
  """
  def parse_header(bin_data) do
    <<
      file_type_id::binary-size(4),
      file_version::big-signed-32,
      num_synth_defs::big-signed-16,
      rest::binary
    >> = bin_data

    {
      %ScFile{type_id: file_type_id, file_version: file_version, synth_defs_count: num_synth_defs},
      rest
    }
  end

end
