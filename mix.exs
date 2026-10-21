defmodule WuzzSupport.MixProject do
  use Mix.Project

  def project do
    [
      app: :wuzz_support,
      version: "0.1.0",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      releases: [wuzz_support: [include_executables_for: [:unix]]],
      deps: deps()
    ]
  end

  def application do
    [mod: {WuzzSupport.Application, []}, extra_applications: [:logger, :runtime_tools]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix, "~> 1.7"},
      {:mongodb_driver, "~> 1.5"},
      {:jason, "~> 1.4"},
      {:bandit, "~> 1.5"},
      {:jose, "~> 1.11"},
      {:cors_plug, "~> 3.0"}
    ]
  end

  defp aliases do
    [setup: ["deps.get"]]
  end
end
