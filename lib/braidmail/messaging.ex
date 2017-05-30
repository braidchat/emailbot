defmodule BraidMail.Messaging do
  @moduledoc """
  Module for handling messages from braid
  """

  def handle_message(%{content: content} = msg) do
    IO.puts "Received #{content} #{inspect msg}"
  end
end
