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

## Integrations Setup

### Braid Config

Add the bot to your braid group.

The message webhook URL should be `https://<bot address>/message`

Leave "Enable All Public Messages" unchecked and don't set the "group event webhook URL".

Put the "Bot ID" in the config under the key `:braid_id` and the "Bot Token" under the key `:braid_token`.

### Gmail API Keys

Go to the [developer console](https://console.developers.google.com) and create a new OAuth-flow app.
Put the "client id" value in the config under the key `:gmail_id` and the "client secret" under the key `:gmail_secret`.

The "Authorized JavaScript origins" should include `https://braid.chat` (or whatever the Braid server you will be using the bot with).
The "Authorized redirect URIs" should include whatever address the bot is accessible at (in dev, you may want to use [ngrok](https://ngrok.com/) to test webhooks; you can add that address too).

Put the URI you set as the authorized redirect URI in the config as `:gmail_redirect_uri`.

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
