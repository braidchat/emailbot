use Mix.Config

config :braidmail,
  listen_port: 4042,
  braid_token: "foobar",
  braid_id: "16db10c6-1a96-4358-baf6-d66d48513ac3",
  braid_api_server: "http://localhost:10003",
  braid_client_server: "http://localhost:10001",
  gmail_id: "",
  gmail_secret: "",
  gmail_redirect_uri: "http://localhost:4042/gmail/oauth2",
  gmail_hmac_secret: <<77, 202, 82, 152, 63, 34, 64, 154, 108, 194>>
