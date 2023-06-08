# ![Supercollider Elixir](https://raw.githubusercontent.com/haubie/supercollider/main/supercollider-elixir-logo.png)

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

If Elixir isn’t your thing, there are other libraries in other programming languages for interacting with SuperCollider, such as [Overtone (Clojure)](https://overtone.github.io/), [Tidal (Haskell)](https://tidalcycles.org/), [Sonic Pi (built with Ruby, Erlang and Elixir)](https://sonic-pi.net/), [Sorceress (Rust)](https://github.com/ooesili/sorceress) and a number in [Python](https://pypi.org/project/supercollider/).

## Status
This library is currently under active development and it’s API is likely to change.

## Architecture
This library consists of a number of modules, the main ones being:
-	`SuperCollider` which allows you to quickly get going without needing to understand too much of this library’s architecture.
-	`SuperCollider.SoundServer` a GenServer which is used to create the main process for sending and listening to scsynth or supernova messages. Messages are sent using OSC packets.
-	`SuperCollider.SynthDef` which is an Elixir struct representation of SuperCollider’s synth definitions, built from networks of UGens (unit generators) which generate or process both audio and control signals.

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
SuperCollider.start()

# Get the status from scynth or supernova
SuperCollider.command(:status)

# The response to some commands, such as :status, is stored in the SuperCollider's GenServer state. You can access that response anytime as below:
SuperCollider.response[:status]

# This reurns the status in a list of Tuples like this:
# [
#  {"unused", 1},
#  {"number of unit generators", 0},
#  {"number of synths", 0},
#  {"number of groups", 2},
#  {"number of loaded synth definitions", 109},
#  {"average percent CPU usage for signal processing", 0.022731395438313484},
#  {"peak percent CPU usage for signal processing", 0.09797607362270355},
#  {"nominal sample rate", 44100.0},
#  {"actual sample rate", 44099.97439210702}
# ]

# Send a command to play a basic 300Hz sinusoidal sound on node 100
# This assumes the sine UGen in installed on the server
SuperCollider.command(:s_new, ["sine", 100, 1, 1, ["freq", 300]])

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

### Adding it to your Elixir project (coming soon)
The package can be installed by adding `supercollider` to your list of dependencies in `mix.exs`:
```elixir
def deps do
  [
    {:supercollider, "~> 0.1.2"}
  ]
end
```

### Using within LiveBook and IEx (coming soon)
```elixir
Mix.install([{:supercollider, "~> 0.1.2"}])
```
## Documentation
The docs can be found at <https://hexdocs.pm/supercollider>.