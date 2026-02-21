defmodule ExScimEcto.MixProject do
  use Mix.Project

  @version "0.1.1"
  @source_url "https://github.com/ExScim/ex_scim"

  def project do
    [
      app: :ex_scim_ecto,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Ecto-based storage adapter for ExScim",
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
      {:ecto_sql, "~> 3.0"},
      {:postgrex, ">= 0.0.0"},
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
