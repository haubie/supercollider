defmodule SuperCollider.SynthDef.ScFile do

  alias SuperCollider.SynthDef
  alias SuperCollider.SynthDef.ScFile

  @type_id "SCgf"
  @file_version_2 2

  defstruct type_id: @type_id, file_version: @file_version_2, synth_defs_count: nil, synth_defs: nil

  @doc"""
  Takes a a filename as as single parameter, which is a the filename (and path) of the .scsyndef file to parse. This currently parses SuperCollider **version 2** file format only.

  Returns the populated `%ScFile{}` struct.

  You can access the individual synth definitions via the `:synth_def` key on the struct.

  ## Example
  ```
  alias uperCollider.SynthDef.ScFile

  # Parse the scsyndef file
  sc_file = ScFile.parse("/supercollider/ambient.scsyndef")
  ```

  This returns the parsed file as a struct:

  ```
  %SuperCollider.SynthDef.ScFile{
    type_id: "SCgf",
    file_version: 2,
    synth_defs_count: 1,
    synth_defs: [
      # ... truncated, see below for example contents of the synth_defs key
    ],
        varient_count: 0,
        varient_specs_list: []
      }
    ]
  }
  ```

  You can access the list of synth definitions using the synth_def key:

  ```
  sc_file.synth_defs

  ```
  Which will return
  ```
  [
    %SuperCollider.SynthDef{
      name: "ambient",
      constant_count: 1,
      constant_values_list: [{0, 0.2}],
      parameter_count: 1,
      parameter_values_list: [{0, 0.0}],
      parameter_names_count: 1,
      parameter_names_list: [
        %{_enum_index: 0, parameter_index: 0, parameter_name: "out"}
      ],
      ugen_count: 4,
      ugen_specs_list: [
        %SuperCollider.SynthDef.UGen{
          class_name: "Out",
          calculation_rate: 2,
          special_index: 0,
          inputs_count: 2,
          input_specs_list: [
            %{_enum_count: 1, index: 2, output_index: 0, type: :ugen},
            %{_enum_count: 0, index: 0, output_index: 0, type: :ugen}
          ],
          outputs_count: 0,
          output_specs_list: []
        },
        %SuperCollider.SynthDef.UGen{
          class_name: "BinaryOpUGen",
          calculation_rate: 2,
          special_index: 2,
          inputs_count: 2,
          input_specs_list: [
            %{_enum_count: 1, index: 0, type: :constant},
            %{_enum_count: 0, index: 1, output_index: 0, type: :ugen}
          ],
          outputs_count: 1,
          output_specs_list: [%{calculation_rate: 2, count: 0}]
        },
        %SuperCollider.SynthDef.UGen{
          class_name: "BrownNoise",
          calculation_rate: 2,
          special_index: 0,
          inputs_count: 0,
          input_specs_list: [],
          outputs_count: 1,
          output_specs_list: [%{calculation_rate: 2, count: 0}]
        },
        %SuperCollider.SynthDef.UGen{
          class_name: "Control",
          calculation_rate: 1,
          special_index: 0,
          inputs_count: 0,
          input_specs_list: [],
          outputs_count: 1,
          output_specs_list: [%{calculation_rate: 1, count: 0}]
        }
      ]
  ```
  """

#   file = "/Users/haubie/Development/supercollider/ambient.scsyndef"
# file = "/Users/haubie/Development/supercollider/pink-ambient.scsyndef"
# file = "/Users/haubie/Development/supercollider/hoover.scsyndef"
# file = "/Users/haubie/Development/supercollider/closedhat.scsyndef"

  def parse(filename \\ "/Users/haubie/Development/supercollider/closedhat.scsyndef") do
    # Parse file header
    File.read!(filename) |> decode()
  end

  def decode(binary) do
    # Parse file header
    case binary |> parse_header() do

      {:error, _reason}=error -> error

      {sc_file_struct, binary_data} ->
         # Parse each synthdef
          synth_defs = parse_synthdef(binary_data, [], sc_file_struct.synth_defs_count)

          # Return the populated ScFile struct
          %ScFile{sc_file_struct | synth_defs: synth_defs}
    end
  end


  def encode(synthdefs) when is_list(synthdefs) do
    num_synth_defs = length(synthdefs)
    encode_header(num_synth_defs) <> SynthDef.encode(synthdefs)
  end

  def encode(synthdef) do
    encode_header(1) <> SynthDef.encode(synthdef)
  end


  # The header consists of:
  # * int32 - four byte file type id containing the ASCII characters: "SCgf"
  # * int32 - file version, currently 2.
  # * int16 - number of synth definitions in this file (D).
  defp parse_header(bin_data) do
    <<
      file_type_id::binary-size(4),
      file_version::big-signed-32,
      num_synth_defs::big-signed-16,
      rest::binary
    >> = bin_data

    if file_version == @file_version_2 do
      {
        %ScFile{type_id: file_type_id, file_version: file_version, synth_defs_count: num_synth_defs},
        rest
      }
    else
      {:error, "Incompatible file version. Only synthdef v2 files are supported."}
    end

  end

  defp encode_header(num_synth_defs) do
    <<
      @type_id::binary,
      @file_version_2::big-signed-32,
      num_synth_defs::big-signed-16
    >>
  end

  # The synthdef is the main data structure of the scsyndef file.

  # It consists of:

  # * name
  # * list of:
  #   * constants
  #   * parameter values
  #   * parameter names
  #   * UGen specs
  #   * varient specs

  # See the `SuperCollider.SynthDef` module for details.
  defp parse_synthdef(_binary_data, acc, 0) do
    acc
    |> Enum.reverse()
  end

  defp parse_synthdef(binary_data, acc, num) when num > 0 do
    {synthdef_struct, data} = SynthDef.parse(binary_data)
    parse_synthdef(data, [synthdef_struct] ++ acc, num-1)
  end

end
