defmodule BraidMail.Plugs.TransitParser do
  @moduledoc """
  Parses msgpack-encoded Transit request body.
  """
  @behaviour Plug

  alias BraidMail.Transit
  alias Plug.Conn

  def init([]), do: false

  @content_type "application/transit+msgpack"

  def call(conn, _opts) do
    if [@content_type] == Conn.get_req_header(conn, "content-type") do
      decode(conn)
    else
      conn
    end
  end

  defp decode(conn) do
    body = conn.assigns[:body] ||
           with {:ok, body, _} <- Conn.read_body(conn), do: body
    case MessagePack.unpack(body) do
      {:ok, parsed} ->
        %{conn | body_params: Transit.from_transit(parsed)}
      {:error, err} ->
        raise Plug.BadRequestError, message: "Couldn't decode msgpack: #{err}"
    end
  end
end
