defmodule ExScimUmbrella.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.1",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      source_url: "https://github.com/ExScim/ex_scim",
      homepage_url: "https://github.com/ExScim/ex_scim"
    ]
  end

  defp description do
    "SCIM 2.0 protocol implementation for Elixir"
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/ExScim/ex_scim"}
    ]
  end

  defp deps do
    []
  end
end
