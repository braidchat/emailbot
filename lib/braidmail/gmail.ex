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
    route = "https://www.googleapis.com/oauth2/v3/token"
    body = [
      code: code,
      client_id: Application.fetch_env!(:braidmail, :gmail_id),
      client_secret: Application.fetch_env!(:braidmail, :gmail_secret),
      redirect_uri: Application.fetch_env!(:braidmail, :gmail_redirect_uri),
      grant_type: "authorization_code"
    ]
    case HTTPoison.post route, {:form, body}, [] do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        with {:ok, creds} <- Poison.Parser.parse(body),
             %{"access_token" => tok, "refresh_token" => refresh} <- creds,
             user when user != nil <- Repo.get_by(User, braid_id: user_id) do
          user
            |> User.changeset(%{gmail_token: tok, gmail_refresh_token: refresh})
            |> Repo.update()
          BraidMail.Messaging.send_connected_msg(user_id)
        else
          _ -> IO.puts "Failed to store creds: #{inspect body}"
        end
      {:ok, %HTTPoison.Response{status_code: status, body: body}} ->
        IO.puts "Unexpected response #{status}: #{body}"
      {:error, %HTTPoison.Error{reason: reason}} ->
        IO.puts "Something went wrong sending message: #{inspect reason}"
    end
  end

end
