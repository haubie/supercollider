defmodule SuperCollider.SynthDef.Encoder do




  ## Encoder helpers

  def write_32(num), do: <<num::big-signed-32>>
  def write_16(num), do: <<num::big-signed-16>>
  def write_8(num), do: <<num::big-integer-8>>

  def write_pstring(string) do
    string_length = String.length(string)
    <<
      string_length::big-integer-8,
      string::binary,
    >>
  end




end
