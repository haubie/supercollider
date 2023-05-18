defmodule SuperCollider.SynthDef.Encoder do

  ## Encoder helpers

  def write_pstring(string) do
    string_length = String.length(string)
    <<
      string_length::big-integer-8,
      string::binary,
    >>
  end

  def write_32(num), do: <<num::big-signed-32>>
  def write_16(num), do: <<num::big-signed-16>>
  def write_8(num), do: <<num::big-integer-8>>

  def write_float(num), do: <<num::big-float-32>>

  def write_floats(numbers) when is_list(numbers) do
    numbers |> Enum.map(fn num -> write_float(num) end) |> Enum.join(<<>>)
  end

  def write_name_integer_pairs(name_value_pairs) do
    name_value_pairs
    |> Enum.map(fn %{parameter_index: parameter_index, parameter_name: parameter_name} ->
      <<
        String.length(parameter_name)::big-integer-8,
        parameter_name::binary,
        parameter_index::big-integer-32
      >>
    end)
    |> Enum.join(<<>>)
  end

  def write_name_float_pairs(name_value_pairs) do
    name_value_pairs
    |> Enum.map(fn %{parameter_index: parameter_index, parameter_name: parameter_name} ->
      <<
        String.length(parameter_name)::big-integer-8,
        parameter_name::binary,
        parameter_index::big-float-32
      >>
    end)
    |> Enum.join(<<>>)
  end


end
