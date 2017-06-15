defmodule BraidMail.Gmail do
  @moduledoc """
  Module for interacting with the Gmail api
  """

  alias BraidMail.Repo
  alias BraidMail.Schemas.User
  alias BraidMail.Schemas.Thread

  @doc """
  Generate a URL to send to the given user which will ask them to authorize us
  """
  def oauth_uri(user_id) do
    token = Base.encode64(:crypto.strong_rand_bytes(15), padding: false)
    BraidMail.Session.store(token, user_id)
    "https://accounts.google.com/o/oauth2/auth?" <>
      URI.encode_query %{
        "response_type" => "code",
        "client_id" => Application.fetch_env!(:braidmail, :gmail_id),
        "redirect_uri" => Application.fetch_env!(:braidmail,
                                                 :gmail_redirect_uri),
        "scope" => "https://www.googleapis.com/auth/gmail.modify",
        "state" => token,
        "access_type" => "offline",
        "approval_prompt" => "force",
      }
  end

  @doc """
  Given state token from OAuth, returning the associated user id if valid
  """
  def verify_state(state) do
    BraidMail.Session.pop(state)
  end

  @doc """
  Perform OAuth code exchange and save the token & refresh token in the database
  """
  def exchange_code(user_id, code) do
    send_auth_req([code: code,
                   grant_type: "authorization_code",
                   redirect_uri: Application.fetch_env!(:braidmail,
                                                        :gmail_redirect_uri)],
                  fn %{"access_token" => tok, "refresh_token" => refresh} ->
                    user = Repo.get_by(User, braid_id: user_id)
                    user
                    |> User.changeset(%{gmail_token: tok,
                                        gmail_refresh_token: refresh})
                    |> Repo.update()

                    BraidMail.Messaging.send_connected_msg(user_id)
                  end)
  end

  @doc """
  Refresh Gmail auth token
  """
  def refresh_token(user_id, refresh_token, done) do
    send_auth_req([refresh_token: refresh_token, grant_type: "refresh_token"],
                  fn %{"access_token" => tok} ->
                    user = Repo.get_by(User, braid_id: user_id)
                    user
                    |> User.changeset(%{gmail_token: tok})
                    |> Repo.update()
                    done.()
                  end)
  end

  # Helper function for exchanging code or refresh token for bearer token
  defp send_auth_req(params, success) do
    route = "https://www.googleapis.com/oauth2/v3/token"
    body = params ++ [
      client_id: Application.fetch_env!(:braidmail, :gmail_id),
      client_secret: Application.fetch_env!(:braidmail, :gmail_secret),
    ]
    case HTTPoison.post route, {:form, body}, [] do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Poison.decode(body) do
          {:ok, creds} -> success.(creds)
          _ -> IO.puts "Failed to store creds: #{inspect body}"
        end
      {:ok, %HTTPoison.Response{status_code: status, body: body}} ->
        IO.puts "Unexpected response #{status}: #{body}"
      {:error, %HTTPoison.Error{reason: reason}} ->
        IO.puts "Something went wrong sending message: #{inspect reason}"
    end
  end

  @doc """
  Get the contents of the inbox for the user with braid id `user_id`.
  The callback `done` will be called for each thread thusly loaded.
  """
  def load_inbox(user_id, just_unread, done) do
    braid_thread_id = UUID.uuid4(:urn)
    user = Repo.get_by(User, braid_id: user_id)

    find_header = fn headers, field ->
      Enum.find headers, fn %{"name" => name} ->
        name == field
      end
    end

    load_thread_details = fn thread_id ->
      # Re-load user to get refreshed token
      user = Repo.get_by(User, braid_id: user_id)
      path = "/threads/" <> thread_id
      params = [{"format", "METADATA"},
                {"metadataHeaders", "Subject"},
                {"metadataHeaders", "From"},
                {"fields", "id,messages(payload/headers,labelIds)"}
              ]
        api_request(%{endpoint: path, params: params}, user, fn thread ->
          with %{"id" => id, "messages" => [msg | _]} <- thread,
               %{"labelIds" => labels} <- msg,
               %{"payload" => %{"headers" => headers}} <- msg,
               %{"value" => from} <- find_header.(headers, "From"),
               %{"value" => subject} <- find_header.(headers, "Subject") do
            done.(braid_thread_id,
                  %{id: id,
                    from: from,
                    subject: subject,
                    is_unread: Enum.find(labels, &(&1 == "UNREAD")) != nil
                  })
          end
        end)
    end

    params = [{"labelIds", "INBOX"},
              {"fields", "threads/id"}] ++
             if just_unread, do: [{"labelIds", "UNREAD"}], else: []
    api_request(%{endpoint: "/threads", params: params}, user,
                fn resp ->
                  with %{"threads" => threads} <- resp do
                    for %{"id" => thread_id} <- threads do
                      spawn fn -> load_thread_details.(thread_id) end
                    end
                  else
                    _ -> done.(braid_thread_id, nil)
                  end
                end)
  end

  def archive_message(user_id, msg_id, done) do
    api_request(%{endpoint: "/threads/#{msg_id}/modify",
                  method: :post,
                  body: Poison.encode!(%{removeLabelIds: ["INBOX", "UNREAD"]}),
                  headers: [{"content-type", "application/json"}]},
                Repo.get_by(User, braid_id: user_id),
                fn _ -> done.() end)
  end

  def read_message(user_id, thread_id, done) do
    user = Repo.get_by(User, braid_id: user_id)
    api_request(%{endpoint: "/threads/#{thread_id}",
                  params: [{"fields", "messages/payload/parts"}]},
                user,
                fn %{"messages" => messages} ->
                  %{"payload" => %{"parts" => parts}} = List.last messages

                  parts
                  |> Enum.find(parts, &(&1["mimeType"] == "text/plain"))
                  |> Map.get("body")
                  |> Map.get("data")
                  |> String.replace("-", "+")
                  |> String.replace("_", "/")
                  |> Base.decode64!
                  |> done.()
                end)

    api_request(%{endpoint: "/threads/#{thread_id}/modify",
                  method: :post,
                  body: Poison.encode!(%{removeLabelIds: ["UNREAD"]}),
                  headers: [{"content-type", "application/json"}]},
                user,
                fn _ -> done.() end)
  end

  def save_draft(user_id,
                 %Thread{to: to, subject: subj, content: content} = thread,
                 done)
  do
    body = ["To: #{to}", "Subject: #{subj}", "\r\n#{content}"]
           |> Enum.join("\r\n")
           |> Base.encode64
           |> String.replace("+", "-")
           |> String.replace("/", "_")

    api_request(%{endpoint: "/drafts",
                  method: :post,
                  body: Poison.encode!(%{message: %{raw: body}}),
                  headers: [{"content-type", "application/json"}]},
                Repo.get_by(User, braid_id: user_id),
                fn %{"id" => msg_id} ->
                  thread
                  |> Thread.changeset(%{gmail_id: msg_id})
                  |> Repo.update

                  done.()
                end)
  end

  def send_message(user_id,
                   %Thread{to: to, subject: subj, content: content} = thread,
                   done)
  do
    body = ["To: #{to}", "Subject: #{subj}", "\r\n#{content}"]
           |> Enum.join("\r\n")
           |> Base.encode64
           |> String.replace("+", "-")
           |> String.replace("/", "_")

    api_request(%{endpoint: "/messages/send",
                  method: :post,
                  body: Poison.encode!(%{raw: body}),
                  headers: [{"content-type", "application/json"}]},
                Repo.get_by(User, braid_id: user_id),
                fn _ ->
                  thread
                  |> Thread.changeset(%{status: "sent"})
                  |> Repo.update

                  done.()
                end)
  end

  defp api_request(req, %User{gmail_token: tok} = user, done, retried \\ false)
  do
    endpoint = req[:endpoint]
    method = Map.get(req, :method, :get)
    params = Map.get(req, :params, [])
    headers = Map.get(req, :headers, [])
    body = Map.get(req, :body, <<>>)
    uri = "https://www.googleapis.com/gmail/v1/users/me" <> endpoint
    headers = [{"authorization", "Bearer " <> tok}] ++ headers
    case HTTPoison.request method, uri, body, headers, params: params do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Poison.decode(body) do
          {:ok, threads} -> done.(threads)
          _ -> IO.puts "Failed to load inbox: #{inspect body}"
        end
      {:ok, %HTTPoison.Response{status_code: 401}} when not retried ->
        IO.puts "need to refresh"
        %User{braid_id: user_id, gmail_refresh_token: refresh_tok} = user
        refresh_token(user_id, refresh_tok,
                      fn ->
                        user = Repo.get_by(User, braid_id: user_id)
                        api_request(req, user, done, true)
                      end)
      {:ok, %HTTPoison.Response{status_code: status, body: body}} ->
        IO.puts "Unexpected response: #{status} #{body}"
      {:error, %HTTPoison.Error{reason: reason}} ->
        IO.puts "Error fetching inbox: #{inspect reason}"
    end
  end

end
