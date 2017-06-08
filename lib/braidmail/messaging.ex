defmodule BraidMail.Messaging do
  @moduledoc """
  Module for handling messages from braid
  """

  alias BraidMail.Braid
  alias BraidMail.Gmail
  alias BraidMail.Repo
  alias BraidMail.Schemas.Thread
  alias BraidMail.Schemas.User

  # Various message strings that will be sent
  @gmail_signup_msg """
  Hi ~s! Looks like you haven't connected your gmail account yet.
  Say `/~s connect` and I'll send you a link to get started.
  """

  @connect_link_msg """
  Click this link to authorize me to connect to your mail account.
  Make sure this message stays private! Don't mention anyone or add any tags to this thread!
  ~s
  """

  @connect_success_msg """
  Your gmail account is connected!
  Invoke me with `/~s help` for a list of things you can do now :)
  """

  @connected_help_msg """
  Cool, you're connected! I know the following commands:
  `inbox` - I'll tell you the subject & senders of your email inbox
  `inbox new` - Like `inbox`, but only the unread emails
  `archive <msg-id>` - Mark as read & archive the thread with the given id
  `compose` - I'll start a new thread you can use to compose an email
  """

  @doc """
  Send a message to the given user after their gmail account has been connected
  """
  def send_connected_msg(user_id) do
    bot_name = Application.fetch_env!(:braidmail, :bot_name)
    Braid.send_message(%{id: UUID.uuid4(:urn),
                         "thread-id": UUID.uuid4(:urn),
                         content: @connect_success_msg
                                  |> :io_lib.format([bot_name])
                                  |> to_string,
                         "mentioned-user-ids": [user_id],
                         "mentioned-tag-ids": []})
  end

  @doc """
  Entry point for receiving messages from Braid
  """
  def handle_message(%{"user-id": user_id, content: body,
                       "thread-id": thread_id} = msg) do
    bot_name = Application.fetch_env!(:braidmail, :bot_name)
    prefix = "/" <> bot_name <> " "
    case Repo.get_by(User, braid_id: user_id) do
      %User{gmail_token: tok} when tok != nil ->
        cond do
          String.starts_with?(body, prefix) ->
            msg
            |> extract_commands(prefix)
            |> handle_mention()
          Repo.get_by(Thread, braid_id: thread_id) -> handle_email_msg(msg)
          true -> IO.puts "Got message #{body}"
        end
      %User{} ->
        msg
        |> extract_commands(prefix)
        |> send_initial_msg()
      _ ->
        Repo.insert(%User{braid_id: user_id})
        msg
        |> extract_commands(prefix)
        |> send_initial_msg()
    end
  end

  # Handle mentions from a user who is not yet connected to gmail
  defp send_initial_msg(%{"user-id": user_id, command: ["connect"]}) do
    Braid.send_message(%{id: UUID.uuid4(:urn),
                         "thread-id": UUID.uuid4(:urn),
                         content: @connect_link_msg
                                  |> :io_lib.format([Gmail.oauth_uri(user_id)])
                                  |> to_string,
                         "mentioned-user-ids": [user_id],
                         "mentioned-tag-ids": []})
  end

  defp send_initial_msg(%{"user-id": user_id} = msg) do
    bot_name = Application.fetch_env!(:braidmail, :bot_name)
    msg
    |> Braid.make_response(
        @gmail_signup_msg
        |> :io_lib.format([uuid2mention(user_id), bot_name])
        |> to_string)
    |> add_mentioned(user_id)
    |> Braid.send_message
  end

  # Handling mentions from already connected users
  defp handle_mention(%{command: ["help"]} = msg) do
    msg
    |> Braid.make_response(@connected_help_msg)
    |> Braid.send_message
  end

  @show_thread_msg """
  ID: ~s
  From: ~s
  Subject: ~s

  """

  defp handle_mention(%{"user-id": user_id, command: ["inbox" | args]}) do
    cb = fn thread_id, %{id: id, from: frm, subject: sub, is_unread: unread} ->
      %{id: UUID.uuid4(:urn),
        "thread-id": thread_id,
        content: @show_thread_msg
                 |> :io_lib.format([id, frm, sub])
                 |> to_string
                 |> maybe_bold(unread),
        "mentioned-user-ids": [user_id],
        "mentioned-tag-ids": []}
      |> Braid.send_message()
    end
    Gmail.load_inbox(user_id, args == ["new"], cb)
  end

  defp handle_mention(%{"user-id": user_id, command: ["archive", msg_id]} = msg)
  do
    done = fn ->
      msg
      |> Braid.make_response("Archived #{msg_id}")
      |> Braid.send_message
    end
    Gmail.archive_message(user_id, msg_id, done)
  end


  defp handle_mention(%{command: ["compose"]} = msg) do
    msg
    |> Braid.make_response("Sorry, still a work in progress")
    |> Braid.send_message
  end

  defp handle_mention(%{"user-id": user_id} = msg) do
    # TODO: send some sort of status info to already connected user
    msg
    |> Braid.make_response("Hi again! " <> uuid2mention(user_id))
    |> add_mentioned(user_id)
    |> Braid.send_message
  end

  defp handle_email_msg(%{content: _body, "thread-id": _thread_id} = _msg) do
  end

  defp uuid2mention("urn:uuid:" <> uuid) do
    "@" <> uuid
  end

  defp add_mentioned(%{"mentioned-user-ids": mentions} = msg, user_id) do
    %{msg | "mentioned-user-ids": [user_id | mentions]}
  end

  defp extract_commands(%{content: content} = msg, prefix) do
    command = content
              |> String.replace_prefix(prefix, "")
              |> String.split(~r(\s+))
    Map.put(msg, :command, command)
  end

  defp maybe_bold(content, true) do
      "*" <> content <> "*"
  end
  defp maybe_bold(content, false) do
    content
  end

end
