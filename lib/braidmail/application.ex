defmodule BraidMail.Application do
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # Define workers and child supervisors to be supervised
    server_port = Application.fetch_env!(:braidmail, :listen_port)
    children = [
      Plug.Adapters.Cowboy.child_spec(:http, BraidMail.Routes, [],
                                      port: server_port),
      supervisor(BraidMail.Repo, []),
      worker(BraidMail.Session, [])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BraidMail.Supervisor]
    ret = Supervisor.start_link(children, opts)

    BraidMail.ReleaseTasks.create()
    BraidMail.ReleaseTasks.migrate()

    ret
  end
end
