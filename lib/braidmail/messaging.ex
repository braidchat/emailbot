defmodule BraidMail.Messaging do
  @moduledoc """
  Module for handling messages from braid
  """

  alias BraidMail.Braid
  alias BraidMail.Repo
  alias BraidMail.Schemas.User

  def handle_message(%{content: body, "thread-id": thread_id} = msg) do
    bot_name = Application.fetch_env!(:braidmail, :bot_name)
    prefix = "/" <> bot_name <> " "
    if String.starts_with?(body, prefix) do
      handle_mention(msg)
    else
      IO.puts "Got message #{body}"
    end
  end

  @usage_msg """
  Hi, I'm the email bot!
  I can help you manage your gmail inbox from braid
  """

  defp handle_mention(%{"user-id": user_id} = msg) do
    IO.puts "Mentioned: #{inspect msg}"
    if Repo.get_by(User, braid_id: user_id) do
      msg
        |> Braid.make_response("Hi again! " <> uuid2mention(user_id))
        |> add_mentioned(user_id)
        |> Braid.send_message
    else
      Repo.insert(%User{braid_id: user_id})
      msg |> Braid.make_response(@usage_msg) |> Braid.send_message
    end
  end

  defp uuid2mention("urn:uuid:" <> uuid) do
    "@" <> uuid
  end

  defp add_mentioned(%{"mentioned-user-ids": mentions} = msg, user_id) do
    %{msg | "mentioned-user-ids": [user_id | mentions]}
  end
end
