defmodule SuperCollider.SynthDef.Encoder do

  @moduledoc """
  Helper functions to encode Elixir data types into the binary format used by SuperCollider.
  """

  ## Encoder helpers

  @doc """
  Takes a string and encodes it into SuperCollider's pstring format.
  """
  def write_pstring(string) do
    string_length = String.length(string)
    <<
      string_length::big-integer-8,
      string::binary,
    >>
  end

  @doc """
  Takes an number and encodes it into SuperCollider's 32-bit integer format.
  """
  def write_32(num), do: <<num::big-signed-32>>

  @doc """
  Takes an number and encodes it into SuperCollider's 16-bit integer format.
  """
  def write_16(num), do: <<num::big-signed-16>>

  @doc """
  Takes an number and encodes it into SuperCollider's 8-bit integer format.
  """
  def write_8(num), do: <<num::big-integer-8>>

  @doc """
  Takes an number and encodes it into SuperCollider's 32-bit float format.
  """
  def write_float(num), do: <<num::big-float-32>>

  @doc """
  Takes a list of numbers and encodes it into SuperCollider's 32-bit float array format.
  """
  def write_floats(numbers) when is_list(numbers) do
    numbers |> Enum.map(fn num -> write_float(num) end) |> Enum.join(<<>>)
  end

  @doc """
  Takes a list of key-value pairs and encodes it into SuperCollider's dictionary format.

  In this function, the key-value pairs must be of the following types:
  * key: is a string
  * value: is an integer.
  """
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

  @doc """
  Takes a list of key-value pairs and encodes it into SuperCollider's dictionary format.

  In this function, the key-value pairs must be of the following types:
  * key: is a string
  * value: is a float.
  """
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
