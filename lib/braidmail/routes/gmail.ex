defmodule BraidMail.Routes.Gmail do
  @moduledoc """
  Routes for Gmail webhook/Oauths
  """
  alias Plug.Conn

  use Plug.Router

  plug :match
  plug :dispatch

  get "/oauth2" do
    conn |> Conn.send_resp(200, "ok")
  end

  match _ do
    conn |> Conn.send_resp(404, "Dunno about that?")
  end
end
