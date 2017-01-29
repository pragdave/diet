defmodule Diet.Mixfile do
  use Mix.Project

  def project do
    [
      app:     :diet,
      version: "0.1.0",
      elixir:  "~> 1.5-dev",
      deps:    deps(),
      build_embedded:  Mix.env == :prod,
      start_permanent: Mix.env == :prod,
    ]
  end

  def application do
    [
      extra_applications: [ :logger ]
    ]
  end

  defp deps do
    [
    ]
  end
end
