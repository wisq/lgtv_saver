defmodule LgtvSaver.MixProject do
  use Mix.Project

  def project do
    [
      app: :lgtv_saver,
      version: "0.1.0",
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      xref: [exclude: IEx]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {LgtvSaver, []},
      extra_applications: [:logger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:ex_lgtv, git: "https://github.com/wisq/ex_lgtv.git", tag: "55c9b5b"},
      {:wakeonlan, "~> 0.1.0"},
      {:ex_osc, "~> 0.1.0", only: :test},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false},
      {:ex_git_test, "~> 0.1.2", only: [:dev, :test], runtime: false}
    ]
  end
end
