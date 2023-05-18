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
  alias SuperCollider.SynthDef.Parser
  alias SuperCollider.SynthDef.Encoder

  defstruct ~w[
    class_name

    calculation_rate
    special_index

    inputs_count input_specs_list

    outputs_count output_specs_list
  ]a

  @doc"""
  The parse function is used as part deconstructing UGen binary data in SuperCollider scsyndef v2 files.

  It is not usually accessed directly, but automatically called via `SuperCollider.SynthDef.ScFileparse(filename)`.
  """
  def parse({synth_def_struct, binary_data}) do
    {num_ugens, rest_bin_data} = Parser.parse_integer_32(binary_data)
    {ugen_specs_list, rem_binary} = parse_ugens(rest_bin_data, num_ugens)

    {
      %SynthDef{synth_def_struct | ugen_count: num_ugens, ugen_specs_list: ugen_specs_list},
      rem_binary
    }
  end


  def encode(ugen_count, ugen_specs_list) do

    specs =
      ugen_specs_list
      |> Enum.map(fn ugen ->

        ugen_header =
          <<
            String.length(ugen.class_name)::big-integer-8,
            ugen.class_name::binary,
            ugen.calculation_rate::big-integer-8,
            ugen.inputs_count::big-integer-32,
            ugen.outputs_count::big-integer-32,
            ugen.special_index::big-integer-16
          >>

        ugen_input_specs =
          ugen.input_specs_list
          |> Enum.map(fn spec -> encode_input_spec(spec) end)
          |> Enum.join(<<>>)

        ugen_output_specs =
          ugen.output_specs_list
          |> Enum.map(fn spec ->
            <<spec.calculation_rate::big-integer-8>>
          end)
          |> Enum.join(<<>>)

        ugen_header <> ugen_input_specs <> ugen_output_specs
      end)
      |> List.flatten()
      |> Enum.join(<<>>)

      Encoder.write_32(ugen_count) <> specs
  end

  defp encode_input_spec(%{type: :constant, index: index_of_ugen_OR_index_of_output_gen}) do
    <<
      (-1)::signed-big-integer-32,
      index_of_ugen_OR_index_of_output_gen::big-integer-32
    >>
  end

  defp encode_input_spec(%{type: :ugen, index: ugen_index_or_constant_flag, output_index: index_of_ugen_OR_index_of_output_gen}) do
    <<
      ugen_index_or_constant_flag::signed-big-integer-32,
      index_of_ugen_OR_index_of_output_gen::big-integer-32
    >>
  end


  defp parse_ugens(binary, number) do
    parse_ugens(binary, number, 0, [])
  end

  defp parse_ugens(binary, number, count, acc) when count < number do
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

  defp parse_ugens(binary, _number, _count, acc) do
    {acc |> Enum.reverse(), binary}
  end


  defp parse_input_spec(binary, number) do
    parse_input_spec(binary, number, 0, [])
  end

  defp parse_input_spec(binary, number, count, acc) when count < number do
    <<
      ugen_index_or_constant_flag::signed-big-integer-32,
      index_of_ugen_OR_index_of_output_gen::big-integer-32,
      rest::binary
    >> = binary

    input_spec =
      case ugen_index_or_constant_flag do
        -1 ->
          # CONSTANT IF -1
            %{
              _enum_count: count,
              type: :constant,
              index: index_of_ugen_OR_index_of_output_gen,
            }

        _ -> # OTHERWISE ITS A UGEN
            %{
              _enum_count: count,
              type: :ugen,
              index: ugen_index_or_constant_flag,
              output_index: index_of_ugen_OR_index_of_output_gen
            }
      end

    parse_input_spec(rest, number, count + 1, [input_spec] ++ acc)
  end

  defp parse_input_spec(binary, _number, _count, acc) do
    {acc |> Enum.reverse(), binary}
  end

  defp parse_output_spec(binary, number) do
    parse_output_spec(binary, number, 0, [])
  end

  defp parse_output_spec(binary, number, count, acc) when count < number do
    <<output_calc_rate::big-integer-8, rest::binary>> = binary
    output_spec = [%{_enum_count: count, calculation_rate: output_calc_rate}]
    parse_output_spec(rest, number, count + 1, output_spec ++ acc)
  end

  defp parse_output_spec(binary, _number, _count, acc) do
    {acc |> Enum.reverse(), binary}
  end

end
