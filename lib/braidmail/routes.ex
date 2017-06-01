defmodule BraidMail.Routes do
  @moduledoc """
  Routes for the email bot
  """
  alias Plug.Conn

  use Plug.Router

  plug :match
  plug BraidMail.Plugs.VerifyBraidSignature
  plug BraidMail.Plugs.TransitParser
  plug :dispatch

  get "/hello/:foo" do
    conn |> Conn.send_resp(200, "Hello #{foo}")
  end

  put "/message" do
    spawn BraidMail.Messaging, :handle_message, [conn.body_params]
    conn
    |> Conn.put_resp_content_type("text/plain")
    |> Conn.send_resp(200, "message received")
  end

  match _ do
    conn |> Conn.send_resp(404, "Dunno about that?")
  end
end
