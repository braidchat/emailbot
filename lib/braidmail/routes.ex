defmodule BraidMail.Routes do
  @moduledoc """
  Routes for the email bot
  """
  alias Plug.Conn

  use Plug.Router

  plug :match
  plug :dispatch

  forward "/gmail", to: BraidMail.Routes.Gmail
  forward "/braid", to: BraidMail.Routes.Braid

  match _ do
    conn |> Conn.send_resp(404, "Dunno about that?")
  end
end
