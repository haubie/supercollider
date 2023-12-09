
# README
![Supercollider Elixir](https://raw.githubusercontent.com/haubie/supercollider/main/supercollider-elixir-logo.png)

[![Documentation](http://img.shields.io/badge/hex.pm-docs-green.svg?style=flat)](https://hexdocs.pm/supercollider)
[![Package](https://img.shields.io/hexpm/v/supercollider.svg)](https://hex.pm/packages/supercollider)

## Overview
This is an Elixir library for interacting with [SuperCollider](https://supercollider.github.io/), an audio synthesis and composition platform.

SuperCollider as a platform covers both client (*sclang* programming language and *scide* editing environment) and server (*scynth* or *supernova*).

This Elixir library deals exclusively with the latter, that is, interacting with either:

- **scsynth**: a real-time audio server with hundreds of unit generators (UGens) for audio analysis, synthesis, and processing
- **supernova**: an alternative server to scsynth with support for parallel DSP on multi-core processors.

##  Why Elixir?
[Elixir](https://elixir-lang.org/) is dynamic, functional, expressive and fun! 

Running on top of the Erlang virtual machine, you’ll find Elixir on embedded systems (see the [Nerves project](https://nerves-project.org/)) to large multi-node distributed systems and everything in between. Maybe you’ll use this for your next hardware synth project!

Elixir also offers [Livebook](https://livebook.dev/), which can be used as a flexible creative coding environment.

If Elixir isn’t your thing, there are other [libraries in other programming languages](https://github.com/supercollider/supercollider/wiki/Systems-interfacing-with-SC) for interacting with SuperCollider, such as [Overtone (Clojure)](https://overtone.github.io/), [Tidal (Haskell)](https://tidalcycles.org/), [Sonic Pi (built with Ruby, Erlang and Elixir)](https://sonic-pi.net/), [Sorceress (Rust)](https://github.com/ooesili/sorceress) and a number in [Python](https://pypi.org/project/supercollider/).

## Status
This library is currently under active development and it’s API is likely to change.

## Architecture
This library consists of a number of modules, the main ones being:
-	`SuperCollider` which allows you to quickly get going without needing to understand too much of this library’s architecture. Using the APIs at this level is useful for live coding in Livebook.
-	`SuperCollider.SynthDef` which is an Elixir struct representation of SuperCollider’s synth definitions, built from networks of UGens (unit generators) which generate or process both audio and control signals.
-	`SuperCollider.SoundServer` a GenServer which is used to create the main process for sending and listening to scsynth or supernova messages. Messages are sent using [Open Sound Control (OSC)](https://en.wikipedia.org/wiki/Open_Sound_Control) protocol via UDP. When building your own apps, you may wish to add this to your application's supervision tree.

## Example
Below shows some basic examples of:
- starting SuperCollider
- sending commands
- loading and decoding .scsyndef files
- encoding a SynthDef struct to binary format
- sending the encoded SynthDef to scsynth or supernova.

```elixir
alias SuperCollider
alias SuperCollider.SynthDef

# Start the SoundServer. If scynth or supernova isn’t loaded, it will attempt to boot it.
SuperCollider.start_link()

# Get the status from scynth or supernova
SuperCollider.command(:status)

# The response to some commands, such as :status, is stored in the SuperCollider's GenServer state. You can access that response anytime as below:
SuperCollider.response[:status]

# This reurns the status in a list of Tuples like this:
%SuperCollider.Message.Status{
  unused: 1,
  num_ugens: 4,
  num_synths: 1,
  num_groups: 1,
  num_synthdefs_loaded: 5,
  avg_cpu: 1.456225872039795,
  peak_cpu: 14.407142639160156,
  nominal_sample_rate: 44100.0,
  actual_sample_rate: 44099.99716593081
}

# Send a command to play a basic 300Hz sinusoidal sound on node 100
# This assumes the sine SynthGen is installed on the server
SuperCollider.command(:s_new, ["sine", 100, 1, 0, ["freq", 300]])

# Stop the sound by freeing node 100
SuperCollider.command(:n_free, 100) 

# Decode a .scsyndef file into an %SynthDef{} struct
closed_hat = SynthDef.from_file("closed_hat.scsyndef")

# Encode a SynthDef to binary format, which is used by scsynth or supernova
encoded_data = SynthDef.to_binary(closed_hat)

# Send the encoded SynthDef to scynth or supernova
SuperCollider.command(:d_recv, encoded_data)
```

## Getting started

### Installation of SuperCollider
You’ll need to have SuperCollider installed. See SuperCollider’s [downloads]( https://supercollider.github.io/downloads) page for supported platforms. Currently there are Mac, Linux, Windows builds. It can be built on embedded platforms, including [Raspberry Pi]( https://github.com/supercollider/supercollider/blob/develop/README_RASPBERRY_PI.md), [Beagle Bone Black]( https://github.com/supercollider/supercollider/blob/develop/README_BEAGLEBONE_BLACK.md) and [Bela](https://github.com/supercollider/supercollider/blob/develop/README_BELA.md).

### Adding it to your Elixir project
The package can be installed by adding `supercollider` to your list of dependencies in `mix.exs`:
```elixir
def deps do
  [
    {:supercollider, "~> 0.2.0"}
  ]
end
```

### Using within LiveBook and IEx
```elixir
Mix.install([{:supercollider, "~> 0.2.0"}])
```

#### LiveBook tour
Also see the introductory tour in LiveBook at [/livebook/supercollider_tour.livemd](https://github.com/haubie/supercollider/blob/main/livebook/supercollider_tour.livemd).

[![Run in Livebook](https://livebook.dev/badge/v1/blue.svg)](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2Fhaubie%2Fsupercollider%2Fblob%2Fmain%2Flivebook%2Fsupercollider_tour.livemd)

## Documentation
The docs can be found at <https://hexdocs.pm/supercollider>.