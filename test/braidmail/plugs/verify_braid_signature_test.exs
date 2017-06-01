defmodule BraidMail.Plugs.VerifyBraidSignatureTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias BraidMail.Plugs.VerifyBraidSignature

  @opts VerifyBraidSignature.init([])

  test "parses hmac signature properly" do
    sig = "325363b2bb86f5e750ea6c8d6dc2cc01ea29567664a4d0b2a3000405c0508d0c"
    conn = conn(:put, "/message", "something something")
            |> put_req_header("content-type", "text/plain")
            |> put_req_header("x-braid-signature", sig)

    conn = VerifyBraidSignature.call(conn, @opts)

    assert conn.state == :unset
    assert conn.assigns[:body] == "something something"
  end

  test "Rejects bad signatures" do
    sig = "67664a4d0b2a3000405c0508d0c325363b2bb86f5e750ea6c8d6dc2cc01ea295"
    conn = conn(:put, "/message", "something something")
            |> put_req_header("content-type", "text/plain")
            |> put_req_header("x-braid-signature", sig)

    conn = VerifyBraidSignature.call(conn, @opts)

    assert conn.state == :sent
    assert conn.status == 403
  end

end
