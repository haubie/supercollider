defmodule SuperCollider.SynthDef.UGen do
  @moduledoc """
  UGens represent calculations with signals. They are the basic building blocks of synth definitions on the server, and are used to generate or process both audio and control signals.

  They're made up of:
  * class_name - Examples include `SinOsc`, `Out`, and `Control`.
  * rate - The rate at which the UGen computes values. There are three rates numbered 0, 1, 2.
  * special_index - This value is used by some unit generators for a special purpose. For example, UnaryOpUGen and BinaryOpUGen use it to indicate which operator to perform. If not used it should be set to zero.
  * inputs - The inputs to this unit generator
  * outputs - The list of outputs of this unit generator. Each element in the list is the `rate` of the output, using the same number as the `rate` field of this struct.
  """

  alias SuperCollider.SynthDef
  alias SuperCollider.SynthDef.UGen

  defstruct ~w[
    class_name

    calculation_rate
    special_index

    inputs_count input_specs_list

    outputs_count output_specs_list
  ]a

  def parse({synth_def_struct, binary_data}) do

    <<
      num_ugens::big-integer-32,
      rest_bin_data::binary
    >> = binary_data

    {ugen_specs_list, rem_binary} = parse_ugens(rest_bin_data, num_ugens)

    {
      %SynthDef{synth_def_struct | ugen_count: num_ugens, ugen_specs_list: ugen_specs_list},
      rem_binary
    }
  end





  def parse_input_spec(binary, number) do
    parse_input_spec(binary, number, 0, [])
  end

  def parse_input_spec(binary, number, count, acc) when count < number do
    <<
      ugen_index::signed-big-integer-32,
      ugen_constant::big-integer-32,
      # ugen_output_index::big-integer-32,
      rest::binary
    >> = binary

    # See: https://github.com/ooesili/sorceress/blob/40388e37b074abe2b837b9d45a12a5674c99435a/src/synthdef/decoder.rs#L166
    # if ugen_index == -1, do: ugen_constant

    input_spec = [
      %{
        _enum_count: count,
        ugen_index: ugen_index,
        ugen_constant: ugen_constant,
        # ugen_output_index: ugen_output_index
      }
    ]

    parse_input_spec(rest, number, count + 1, input_spec ++ acc)
  end

  def parse_input_spec(binary, _number, _count, acc) do
    {acc, binary}
  end

  def parse_output_spec(binary, number) do
    parse_output_spec(binary, number, 0, [])
  end

  def parse_output_spec(binary, number, count, acc) when count < number do
    <<output_calc_rate::big-integer-8, rest::binary>> = binary
    output_spec = [%{count: count, calculation_rate: output_calc_rate}]
    parse_output_spec(rest, number, count + 1, output_spec ++ acc)
  end

  def parse_output_spec(binary, _number, _count, acc) do
    {acc, binary}
  end

  def parse_ugens(binary, number) do
    parse_ugens(binary, number, 0, [])
  end

  def parse_ugens(binary, number, count, acc) when count < number do
    <<
      ugen_class_name_length::big-integer-8,
      ugen_class_name::binary-size(ugen_class_name_length),
      calculation_rate::big-integer-8,
      num_inputs::big-integer-32,
      num_outputs::big-integer-32,
      special_index::big-integer-16,
      binary_ugen_rest::binary
    >> = binary

    {input_specs, binary_input_specs} = parse_input_spec(binary_ugen_rest, num_inputs)
    {output_specs, binary_output_specs} = parse_output_spec(binary_input_specs, num_outputs)

    ugen = [
      %UGen{
        # ugen_class_name_length: ugen_class_name_length,
        class_name: ugen_class_name,
        calculation_rate: calculation_rate,
        inputs_count: num_inputs,
        outputs_count: num_outputs,
        special_index: special_index,
        input_specs_list: input_specs,
        output_specs_list: output_specs
      }
    ]

    parse_ugens(binary_output_specs, number, count + 1, ugen ++ acc)
  end

  def parse_ugens(binary, _number, _count, acc) do
    {acc, binary}
  end


end