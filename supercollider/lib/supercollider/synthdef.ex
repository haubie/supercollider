
defmodule SuperCollider.SynthDef do
  @moduledoc """
  The SynthDef is module and struct for SuperCollider Synthesis Definitions.

  The SynthDef struct contains the:

  * the name of the synth definition
  * number of constants
  * list of constant values
  *  number of parameters
  * [float32] * P - initial parameter values
  * number of parameter names
  * list of named parameters and their index
  * number of unit generators (UGens)
  * list of UGens (using the `%SuperCollider.SynthDef.UGen{}` struct)
  * number of variants
  * list of named varient specs (named key-value pairs with the value as a float.)

  The module includes the parser code for synthgens.
  """

  alias SuperCollider.SynthDef
  alias SuperCollider.SynthDef.Parser
  alias SuperCollider.SynthDef.UGen

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
  Parses syndef binary data. This function is not usually called directly, but is automatically called as part of `ScFile.parse(filename)`.

  Parsing of the SynthDef is in the follwoing order:
  * name (of synthdef)
  * constants
  * parameters
  * parameter names
  * UGen specs
  * varient specs
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
