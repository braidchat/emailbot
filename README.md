# BraidMail

A [Braid Chat](https://github.com/braidchat/braid) bot that lets you manage your email from Braid.

## Development

Create config file `config/dev.exs` and fill in the appropriate information.
See `config/test.exs` for a reference of the config info that should be set.
See below under ["Integrations Setup"](#integrations-setup) how to get the various API tokens.

Run `mix deps.get` to fetch all dependencies.

Run `mix ecto.create` and `mix ecto.migrate` to set up the database.

## Deployment

Create `config/prod.exs` and populate it with the appropriate information.
See `config/test.exs` for a reference of the config info that should be set.

You'll probably also want to put `config :mnesia, :dir, 'data/mnesia'` in `prod.exs`.

To create the release artifact, run

```
$ MIX_ENV=prod mix release --env=prod
```

Then find the created tarball under `_build/prod/rel/braidmail/releases/`, upload it to your server, and extract it.
You'll also want to create a directory for the Mnesia database (e.g. `mkdir -p data/mnesia`).
The bot can then be started as a daemon with `bin/braidmail start` or `bin/braidmail foreground` to run in the foreground (e.g. with Supervisor).
To point the database to the correct host, you'll need to set an environment variable: `MNESIA_HOST=braidmail@127.0.0.1`.
This only seems necessary when starting the server, but not when running the migrations.

Connect to the running process with `bin/braidmail remote_console`.

## Integrations Setup

### Braid Config

Add the bot to your braid group.

The message webhook URL should be `https://<bot address>/braid/message`

Leave "Enable All Public Messages" unchecked and don't set the "group event webhook URL".

Put the "Bot ID" in the config under the key `:braid_id` and the "Bot Token" under the key `:braid_token`.

### Gmail API Keys

Go to the [developer console](https://console.developers.google.com) and create a new OAuth-flow app.
Put the "client id" value in the config under the key `:gmail_id` and the "client secret" under the key `:gmail_secret`.

The "Authorized redirect URIs" should include whatever address the bot is accessible at, with the path `"/gmail/oauth2"`.

Put the URI you set as the authorized redirect URI in the config as `:gmail_redirect_uri`.

You also need to enable the gmail API for the project, which you should be able to do from the developer console by going to dashboard, then clicking "Enable API", then selecting Gmail.

## Installation

<!-- TODO -->

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `braidmail` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:braidmail, "~> 0.1.0"}]
end
```

## Documentation

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc) and published on [HexDocs](https://hexdocs.pm).
Once published, the docs can be found at [https://hexdocs.pm/braidmail](https://hexdocs.pm/braidmail).
