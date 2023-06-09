defmodule SuperCollider.MixProject do
  use Mix.Project

  def project do
    [
      app: :supercollider,
      name: "SuperCollider",
      description: "An Elixir library for interacting with SuperCollider, an audio synthesis and composition platform.",
      version: "0.1.5",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: [
        main: "readme",
        source_url: "https://github.com/haubie/supercollider",
        homepage_url: "https://github.com/haubie/supercollider",
        logo: "logo-hexdoc.png",
        extras: [
          "README.md",
          "livebook/supercollider_tour.livemd",
          {:"LICENSE", [title: "License (MIT)"]},
        ],
        groups_for_modules: [
          # SuperCollider,
          # SuperCollider.SynthDef,
          # SuperCollider.SynthDef.UGen,
          Server: [
            SuperCollider.SoundServer,
            SuperCollider.SoundServer.Command,
            SuperCollider.SoundServer.Response
          ],
          Helpers: [
            SuperCollider.SynthDef.ScFile,
            SuperCollider.SynthDef.Encoder,
            SuperCollider.SynthDef.Parser
          ]
        ],
        groups_for_docs: [
          "OSC communication": &(&1[:section] == :osc),
          "General commands": &(&1[:section] == :top_level_commands),
          "Synth commands": &(&1[:section] == :synth_commands),
          "Node commands": &(&1[:section] == :node_commands),
          "Group commands": &(&1[:section] == :group_commands),
          "Unit generator commands": &(&1[:section] == :ug_commands),
          "Support functions": &(&1[:section] == :encode_decode),
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:osc, "~> 0.1.2"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp package() do
    [
      files: [
        "lib",
        "mix.exs",
        "README.md",
        "LICENSE"
      ],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/haubie/supercollider"},
      maintainers: ["David Haubenschild"]
    ]
  end

end
