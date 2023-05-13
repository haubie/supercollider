defmodule SuperCollider.SynthDef.Parser do

  alias SuperCollider.SynthDef.ScFile
  alias SuperCollider.SynthDef

  # 1 Parse file header
  # 2 Parse synthdefs

  def parse(filename \\ "/Users/haubie/Development/supercollider/ambient.scsyndef") do

    # Parse file header
    {sc_file_struct, binary_data} =
      ScFile.open(filename)
      |> ScFile.parse_header()

    # Parse each synthdef
    synth_defs = parse_synthdef(binary_data, [], sc_file_struct.synth_defs_count)

    %ScFile{sc_file_struct | synth_defs: synth_defs}

  end

  def parse_synthdef(_binary_data, acc, 0) do
    acc
    |> Enum.reverse()
  end

  def parse_synthdef(binary_data, acc, num) when num > 0 do
    {synthdef_struct, data} = SynthDef.parse(binary_data)
    parse_synthdef(data, [synthdef_struct] ++ acc, num-1)
  end


  def parse_input_spec(binary, number) do
    parse_input_spec(binary, number, 0, [])
  end

  def parse_input_spec(binary, number, count, acc) when count < number do
    <<
      ugen_index::signed-big-integer-32,
      ugen_constant::big-integer-32,
      ugen_output_index::big-integer-32,
      rest::binary
    >> = binary

    input_spec = [
      %{
        count: count,
        ugen_index: ugen_index,
        ugen_constant: ugen_constant,
        ugen_output_index: ugen_output_index
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
      %{
        ugen_class_name_length: ugen_class_name_length,
        ugen_class_name: ugen_class_name,
        calculation_rate: calculation_rate,
        num_inputs: num_inputs,
        num_outputs: num_outputs,
        special_index: special_index,
        input_specs: input_specs,
        output_specs: output_specs
      }
    ]

    parse_ugens(binary_output_specs, number, count + 1, ugen ++ acc)
  end

  def parse_ugens(binary, _number, _count, acc) do
    {acc, binary}
  end



  ## PARSER HELPERS

  @doc """
  Helper function for parsing multiple big-float-32s in a sequence.
  * binary: hold the binary data
  * number: number of floats to parse in a sequenece
  """

  def parse_floats(binary, number) do
    parse_floats(binary, number, 0, [])
  end

  def parse_floats(binary, number, const_index, acc) when const_index < number do
    <<constant_value::big-float-32, rest_binary::binary>> = binary

    # IO.puts "i(#{const_index}):\t#{constant_value}"
    constant = {const_index, constant_value |> Float.round(3)}

    parse_floats(rest_binary, number, const_index + 1, [constant] ++ acc)
  end

  def parse_floats(binary, _number, _const_index, acc) do
    {acc |> Enum.sort(), binary}
  end


  @doc"""
  Helper function to parse each named parameter
  """

  def parse_param_name_value_pairs(binary, number) do
    parse_param_name_value_pairs(binary, number, 0, [])
  end

  def parse_param_name_value_pairs(binary, number, count, acc) when count < number do
    <<
      param_name_length::big-integer-8,
      param_name::binary-size(param_name_length),
      param_index_value::big-integer-32,
      rest_binary::binary
    >> = binary

    param = %{_enum_index: count, parameter_name: param_name, parameter_index: param_index_value}

    parse_param_name_value_pairs(rest_binary, number, count + 1, [param] ++ acc)
  end

  def parse_param_name_value_pairs(binary, _number, _count, acc) do
    {acc |> Enum.sort(), binary}
  end


end
