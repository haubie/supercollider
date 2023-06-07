
defmodule SuperCollider.SynthDef do
  @moduledoc """
  The SynthDef is module and struct for SuperCollider Synthesis Definitions.

  This module includes functions for:
  * converting binary scsyndef to a `%SynthDef{}` struct with parser/1 or from_file/1
  * encoding `%SynthDef{}` to binary scsyndef file format.

  The SynthDef struct contains the:

  * the name of the synth definition
  * number of constants
  * list of constant values
  * number of parameters
  * [float32] * P - initial parameter values
  * number of parameter names
  * list of named parameters and their index
  * number of unit generators (UGens)
  * list of UGens (using the `%SuperCollider.SynthDef.UGen{}` struct)
  * number of variants
  * list of named varient specs (named key-value pairs with the value as a float.)

  **TODO: Currently there isn't a 'friendly' DSL for creating SynthDefs but that is on the roadmap!**

  ## Example - create a SynthDef from scratch
  This example:
  - creates a brown-noise SynthDef
  - encodes it to binary format
  - sends it to SuperCollider (scsynth or supernova)
  - play it by sending the `:s_new` command
  - stop it by sending the `:n_free` command

  ```
  # Define the brown noise SynthDef and call it 'ambient'
  brown_noise_synthdef =
    [
      %SuperCollider.SynthDef{
        name: "ambient",
        constant_count: 1,
        constant_values_list: [0.2],
        parameter_count: 1,
        parameter_values_list: [0.0],
        parameter_names_count: 1,
        parameter_names_list: [
          %{_enum_index: 0, parameter_index: 0, parameter_name: "out"}
        ],
        ugen_count: 4,
        ugen_specs_list: [
          %SuperCollider.SynthDef.UGen{
            class_name: "Control",
            calculation_rate: 1,
            special_index: 0,
            inputs_count: 0,
            input_specs_list: [],
            outputs_count: 1,
            output_specs_list: [%{_enum_count: 0, calculation_rate: 1}]
          },
          %SuperCollider.SynthDef.UGen{
            class_name: "BrownNoise",
            calculation_rate: 2,
            special_index: 0,
            inputs_count: 0,
            input_specs_list: [],
            outputs_count: 1,
            output_specs_list: [%{_enum_count: 0, calculation_rate: 2}]
          },
          %SuperCollider.SynthDef.UGen{
            class_name: "BinaryOpUGen",
            calculation_rate: 2,
            special_index: 2,
            inputs_count: 2,
            input_specs_list: [
              %{_enum_count: 0, index: 1, output_index: 0, type: :ugen},
              %{_enum_count: 1, index: 0, type: :constant}
            ],
            outputs_count: 1,
            output_specs_list: [%{_enum_count: 0, calculation_rate: 2}]
          },
          %SuperCollider.SynthDef.UGen{
            class_name: "Out",
            calculation_rate: 2,
            special_index: 0,
            inputs_count: 2,
            input_specs_list: [
              %{_enum_count: 0, index: 0, output_index: 0, type: :ugen},
              %{_enum_count: 1, index: 2, output_index: 0, type: :ugen}
            ],
            outputs_count: 0,
            output_specs_list: []
          }
        ],
        varient_count: 0,
        varient_specs_list: []
      }
    ]
  ```
  Encode the SynthDef into binary format:
  ```
  sc_binary = SynthDef.to_binary(brown_noise_synthdef)
  ```
  Assuming SuperCollider (scsynth or supernova) is running and `SuperCollider.SoundServer` has been started, e.g. through `SuperCollider.start()`, you can send this binary SynthDef to the server and play it!

  Send the binary to SuperCollider server (scsynth or supernova):
  ```
  SuperCollider.command(:d_recv, sc_binary)
  ```
  You can then play the brown noise by issuing the following command. This will load it on node 100:
  ```
  SuperCollider.command(:s_new, ["ambient", 100, 1, 0, []])
  ```
  You can stop it by freeing node 100:
  ```
  SuperCollider.command(:n_free, 100)
  ```
  """

  alias SuperCollider.SynthDef
  alias SuperCollider.SynthDef.Parser
  alias SuperCollider.SynthDef.UGen
  alias SuperCollider.SynthDef.Encoder
  alias SuperCollider.SynthDef.ScFile

  # The name of the synth definition
  # All of the constants used in the UGen graph
  # Names for parameters.
  # Parameters can have no name, and a single name can be used for multiple parameters.
  # The list of UGens that make up this synth definition.
  # The variants of this synth definition.

  defstruct ~w[
    name

    constant_count constant_values_list

    parameter_count parameter_values_list
    parameter_names_count parameter_names_list

    ugen_count ugen_specs_list

    varient_count varient_specs_list
  ]a


  @doc """
  Defines a new SynthDef.

  Takes a name (string) as the first parameter.

  A SynthDef conisits of the following:
  * name (of synthdef)
  * constants
  * parameters
  * parameter names
  * UGen specs
  * varient specs

  """
  def new(name) do
    %SynthDef{name: name}
  end

  @doc """
  Encodes one or more `%SynthDef{}` into SuperCollider's binary file format.

  This function is the same as `SuperCollider.SynthDef.ScFile.encode/1`.
  """
  def to_binary(synthdef), do: ScFile.encode(synthdef)

  @doc """
  Parses a SuperCollider .scynthdef binary file into an`%ScFile{}` struct.

  This function is similar to `SuperCollider.SynthDef.ScFile.parse/1` except this function will only return the list of `%SyntDef{}`'s contained in the file, and not any of the other file metadata.
  """
  def from_file(filename) do
    parsed_file = ScFile.parse(filename)
    parsed_file.synth_defs
  end


  @doc """
  Parses syndef binary data. This function is not usually called directly, but is automatically called as part of `ScFile.parse(filename)`.

  Parsing of the SynthDef is in the follwoing order:
  * name (of synthdef)
  * constants
  * parameters
  * parameter names
  * UGen specs
  * varient specs.

  Returns a tuple in the format `{%SynthDef{}, binary_data}`. `binary_data` should be empty if all data was successfully parsed.
  """
  def parse(bin_data) do
      {%SynthDef{}, bin_data}
      |> parse_synthdef_name()
      |> parse_synthdef_constants()
      |> parse_synthdef_parameters()
      |> parse_synthdef_parameter_names()
      |> UGen.parse()
      |> parse_synthdef_varients()
  end

  @doc """
  Encodes SynthDefs into SuperCollider's binary format.

  It takes as its first parameter either a list of `%SynthDef{}` or an individual `%SynthDef{}`.

  This function is not usually called directly, but is automatically called as part of `SuperCollider.SynthDef.ScFile.encode(synthdef)`.
  """
  def encode(synthdefs) when is_list(synthdefs) do
    synthdefs
    |> Enum.map(fn synthdef -> encode(synthdef) end)
    |> Enum.join(<<>>)
  end

  def encode(synthdef) do
      Encoder.write_pstring(synthdef.name) <>
      Encoder.write_32(synthdef.constant_count) <>
      Encoder.write_floats(synthdef.constant_values_list) <>
      Encoder.write_32(synthdef.parameter_count) <>
      Encoder.write_floats(synthdef.parameter_values_list) <>
      Encoder.write_32(synthdef.parameter_names_count) <>
      Encoder.write_name_integer_pairs(synthdef.parameter_names_list) <>
      UGen.encode(synthdef.ugen_count, synthdef.ugen_specs_list) <>
      Encoder.write_16(synthdef.varient_count) <>
      Encoder.write_name_float_pairs(synthdef.varient_specs_list)
  end

  defp parse_synthdef_name({synth_def_struct, bin_data}) do
    {synth_name, rest_synthdef} = Parser.parse_pstring(bin_data)

    {
      %SynthDef{synth_def_struct | name: synth_name},
      rest_synthdef
    }
  end

  defp parse_synthdef_constants({synth_def_struct, bin_data}) do
    {num_constants, rest_synthdef} = Parser.parse_integer_32(bin_data)
    {constant_values_list, rem_binary} = Parser.parse_floats(rest_synthdef, num_constants)

    {
      %SynthDef{synth_def_struct | constant_count: num_constants, constant_values_list: constant_values_list},
      rem_binary
    }
  end

  defp parse_synthdef_parameters({synth_def_struct, bin_data}) do
    {num_params, rest_synthdef} = Parser.parse_integer_32(bin_data)
    {param_values_list, rem_binary} = Parser.parse_floats(rest_synthdef, num_params)

    {
      %SynthDef{synth_def_struct | parameter_count: num_params, parameter_values_list: param_values_list},
      rem_binary
    }
  end

  defp parse_synthdef_parameter_names({synth_def_struct, bin_data}) do
    {num_param_names, rest_synthdef} = Parser.parse_integer_32(bin_data)
    {param_names_and_values_list, rem_binary} = Parser.parse_name_integer_pairs(rest_synthdef, num_param_names)

    {
      %SynthDef{synth_def_struct | parameter_names_count: num_param_names, parameter_names_list: param_names_and_values_list},
      rem_binary
    }
  end

  defp parse_synthdef_varients({synth_def_struct, bin_data}) do
    {num_varients, rest_synthdef} = Parser.parse_integer_16(bin_data)
    {varient_names_and_values_list, rem_binary} = Parser.parse_name_float_pairs(rest_synthdef, num_varients)

    {
      %SynthDef{synth_def_struct | varient_count: num_varients, varient_specs_list: varient_names_and_values_list},
      rem_binary
    }
  end
end
