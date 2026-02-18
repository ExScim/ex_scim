defmodule ExScimPhoenix.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/ExScim/ex_scim"

  def project do
    [
      app: :ex_scim_phoenix,
      version: @version,
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Phoenix integration for ExScim SCIM 2.0",
      package: package(),
      source_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ["lib", "mix.exs", "README.md", "../../LICENSE", "../../CHANGELOG.md"]
    ]
  end

  defp deps do
    [
      {:ex_scim, in_umbrella: true},
      {:phoenix, "~> 1.8.0"},
      {:jason, "~> 1.2"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end
end
