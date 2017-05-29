defmodule BraidMail.Routes do
  @moduledoc """
  Routes for the email bot
  """

  use BraidMail.Router

  def route("GET", ["hello", foo], conn) do
    conn |> Plug.Conn.send_resp(200, "Hello #{foo}")
  end

  def route("PUT", ["message"], conn) do
    IO.puts "Got message #{inspect conn.body_params}"
    conn
    |> Plug.Conn.put_resp_content_type("text/plain")
    |> Plug.Conn.send_resp(200, "message received")
  end

  def route(_method, _path, conn) do
    conn |> Plug.Conn.send_resp(404, "Dunno about that?")
  end
end
