defmodule BraidMail.Parsers.Transit do
  @moduledoc """
  Parsers msgpack-encoded Transit request body.
  """

  def init(opts) do
  end

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
      {:ok, parsed} -> {:ok, from_transit(parsed), conn}
      _ -> raise Plug.Parsers.ParseError
    end
  end

  defp from_transit(map) do
    Enum.into map, %{}, fn {k, v} ->
      {parse_transit_item(k), parse_transit_item(v)}
    end
  end

  defp parse_transit_item("~:" <> kw) do
    String.to_atom(kw)
  end

  defp parse_transit_item(["~#u", [hi64, lo64]]) do
    UUID.binary_to_string!(<<hi64::64>> <> <<lo64::64>>)
  end

  defp parse_transit_item(arr) when is_list(arr) do
    Enum.map arr, &parse_transit_item/1
  end

  defp parse_transit_item(x) do
    x
  end
end
