defmodule BraidMail.Mixfile do
  use Mix.Project

  def project do
    [app: :braidmail,
     version: "0.1.0",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger, :cowboy, :plug, :timex, :httpoison,
                          :confex, :ecto_mnesia, :ecto],
     env: [listen_port: 4040,
           braid_token: "",
           braid_id: "",
           braid_api_server: "https://api.braid.chat",
           bot_name: "emailbot",
         ],
     mod: {BraidMail.Application, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [{:cowboy, "~> 1.0.0"},
     {:plug, "~> 1.0"},
     {:message_pack, "~> 0.2.0"},
     {:uuid, "~> 1.1"},
     {:timex, "~> 3.0"},
     {:httpoison, "~> 0.11.1"},
     {:ecto_mnesia, "~> 0.9.0"},
     {:ecto, "~> 2.1"},
     {:poison, "~> 3.0"},
     {:html_entities, "~> 0.3"},
     {:distillery, "~> 1.5", runtime: false},
     {:confex, "~> 1.5"},
   ]
  end
end
