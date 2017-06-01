defmodule BraidMail.Plugs.TransitParserTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias BraidMail.Plugs.TransitParser

  @opts TransitParser.init([])

  @body <<131, 169, 126, 58, 99, 114, 101, 97, 116, 101, 100, 146, 163, 126,
          35, 109, 207, 0, 0,1, 92, 101, 31, 136, 68, 164, 126, 58, 105, 100,
          146, 163, 126, 35, 117, 146, 207, 8, 133, 164, 84, 239, 42, 75, 61,
          211, 176, 113, 87, 193, 240, 233, 135, 244, 167, 126, 58, 116, 104,
          105, 110, 103, 146, 165, 104, 101, 108, 108, 111, 165, 116, 104, 101,
          114, 101>>

  test "Parses transit from request body" do
    conn = conn(:put, "/message", @body)
            |> put_req_header("content-type", "application/transit+msgpack")

    conn = TransitParser.call(conn, @opts)

    assert conn.state == :unset
    assert conn.body_params == %{
      created: ~N[2017-06-01 19:26:24.324],
      id: "urn:uuid:0885a454-ef2a-4b3d-b071-57c1f0e987f4",
      thing: ["hello", "there"],
    }
  end

  test "Doesn't try to parse plain text" do
    conn = conn(:put, "/message", "hello world")
            |> put_req_header("content-type", "text/plain")

    conn = TransitParser.call(conn, @opts)

    assert conn.state == :unset
    assert %Plug.Conn.Unfetched{} = conn.body_params
  end

  test "Can be composed with VerifyBraidSignature" do
    sig = "93288692f7552fe51594030d3ee763153567a839478b74c3b478740e01c83e24"
    conn = conn(:put, "/message", @body)
            |> put_req_header("content-type", "application/transit+msgpack")
            |> put_req_header("x-braid-signature", sig)

    alias BraidMail.Plugs.VerifyBraidSignature

    conn = conn
           |> VerifyBraidSignature.call(VerifyBraidSignature.init([]))
           |> TransitParser.call(@opts)

    assert conn.state == :unset
    assert conn.body_params == %{
      created: ~N[2017-06-01 19:26:24.324],
      id: "urn:uuid:0885a454-ef2a-4b3d-b071-57c1f0e987f4",
      thing: ["hello", "there"],
    }

  end

end
