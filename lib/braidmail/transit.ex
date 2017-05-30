defmodule BraidMail.Transit do

  @moduledoc """
  Module for parsing transit once it's been turned into a native map (i.e.
  after the underlying MessagePack or JSON has been parsed)
  """

  @doc ~S"""
  Parse a map that has been converted from its transport format into a
  dictionary with proper transit types

  ## Example

      iex> BraidMail.Transit.from_transit(
      ...> %{"~:content" => "bot message with mentions",
      ...> "~:group-id" => ["~#u", [6273459376532637008, -7699670969090207191]],
      ...> "~:id" => ["~#u", [6293944736955582425, -8992464959676820504]],
      ...> "~:mentioned-tag-ids" => [["~#u", [-5080801676494353203, -7989731185396700233]],
      ...> ["~#u", [-3600665235774028423, -9179438085886213543]]],
      ...> "~:mentioned-user-ids" => [["~#u", [6364412569462852024, -5836293616197882762]]],
      ...> "~:thread-id" => ["~#u", [6283173812582826269, -4670737039013049002]],
      ...> "~:user-id" => ["~#u", [6293933501437199116, -7244934908353538652]],
      ...> "~:created-at" => ["~#m", 1496175036723]})
      %{content: "bot message with mentions",
        "group-id": "urn:uuid:570fce10-9312-4550-9525-460c57fd9229",
        id: "urn:uuid:57589564-3a2d-47d9-8334-58c36750d3e8",
        "mentioned-tag-ids": ["urn:uuid:b97d5dcb-6258-4ccd-911e-c5d17b91abb7",
                              "urn:uuid:ce07de0b-9297-4579-809c-15b2150f8259"],
        "mentioned-user-ids": ["urn:uuid:5852ef83-06dd-49b8-af01-51e0c9a52c76"],
        "thread-id": "urn:uuid:5732514a-f909-411d-bf2e-3568de5e0d56",
        "user-id": "urn:uuid:57588b2c-4118-430c-9b74-d2160ec295a4",
        "created-at": ~N[2017-05-30 20:10:36.723]}
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
    UUID.binary_to_string!(<<hi64::64>> <> <<lo64::64>>, :urn)
  end

  defp parse_transit_item(["~#m", msecs]) do
    msecs |> Timex.from_unix(:milliseconds) |> Timex.to_naive_datetime
  end

  defp parse_transit_item(arr) when is_list(arr) do
    Enum.map arr, &parse_transit_item/1
  end

  defp parse_transit_item(x) do
    x
  end

  @doc """
  Unparses a map into a format suitable to being converted to MessagePack or
  JSON and sent back

  ## Example

      iex> BraidMail.Transit.to_transit(
      ...> %{thing: "hello",
      ...> "group-id": "urn:uuid:00210cbc-fdef-465b-a8cd-3a439a3112ae",
      ...> "created-at": ~N[2017-05-30 20:10:36.723],
      ...> "mentions": ["urn:uuid:9bbb5c63-6432-4212-bcd5-c5ed944dd6e4",
      ...>              "urn:uuid:f5bcb891-153f-4b8d-a114-b0260437811d"]})
      %{"~:thing" => "hello",
        "~:group-id" => ["~#u", [9302680085153371, -6283301843087846738]],
        "~:created-at" => ["~#m", 1496175036723],
        "~:mentions" => [["~#u", [-7225079595233295854, -4839744600353679644]],
                         ["~#u", [-739513305529365619, -6839648256742948579]]]}
  """
  def to_transit(map) do
    Enum.into map, %{}, fn {k, v} ->
      {unparse_transit_item(k), unparse_transit_item(v)}
    end
  end

  defp unparse_transit_item(at) when is_atom(at) do
    "~:" <> Atom.to_string(at)
  end

  defp unparse_transit_item(arr) when is_list(arr) do
    Enum.map arr, &unparse_transit_item/1
  end

  defp unparse_transit_item(%NaiveDateTime{} = dt) do
    secs = Timex.to_unix(dt)
    {usecs, _} = dt.microsecond
    ["~#m", (secs * 1000) + round(usecs / 1000)]
  end

  defp unparse_transit_item(("urn:uuid:" <> _) = uuid) do
    <<hi64::64, lo64::64>> = UUID.string_to_binary!(uuid)
    ["~#u", [signed64(hi64), signed64(lo64)]]
  end

  defp unparse_transit_item(x) do
    x
  end

  # Make the given number a signed 64-bit integer
  # We need this for sending UUIDs
  defp signed64(n) do
    use Bitwise
    n - (2 * (n &&& (1 <<< 63)))
  end

end
