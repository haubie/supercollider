defmodule SuperCollider.Message.Late do
    @moduledoc """
    A command was received too late.

    This is sent by the server when the command was received too late to be executed on time.
    
    According to the SuperCollider offical docs, this is not yet implemented. See: https://doc.sccode.org/Reference/Server-Command-Reference.html#/late
    """

    defstruct [
        :original_timestamp,
        :executed_timestamp
    ]

    @doc """
    Parses OSC arguments in the following order:
    1. original_high: high 32 bits of the original time stamp
    2. original_low: low 32 bits of the original time stamp
    3. executed_high: high 32 bits of the time it was executed
    4. executed_low: low 32 bits of the time it was executed.

    The above OSC argument are use to populate the struct with two lists as follows:
    - `original_timestamp:` [original_high, original_low]
    - `executed_timestamp:` [executed_high, executed_low]
    """
    def parse([or_hi, or_low, ex_hi, ex_low]=_res_data) do
        %__MODULE__{
            original_timestamp: [or_hi, or_low],
            executed_timestamp: [ex_hi, ex_low]
        }
    end

end