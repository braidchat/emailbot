defmodule BraidMail.Routes do
  @moduledoc """
  Routes for the email bot
  """

  use Plug.Router

  plug :match
  plug Plug.Parsers, parsers: [Elixir.BraidMail.Parsers.Transit],
                     pass: ["application/transit+msgpack"]
  plug :dispatch

  get "/hello/:foo" do
    conn |> Plug.Conn.send_resp(200, "Hello #{foo}")
  end

  put "/message" do
    spawn BraidMail.Messaging, :handle_message, [conn.body_params]
    conn
    |> Plug.Conn.put_resp_content_type("text/plain")
    |> Plug.Conn.send_resp(200, "message received")
  end

  match _ do
    conn |> Plug.Conn.send_resp(404, "Dunno about that?")
  end
end
