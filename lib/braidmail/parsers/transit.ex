defmodule BraidMail.Parsers.Transit do
  @moduledoc """
  Parsers msgpack-encoded Transit request body.
  """

  @behaviour Plug.Parsers
  import Plug.Conn

  def parse(conn, "application", "transit+msgpack", _headers, opts) do
    conn
    |> read_body(opts)
    |> decode()
  end

  def parse(conn, _type, _subtype, _headers, _opts) do
    {:next, conn}
  end

  defp decode({:more, _, conn}) do
    {:error, :too_large, conn}
  end

  defp decode({:error, :timeout}) do
    raise Plug.TimeoutError
  end

  defp decode({:error, _}) do
    raise Plug.BadRequestError
  end

  defp decode({:ok, "", conn}) do
    {:ok, %{}, conn}
  end

  defp decode({:ok, body, conn}) do
    case MessagePack.unpack(body) do
      {:ok, parsed} -> {:ok, BraidMail.Transit.from_transit(parsed), conn}
      _ -> raise Plug.Parsers.ParseError
    end
  end
end
