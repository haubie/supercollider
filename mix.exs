defmodule SuperCollider.MixProject do
  use Mix.Project

  def project do
    [
      app: :supercollider,
      name: "SuperCollider",
      description: "An Elixir library for interacting with SuperCollider, an audio synthesis and composition platform.",
      version: "0.1.1",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: [
        main: "readme",
        source_url: "https://github.com/haubie/supercollider",
        homepage_url: "https://github.com/haubie/supercollider",
        extras: [
          "README.md",
          {:"LICENSE", [title: "License (MIT)"]},
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
