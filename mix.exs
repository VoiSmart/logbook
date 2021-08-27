defmodule Logbook.MixProject do
  @moduledoc false
  use Mix.Project

  def project do
    [
      app: :logbook,
      version: "2.0.0",
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

  defp deps do
    [
      # development stuff
      {:benchee, "~> 1.0", only: :dev},
      {:stream_data, "~> 0.5", only: :test},
      {:credo, "~> 1.5", only: [:dev, :test]},
      {:dialyxir, "~> 1.1.0", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.14", only: :test}
    ]
  end
end
