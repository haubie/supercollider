defmodule OSC.TimeTag do
  defstruct seconds: 0,
            fraction: 0

  def from_float(seconds) do
    s = trunc(seconds)
    %__MODULE__{
      seconds: s,
      fraction: trunc((seconds - s) * 4_294_967_296)
    }
  end

  def parse(<< seconds :: big-size(32), fraction :: big-size(32) >>, options) do
    %__MODULE__{seconds: seconds, fraction: fraction}
    |> OSC.Decoder.decode(options)
  end
end

defimpl OSC.Encoder, for: OSC.TimeTag do
  def encode(%{seconds: seconds, fraction: fraction}, _) do
    << seconds :: big-size(32), fraction :: big-size(32) >>
  end
  def flag(_), do: ?t
end
