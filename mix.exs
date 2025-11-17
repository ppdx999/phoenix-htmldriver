defmodule PhoenixHtmldriver.MixProject do
  use Mix.Project

  def project do
    [
      app: :phoenix_htmldriver,
      version: "0.10.0",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "A lightweight Phoenix library for testing pure HTML with human-like interactions",
      package: package(),
      docs: docs(),
      source_url: "https://github.com/ppdx999/phoenix-htmldriver",
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:ex_unit]
      ]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

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
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false}
    ]
  end
end
