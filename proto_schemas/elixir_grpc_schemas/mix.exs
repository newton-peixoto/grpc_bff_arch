defmodule ElixirGrpcSchemas.MixProject do
  use Mix.Project

  def project do
    [
      app: :elixir_grpc_schemas,
      version: "0.1.0",
      elixir: "~> 1.15",
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
      {:grpc, "~> 0.5.0-beta"},
      {:protobuf, "~> 0.10.0"},
      {:cowlib, "~> 2.8.0", hex: :grpc_cowlib, override: true},
    ]
  end
end
