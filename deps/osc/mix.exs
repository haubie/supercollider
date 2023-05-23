defmodule Osc.Mixfile do
  use Mix.Project

  def project do
    [app: :osc,
     version: "0.1.2",
     elixir: "~> 1.0",
     description: "OSC encoder/decoder for elixir",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps,
     package: package,]
  end

  def application do
    [applications: [:logger]]
  end

  defp deps do
    [{:excheck, "~> 0.5.0", only: [:dev, :test]},
     {:triq, github: "krestenkrab/triq", only: [:dev, :test]},
     {:ex_doc, ">= 0.0.0", only: :dev}]
  end

  defp package do
    [files: ["lib", "mix.exs", "README*"],
     maintainers: ["Cameron Bytheway"],
     licenses: ["MIT"],
     links: %{"GitHub" => "https://github.com/camshaft/osc_ex"}]
  end
end
