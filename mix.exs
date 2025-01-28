defmodule Logbook.MixProject do
  @moduledoc false
  use Mix.Project

  def project do
    [
      app: :logbook,
      docs: docs(),
      package: package(),
      description: "A tag based Logger wrapper",
      source_url: "https://github.com/VoiSmart/logbook",
      homepage_url: "https://github.com/VoiSmart/logbook",
      version: "3.0.0",
      elixir: "~> 1.17",
      elixirc_options: [warnings_as_errors: true],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Logbook.Application, []}
    ]
  end

  defp package do
    [
      mantainers: ["Matteo Brancaleoni"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/VoiSmart/logbook"}
    ]
  end

  defp docs do
    [
      main: "Logbook"
    ]
  end

  defp deps do
    [
      {:benchee, "~> 1.3", only: :dev},
      {:stream_data, "~> 1.1", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test]},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:ex_doc, "~> 0.36", only: :dev}
    ]
  end
end
