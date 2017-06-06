defmodule BraidMail.Gmail do
  @moduledoc """
  Module for interacting with the Gmail api
  """

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
  Perform OAuth code exchange
        {:type "gmail"
                     :access-token access_token
                     :id-token id_token
                     :refresh-token refresh_token
                     :expires-in expires_in}
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
    case HTTPoison.post route, body, [] do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, creds} = Poison.Parser.parse(body)
        IO.puts "Got token #{creds}"
      {:ok, %HTTPoison.Response{status_code: status, body: body}} ->
        IO.puts "Unexpected response #{status}: #{body}"
      {:error, %HTTPoison.Error{reason: reason}} ->
        IO.puts "Something went wrong sending message: #{inspect reason}"
    end
  end

end
