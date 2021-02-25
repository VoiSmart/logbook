defmodule Logbook.MixProject do
  @moduledoc false
  use Mix.Project

  def project do
    [
      app: :logbook,
      version: "0.3.0",
      elixir: "~> 1.9",
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
      {:stream_data, "~> 0.4", only: :test},
      {:credo, "~> 1.0", only: [:dev, :test]},
      {:dialyxir, "~> 1.0.0-rc.4", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.10", only: :test}
    ]
  end
end
