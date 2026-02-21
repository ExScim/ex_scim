defmodule ExScimPhoenix.MixProject do
  use Mix.Project

  @version "0.1.1"
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
      source_url: @source_url,
      docs: docs()
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"]
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
      files: ["lib", "mix.exs", "README.md"]
    ]
  end

  defp deps do
    [
      ex_scim_dep(),
      {:phoenix, "~> 1.8.0"},
      {:jason, "~> 1.2"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp ex_scim_dep do
    if System.get_env("HEX_BUILD") do
      {:ex_scim, "~> 0.1.0"}
    else
      {:ex_scim, in_umbrella: true}
    end
  end
end
