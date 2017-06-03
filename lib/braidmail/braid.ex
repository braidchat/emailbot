defmodule BraidMail.Braid do
  @moduledoc """
  Sending messages to a Braid server
  """

  alias BraidMail.Transit

  @doc """
  Send a message to the Braid API endpoint
  """
  def send_message(msg) do
    braid_api = Application.fetch_env!(:braidmail, :braid_api_server)
    user = Application.fetch_env!(:braidmail, :braid_id)
    pass = Application.fetch_env!(:braidmail, :braid_token)
    auth = Base.encode64(user <> ":" <> pass)
    route = braid_api <> "/bots/message"
    body = msg |> Transit.to_transit |> MessagePack.pack!
    headers = [{"Content-Type", "application/transit+msgpack"},
               {"Authorization", "Basic #{auth}"}]
    case HTTPoison.post route, body, headers do
      {:ok, %HTTPoison.Response{status_code: 201}} ->
        IO.puts "Message sent"
      {:ok, %HTTPoison.Response{status_code: status, body: body}} ->
        IO.puts "Unexpected response #{status}: #{body}"
      {:error, %HTTPoison.Error{reason: reason}} ->
        IO.puts "Something went wrong sending message: #{inspect reason}"
    end
  end

  @doc """
  Create a new message that will be in reply to `msg` with the body `reply`.
  """
  def make_response(%{"thread-id": thread_id}, reply) do
    %{id: UUID.uuid4(:urn),
      "thread-id": thread_id,
      content: reply,
      "mentioned-user-ids": [],
      "mentioned-tag-ids": []}
  end

  @doc """
  Register to get all updates for a given thread
  """
  def watch_thread(thread_id) do
    braid_api = Application.fetch_env!(:braidmail, :braid_api_server)
    user = Application.fetch_env!(:braidmail, :braid_id)
    pass = Application.fetch_env!(:braidmail, :braid_token)
    auth = Base.encode64(user <> ":" <> pass)
    route = braid_api <> "/bots/subscribe/" <> strip_prefix(thread_id)
    headers = [{"Authorization", "Basic #{auth}"}]
    case HTTPoison.put route, <<>>, headers do
      {:ok, %HTTPoison.Response{:status_code: 201}} -> IO.puts "Subscribed"
      {:ok, %HTTPoison.Response{status_code: status, body: body}} ->
        IO.puts "Unexpected response subscribing: #{status}: #{body}"
      {:error, %HTTPoison.Error{reason: reason}} ->
        IO.puts "Something went wrong subscribing: #{inspect reason}"
    end
  end

  defp strip_prefix("urn:uuid:" <> uuid), do; uuid
end
