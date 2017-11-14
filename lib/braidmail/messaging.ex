defmodule BraidMail.Messaging do
  @moduledoc """
  Module for handling messages from braid
  """

  alias BraidMail.Braid
  alias BraidMail.Gmail
  alias BraidMail.Repo
  alias BraidMail.Schemas.Thread
  alias BraidMail.Schemas.User

  @connect_success_msg """
  Your gmail account is connected!
  Invoke me with `/~ts help` for a list of things you can do now :)
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
          thread = Repo.get_by(Thread, braid_id: thread_id, user_id: user_id) ->
            handle_email_msg(thread, extract_commands(msg, "/"))
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
  @connect_link_msg """
  Click this link to authorize me to connect to your mail account.
  Make sure this message stays private! Don't mention anyone or add any tags to this thread!
  ~ts
  """

  defp send_initial_msg(%{"user-id": user_id, command: ["connect"]}) do
    Braid.send_message(%{id: UUID.uuid4(:urn),
                         "thread-id": UUID.uuid4(:urn),
                         content: @connect_link_msg
                                  |> :io_lib.format([Gmail.oauth_uri(user_id)])
                                  |> to_string,
                         "mentioned-user-ids": [user_id],
                         "mentioned-tag-ids": []})
  end

  @gmail_signup_msg """
  Hi ~ts! Looks like you haven't connected your gmail account yet.
  Say `/~ts connect` and I'll send you a link to get started.
  """

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

  ## Handling mentions from already connected users
  @connected_help_msg """
  Cool, you're connected! I know the following commands:
  `inbox` - I'll tell you the subject & senders of your email inbox
  `inbox new` - Like `inbox`, but only the unread emails
  `archive <msg-id>` - Mark as read & archive the thread with the given id
  `read <msg-id>` - I'll reply with the body of the email with the given id
  `compose <to-addresses>` - Start composing an email
  `reply <msg-id>` - Start composing a reply to the thread with the given id
  """

  defp handle_mention(%{command: ["help"]} = msg) do
    msg
    |> Braid.make_response(@connected_help_msg)
    |> Braid.send_message
  end

  @show_thread_msg """
  ID: ~ts
  From: ~ts
  Subject: ~ts

  """

  defp handle_mention(%{"user-id": user_id, command: ["inbox" | args]} = msg) do
    cb = fn thread_id, message ->
      with %{id: id, from: frm, subject: sub, is_unread: unread} <- message do
        %{id: UUID.uuid4(:urn),
          "thread-id": thread_id,
          content: @show_thread_msg
                   |> :io_lib.format([id, frm, sub])
                   |> to_string
                   |> maybe_bold(unread),
          "mentioned-user-ids": [user_id],
          "mentioned-tag-ids": []}
        |> Braid.send_message()
      else
        _ ->
          msg
          |> Braid.make_response("No new messages")
          |> Braid.send_message
      end
    end
    Gmail.load_inbox(user_id, args == ["new"], cb)
  end

  defp handle_mention(%{"user-id": user_id, command: ["read", msg_id]} = msg)
  do
    done = fn content ->
      msg
      |> Braid.make_response(content)
      |> Braid.send_message
    end
    Gmail.read_message(user_id, msg_id, done)
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

  @begin_compose_msg """
  Message to ~ts
  Type the body of your email in this thread, sending as many messages as you want.
  Type `/subject <subject>` to set the subject of the email
  When you're done, type `/save` to save a draft or `/send` to send the email
  """
  defp handle_mention(%{"user-id": user_id, command: ["compose" | to_addrs]}) do
    new_thread_id = UUID.uuid4(:urn)

    Repo.insert(%Thread{braid_id: new_thread_id,
                        status: "composing",
                        content: "",
                        user_id: user_id,
                        to: Enum.join(to_addrs, ",")})

    %{id: UUID.uuid4(:urn),
      "thread-id": new_thread_id,
      content: @begin_compose_msg
               |> :io_lib.format([Enum.join(to_addrs, ", ")])
               |> to_string,
      "mentioned-user-ids": [user_id],
      "mentioned-tag-ids": []}
    |> Braid.send_message()

    Braid.watch_thread(new_thread_id)
  end

  @begin_reply_msg """
  Replying to ~ts
  Type the body of your email in this thread, sending as many messages as you want.
  When you're done, type `/save` to save a draft or `/send` to send the email
  """
  defp handle_mention(%{"user-id": user_id, command: ["reply", msg_id]}) do
    new_thread_id = UUID.uuid4(:urn)

    Gmail.load_thread_details(user_id, msg_id,
      fn %{subject: sub, message_id: reply_to_id, from: from} ->
        Repo.insert(%Thread{braid_id: new_thread_id,
                            status: "replying",
                            content: "",
                            user_id: user_id,
                            gmail_id: msg_id,
                            subject: sub,
                            reply_to: reply_to_id,
                            # TODO: get to, subject from thread?
                            to: from})

        %{id: UUID.uuid4(:urn),
        "thread-id": new_thread_id,
        content: @begin_reply_msg |> :io_lib.format([from]) |> to_string,
        "mentioned-user-ids": [user_id],
        "mentioned-tag-ids": []}
        |> Braid.send_message()

        Braid.watch_thread(new_thread_id)
      end)
  end

  @unknown_command_msg """
  Sorry, I don't know what you mean; try `/~ts help` the commands I know
  """

  defp handle_mention(msg) do
    bot_name = Application.fetch_env!(:braidmail, :bot_name)
    msg
    |> Braid.make_response(@unknown_command_msg
                           |> :io_lib.format([bot_name])
                           |> to_string)
    |> Braid.send_message
  end

  ## Messages to subscribed threads

  defp handle_email_msg(%Thread{status: "composing"} = thread,
                        %{command: ["subject" | subject]} = msg)
  do
    subj = Enum.join(subject, " ")

    thread
    |> Thread.changeset(%{subject: subj})
    |> Repo.update

    msg
    |> Braid.make_response("Set subject to #{subj}")
    |> Braid.send_message
  end

  defp handle_email_msg(%Thread{user_id: user_id} = thread,
                        %{command: ["save"]} = msg)
  do
    Gmail.save_draft(user_id, thread, fn ->
      msg
      |> Braid.make_response("Draft saved")
      |> Braid.send_message
    end)
  end

  defp handle_email_msg(%Thread{user_id: user_id} = thread,
                        %{command: ["send"]} = msg)
  do
    Gmail.send_message(user_id, thread, fn ->
      msg
      |> Braid.make_response("Message sent!")
      |> Braid.send_message
    end)
  end

  defp handle_email_msg(%Thread{status: "composing"} = thread, %{content: body})
  do
    {:ok, _} = thread
               |> Thread.append_changeset(body)
               |> Repo.update
  end

  defp handle_email_msg(%Thread{status: "replying"} = thread, %{content: body})
  do
    {:ok, _} = thread
               |> Thread.append_changeset(body)
               |> Repo.update
  end

  defp handle_email_msg(thread, msg) do
    IO.puts("Non-composing thread #{inspect thread} #{inspect msg}")
  end

  ## Helper functions

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
