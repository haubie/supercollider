defmodule SuperCollider.SynthDef.ScFile do
  @moduledoc """
  A struct representing a .scsyndef file in Elixir and a module for parsing (decoding) and encoding (to binary) SuperCollider synthdef files.

  Currently only version 2 files are supported.

  As a struct, `%ScFile{}` contains the following:
  - `type_id`: a string (`SCgf`) representing the SuperCollider file format
  - `file_version`: currently set to 2 (version 2 is the only file format currently supported)
  - `synth_defs_count`: an integer count of the number of synthdefs within the file.`nil` if empty
  - `synth_defs`: a list of synth definitions. These will use the `%SynthDef{}` struct.

  Key functions in this module include:
  - `parse/1`: for parsing a .scsyndef file. This will read the file from disc and call the `decode/1` function.
  - `encode/1`: for encoding one or more `%SynthDef{}` into the scsyndef binary format.


  ## Example
  ```
  alias SuperCollider.SynthDef.ScFile

  # Parse the scsyndef file
  sc_file = ScFile.parse("/supercollider/ambient.scsyndef")

  # returns the parsed file as a `%ScFile{}` struct
  ```

  See below for further examples.
  """

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
  alias SuperCollider.SynthDef.ScFile

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
      constant_values_list: [0.2],
      parameter_values_list: [0.0],
      parameter_names_list: [%{parameter_index: 0, parameter_name: "out"}],
      ugen_specs_list: [
        %SuperCollider.SynthDef.UGen{
          class_name: "Control",
          calculation_rate: 1,
          special_index: 0,
          input_specs_list: [],
          output_specs_list: [%{_enum_count: 0, calculation_rate: 1}]
        },
        %SuperCollider.SynthDef.UGen{
          class_name: "BrownNoise",
          calculation_rate: 2,
          special_index: 0,
          input_specs_list: [],
          output_specs_list: [%{_enum_count: 0, calculation_rate: 2}]
        },
        %SuperCollider.SynthDef.UGen{
          class_name: "BinaryOpUGen",
          calculation_rate: 2,
          special_index: 2,
          input_specs_list: [
            %{index: 1, output_index: 0, type: :ugen},
            %{index: 0, type: :constant}
          ],
          output_specs_list: [%{_enum_count: 0, calculation_rate: 2}]
        },
        %SuperCollider.SynthDef.UGen{
          class_name: "Out",
          calculation_rate: 2,
          special_index: 0,
          input_specs_list: [
            %{index: 0, output_index: 0, type: :ugen},
            %{index: 2, output_index: 0, type: :ugen}
          ],
          output_specs_list: []
        }
      ],
      varient_specs_list: []
    }
  ]
  ```
  """

# file = "/Users/haubie/Development/supercollider_livebook/ambient.scsyndef"
# file = "/Users/haubie/Development/supercollider_livebook/pink-ambient.scsyndef"
# file = "/Users/haubie/Development/supercollider_livebook/hoover.scsyndef"
# file = "/Users/haubie/Development/supercollider_livebook/closedhat.scsyndef"

  def parse(filename) do
    # Parse file header
    File.read!(filename) |> decode()
  end


  @doc """
  Decodes a scsyndef binary into an `%ScFile{}` struct.

  ## Example
  Read a .scsyndef file from disc and decode it:
  ```
  alias SuperCollider.SynthDef.ScFile

  filename = "/supercollider/closedhat.scsyndef"
  sc_file =
    File.read!(filename)
    |> ScFile.decode()
  ```

  Note: If decoding directly from a file, you can use the `ScFile.parse(filename)` instead.
  """
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

  @doc """
  Takes:
  - an `%ScFile{}` and encodes it into a new scsyndef binary
  - single `%SynthDef{}` and encodes it into a new scsyndef binary (converting it to a `%ScFile{}` first)
  - list of `%SynthDef{}` and encodes them into a new scsyndef binary (converting it to a `%ScFile{}` first).
  """
  def encode(synthdefs) when is_struct(synthdefs, SuperCollider.SynthDef.ScFile), do: encode(synthdefs.synth_defs)
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
