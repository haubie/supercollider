
defmodule SuperCollider.SynthDef do


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


  def parse(bin_data) do

    {%SynthDef{}, bin_data}
    |> parse_synthdef_name()
    |> parse_synthdef_constants()
    |> parse_synthdef_parameters()
    |> parse_synthdef_parameter_names()
    |> UGen.parse()

  end

  def parse_synthdef_name({synth_def_struct, bin_data}) do
    <<
      synth_name_length::big-integer-8,
      synth_name::binary-size(synth_name_length),
      rest_synthdef::binary
    >> = bin_data

    {
      %SynthDef{synth_def_struct | name: synth_name},
      rest_synthdef
    }
  end

  def parse_synthdef_constants({synth_def_struct, bin_data}) do
    <<
      num_constants::big-integer-32,
      rest_synthdef::binary
    >> = bin_data

  {constant_values_list, rem_binary} = Parser.parse_floats(rest_synthdef, num_constants)

  {
    %SynthDef{synth_def_struct | constant_count: num_constants, constant_values_list: constant_values_list},
    rem_binary
  }

  end

  def parse_synthdef_parameters({synth_def_struct, bin_data}) do
    <<
      num_params::big-integer-32,
      rest_synthdef::binary
    >> = bin_data

  {param_values_list, rem_binary} = Parser.parse_floats(rest_synthdef, num_params)

  {
    %SynthDef{synth_def_struct | parameter_count: num_params, parameter_values_list: param_values_list},
    rem_binary
  }
end

def parse_synthdef_parameter_names({synth_def_struct, bin_data}) do
  <<
    num_param_names::big-integer-32,
    rest_synthdef_params_names::binary
  >> = bin_data


  {param_names_and_values_list, rem_binary} = Parser.parse_param_name_value_pairs(rest_synthdef_params_names, num_param_names)

  {
    %SynthDef{synth_def_struct | parameter_names_count: num_param_names, parameter_names_list: param_names_and_values_list},
    rem_binary
  }

  end

end
