defmodule SuperCollider.Message.Status do
    @moduledoc """
    A status message.

    This message sent in response to the `:status` command.
    """

    defstruct [
        :unused,
        :num_ugens,
        :num_synths,
        :num_groups,
        :num_synthdefs_loaded,
        :avg_cpu,
        :peak_cpu,
        :nominal_sample_rate,
        :actual_sample_rate
    ]

    @doc """
    Parses OSC arguments in the following order:

    1. `unused:` Unused
    2. `num_ugens:` Number of unit generators
    3. `num_synths:` Number of synths
    4. `num_groups:` Number of groups
    5. `num_synthdefs_loaded:` Number of loaded synth definitions
    6. `avg_cpu:` Average percent CPU usage for signal processing
    7. `peak_cpu:` Peak percent CPU usage for signal processing
    8. `nominal_sample_rate:` Nominal sample rate
    9. `actual_sample_rate:` Actual sample rate
    """
    def parse(res_data) do
        response_labels = [
            :unused,
            :num_ugens,
            :num_synths,
            :num_groups,
            :num_synthdefs_loaded,
            :avg_cpu,
            :peak_cpu,
            :nominal_sample_rate,
            :actual_sample_rate
          ]
        struct(__MODULE__, Enum.zip(response_labels, res_data))
    end

end