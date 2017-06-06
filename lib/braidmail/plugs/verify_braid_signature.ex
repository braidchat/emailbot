defmodule BraidMail.Plugs.VerifyBraidSignature do
  @moduledoc """
  Verifies the X-Braid-Signature for a braid webhook request

  Note that it reads the body to verify the HMAC, so subsequent plugs must read
  the body from `conn.assigns[:body]`.
  """
  @behaviour Plug

  alias Plug.Conn

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
      {:more, _, conn} -> {:error, :too_large, conn}
      {:error, :timeout} -> raise Plug.TimeoutError
      _ ->
        conn
        |> Conn.send_resp(403, "Invalid signature for message")
        |> Conn.halt()
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
