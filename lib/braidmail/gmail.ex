defmodule BraidMail.Gmail do
  @moduledoc """
  Module for interacting with the Gmail api
  """

  alias BraidMail.Repo
  alias BraidMail.Schemas.User

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
    send_auth_req([code: code, grant_type: "authorization_code"],
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
        case Poison.Parser.parse(body) do
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
  Get the contents of the inbox for the given user
  """
  def load_inbox(user_id, done) do
    user = Repo.get_by(User, braid_id: user_id)
    inbox_request(user, done)
  end

  defp inbox_request(%User{gmail_token: tok} = user, done, retried \\ false) do
    route = "https://www.googleapis.com/gmail/v1/users/me/threads"
    headers = [{"authorization", "Bearer " <> tok}]
    case HTTPoison.get route, headers do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Poison.Parser.parse(body) do
          {:ok, threads} -> done.(threads)
          _ -> IO.puts "Failed to load inbox: #{inspect body}"
        end
      {:ok, %HTTPoison.Response{status_code: 401}} when not retried ->
        IO.puts "need to refresh"
        %User{braid_id: user_id, gmail_refresh_token: refresh_tok} = user
        refresh_token(user_id, refresh_tok,
                      fn ->
                        user = Repo.get_by(User, braid_id: user_id)
                        inbox_request(user, done, true)
                      end)
      {:ok, %HTTPoison.Response{status_code: status, body: body}} ->
        IO.puts "Unexpected response: #{status} #{body}"
      {:error, %HTTPoison.Error{reason: reason}} ->
        IO.puts "Error fetching inbox: #{inspect reason}"
    end
  end

end
