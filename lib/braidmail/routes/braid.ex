defmodule BraidMail.Routes.Braid do
  @moduledoc """
  Routes for braid webhooks
  """
  alias Plug.Conn

  use Plug.Router

  plug :match
  plug BraidMail.Plugs.VerifyBraidSignature
  plug BraidMail.Plugs.TransitParser
  plug :dispatch

  put "/message" do
    spawn BraidMail.Messaging, :handle_message, [conn.body_params]
    conn
    |> Conn.put_resp_content_type("text/plain")
    |> Conn.send_resp(200, "message received")
  end
end

