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
    case MessagePack.unpack!(body) do
      {:ok, parsed} -> {:ok, from_transit(parsed), conn}
      _ -> raise Plug.Parsers.ParseError
    end
  end

  @doc ~S"""
  Parse a map that has been converted from its transport format into a
  dictionary with proper transit types

  ## Example

      iex> BraidMail.Parsers.Transit.from_transit(
      ...> %{"~:content" => "bot message with mentions",
      ...> "~:group-id" => ["~#u", [6273459376532637008, -7699670969090207191]],
      ...> "~:id" => ["~#u", [6293944736955582425, -8992464959676820504]],
      ...> "~:mentioned-tag-ids" => [["~#u", [-5080801676494353203, -7989731185396700233]],
      ...> ["~#u", [-3600665235774028423, -9179438085886213543]]],
      ...> "~:mentioned-user-ids" => [["~#u", [6364412569462852024, -5836293616197882762]]],
      ...> "~:thread-id" => ["~#u", [6283173812582826269, -4670737039013049002]],
      ...> "~:user-id" => ["~#u", [6293933501437199116, -7244934908353538652]]})
      %{content: "bot message with mentions",
        "group-id": "570fce10-9312-4550-9525-460c57fd9229",
        id: "57589564-3a2d-47d9-8334-58c36750d3e8",
        "mentioned-tag-ids": ["b97d5dcb-6258-4ccd-911e-c5d17b91abb7",
                              "ce07de0b-9297-4579-809c-15b2150f8259"],
        "mentioned-user-ids": ["5852ef83-06dd-49b8-af01-51e0c9a52c76"],
        "thread-id": "5732514a-f909-411d-bf2e-3568de5e0d56",
        "user-id": "57588b2c-4118-430c-9b74-d2160ec295a4"}
  """
  def from_transit(map) do
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
