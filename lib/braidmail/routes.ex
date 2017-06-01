defmodule BraidMail.Routes do
  @moduledoc """
  Routes for the email bot
  """

  alias Plug.Conn

  defmodule VerifyBraidSignature do
    @behaviour Plug

    def init(_opts) do
      Application.fetch_env!(:braidmail, :braid_token)
    end

    def call(conn, secret) do
      with [sig_hex] <- Conn.get_req_header(conn, "x-braid-signature"),
           {:ok, sig} <- Base.decode16(sig_hex, case: :mixed),
           {:ok, body, conn} <- Conn.read_body(conn),
           :ok <- verify_signature(sig, body, secret) do
        conn |> Conn.assign(:body, body)
      else
        _ -> Conn.send_resp(conn, 403, "Invalid signature for message")
      end
    end

    defp verify_signature(signature, body, secret) do
      if signature == :crypto.hmac(:sha256, secret, body) do
        :ok
      else
        :error
      end
    end
  end

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
