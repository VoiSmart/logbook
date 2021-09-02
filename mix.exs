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
      version: "2.0.1",
      elixir: "~> 1.11",
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
      {:benchee, "~> 1.0", only: :dev},
      {:stream_data, "~> 0.5", only: :test},
      {:credo, "~> 1.5", only: [:dev, :test]},
      {:dialyxir, "~> 1.1.0", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.14", only: :test},
      {:ex_doc, "~> 0.25", only: :dev}
    ]
  end
end
