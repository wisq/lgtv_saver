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
    opts = [strategy: :one_for_one, name: LgtvSaver.Supervisor]

    Supervisor.start_link(children, opts)
  end

  def supervise? do
    case Application.get_env(:lgtv_saver, :start, :if_not_iex) do
      true -> true
      false -> false
      :if_not_iex -> !iex_running?()
    end
  end

  defp iex_running? do
    Code.ensure_loaded?(IEx) and IEx.started?()
  end

  @supervisor LgtvSaver.Supervisor
  @tv_id Module.concat(@supervisor, TV)
  @saver_id Module.concat(@supervisor, Saver)

  defp child_specs() do
    main = [
      {LgtvSaver.Saver,
       [
         tv: @tv_id,
         saver_input: Application.fetch_env!(:lgtv_saver, :saver_input),
         waker: generate_waker(),
         name: @saver_id
       ]},
      {LgtvSaver.TV,
       [
         saver: @saver_id,
         ip: Application.fetch_env!(:lgtv_saver, :tv_ip),
         name: @tv_id
       ]}
    ]

    watchers =
      Application.fetch_env!(:lgtv_saver, :bindings)
      |> Enum.map(&watcher_spec/1)

    main ++ watchers
  end

  defp watcher_spec({input, options}) do
    {LgtvSaver.Watcher,
     Enum.to_list(options)
     |> Keyword.merge(
       saver: @saver_id,
       input: input
     )}
    |> Supervisor.child_spec(id: :"watcher_#{input}")
  end

  defp generate_waker do
    with {:ok, broadcast} <- Application.fetch_env(:lgtv_saver, :wake_broadcast),
         {:ok, mac} <- Application.fetch_env(:lgtv_saver, :wake_mac) do
      Logger.info("Wake-on-LAN enabled for #{mac} via #{broadcast}.")
      LgtvSaver.Waker.new(broadcast, mac)
    else
      :error ->
        Logger.info("Wake-on-LAN not enabled.")
        :no_waker
    end
  end
end
