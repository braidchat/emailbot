defmodule BraidMail.Messaging do
  @moduledoc """
  Module for handling messages from braid
  """

  alias BraidMail.Braid

  def handle_message(%{content: body} = msg) do
    bot_name = Application.fetch_env!(:braidmail, :bot_name)
    prefix = "/" <> bot_name <> " "
    if String.starts_with?(body, prefix) do
      handle_mention(msg)
    else
      IO.puts "Got message #{body}"
    end
  end

  defp handle_mention(msg) do
    IO.puts "Mentioned: #{inspect msg}"
    msg |> Braid.make_response("Hello there!") |> Braid.send_message
  end
end
