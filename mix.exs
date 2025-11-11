defmodule PhoenixHtmldriver.MixProject do
  use Mix.Project

  def project do
    [
      app: :phoenix_htmldriver,
      version: "0.4.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "A lightweight Phoenix library for testing pure HTML with human-like interactions",
      package: package(),
      docs: docs(),
      source_url: "https://github.com/ppdx999/phoenix-htmldriver"
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/ppdx999/phoenix-htmldriver"},
      maintainers: ["ppdx999"],
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "PhoenixHtmldriver",
      extras: ["README.md"]
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
      {:floki, "~> 0.36.0"},
      {:phoenix, "~> 1.7"},
      {:plug, "~> 1.14"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end
end
