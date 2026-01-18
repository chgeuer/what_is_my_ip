defmodule WhatIsMyIp.MixProject do
  use Mix.Project

  def project do
    [
      app: :what_is_my_ip,
      version: "0.1.0",
      elixir: "~> 1.20-rc",
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:req, "~> 0.5"},
      {:nimble_options, "~> 1.1"}
    ]
  end
end
