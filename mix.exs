defmodule LgtvSaver.MixProject do
  use Mix.Project

  def project do
    [
      app: :lgtv_saver,
      version: "0.1.0",
      elixir: "~> 1.10",
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

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:ex_lgtv, git: "https://github.com/wisq/ex_lgtv.git", tag: "55c9b5b"},
      {:wakeonlan, "~> 0.1.0"}
    ]
  end
end
