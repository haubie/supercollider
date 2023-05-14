defmodule SuperCollider.SynthDef.Parser do
  @moduledoc """
  This is a helper function to parse values from a scsyndef file
  """

  ## PARSER HELPERS

  @doc """
  Helper function for parsing pstrings.

  A pstring is SuperColliders string format, which starts with a 8-bit integer holding the length of the string (`string_length`), followed by a binary of `string_length` with the string data.

  Returns a tuple with string as the first element, and the remainder of the binary data as the second parameter, e.g.:
  `{int_value, binary_data}`.
  """
  def parse_pstring(binary) do
    <<
      string_length::big-integer-8,
      string_value::binary-size(string_length),
      rest::binary
    >> = binary

    {string_value, rest}
  end

  @doc """
  Helper function for parsing 32 bit integers.

  Returns a tuple with a 32-big integer as the first element, and the remainder of the binary data as the second parameter, e.g.:
  `{int_value, binary_data}`.
  """
  def parse_integer_32(binary) do
    <<
      value::big-signed-32,
      rest::binary
    >> = binary
    {value, rest}
  end

  @doc """
  Helper function for parsing 16 bit integers.

  Returns a tuple with a 16-bit integer as the first element, and the remainder of the binary data as the second parameter, e.g.:
  `{int_value, binary_data}`.
  """
  def parse_integer_16(binary) do
    <<
      value::big-signed-16,
      rest::binary
    >> = binary
    {value, rest}
  end

  @doc """
  Helper function for parsing multiple big-float-32s in a sequence.
  * binary: hold the binary data
  * number: number of floats to parse in a sequenece

  Returns a tuple with a list of the floats as the first element, and the remainder of the binary data as the second parameter, e.g.:
  `{float_list, binary_data}`.
  """
  def parse_floats(binary, number) do
    parse_floats(binary, number, 0, [])
  end

  def parse_floats(binary, number, const_index, acc) when const_index < number do
    <<constant_value::big-float-32, rest_binary::binary>> = binary

    constant = {const_index, constant_value |> Float.round(3)}

    parse_floats(rest_binary, number, const_index + 1, [constant] ++ acc)
  end

  def parse_floats(binary, _number, _const_index, acc) do
    {acc |> Enum.reverse(), binary}
  end


   @doc """
    Helper function for parsing multiple key-value pairs in a sequence, where the key is a string and the value is an integer.
    * binary: hold the binary data
    * number: number of key-integer value pairs to parse in a sequenece.

    Returns a tuple with a list of the floats as the first element, and the remainder of the binary data as the second parameter, e.g.:
    `{float_list, binary_data}`.
    """
  def parse_name_integer_pairs(binary, number) do
    parse_name_integer_pairs(binary, number, 0, [])
  end

  def parse_name_integer_pairs(binary, number, count, acc) when count < number do
    <<
      param_name_length::big-integer-8,
      param_name::binary-size(param_name_length),
      param_index_value::big-integer-32,
      rest_binary::binary
    >> = binary

    param = %{_enum_index: count, parameter_name: param_name, parameter_index: param_index_value}

    parse_name_integer_pairs(rest_binary, number, count + 1, [param] ++ acc)
  end

  def parse_name_integer_pairs(binary, _number, _count, acc) do
    {acc |> Enum.reverse(), binary}
  end

    @doc """
    Helper function for parsing multiple key-value pairs in a sequence, where the key is a string and the value is a a float.
    * binary: hold the binary data
    * number: number of key-float value pairs to parse in a sequenece.

    Returns a tuple with a list of the floats as the first element, and the remainder of the binary data as the second parameter, e.g.:
    `{float_list, binary_data}`.
    """

  def parse_name_float_pairs(binary, number) do
    parse_name_float_pairs(binary, [], number)
  end

  def parse_name_float_pairs(binary, acc, number) when number > 0 do
    <<
      name_length::big-integer-8,
      name::binary-size(name_length),
      index_value::big-float-32,
      rest_binary::binary
    >> = binary

    param = %{name: name, index_value: index_value |> Float.round(3)}
    parse_name_float_pairs(rest_binary, [param] ++ acc, number-1)
  end

  def parse_name_float_pairs(binary, acc, 0) do
   {acc |> Enum.reverse(), binary}
  end



end
