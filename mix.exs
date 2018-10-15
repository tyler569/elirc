defmodule Elirc.Mixfile do
  use Mix.Project

  def project do
    [
      app: :elirc,
      version: "0.1.0",
      elixir: "~> 1.5",
      # escript: [main_module: Elirc],
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Elirc, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
    ]
  end
end
