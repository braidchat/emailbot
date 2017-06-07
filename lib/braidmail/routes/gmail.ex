defmodule BraidMail.Routes.Gmail do
  @moduledoc """
  Routes for Gmail webhook/Oauths
  """
  alias Plug.Conn

  alias BraidMail.Gmail

  use Plug.Router

  plug :match
  plug :dispatch

  get "/oauth2" do
    conn = Conn.fetch_query_params(conn)
    case conn.query_params do
      %{error: err} ->
        IO.puts "Error in oauth: #{err}"
        conn |> Conn.send_resp(400, "OAuth2 error: #{err}")
      %{"code" => code, "state" => state} ->
        braid_uri = Application.fetch_env!(:braidmail, :braid_client_server)
        user_id = Gmail.verify_state(state)
        if user_id != nil do
          spawn fn -> Gmail.exchange_code(user_id, code) end
          conn
            |> Conn.put_resp_header("location", braid_uri)
            |> Conn.send_resp(302, "")
        else
          conn |> Conn.send_resp(400, "Bad state token")
        end
    end
  end

  match _ do
    conn |> Conn.send_resp(404, "Dunno about that?")
  end

end
