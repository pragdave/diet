defmodule Samples.Mixfile do
  use Mix.Project

  def application do
    [
      applications: [ :logger ],
      modules: [ :hangman ]
    ]
  end

  def project do
    [
      app:     :samples,
      version: "1.0.0",
      deps:    deps(),
    ]
  end

  defp deps do
    [
      { :diet, path: "../" }
    ]
  end
end
