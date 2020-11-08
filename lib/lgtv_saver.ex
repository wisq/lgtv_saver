defmodule LgtvSaver do
  use Application
  require Logger

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    children =
      if supervise?() do
        Logger.info("LgtvSaver starting ...")
        child_specs()
      else
        []
      end

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Sundog.Supervisor]

    Supervisor.start_link(children, opts)
  end

  def supervise? do
    !iex_running?()
  end

  defp iex_running? do
    Code.ensure_loaded?(IEx) and IEx.started?()
  end

  defp child_specs() do
    tv_id = :lgtv_saver_tv
    saver_id = :lgtv_saver

    saver_spec = %{
      id: saver_id,
      start:
        {LgtvSaver.Saver, :start_link,
         [
           tv_id,
           Application.fetch_env!(:lgtv_saver, :saver_input),
           LgtvSaver.Waker.new(
             Application.fetch_env!(:lgtv_saver, :wake_broadcast),
             Application.fetch_env!(:lgtv_saver, :wake_mac)
           ),
           [name: saver_id]
         ]}
    }

    tv_spec = %{
      id: tv_id,
      start:
        {LgtvSaver.TV, :start_link,
         [
           saver_id,
           Application.fetch_env!(:lgtv_saver, :tv_ip),
           [name: tv_id]
         ]}
    }

    watcher_specs =
      Application.fetch_env!(:lgtv_saver, :bindings)
      |> Enum.map(fn {input, options} ->
        %{
          id: :"lgtv_saver_watcher_#{input}",
          start: {LgtvSaver.Watcher, :start_link, [saver_id, input, options]}
        }
      end)

    [saver_spec, tv_spec] ++ watcher_specs
  end
end
